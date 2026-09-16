# vfs.Containerfile
# Purpose: Hands-on VFS lab. Create custom filesystems (tmpfs, overlayfs, FUSE),
#          observe dentry/inode cache behavior, inspect mount namespaces, and trace
#          VFS operations.
# Build:  podman build -f vfs.Containerfile -t vfs-lab .
# Run:    podman run -it --rm --privileged vfs-lab
# Notes:  --privileged is required for mount, FUSE, and bpftrace probes.

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    fuse3 \
    fuse-common \
    python \
    strace \
    util-linux \
    e2fsprogs \
    bpftrace \
    btrfs-progs \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /lab/mnt1 /lab/mnt2 /lab/upper /lab/work /lab/merged /lab/fuse

# ------------------------------------------------------------
# Simple FUSE filesystem (Python) - a memory-backed fs
# ------------------------------------------------------------
COPY <<'FUSE_PY' /lab/memfs.py
#!/usr/bin/env python3
"""Minimal FUSE memory-backed filesystem - demonstrates VFS pluggability."""
import os, sys, stat, errno, time
from collections import defaultdict

# FUSE Python bindings may not be installed - use fusepy
try:
    from fuse import FUSE, FuseOSError, Operations, LoggingMixIn
except ImportError:
    print("Installing fusepy...", file=sys.stderr)
    import subprocess
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--break-system-packages", "fusepy"])
    from fuse import FUSE, FuseOSError, Operations, LoggingMixIn


class MemFS(LoggingMixIn, Operations):
    """A filesystem that lives entirely in memory. Files stored in dict."""

    def __init__(self):
        self.files = defaultdict(lambda: {
            'content': b'',
            'attrs': {
                'st_mode': 0,
                'st_nlink': 1,
                'st_uid': os.getuid(),
                'st_gid': os.getgid(),
                'st_size': 0,
                'st_atime': time.time(),
                'st_mtime': time.time(),
                'st_ctime': time.time(),
            }
        })
        self.files['/']['attrs']['st_mode'] = stat.S_IFDIR | 0o755
        self.files['/']['attrs']['st_nlink'] = 2

    def _get_path(self, path):
        path = '/' + path.lstrip('/')
        return path

    def getattr(self, path, fh=None):
        path = self._get_path(path)
        if path not in self.files:
            raise FuseOSError(errno.ENOENT)
        return self.files[path]['attrs']

    def readdir(self, path, fh=None):
        path = self._get_path(path)
        entries = ['.', '..']
        prefix = path.rstrip('/') + '/'
        if path != '/':
            prefix_len = len(prefix)
            for p in self.files:
                if p.startswith(prefix) and '/' not in p[prefix_len:]:
                    entries.append(p[prefix_len:])
        return entries

    def mknod(self, path, mode, dev):
        path = self._get_path(path)
        self.files[path]['attrs']['st_mode'] = mode
        self.files[path]['attrs']['st_atime'] = time.time()
        self.files[path]['attrs']['st_mtime'] = time.time()
        self.files[path]['attrs']['st_ctime'] = time.time()
        return 0

    def create(self, path, mode, fi=None):
        path = self._get_path(path)
        self.files[path]['attrs']['st_mode'] = stat.S_IFREG | mode
        self.files[path]['attrs']['st_size'] = 0
        self.files[path]['content'] = b''
        return 0

    def write(self, path, buf, offset, fh=None):
        path = self._get_path(path)
        data = self.files[path]['content']
        if offset + len(buf) > len(data):
            data = data.ljust(offset) + b'\x00' * (offset - len(data)) if offset > len(data) else data[:offset]
            data += buf
        else:
            data = data[:offset] + buf + data[offset + len(buf):]
        self.files[path]['content'] = data
        self.files[path]['attrs']['st_size'] = len(data)
        self.files[path]['attrs']['st_mtime'] = time.time()
        return len(buf)

    def read(self, path, length, offset, fh=None):
        path = self._get_path(path)
        data = self.files[path]['content']
        if offset >= len(data):
            return b''
        return data[offset:offset + length]

    def unlink(self, path):
        path = self._get_path(path)
        if path in self.files:
            del self.files[path]
        return 0

    def mkdir(self, path, mode):
        path = self._get_path(path)
        self.files[path]['attrs']['st_mode'] = stat.S_IFDIR | mode
        self.files[path]['attrs']['st_nlink'] = 2
        if path != '/':
            dir_path = os.path.dirname(path)
            if dir_path in self.files:
                self.files[dir_path]['attrs']['st_nlink'] += 1
        return 0

    def rmdir(self, path):
        path = self._get_path(path)
        if path != '/':
            dir_path = os.path.dirname(path)
            if dir_path in self.files:
                self.files[dir_path]['attrs']['st_nlink'] -= 1
        if path in self.files:
            # ensure empty
            del self.files[path]
        return 0

    def chmod(self, path, mode):
        path = self._get_path(path)
        self.files[path]['attrs']['st_mode'] = (self.files[path]['attrs']['st_mode'] & ~0o7777) | mode
        return 0

    def statfs(self, path):
        return {
            'f_bsize': 4096,
            'f_blocks': 100000,
            'f_bfree': 90000,
            'f_bavail': 90000,
            'f_files': 10000,
            'f_ffree': 9000,
        }


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('mountpoint')
    args = parser.parse_args()

    fuse = FUSE(
        MemFS(),
        args.mountpoint,
        foreground=True,
        allow_other=False,
        nothreads=True,
    )
FUSE_PY

RUN chmod +x /lab/memfs.py

# ------------------------------------------------------------
# VFS tracing script
# ------------------------------------------------------------
COPY <<'TRACE_VFS' /lab/trace_vfs.sh
#!/bin/bash
# Trace all VFS operations for a command
set -e
echo "=== VFS Operation Trace ==="
echo "Command: $@"
echo ""

# Count VFS operations
strace -e trace=openat,read,write,close,stat,newfstatat,lstat,mkdir,rmdir,unlink,rename,link,symlink,chmod,chown,readlink \
    -c "$@" 2>/tmp/vfs_strace.txt

cat /tmp/vfs_strace.txt

echo ""
echo "-- Dentry cache state --"
cat /proc/sys/fs/dentry-state

echo ""
echo "-- Inode cache state --"
cat /proc/sys/fs/inode-nr
TRACE_VFS

RUN chmod +x /lab/trace_vfs.sh

# ------------------------------------------------------------
# Entrypoint
# ------------------------------------------------------------
COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

cat << 'BANNER'
+==============================================================+
|          VFS Lab - Virtual File System Exploration          |
+==============================================================+

This container demonstrates the Linux VFS layer hands-on.
You will create custom filesystems, explore dentry/inode caches,
and trace VFS operations in real-time.

===============================================================
EXERCISE 1: Explore the four VFS objects
===============================================================

  echo "=== Superblocks ==="
  findmnt -o TARGET,SOURCE,FSTYPE | head -15

  echo "=== Inode cache ==="
  cat /proc/sys/fs/inode-nr

  echo "=== Dentry cache ==="
  cat /proc/sys/fs/dentry-state

  echo "=== Open files (file objects) ==="
  ls -la /proc/$$/fd/


===============================================================
EXERCISE 2: Create a tmpfs - instant mount with new superblock
===============================================================

  mkdir -p /lab/mnt1
  mount -t tmpfs none /lab/mnt1
  findmnt /lab/mnt1

  # Create files - observe they live in memory (tmpfs)
  echo "Hello from VFS!" > /lab/mnt1/test.txt
  cat /lab/mnt1/test.txt

  # tmpfs operations - inode is created, dentry is cached
  /lab/trace_vfs.sh ls -la /lab/mnt1/

  # Clean up
  umount /lab/mnt1


===============================================================
EXERCISE 3: Overlay filesystem - layered VFS
===============================================================

  mkdir -p /lab/{lower,upper,work,merged}

  # Lower layer (read-only base)
  echo "base config" > /lab/lower/config.txt
  echo "base data" > /lab/lower/data.txt

  # Mount overlay (upper=writable, lower=read-only)
  mount -t overlay overlay \
    -o lowerdir=/lab/lower,upperdir=/lab/upper,workdir=/lab/work \
    /lab/merged

  echo "=== Read from lower ==="
  cat /lab/merged/config.txt

  echo "=== Write: copy-up to upper ==="
  echo "modified" > /lab/merged/config.txt
  echo "new file" > /lab/merged/extra.txt

  echo "=== Upper now has modified + new ==="
  ls -la /lab/upper/
  cat /lab/upper/config.txt

  echo "=== Lower unchanged ==="
  cat /lab/lower/config.txt

  umount /lab/merged


===============================================================
EXERCISE 4: FUSE filesystem - implement a VFS driver in userspace
===============================================================

  mkdir -p /lab/fuse

  # Start FUSE memory filesystem in background
  python3 /lab/memfs.py /lab/fuse &
  FUSE_PID=$!
  sleep 1

  # Interact with the in-memory filesystem
  echo "Hello FUSE!" > /lab/fuse/greeting.txt
  cat /lab/fuse/greeting.txt
  echo "Another file" > /lab/fuse/second.txt
  ls -la /lab/fuse/

  # Despite being "files", everything is in Python dicts!
  # The VFS dispatches read/write to our MemFS class
  echo "File 3" > /lab/fuse/third.txt
  cat /lab/fuse/third.txt

  fusermount3 -u /lab/fuse
  kill $FUSE_PID 2>/dev/null || true


===============================================================
EXERCISE 5: Pathname resolution tracing
===============================================================

  # namei walks the path like the kernel
  namei -l /etc/ssl/certs/ca-certificates.crt

  # strace shows the VFS syscalls
  /lab/trace_vfs.sh cat /etc/hostname


===============================================================
EXERCISE 6: Dentry and inode cache behavior
===============================================================

  echo "=== Before: dentry state ==="
  cat /proc/sys/fs/dentry-state

  echo "=== Creating 1000 small files ==="
  mkdir -p /tmp/dcache_test
  for i in $(seq 1 1000); do
      echo "data" > /tmp/dcache_test/file_$i
  done

  echo "=== Accessing all files (fills dcache) ==="
  cat /tmp/dcache_test/file_* > /dev/null

  echo "=== After: dentry state ==="
  cat /proc/sys/fs/dentry-state

  echo "=== Drop caches (evicts dentries + inodes) ==="
  echo 2 > /proc/sys/vm/drop_caches

  echo "=== After drop: dentry state ==="
  cat /proc/sys/fs/dentry-state

  rm -rf /tmp/dcache_test


===============================================================
EXERCISE 7: bpftrace VFS hooks
===============================================================

  echo "=== Tracing VFS operations (5 second capture) ==="
  timeout 5 bpftrace -e '
  kprobe:vfs_open    { @opens[comm] = count(); }
  kprobe:vfs_read    { @reads[comm] = count(); }
  kprobe:vfs_write   { @writes[comm] = count(); }
  END { printf("\nVFS opens:\n"); print(@opens);
        printf("VFS reads:\n"); print(@reads);
        printf("VFS writes:\n"); print(@writes); }
  ' 2>/dev/null || echo "(bpftrace may need SYS_ADMIN or privileged mode)"

  # If bpftrace works:
  # Trigger some VFS operations while it runs
  find /etc -name "*.conf" -exec cat {} \; > /dev/null 2>&1 &


===============================================================
EXERCISE 8: Mount namespaces
===============================================================

  echo "=== Current mount namespace ==="
  readlink /proc/$$/ns/mnt

  echo "=== Creating isolated mount namespace ==="
  unshare -m bash -c '
    echo "Inside new mnt ns: \$(readlink /proc/\$\$/ns/mnt)"

    # Mount tmpfs in this namespace
    mkdir -p /secret
    mount -t tmpfs none /secret
    echo "PRIVATE DATA" > /secret/private.txt
    ls -la /secret/

    echo "=== Namespace\'s mounts ==="
    findmnt -o TARGET,SOURCE,FSTYPE | grep secret

    # Exit - namespace destroyed, mount disappears
  '

  echo "=== Back in original namespace ==="
  ls /secret/ 2>&1 || echo "/secret does not exist here"


===============================================================
EXERCISE 9: Filesystem type registration
===============================================================

  echo "=== Registered filesystem types ==="
  cat /proc/filesystems

  echo "=== Filesystem kernel modules ==="
  ls /sys/fs/
  ls /sys/module/ | grep -E "ext4|btrfs|fuse|overlay|tmpfs|proc"

  echo "=== ext4 superblock info ==="
  DEV=$(findmnt -n -o SOURCE / 2>/dev/null | head -1)
  if [ -n "$DEV" ]; then
    dumpe2fs -h "$DEV" 2>/dev/null | head -20 || echo "(not ext4 or no device)"
  fi


===============================================================
EXERCISE 10: Filesystem mountinfo deep dive
===============================================================

  echo "=== /proc/self/mountinfo - full mount table ==="
  cat /proc/self/mountinfo | head -5

  echo ""
  echo "=== Column meanings: ==="
  echo "mount_id parent_id major:minor root mount_point options tags - fstype source options"
  echo ""
  echo "Parse key fields:"
  cat /proc/self/mountinfo | awk -F' ' '{
      printf("id=%-4s parent=%-4s dev=%-8s mount=%-20s fstype=%-8s source=%s\n",
             $1, $2, $3, $5, $NF-2, $NF)
  }' | head -15

BANNER

exec /bin/bash
ENTRY

RUN chmod +x /entrypoint.sh

WORKDIR /lab
ENTRYPOINT ["/entrypoint.sh"]

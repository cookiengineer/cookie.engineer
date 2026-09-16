# Page Cache Lab - Cache Behavior, Writeback, and O_DIRECT
# Purpose: Demonstrates the Linux page cache hands-on. Students observe page
#          cache population, dirty page writeback, read-ahead, O_DIRECT
#          bypass, and mmap() cache sharing.
# Build:  podman build -f sysinternals/page-cache.Containerfile -t page-cache-lab .
# Run:    podman run -it --rm --privileged page-cache-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    util-linux \
    python \
    bpftrace \
    strace \
    fio \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /lab /lab/data

# ────────────────────────────────────────────────────────────
# Helper scripts
# ────────────────────────────────────────────────────────────
COPY <<'CACHESTAT' /lab/cachestat.sh
#!/bin/bash
# Periodically display page cache statistics
set -e

INTERVAL=${1:-1}
COUNT=${2:-10}

echo "════ Page Cache Monitor ════"
echo "Interval: ${INTERVAL}s, Count: $COUNT"
echo ""

for i in $(seq 1 $COUNT); do
    CACHED=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
    DIRTY=$(grep "^Dirty:" /proc/meminfo | awk '{print $2}')
    WB=$(grep "^Writeback:" /proc/meminfo | awk '{print $2}')
    BUFFERS=$(grep "^Buffers:" /proc/meminfo | awk '{print $2}')
    
    printf "[%3d] Cached: %8d kB | Dirty: %8d kB | Writeback: %8d kB | Buffers: %8d kB\n" \
        $i $CACHED ${DIRTY:-0} ${WB:-0} $BUFFERS
    
    sleep $INTERVAL
done
CACHESTAT

COPY <<'DIRTYWATCH' /lab/dirtywatch.sh
#!/bin/bash
# Watch dirty page counts in real-time
set -e

echo "Watching dirty pages. Press Ctrl+C to stop."
echo ""
echo "Thresholds:"
echo "  dirty_background_ratio = $(sysctl -n vm.dirty_background_ratio)% ($(sysctl -n vm.dirty_background_bytes 2>/dev/null || echo 'not set'))"
echo "  dirty_ratio            = $(sysctl -n vm.dirty_ratio)% ($(sysctl -n vm.dirty_bytes 2>/dev/null || echo 'not set'))"
echo "  dirty_expire_centisecs = $(sysctl -n vm.dirty_expire_centisecs) (cs)"
echo "  dirty_writeback_centisecs = $(sysctl -n vm.dirty_writeback_centisecs) (cs)"
echo ""

while true; do
    DIRTY=$(grep "^Dirty:" /proc/meminfo | awk '{print $2}')
    TOTAL_DIRTY=$(grep "^nr_dirty " /proc/vmstat | awk '{print $2}')
    TOTAL_WB=$(grep "^nr_writeback " /proc/vmstat | awk '{print $2}')
    THRESH=$(grep "^nr_dirty_threshold " /proc/vmstat | awk '{print $2}')
    BG_THRESH=$(grep "^nr_dirty_background_threshold " /proc/vmstat | awk '{print $2}')
    
    printf "\rDirty: %6d kB | WB: %6d | dirty_pages: %8d / %8d (threshold) / %8d (bg)" \
        ${DIRTY:-0} ${TOTAL_WB:-0} ${TOTAL_DIRTY:-0} ${THRESH:-0} ${BG_THRESH:-0}
    
    sleep 0.5
done
DIRTYWATCH

COPY <<'FIO_CACHETEST' /lab/cachebench.fio
[read-cached]
rw=read
bs=4k
size=200M
direct=0
ioengine=psync
numjobs=1
filename=/lab/data/cachetest.0
runtime=10
time_based=1
FIO_CACHETEST

COPY <<'FIO_DIRECTTEST' /lab/directbench.fio
[read-direct]
rw=read
bs=4k
size=200M
direct=1
ioengine=psync
numjobs=1
filename=/lab/data/cachetest.0
runtime=10
time_based=1
FIO_DIRECTTEST

RUN chmod +x /lab/cachestat.sh /lab/dirtywatch.sh

# ────────────────────────────────────────────────────────────
# Python cache residency checker (no fincore needed)
# ────────────────────────────────────────────────────────────
COPY <<'FINCORE_PY' /lab/fincore.py
#!/usr/bin/env python3
"""Show page cache residency for files using mincore(2)."""
import os, sys, mmap

def fincore(filepath):
    try:
        fd = os.open(filepath, os.O_RDONLY)
        st = os.fstat(fd)
        if st.st_size == 0:
            os.close(fd)
            return 0, 0
        m = mmap.mmap(fd, st.st_size, mmap.MAP_SHARED, mmap.PROT_READ)
        pagesize = os.sysconf('SC_PAGE_SIZE')
        num_pages = (st.st_size + pagesize - 1) // pagesize
        vec = m.mincore()
        cached = sum(1 for v in vec if v)
        m.close()
        os.close(fd)
        return cached, num_pages
    except Exception as e:
        return 0, 0

if __name__ == '__main__':
    for path in sys.argv[1:]:
        if not os.path.exists(path):
            print(f"{path}: not found")
            continue
        cached, total = fincore(path)
        size_kb = os.path.getsize(path) // 1024
        if total > 0:
            print(f"{path}: {cached}/{total} pages ({size_kb} KB, {cached*100//total}% cached)")
        else:
            print(f"{path}: 0 pages ({size_kb} KB)")
FINCORE_PY

RUN chmod +x /lab/fincore.py
RUN ln -s /lab/fincore.py /usr/local/bin/fincore 2>/dev/null || true

# ────────────────────────────────────────────────────────────
# Entrypoint
# ────────────────────────────────────────────────────────────
COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

cat << 'BANNER'
╔══════════════════════════════════════════════════════════════╗
║      Page Cache Lab — Cache, Writeback, and Direct I/O     ║
╚══════════════════════════════════════════════════════════════╝

This container demonstrates the Linux page cache hands-on.
You will populate the cache, observe dirty page writeback,
compare buffered vs direct I/O, and trace cache operations.

═══════════════════════════════════════════════════════════════
EXERCISE 1: Baseline page cache inspection
═══════════════════════════════════════════════════════════════

  echo "=== Cache stats ==="
  grep -E "^Cached:|^Dirty:|^Writeback:|^Buffers:" /proc/meminfo

  echo "=== VM dirty stats ==="
  grep -E "^nr_dirty|^nr_writeback|^nr_written|^nr_dirtied" /proc/vmstat

  echo "=== Tuning knobs ==="
  sysctl vm.dirty_background_ratio vm.dirty_ratio
  sysctl vm.dirty_expire_centisecs vm.dirty_writeback_centisecs


═══════════════════════════════════════════════════════════════
EXERCISE 2: Populate the page cache
═══════════════════════════════════════════════════════════════

  echo "=== Before: cache size ==="
  grep "^Cached:" /proc/meminfo

  echo "=== Creating a 200 MB file ==="
  dd if=/dev/urandom of=/lab/data/cachetest.0 bs=1M count=200 2>/dev/null

  echo "=== Reading to fill page cache ==="
  time cat /lab/data/cachetest.0 > /dev/null

  echo "=== After: cache size ==="
  grep "^Cached:" /proc/meminfo

  echo "=== File cache residency ==="
  fincore /lab/data/cachetest.0


═══════════════════════════════════════════════════════════════
EXERCISE 3: Observe dirty pages and writeback
═══════════════════════════════════════════════════════════════

  echo "=== Creating 100 MB of dirty pages ==="
  echo "Before:"
  grep "^Dirty:" /proc/meminfo

  dd if=/dev/zero of=/lab/data/dirtytest bs=1M count=100 conv=notrunc 2>/dev/null

  echo "After write (dirty):"
  grep "^Dirty:" /proc/meminfo

  echo "=== Triggering sync ==="
  sync
  sleep 1
  echo "After sync (clean):"
  grep -E "^Dirty:|^Writeback:" /proc/meminfo


═══════════════════════════════════════════════════════════════
EXERCISE 4: Cached read vs buffered read performance
═══════════════════════════════════════════════════════════════

  # First: read from cache (file already cached from Exercise 2)
  echo "=== Cached read (from page cache) ==="
  fio /lab/cachebench.fio 2>&1 | grep -E "read:|READ:"

  # Drop caches
  echo 1 > /proc/sys/vm/drop_caches

  # Second: read from disk (cold cache)
  echo "=== Cold read (from disk) ==="
  fio /lab/cachebench.fio 2>&1 | grep -E "read:|READ:"


═══════════════════════════════════════════════════════════════
EXERCISE 5: O_DIRECT — bypassing the page cache
═══════════════════════════════════════════════════════════════

  echo "=== O_DIRECT read (bypasses cache) ==="
  fio /lab/directbench.fio 2>&1 | grep -E "read:|READ:"

  echo "=== Cache after O_DIRECT read ==="
  fincore /lab/data/cachetest.0

  echo "=== Compare: cached vs O_DIRECT ==="
  echo 1 > /proc/sys/vm/drop_caches
  echo "Cold cache O_DIRECT:"
  fio /lab/directbench.fio 2>&1 | grep -E "read:|READ:"

  echo "Cold cache buffered:"
  fio /lab/cachebench.fio 2>&1 | grep -E "read:|READ:"


═══════════════════════════════════════════════════════════════
EXERCISE 6: Writeback throttling (dirty_ratio)
═══════════════════════════════════════════════════════════════

  echo "=== Current dirty limits ==="
  sysctl vm.dirty_ratio vm.dirty_background_ratio

  echo "=== Reducing dirty limit to 5% ==="
  echo 5 > /proc/sys/vm/dirty_ratio
  echo 2 > /proc/sys/vm/dirty_background_ratio

  # Start dirty watch in background
  /lab/dirtywatch.sh &
  DIRTY_PID=$!
  sleep 0.5

  echo "=== Write 200 MB — observe throttling ==="
  dd if=/dev/zero of=/lab/data/throttletest bs=1M count=200 conv=fsync status=progress 2>/dev/null

  kill $DIRTY_PID 2>/dev/null || true
  wait $DIRTY_PID 2>/dev/null || true

  # Restore defaults
  echo 20 > /proc/sys/vm/dirty_ratio
  echo 10 > /proc/sys/vm/dirty_background_ratio

  echo ""
  echo "Throttling complete."


═══════════════════════════════════════════════════════════════
EXERCISE 7: mmap() and page cache sharing
═══════════════════════════════════════════════════════════════

  python3 << 'PYEOF'
import mmap, os

tmpf = '/lab/data/mmaptest'
with open(tmpf, 'wb') as f:
    f.write(b'A' * 4096)

# Writer: mmap the file, modify memory
fd_w = os.open(tmpf, os.O_RDWR)
m = mmap.mmap(fd_w, 4096, mmap.MAP_SHARED, mmap.PROT_WRITE)
m[0:6] = b'MODIFY'
m.flush()
print(f"[Writer] mmap content: {m[0:10]}")

# Reader: read() from the same file
fd_r = os.open(tmpf, os.O_RDONLY)
data = os.read(fd_r, 10)
print(f"[Reader] read() content: {data}")
# Both see the same data — same page cache page!

m.close()
os.close(fd_w)
os.close(fd_r)
os.unlink(tmpf)
PYEOF


═══════════════════════════════════════════════════════════════
EXERCISE 8: Read-ahead behavior
═══════════════════════════════════════════════════════════════

  echo "=== Read-ahead size ==="
  cat /sys/block/*/queue/read_ahead_kb 2>/dev/null | head -3

  echo "=== Sequential read (4K, cache hot) ==="
  echo 1 > /proc/sys/vm/drop_caches
  dd if=/lab/data/cachetest.0 of=/dev/null bs=4K count=10000 2>&1 | tail -1

  echo "=== Random-like read (O_DIRECT, 4K) ==="
  dd if=/lab/data/cachetest.0 of=/dev/null bs=4K count=10000 iflag=direct 2>&1 | tail -1


═══════════════════════════════════════════════════════════════
EXERCISE 9: Cache coherence — external modification
═══════════════════════════════════════════════════════════════

  echo "=== Cache coherence test ==="
  echo "original content" > /lab/data/coherence_test
  cat /lab/data/coherence_test > /dev/null  # Populate cache

  # External modification (bypassing this process's cache access)
  # On the same machine this still works because there's ONE page cache
  echo "modified content" > /lab/data/coherence_test

  echo "After external modification:"
  cat /lab/data/coherence_test
  echo "(Local coherency is guaranteed — there is only one page cache.)"


═══════════════════════════════════════════════════════════════
EXERCISE 10: Cache monitoring dashboard
═══════════════════════════════════════════════════════════════

  echo "=== Cache status dashboard ==="
  /lab/cachestat.sh 1 5

  echo ""
  echo "=== VM dirty statistics ==="
  grep -E "^nr_dirty|^nr_writeback|^nr_written|^nr_dirtied|^dirty_background|^dirty_threshold" /proc/vmstat

  echo ""
  echo "=== Memory pressure indicators ==="
  grep -E "^pgsteal_|^kswapd_steals|^allocstall" /proc/vmstat

  echo ""
  echo "=== Swappiness ==="
  sysctl vm.swappiness

BANNER

exec /bin/bash
ENTRY

RUN chmod +x /entrypoint.sh

WORKDIR /lab
ENTRYPOINT ["/entrypoint.sh"]

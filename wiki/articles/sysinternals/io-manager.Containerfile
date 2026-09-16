# I/O Manager Lab — I/O Workload Generation and Tracing Container
# Build:  podman build -f sysinternals/io-manager.Containerfile -t io-manager-lab .
# Run:    podman run -it --rm --privileged -v /tmp/io-traces:/traces io-manager-lab
#
# Purpose: Provides fio, iostat, iotop, blktrace for exploring the Linux I/O stack.
# Students generate synthetic I/O workloads and observe how the kernel's block layer,
# I/O scheduler, and device drivers handle them. Each exercise maps back to concepts
# in the I/O Manager article (IRPs, dispatch, buffering, completion).

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    fio \
    sysstat \
    iotop \
    blktrace \
    strace \
    util-linux \
    bpftrace \
    python \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /traces /workloads

# ────────────────────────────────────────────────────────────
# Fio workload profiles — mimic real-world I/O patterns
# ────────────────────────────────────────────────────────────
COPY <<'FIO_SEQREAD' /workloads/seqread.fio
[sequential-read]
rw=read
bs=128k
size=500M
direct=1
ioengine=libaio
iodepth=32
numjobs=1
filename=/tmp/fio_seqread_test
runtime=15
time_based=1
FIO_SEQREAD

COPY <<'FIO_RANDWRITE' /workloads/randwrite.fio
[random-write]
rw=randwrite
bs=4k
size=500M
direct=1
ioengine=libaio
iodepth=64
numjobs=4
filename=/tmp/fio_randwrite_test
runtime=15
time_based=1
FIO_RANDWRITE

COPY <<'FIO_MIXED' /workloads/mixed.fio
[mixed-rw]
rw=randrw
rwmixread=70
bs=4k
size=500M
direct=1
ioengine=libaio
iodepth=32
numjobs=4
filename=/tmp/fio_mixed_test
runtime=15
time_based=1
FIO_MIXED

# ────────────────────────────────────────────────────────────
# Tracing scripts
# ────────────────────────────────────────────────────────────
COPY <<'TRACE' /workloads/trace_io.sh
#!/bin/bash
# Full I/O trace: strace → VFS → block layer
# Usage: ./trace_io.sh <command...>

set -e

if [ $# -eq 0 ]; then
    echo "Usage: $0 <command with args>"
    echo "Example: $0 dd if=/dev/zero of=/tmp/test bs=1M count=10 oflag=direct"
    exit 1
fi

echo "=== I/O Stack Trace ==="
echo "Command: $@"
echo ""

# 1. Syscall trace (user → VFS boundary)
echo "── Syscall trace (strace) ──"
strace -e trace=openat,read,write,pread64,pwrite64,fsync,close -c "$@" 2>/tmp/syscall_trace.txt

echo ""
echo "── System call counts ──"
cat /tmp/syscall_trace.txt

echo ""
echo "── I/O statistics (iostat) ──"
# Run iostat in background during the workload
iostat -x 1 3 > /tmp/iostat_out.txt 2>&1 &
IOSTAT_PID=$!
sleep 1

# Run the command
eval "$@" > /dev/null 2>&1

sleep 2
kill $IOSTAT_PID 2>/dev/null || true
wait $IOSTAT_PID 2>/dev/null || true
cat /tmp/iostat_out.txt

echo ""
echo "── Block device stats ──"
cat /proc/diskstats | awk '{if($4>0) printf "dev=%s reads=%d writes=%d\n", $3, $4, $8}' | head -5

echo ""
echo "── I/O scheduler info ──"
for dev in /sys/block/sd* /sys/block/nvme* /sys/block/vd*; do
    [ -e "$dev" ] || continue
    NAME=$(basename $dev)
    SCHED=$(cat $dev/queue/scheduler 2>/dev/null)
    echo "$NAME: scheduler=$SCHED"
done

echo ""
echo "Trace complete."
TRACE

RUN chmod +x /workloads/trace_io.sh

# ────────────────────────────────────────────────────────────
# Entrypoint
# ────────────────────────────────────────────────────────────
COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

cat << 'BANNER'
╔══════════════════════════════════════════════════════════════╗
║         I/O Manager Lab — Linux I/O Stack Tracing           ║
╚══════════════════════════════════════════════════════════════╝

This container is a hands-on lab for the I/O Manager article.
You will generate I/O workloads and observe how the Linux kernel
processes them through the VFS, block layer, and device drivers.

═══════════════════════════════════════════════════════════════
EXERCISE 1: Observe disk structure
═══════════════════════════════════════════════════════════════

  lsblk -o NAME,KNAME,MAJ:MIN,SCHED,TYPE,SIZE,MOUNTPOINTS
  cat /sys/block/*/queue/scheduler
  cat /proc/diskstats | head -5


═══════════════════════════════════════════════════════════════
EXERCISE 2: Generate a sequential write (Fast I/O simulator)
═══════════════════════════════════════════════════════════════

  # In terminal 1: start iostat monitoring
  iostat -x 1 5

  # In terminal 2: run the workload
  fio /workloads/seqread.fio


═══════════════════════════════════════════════════════════════
EXERCISE 3: Random 4K writes (simulate database workload)
═══════════════════════════════════════════════════════════════

  fio /workloads/randwrite.fio

  # While it runs, in another terminal watch:
  iotop -o -b -n 5
  cat /proc/diskstats | grep -E "sda|nvme|vd"


═══════════════════════════════════════════════════════════════
EXERCISE 4: Trace a full I/O operation
═══════════════════════════════════════════════════════════════

  /workloads/trace_io.sh dd if=/dev/zero of=/tmp/trace_test bs=4K count=1000 oflag=direct

  # This shows: syscall → block stats → scheduler info


═══════════════════════════════════════════════════════════════
EXERCISE 5: Blktrace — block-level I/O tracing (requires SYS_ADMIN)
═══════════════════════════════════════════════════════════════

  DEV=$(lsblk -nd -o NAME | head -1)
  echo "Tracing device: /dev/$DEV"

  blktrace -d /dev/$DEV -o - | blkparse -i - &
  BLPID=$!
  sleep 1

  # Generate I/O
  dd if=/dev/zero of=/tmp/blktrace_test bs=4K count=100 oflag=direct 2>/dev/null
  sync
  sleep 2

  kill $BLPID 2>/dev/null
  wait $BLPID 2>/dev/null || true

  # Output format:
  # <dev> <cpu> <seq> <time> <pid> <action> <RWBS> <sector> + <count> [<proc>]
  #
  # Actions: D=issued, C=completed, Q=queued, M=merged, I=inserted
  # RWBS: R=read, W=write, S=sync, M=metadata, A=readahead


═══════════════════════════════════════════════════════════════
EXERCISE 6: Compare buffered vs direct I/O
═══════════════════════════════════════════════════════════════

  echo "=== Buffered (through page cache) ==="
  dd if=/dev/zero of=/tmp/buf_test bs=1M count=200 conv=fsync 2>&1

  echo "=== Direct (O_DIRECT, bypasses cache) ==="
  dd if=/dev/zero of=/tmp/dir_test bs=1M count=200 oflag=direct 2>&1

  echo "=== I/O scheduler stats ==="
  cat /sys/block/*/stat

  # Observe: direct I/O shows in %util, buffered may not (cached)


═══════════════════════════════════════════════════════════════
EXERCISE 7: Trace VFS → Block Layer with bpftrace
═══════════════════════════════════════════════════════════════

  bpftrace -e '
  kprobe:vfs_write { printf("VFS write: pid=%d comm=%s\n", pid, comm); }
  kprobe:submit_bio { printf("  BLOCK submit: pid=%d\n", pid); }
  ' &

  # Generate some I/O
  dd if=/dev/zero of=/tmp/bpftrace_test bs=4K count=50 oflag=direct 2>/dev/null
  sync
  sleep 1

  kill %1 2>/dev/null || true


═══════════════════════════════════════════════════════════════
EXERCISE 8: Investigate I/O latency
═══════════════════════════════════════════════════════════════

  # Check average I/O wait
  iostat -x 1 3 | awk '/^Device/ || /^sd/ || /^nvme/ || /^vd/'

  # Check queue depth in real-time
  watch -n 0.5 'cat /sys/block/*/inflight'

  # High await + high aqu-sz = I/O bottleneck


═══════════════════════════════════════════════════════════════
EXERCISE 9: I/O error injection and detection
═══════════════════════════════════════════════════════════════

  # Check for I/O errors in dmesg
  dmesg -T | grep -i "i/o error\|medium error\|bad block\|filesystem error" || echo "No I/O errors detected"

  # Check per-device error counters
  cat /sys/block/*/stat | awk '{if($1+$5>0) printf "device: reads=%d writes=%d\n", $1, $5}'


═══════════════════════════════════════════════════════════════
EXERCISE 10: I/O scheduler experimentation
═══════════════════════════════════════════════════════════════

  DEV=$(lsblk -nd -o NAME | head -1)
  echo "Current scheduler for $DEV:"
  cat /sys/block/$DEV/queue/scheduler

  # Try different schedulers (if supported):
  # echo mq-deadline > /sys/block/$DEV/queue/scheduler
  # echo kyber > /sys/block/$DEV/queue/scheduler
  # echo none > /sys/block/$DEV/queue/scheduler

  # For each, run a mixed fio workload and compare:
  # fio /workloads/mixed.fio

BANNER

# Drop into interactive shell
exec /bin/bash
ENTRY

RUN chmod +x /entrypoint.sh

WORKDIR /workloads
ENTRYPOINT ["/entrypoint.sh"]

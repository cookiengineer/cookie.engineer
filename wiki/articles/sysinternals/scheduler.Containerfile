# Scheduler Lab - CPU scheduling, cgroups v2, workloads
# Purpose: Experiment with scheduling classes and CPU cgroup limits.
# Build:  podman build -f sysinternals/scheduler.Containerfile -t scheduler-lab .
# Run:    podman run -it --rm --privileged scheduler-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    base-devel \
    stress-ng \
    htop \
    procps-ng \
    python \
    util-linux \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /scripts

COPY <<'CPU_BURN' /scripts/cpu_burn.py
#!/usr/bin/env python3
"""CPU-bound workload: tight mathematical loop."""
import sys, os, time

def cpu_burn(seconds=30):
    end = time.time() + seconds
    x = 0.0
    while time.time() < end:
        x += 0.0001
        x *= 1.000001
    return x

if __name__ == '__main__':
    dur = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    print(f"[CPU-Bound] PID={os.getpid()} running for {dur}s")
    cpu_burn(dur)
    print("[CPU-Bound] done")
CPU_BURN

COPY <<'IO_BURN' /scripts/io_burn.py
#!/usr/bin/env python3
"""I/O-bound workload: repeated file writes and syncs."""
import sys, os, time, tempfile

def io_burn(path, seconds=30, bs=4096):
    end = time.time() + seconds
    count = 0
    with open(path, 'wb', buffering=0) as f:
        while time.time() < end:
            f.write(b'X' * bs)
            count += 1
            if count % 1000 == 0:
                os.fsync(f.fileno())
    return count

if __name__ == '__main__':
    dur = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    tmp = '/tmp/io_burn_test'
    print(f"[I/O-Bound] PID={os.getpid()} running for {dur}s")
    ops = io_burn(tmp, dur)
    print(f"[I/O-Bound] done: {ops} writes")
    os.unlink(tmp)
IO_BURN

COPY <<'MIXED_BURN' /scripts/mixed_burn.py
#!/usr/bin/env python3
"""Mixed CPU + I/O workload."""
import sys, os, time, threading

def cpu_worker(seconds):
    end = time.time() + seconds
    x = 0.0
    while time.time() < end:
        for i in range(1000):
            x += i * 0.0001
    return x

def io_worker(path, seconds):
    end = time.time() + seconds
    count = 0
    with open(path, 'ab') as f:
        while time.time() < end:
            f.write(b'X' * 4096)
            count += 1
            if count % 100 == 0:
                f.flush()
    return count

if __name__ == '__main__':
    dur = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    print(f"[Mixed] PID={os.getpid()} running for {dur}s")
    
    tmp = '/tmp/mixed_burn_test'
    
    cpu_t = threading.Thread(target=cpu_worker, args=(dur,))
    io_t  = threading.Thread(target=io_worker, args=(tmp, dur))
    
    cpu_t.start()
    io_t.start()
    
    cpu_t.join()
    io_t.join()
    
    print("[Mixed] done")
    os.unlink(tmp)
MIXED_BURN

COPY <<'CGROUPS' /scripts/cgroup_demo.sh
#!/bin/bash
# Demonstrate cgroups v2 CPU controller
set -e

CGROUP_ROOT="/sys/fs/cgroup"
DEMO_GROUP="$CGROUP_ROOT/scheduler_demo"

echo "── Cgroups v2 CPU Controller Demo ──"
echo ""

# Check if cgroups v2 is active
if [ -f "$CGROUP_ROOT/cgroup.controllers" ]; then
    echo "Cgroups v2 detected."
    echo "Available controllers: $(cat $CGROUP_ROOT/cgroup.controllers)"
else
    echo "Cgroups v2 not found. Trying legacy cgroups v1..."
    CGROUP_ROOT="/sys/fs/cgroup/cpu"
    if [ -d "$CGROUP_ROOT" ]; then
        echo "Cgroups v1 CPU controller found at $CGROUP_ROOT"
    else
        echo "ERROR: No cgroup CPU controller available."
        exit 1
    fi
fi
echo ""

# Detect v2 vs v1
if [ -f "$CGROUP_ROOT/../cgroup.controllers" ]; then
    # v2
    CGV=2
    CGPARENT="/sys/fs/cgroup"
    mkdir -p "$DEMO_GROUP" 2>/dev/null || true
else
    # v1
    CGV=1
    CGPARENT="/sys/fs/cgroup/cpu"
    mkdir -p "$DEMO_GROUP" 2>/dev/null || true
fi

echo "1. Current CPU shares/weight:"
if [ "$CGV" = "2" ]; then
    cat "$DEMO_GROUP/cpu.weight" 2>/dev/null || echo "  (unavailable)"
else
    cat "$DEMO_GROUP/cpu.shares" 2>/dev/null || echo "  (unavailable)"
fi
echo ""

echo "2. Setting CPU limit to 50% (50000/100000 per period):"
if [ "$CGV" = "2" ]; then
    echo "max 50000" > "$DEMO_GROUP/cpu.max" 2>/dev/null || echo "  (cannot write — needs --privileged)"
else
    echo 50000 > "$DEMO_GROUP/cpu.cfs_period_us" 2>/dev/null || echo "  (cannot write)"
    echo 25000 > "$DEMO_GROUP/cpu.cfs_quota_us" 2>/dev/null || echo "  (cannot write)"
fi
echo ""

echo "3. Adding current shell to demo cgroup:"
echo $$ > "$DEMO_GROUP/cgroup.procs" 2>/dev/null && echo "  PID $$ added to $DEMO_GROUP" || echo "  (cannot join cgroup — needs --privileged)"
echo ""

echo "4. Cgroup hierarchy:"
find "$CGPARENT" -maxdepth 1 -name 'cgroup.procs' -exec sh -c 'echo "  $1: $(cat "$1" | wc -l) processes"' _ {} \; 2>/dev/null || true
echo ""

echo "5. Cgroup CPU usage stats:"
if [ "$CGV" = "2" ]; then
    cat "$DEMO_GROUP/cpu.stat" 2>/dev/null || echo "  (unavailable)"
else
    cat "$DEMO_GROUP/cpu.stat" 2>/dev/null || echo "  (unavailable)"
fi
echo ""

echo "── Cgroup Demo Complete ──"
CGROUPS

RUN chmod +x /scripts/cpu_burn.py /scripts/io_burn.py /scripts/mixed_burn.py /scripts/cgroup_demo.sh

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== CPU Scheduler Lab — Cgroups & Scheduling ==="
echo ""
echo "This lab demonstrates the Linux CFS scheduler, CPU cgroups, and"
echo "how the kernel balances CPU-bound and I/O-bound workloads."
echo ""

echo "── System Information ──"
echo "CPUs:     $(nproc)"
echo "CFS:      $(grep 'CONFIG_FAIR_GROUP_SCHED=' /boot/config-$(uname -r) 2>/dev/null || echo 'likely yes')"
echo "HZ:       $(grep 'CONFIG_HZ=' /boot/config-$(uname -r) 2>/dev/null | cut -d= -f2 || echo 'unknown')"
echo "PREEMPT:  $(uname -v | grep -c PREEMPT || echo 0) (0=none, 1=voluntary, 2=full)"
echo ""

echo "── Scheduler Tunables ──"
echo "  sched_latency_ns:        $(cat /proc/sys/kernel/sched_latency_ns 2>/dev/null || echo 'unreadable')"
echo "  sched_min_granularity_ns: $(cat /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null || echo 'unreadable')"
echo "  sched_wakeup_granularity_ns: $(cat /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null || echo 'unreadable')"
echo "  sched_migration_cost_ns: $(cat /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null || echo 'unreadable')"
echo "  sched_nr_migrate:        $(cat /proc/sys/kernel/sched_nr_migrate 2>/dev/null || echo 'unreadable')"
echo ""

echo "── Per-CPU Run Queue Stats ──"
cat /proc/schedstat 2>/dev/null | head -5 || echo "  (schedstat not accessible)"
echo ""

echo "── Scheduler Debug (if available) ──"
if [ -d /sys/kernel/debug/sched ]; then
    echo "Scheduler debug available at /sys/kernel/debug/sched/"
    ls /sys/kernel/debug/sched/ 2>/dev/null | head -10
else
    echo "  Debug not available (needs CONFIG_SCHED_DEBUG=y and mount -t debugfs)"
fi
echo ""

echo "── Process Scheduling Attributes ──"
echo "  Current shell: PID=$$ PPID=$PPID"
echo "  Policy:      $(chrt -p $$ 2>/dev/null | awk '{print $NF}' || echo 'unknown')"
echo "  Nice value:  $(ps -o ni -p $$ --no-headers 2>/dev/null || echo 'unknown')"
echo "  Priority:    $(ps -o pri -p $$ --no-headers 2>/dev/null || echo 'unknown')"
echo ""

echo "── Available Scheduling Policies ──"
echo "  SCHED_OTHER  (0) — Completely Fair Scheduler (CFS)"
echo "  SCHED_FIFO   (1) — First-in-first-out real-time"
echo "  SCHED_RR     (2) — Round-robin real-time"
echo "  SCHED_BATCH  (3) — Batch (throughput-oriented)"
echo "  SCHED_IDLE   (5) — Idle (only run when nothing else)"
echo "  SCHED_DEADLINE (6) — Deadline scheduler (EDF)"
echo ""

echo "── Trying Cgroup Demo ──"
/scripts/cgroup_demo.sh
echo ""

echo "── CPU-Bound vs I/O-Bound Workload Demo ──"
echo "Run these in separate terminals to observe scheduling:"
echo ""
echo "  # Terminal 1: CPU-bound workload"
echo "  python3 /scripts/cpu_burn.py 60 &"
echo ""
echo "  # Terminal 2: I/O-bound workload"
echo "  python3 /scripts/io_burn.py 60 &"
echo ""
echo "  # Terminal 3: Watch scheduler activity"
echo "  watch -n1 'cat /proc/schedstat | head -1'"
echo "  pidstat -w 1    # context switches per second"
echo "  mpstat -P ALL 1 # per-CPU utilization"
echo ""
echo "  # Compare nr_involuntary_switches before/after:"
echo "  cat /proc/\$(pgrep -f cpu_burn | head -1)/status | grep ctxt"
echo ""

echo "── Scheduler Activation Trace ──"
echo "  # Using bpftrace (if available):"
echo "  bpftrace -e 'kprobe:schedule { printf(\"sched: pid=%d comm=%s\\n\", pid, comm); }'"
echo ""

echo "── Task State Reference ──"
echo "  TASK_RUNNING       (0) — On CPU or in runqueue"
echo "  TASK_INTERRUPTIBLE  (1) — Sleeping, waiting for event"
echo "  TASK_UNINTERRUPTIBLE (2) — Sleeping, can't be woken by signal (D state)"
echo "  TASK_STOPPED       (4) — Stopped by SIGSTOP"
echo "  TASK_TRACED        (8) — Being traced by ptrace"
echo "  EXIT_ZOMBIE       (32) — Exited but parent hasn't waited"
echo "  EXIT_DEAD         (16) — Final state before removal"
echo ""

echo "── Observing D-State Processes ──"
echo "  ps aux | awk '\$8 ~ /D/ { print }'  # processes in uninterruptible sleep"
echo ""

echo "── Stress Test with stress-ng ──"
echo "  # CPU stress: 4 workers for 10 seconds"
echo "  stress-ng --cpu 4 --timeout 10s --metrics-brief"
echo ""
echo "  # I/O stress: 2 workers writing 1 GB"
echo "  stress-ng --hdd 2 --hdd-bytes 1G --timeout 10s --metrics-brief"
echo ""
echo "  # Mixed stress: CPU + I/O + memory"
echo "  stress-ng --cpu 2 --hdd 2 --vm 2 --timeout 15s --metrics-brief"
echo ""
echo "  # With cgroup CPU limit:"
echo "  echo '+cpu' > /sys/fs/cgroup/cgroup.subtree_control"
echo "  mkdir /sys/fs/cgroup/stress_test"
echo "  echo 'max 20000' > /sys/fs/cgroup/stress_test/cpu.max"
echo "  echo $$ > /sys/fs/cgroup/stress_test/cgroup.procs"
echo "  stress-ng --cpu 4 --timeout 10s --metrics-brief"
echo ""

echo "── Real-Time Scheduling Demo ──"
echo "  # Run a FIFO task with high priority:"
echo "  chrt -f 99 python3 /scripts/cpu_burn.py 10"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Compare voluntary vs involuntary context switches for CPU/IO workloads"
echo "  2. Use cgroups to limit a CPU hog to 25% of one core"
echo "  3. Try different nice levels: nice -n -20 vs nice -n 19 with same workload"
echo "  4. Observe scheduler load balancing: taskset -c 0 stress-ng --cpu 4"
echo "  5. Check /proc/PID/sched for detailed scheduler stats per task"
echo "  6. Explore deadline scheduler: chrt -d --sched-runtime 10000000 ..."
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /root
ENTRYPOINT ["/entrypoint.sh"]

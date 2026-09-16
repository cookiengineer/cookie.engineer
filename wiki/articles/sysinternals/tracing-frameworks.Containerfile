# tracing-frameworks.Containerfile
# Purpose: Side-by-side comparison of ftrace, perf, bpftrace, strace, and LTTng on one workload.
# Build:  podman build -f tracing-frameworks.Containerfile -t tracing-frameworks-lab .
# Run:    podman run -it --rm --privileged -v /sys/kernel/debug:/sys/kernel/debug tracing-frameworks-lab
# Notes:  --privileged and the debugfs mount are required for ftrace and kprobe-based tracing.

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    perf \
    bpftrace \
    trace-cmd \
    strace \
    lttng-tools \
    procps-ng \
    util-linux \
    python \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /lab

COPY <<'WORKLOAD' /lab/workload.sh
#!/bin/bash
# workload.sh - A fixed workload for comparing tracing frameworks.
# Runs for the specified number of seconds with mixed activity.
set -e
DURATION="${1:-10}"
echo "[Workload] Running for ${DURATION}s - PID $$"

end=$(($(date +%s) + DURATION))
while [ $(date +%s) -lt $end ]; do
    # CPU: compute primes
    python3 -c "
n=0
for i in range(2, 2000):
    for j in range(2, int(i**0.5)+1):
        if i % j == 0: break
    else: n+=1
" &
    # I/O: write small files
    dd if=/dev/zero of=/tmp/wl_$$ bs=4K count=10 oflag=direct 2>/dev/null
    rm -f /tmp/wl_$$
    # File ops
    cat /etc/hostname > /dev/null 2>&1
    ls /tmp > /dev/null 2>&1
    wait
    usleep 100000
done
echo "[Workload] Done."
WORKLOAD

COPY <<'COMPARISON' /lab/comparison_demo.sh
#!/bin/bash
# comparison_demo.sh - Run the same workload through each tracing framework.
set -e

echo "=== Tracing Framework Comparison ==="
echo ""
echo "Each framework runs with the SAME workload to demonstrate"
echo "differences in overhead, granularity, and output format."
echo ""

WL="/lab/workload.sh"
DUR=5

echo "--------------------------------------------"
echo "1. strace - System Call Tracing"
echo "--------------------------------------------"
echo "  strace -c $WL $DUR"
echo ""
strace -c -o /tmp/strace_out.log $WL $DUR 2>/dev/null
echo "  Output (/tmp/strace_out.log):"
head -20 /tmp/strace_out.log
echo "  ..."
echo "  Lines: $(wc -l < /tmp/strace_out.log)"
echo ""
echo "  Strengths:  Simple, no privileges needed, shows args"
echo "  Weaknesses: High overhead, per-syscall, limited filtering"
echo ""

echo "--------------------------------------------"
echo "2. perf stat - Hardware Performance Counters"
echo "--------------------------------------------"
echo "  perf stat $WL $DUR"
echo ""
perf stat -e cycles,instructions,cache-misses,context-switches,page-faults \
    $WL $DUR 2>&1 || echo "  (perf not available - needs --privileged)"
echo ""
echo "  Strengths:  Low overhead, CPU hardware counters"
echo "  Weaknesses: No event context, only aggregate counts"
echo ""

echo "--------------------------------------------"
echo "3. perf record - Sampling Profiler"
echo "--------------------------------------------"
echo "  perf record -F 99 -g -- $WL $DUR"
echo ""
perf record -F 99 -g -o /tmp/perf.data -- $WL $DUR 2>&1 || \
    echo "  (perf record not available)"
echo ""
if [ -f /tmp/perf.data ]; then
    echo "  perf report --stdio --stdio -n --no-children | head -30"
    perf report --stdio -i /tmp/perf.data -n --no-children 2>/dev/null | head -20 || true
fi
echo "  Strengths:  Call graphs, flame graphs, low overhead"
echo "  Weaknesses: Sampling-based (may miss short events)"
echo ""

echo "--------------------------------------------"
echo "4. ftrace (via trace-cmd) - Function/Event Tracing"
echo "--------------------------------------------"
echo "  trace-cmd record -e sched_switch -e syscalls:sys_enter_write -- $WL $DUR"
echo ""
trace-cmd record -e sched_switch -e syscalls:sys_enter_write \
    -o /tmp/trace.dat -- $WL $DUR 2>/dev/null || \
    echo "  (trace-cmd not available)"
echo ""
if [ -f /tmp/trace.dat ]; then
    echo "  trace-cmd report /tmp/trace.dat | head -15"
    trace-cmd report /tmp/trace.dat 2>/dev/null | head -15 || true
fi
echo "  Strengths:  Very low overhead, built into kernel"
echo "  Weaknesses: Fixed event set, manual enable/disable"
echo ""

echo "--------------------------------------------"
echo "5. bpftrace - Dynamic Tracing with BPF"
echo "--------------------------------------------"
echo "  bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }'"
echo "  (runs for $DUR seconds in background)"
echo ""
bpftrace -e 'tracepoint:raw_syscalls:sys_enter { @[comm] = count(); }' &
BPPID=$!
$WL $DUR 2>/dev/null
sleep 1
kill $BPPID 2>/dev/null || true
wait $BPPID 2>/dev/null || true
echo ""
echo "  Strengths:  Programmable, low overhead, in-kernel aggregation"
echo "  Weaknesses: BPF verifier limits, learning curve"
echo ""

echo "--------------------------------------------"
echo "6. Comparison Summary"
echo "--------------------------------------------"
echo ""
echo "  +-----------+----------+----------+----------+----------+----------+"
echo "  | Feature   | strace   | perf     | ftrace   |bpftrace  | LTTng    |"
echo "  +-----------+----------+----------+----------+----------+----------+"
echo "  | Overhead  | HIGH     | LOW      | V.LOW    | LOW      | LOW      |"
echo "  | Passive   | No       | Yes      | Yes      | Yes      | Yes      |"
echo "  | Custom    | No       | No       | Limited  | Yes      | Limited  |"
echo "  | Args/Data | Yes      | Counters | Events   | Events   | Full     |"
echo "  | Filtering | Limited  | No       | No       | Yes      | No       |"
echo "  | Aggregatn | No       | Yes      | No       | Yes      | No       |"
echo "  | Production| No       | Yes      | Yes      | Yes      | Yes      |"
echo "  | Complexity| Easy     | Medium   | Medium   | Hard     | Hard     |"
echo "  +-----------+----------+----------+----------+----------+----------+"
echo ""
echo "  When to use what:"
echo "    strace:   Debug a single failing program"
echo "    perf:     CPU profiling / performance regression"
echo "    ftrace:   Kernel function flow analysis"
echo "    bpftrace: Custom dynamic instrumentation"
echo "    LTTng:    High-throughput production tracing"
echo ""
COMPARISON

RUN chmod +x /lab/workload.sh /lab/comparison_demo.sh

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Tracing Frameworks Comparison Lab ==="
echo ""
echo "This lab runs the same workload through multiple tracing frameworks"
echo "so you can compare their capabilities, overhead, and output."
echo ""

echo "-- The Tracing Landscape --"
echo ""
echo "  Complexity:"
echo "    Low   -> strace, ftrace, perf stat"
echo "    Med   -> trace-cmd, perf record"
echo "    High  -> bpftrace, eBPF, LTTng"
echo ""
echo "  Overhead:"
echo "    High  -> strace (every syscall crosses userspace boundary)"
echo "    Low   -> perf stat (~2-5% with counters)"
echo "    V.Low -> ftrace (~1-2% for event tracing)"
echo "    Low   -> bpftrace (~1-3% for BPF programs)"
echo "    Low   -> LTTng (optimized ring buffer)"
echo ""

echo "-- Framework Deep Dive --"
echo ""

echo "-- Ftrace Architecture --"
echo "  Built into the kernel (CONFIG_FTRACE=y)."
echo "  Uses mcount calls inserted by the compiler at function entry."
echo "  Controlled via /sys/kernel/debug/tracing/."
echo ""
echo "  Current tracer: (cat /sys/kernel/debug/tracing/current_tracer)"
cat /sys/kernel/debug/tracing/current_tracer 2>/dev/null || echo "  (debugfs not mounted)"
echo ""
echo "  Available tracers:"
cat /sys/kernel/debug/tracing/available_tracers 2>/dev/null | head -1 || echo "  (debugfs not mounted)"
echo ""
echo "  Tracers explained:"
echo "    nop             - no tracing (default)"
echo "    function        - trace every kernel function call (HIGH overhead)"
echo "    function_graph  - trace function entry+exit with timing"
echo "    blk             - block I/O tracer"
echo "    mmiotrace       - MMIO register trace"
echo "    wakeup_rt       - max real-time latency tracer"
echo "    wakeup          - max normal latency tracer"
echo "    irqsoff         - max IRQ-off latency"
echo "    preemptoff      - max preempt-off latency"
echo "    preemptirqsoff  - max IRQ + preempt-off latency"
echo ""

echo "-- perf Architecture --"
echo "  Uses hardware performance monitoring units (PMU) on the CPU."
echo "  Sampling-based: interrupts CPU every N events."
echo ""
echo "  Modes:"
echo "    perf stat    - count events for a command"
echo "    perf record  - sample events for a command"
echo "    perf top     - live interactive sampling"
echo "    perf trace   - like strace but via tracepoints"
echo "    perf sched   - scheduler analysis"
echo "    perf lock    - lock contention analysis"
echo "    perf mem     - memory access profiling"
echo "    perf kvm     - KVM guest/host analysis"
echo ""

echo "-- bpftrace Architecture --"
echo "  High-level language that compiles to BPF bytecode."
echo "  BPF verifier checks safety, JIT compiles to native code."
echo "  Programs run in-kernel at attach points."
echo ""
echo "  Attach points:"
echo "    kprobe/kretprobe     - any kernel function"
echo "    uprobe/uretprobe     - any user function"
echo "    tracepoint           - static kernel tracepoints"
echo "    USDT                 - user-space statically defined tracing"
echo "    profile              - timer-based sampling"
echo "    software/hardware    - perf events"
echo ""

echo "-- LTTng (Linux Trace Toolkit Next Generation) --"
echo "  High-performance tracer designed for production use."
echo "  Architecture: Session daemon + consumer daemon + relay daemon."
echo "  Uses per-CPU ring buffers for zero-copy tracing."
echo ""
echo "  Commands:"
echo "    lttng create <session>"
echo "    lttng enable-event -k <event>"
echo "    lttng start"
echo "    lttng stop"
echo "    lttng destroy"
echo ""

echo "-- Framework Selection Guide --"
echo ""
echo "  Question                            -> Best Tool"
echo "  ----------------------------------------------------"
echo "  'Why is this program slow?'         -> strace -c"
echo "  'Which function is using CPU?'      -> perf record + report"
echo "  'What's the call flow in the kernel?' -> ftrace function_graph"
echo "  'How many times is open() called?'  -> bpftrace one-liner"
echo "  'Show me all execs on the system'   -> bpftrace tracepoint"
echo "  'Trace I/O latency per device'      -> bpftrace block probes"
echo "  'Production-grade tracing'          -> LTTng"
echo "  'Debug a segfault'                  -> strace + gdb"
echo "  'Find memory leaks'                 -> perf kmem / valgrind"
echo "  'Scheduler analysis'                -> perf sched"
echo ""

echo "-- Running Comparison Demo --"
echo ""
echo "  Execute the full comparison:"
echo "  /lab/comparison_demo.sh"
echo ""
echo "  Or run individual parts:"
echo "  strace -c /lab/workload.sh 5"
echo "  perf stat /lab/workload.sh 5"
echo "  trace-cmd record -e sched_switch -- /lab/workload.sh 5"
echo ""
echo "  Start comparison now? (will run ~30 seconds)"
echo "  Press Ctrl+C to skip, or press Enter to run."
read -t 5 -r && /lab/comparison_demo.sh || echo "  Skipped."
echo ""

echo "-- Ftrace Quick Recipes --"
echo ""
echo "  # Enable function graph tracer:"
echo "  echo function_graph > /sys/kernel/debug/tracing/current_tracer"
echo "  echo 1 > /sys/kernel/debug/tracing/tracing_on"
echo "  cat /sys/kernel/debug/tracing/trace"
echo "  echo 0 > /sys/kernel/debug/tracing/tracing_on"
echo ""
echo "  # Trace specific events:"
echo "  echo 1 > /sys/kernel/debug/tracing/events/syscalls/sys_enter_openat/enable"
echo "  cat /sys/kernel/debug/tracing/trace_pipe"
echo ""

echo "-- trace-cmd Quick Recipes --"
echo ""
echo "  # Record sched and syscall events:"
echo "  trace-cmd record -e sched_switch -e syscalls:sys_enter_write -- sleep 5"
echo ""
echo "  # Report the trace:"
echo "  trace-cmd report"
echo "  trace-cmd report -l          # latency format"
echo "  trace-cmd report -F 'comm==\"myapp\"'"  # filter"
echo ""
echo "  # Show histogram:"
echo "  trace-cmd hist -e sched_switch -f 'next_comm'"
echo ""

echo "-- perf Quick Recipes --"
echo ""
echo "  # Profile CPU for 10 seconds:"
echo "  perf record -F 99 -a -g -- sleep 10"
echo ""
echo "  # View the report:"
echo "  perf report --stdio"
echo "  perf report --sort comm,dso"
echo ""
echo "  # Generate flame graph (needs scripts):"
echo "  perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg"
echo "  # (Clone: git clone https://github.com/brendangregg/FlameGraph)"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Run the full comparison: /lab/comparison_demo.sh"
echo "  2. Compare strace vs perf overhead on the same workload"
echo "  3. Use ftrace function_graph to trace the workload's kernel path"
echo "  4. Write a bpftrace one-liner that counts each framework's overhead"
echo "  5. Try LTTng: lttng create test; lttng enable-event -k sched_switch; lttng start"
echo "  6. Visualize trace-cmd output in KernelShark: kernelshark trace.dat"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /lab
ENTRYPOINT ["/entrypoint.sh"]

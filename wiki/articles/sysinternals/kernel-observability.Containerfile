# Kernel Observability Lab - perf, ftrace, bpftrace, trace-cmd toolbox
# Build:  podman build -f kernel-observability.Containerfile -t kernel-observability-lab .
# Run:    podman run -it --rm --privileged kernel-observability-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    perf \
    linux-tools \
    bpf-tools \
    bpftrace \
    trace-cmd \
    kernelshark \
    procps-ng \
    util-linux \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /observability

COPY <<'WORKLOAD' /observability/workload.sh
#!/bin/bash
# workload.sh — Synthetic workload for observability tool demos.
# Generates CPU activity, disk I/O, and network traffic.
set -e

MODE="${1:-all}"
DURATION="${2:-30}"

echo "[Workload] Starting $MODE workload for ${DURATION}s (PID $$)"

case "$MODE" in
    cpu)
        end=$(($(date +%s) + DURATION))
        while [ $(date +%s) -lt $end ]; do
            python3 -c "
import math
x = 0.0
for i in range(50000):
    x += math.sin(i * 0.001) * math.cos(i * 0.0001)
" &
            wait
        done
        ;;
    io)
        end=$(($(date +%s) + DURATION))
        while [ $(date +%s) -lt $end ]; do
            dd if=/dev/zero of=/tmp/workload_io bs=64K count=100 oflag=direct 2>/dev/null
            sync
            rm -f /tmp/workload_io
        done
        ;;
    net)
        end=$(($(date +%s) + DURATION))
        while [ $(date +%s) -lt $end ]; do
            curl -s --max-time 2 http://example.com > /dev/null 2>&1 || true
            sleep 0.1
        done
        ;;
    mixed)
        end=$(($(date +%s) + DURATION))
        while [ $(date +%s) -lt $end ]; do
            ( python3 -c "x=0.0; [x:=x+i*0.001 for i in range(20000)]" ) &
            dd if=/dev/zero of=/tmp/wl_mixed bs=4K count=50 oflag=direct 2>/dev/null
            rm -f /tmp/wl_mixed
            wait
        done
        ;;
    all|*)
        echo "  CPU:  tight math loop"
        echo "  IO:   dd write/delete cycles"
        echo "  NET:  curl example.com"
        echo ""
        end=$(($(date +%s) + DURATION))
        while [ $(date +%s) -lt $end ]; do
            python3 -c "x=0; [x:=x+i for i in range(10000)]" &>/dev/null &
            dd if=/dev/zero of=/tmp/wl_all bs=4K count=20 oflag=direct 2>/dev/null
            curl -s --max-time 1 http://example.com > /dev/null 2>&1 || true
            rm -f /tmp/wl_all
            wait
        done
        ;;
esac

echo "[Workload] Done."
WORKLOAD

COPY <<'BENCHMARK' /observability/benchmark.sh
#!/bin/bash
# benchmark.sh — Run controlled benchmarks across observability tools

echo "=== Observability Tools Benchmark ==="
echo "  Comparing overhead of different tracing methods"
echo ""

echo "── Baseline (no tracing) ──"
time /observability/workload.sh cpu 5 2>/dev/null

echo ""
echo "── strace overhead ──"
time strace -c /observability/workload.sh cpu 5 2>/dev/null

echo ""
echo "── perf stat overhead ──"
time perf stat /observability/workload.sh cpu 5 2>/dev/null

echo ""
echo "── ftrace overhead (trace-cmd) ──"
trace-cmd record -e sched -e syscalls /observability/workload.sh cpu 5 2>/dev/null
TRACE_FILE=$(ls -t trace.dat 2>/dev/null | head -1)
echo "  Trace file: $TRACE_FILE ($(stat -c%s $TRACE_FILE) bytes)"

echo ""
echo "Overhead summary:"
echo "  strace:   High (every syscall crosses userspace→kernel)"
echo "  perf:     Low (~2-5% for stat mode)"
echo "  ftrace:   Very low (~1-2% for event tracing)"
echo "  bpftrace: Low (~1-3% for BPF programs)"
echo "  eBPF:     Virtually zero (JIT'd to native code)"
BENCHMARK

RUN chmod +x /observability/workload.sh /observability/benchmark.sh

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Kernel Observability Lab — perf, ftrace, bpftrace, trace-cmd ==="
echo ""
echo "This lab demonstrates Linux kernel observability tools side-by-side."
echo "Learn which tool to use for what, and understand their trade-offs."
echo ""

echo "── Observability Stack ──"
echo "  Level 1: Application Metrics (prometheus, /proc, /sys)"
echo "  Level 2: System Call Tracing (strace)"
echo "  Level 3: Kernel Event Tracing (trace-cmd / ftrace)"
echo "  Level 4: Sampling Profiling (perf)"
echo "  Level 5: Dynamic Tracing (kprobes, uprobes, tracepoints)"
echo "  Level 6: Programmable Tracing (bpftrace, BPF)"
echo ""

echo "── Tool Comparison ──"
printf "  %-16s %-8s %-12s %-20s\n" "TOOL" "OVERHEAD" "GRANULARITY" "USE CASE"
echo "  ────────────────────────────────────────────────────────────"
printf "  %-16s %-8s %-12s %-20s\n" "strace" "High" "Syscall" "Debug single process"
printf "  %-16s %-8s %-12s %-20s\n" "perf stat" "Low" "Counter" "CPU perf counters"
printf "  %-16s %-8s %-12s %-20s\n" "perf record" "Medium" "Sample" "CPU profiling"
printf "  %-16s %-8s %-12s %-20s\n" "ftrace" "Very Low" "Function" "Function graph"
printf "  %-16s %-8s %-12s %-20s\n" "trace-cmd" "Low" "Event" "Event tracing"
printf "  %-16s %-8s %-12s %-20s\n" "bpftrace" "Low" "Dynamic" "Custom tracing"
printf "  %-16s %-8s %-12s %-20s\n" "perf top" "Low" "Sample" "Live hotspot view"
printf "  %-16s %-8s %-12s %-20s\n" "KernelShark" "N/A" "Trace Viz" "GUI analysis"
echo ""

echo "── Ftrace (tracefs) ──"
echo "  The kernel's built-in function tracer infrastructure."
echo "  Located at /sys/kernel/debug/tracing/"
echo ""
if [ -d /sys/kernel/debug/tracing ]; then
    echo "  Available tracers:"
    cat /sys/kernel/debug/tracing/available_tracers 2>/dev/null || echo "    (not accessible)"
    echo ""
    echo "  Available events: $(ls /sys/kernel/debug/tracing/events/ 2>/dev/null | wc -l) categories"
    echo ""
    echo "  Example: Function graph tracer (trace all kernel functions):"
    echo "    echo function_graph > /sys/kernel/debug/tracing/current_tracer"
    echo "    echo 1 > /sys/kernel/debug/tracing/tracing_on"
    echo "    # ... run workload ..."
    echo "    cat /sys/kernel/debug/tracing/trace"
    echo ""
    echo "  Example: Trace specific events:"
    echo "    echo 1 > /sys/kernel/debug/tracing/events/sched/sched_switch/enable"
    echo "    cat /sys/kernel/debug/tracing/trace_pipe"
else
    echo "  debugfs not mounted. Run with --privileged or:"
    echo "    mount -t debugfs none /sys/kernel/debug"
fi
echo ""

echo "── perf — Hardware Performance Counters ──"
echo "  perf stat: Count specific events during command execution."
echo ""
echo "  Try these:"
echo "  perf stat ls / > /dev/null"
echo ""
echo "  Counting instructions and cycles:"
perf stat -e instructions,cycles ls / > /dev/null 2>&1 || echo "  (perf stat unavailable — needs --privileged)"
echo ""

echo "── perf stat — Common Events ──"
echo "  cycles             — CPU clock cycles"
echo "  instructions       — Instructions retired"
echo "  cache-misses       — Cache misses (last level)"
echo "  cache-references   — Cache references"
echo "  branch-misses      — Mispredicted branches"
echo "  page-faults        — Page faults (all types)"
echo "  context-switches   — Context switches"
echo "  cpu-migrations     — Thread migrations across CPUs"
echo "  L1-dcache-loads    — L1 data cache loads"
echo "  L1-dcache-load-misses — L1 data cache misses"
echo ""
echo "  List all available: perf list"
echo ""

echo "── perf record + perf report — CPU Profiling ──"
echo "  Record and analyze CPU usage of a workload."
echo ""
echo "  perf record -F 99 -g -- /observability/workload.sh cpu 10"
echo "  perf report --stdio"
echo "  perf script | stackcollapse-perf.pl | flamegraph.pl > flame.svg"
echo ""

echo "── perf top — Live Hotspot View ──"
echo "  perf top    — interactive function-level profile"
echo "  perf top -g — with call graph (like htop for CPU instructions)"
echo ""

echo "── trace-cmd (ftrace frontend) ──"
echo "  Record and report ftrace events with a simpler interface."
echo ""
echo "  trace-cmd record -e sched_switch -e syscalls:sys_enter_write -- \\"
echo "      /observability/workload.sh mixed 10"
echo "  trace-cmd report    — view the trace"
echo "  trace-cmd report --cpu 0    — filter by CPU"
echo "  trace-cmd report -l         — latency format"
echo "  trace-cmd report -F 'comm=="bash"' — filter by command"
echo "  trace-cmd hist   — histogram of trace events"
echo "  kernelshark trace.dat — GUI visualization"
echo ""

echo "── bpftrace — Dynamic Kprobe/Uprobe Tracing ──"
echo "  One-liners for quick questions:"
echo ""
echo "  # What files are being opened?"
echo "  bpftrace -e 'tracepoint:syscalls:sys_enter_openat {"
echo "      printf(\"%s %s\\n\", comm, str(args->filename)); }'"
echo ""
echo "  # Count syscalls by program:"
echo "  bpftrace -e 'tracepoint:raw_syscalls:sys_enter {"
echo "      @[comm] = count(); }'"
echo ""
echo "  # I/O latency histogram:"
echo "  bpftrace -e 'kprobe:blk_account_io_start {"
echo "      @start[arg0] = nsecs; }"
echo "  kprobe:blk_account_io_done / @start[arg0] / {"
echo "      $delta = nsecs - @start[arg0]; @io_latency_us = hist($delta / 1000);"
echo "      delete(@start[arg0]); }'"
echo ""
echo "  # Process creation trace:"
echo "  bpftrace -e 'tracepoint:syscalls:sys_enter_execve {"
echo "      printf(\"PID %d exec: %s\\n\", pid, str(args->filename)); }'"
echo ""

echo "── eBPF vs Traditional Observability ──"
echo "  +---------------+-----------+-----------+-----------+"
echo "  | Capability    |  strace   |   perf    |   eBPF    |"
echo "  +---------------+-----------+-----------+-----------+"
echo "  | Overhead      |  High     |  Low      |  Very Low |"
echo "  | Granularity   |  Syscall  |  Counter  |  Custom   |"
echo "  | In-kernel     |  No       |  Partly   |  Yes      |"
echo "  | Filtering     |  Limited  |  No       |  Yes      |"
echo "  | Aggregation   |  No       |  Yes      |  Yes      |"
echo "  | ProductionOK  |  No       |  Yes      |  Yes      |"
echo "  +---------------+-----------+-----------+-----------+"
echo ""

echo "── Using perf on the Workload ──"
echo "  Running a quick CPU workload with perf stat..."
/observability/workload.sh cpu 3 &
WL_PID=$!
sleep 0.5

perf stat -e cycles,instructions,cache-misses,branch-misses \
    -e context-switches,cpu-migrations,page-faults \
    -p $WL_PID -- sleep 5 2>&1 || echo "  (perf not available — needs --privileged)"

wait $WL_PID 2>/dev/null || true
echo ""

echo "── Observability via /proc ──"
echo "  No tools needed — just cat the right files:"
echo ""
echo "  # Process state:"
echo "  cat /proc/\$(pgrep -f workload | head -1)/status | grep -E 'State|Vm|voluntary|nonvoluntary'"
echo ""
echo "  # System-wide interrupt counts:"
echo "  cat /proc/interrupts | head -5"
echo ""
echo "  # SoftIRQ counts:"
echo "  cat /proc/softirqs | head -5"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Compare perf stat output for CPU vs IO workload"
echo "  2. Use trace-cmd to record sched_switch events during workload"
echo "  3. bpftrace: trace all open() calls system-wide"
echo "  4. perf record -g: capture a call graph and view with perf report"
echo "  5. Take the benchmark.sh test to compare tool overheads"
echo "  6. Generate a kernel function call graph with ftrace"
echo "  7. Explore /sys/kernel/debug/tracing/ for available events"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /observability
ENTRYPOINT ["/entrypoint.sh"]

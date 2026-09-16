# Performance Analysis Lab - perf profiling, flame graphs, stress
# Purpose: Profiling environment for the performance-analysis article.
# Build:  podman build -f sysinternals/performance-analysis.Containerfile -t performance-analysis-lab .
# Run:    podman run -it --rm --privileged performance-analysis-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    perf \
    linux-tools \
    bpf-tools \
    git \
    python \
    procps-ng \
    stress-ng \
    util-linux \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /perf /perf/FlameGraph

# Clone Brendan Gregg's FlameGraph tools
RUN git clone --depth 1 https://github.com/brendangregg/FlameGraph.git /perf/FlameGraph 2>/dev/null || \
    echo "FlameGraph clone failed (network issue?) — downloading minimal script set" && \
    mkdir -p /perf/FlameGraph

# If git clone failed, download the essential scripts
RUN if [ ! -f /perf/FlameGraph/stackcollapse-perf.pl ]; then \
    curl -sL -o /perf/FlameGraph/stackcollapse-perf.pl \
        https://raw.githubusercontent.com/brendangregg/FlameGraph/master/stackcollapse-perf.pl && \
    curl -sL -o /perf/FlameGraph/flamegraph.pl \
        https://raw.githubusercontent.com/brendangregg/FlameGraph/master/flamegraph.pl && \
    curl -sL -o /perf/FlameGraph/difffolded.pl \
        https://raw.githubusercontent.com/brendangregg/FlameGraph/master/difffolded.pl && \
    chmod +x /perf/FlameGraph/*.pl; \
    fi 2>/dev/null; true

COPY <<'CPU_WORKLOAD' /perf/cpu_workload.py
#!/usr/bin/env python3
"""
cpu_workload.py — CPU-intensive workload with varied behavior.

Modes:
  math    — pure floating point math (CPU-bound)
  string  — string operations (memory + CPU)
  mixed   — math + string (balanced)
  syscall — frequently calls os.getpid() (syscall stress)

Usage: python3 cpu_workload.py <mode> <seconds>
"""
import sys, os, time, math, hashlib, random

def math_worker(seconds):
    end = time.time() + seconds
    x = 0.0
    while time.time() < end:
        for i in range(10000):
            x += math.sin(i * 0.001) * math.cos(i * 0.0001)
            x *= 1.000001
    return x

def string_worker(seconds):
    end = time.time() + seconds
    s = ""
    while time.time() < end:
        s += f"iteration_{random.randint(0, 1000000)}"
        hashlib.md5(s.encode()).hexdigest()
        if len(s) > 10000:
            s = ""
    return None

def mixed_worker(seconds):
    end = time.time() + seconds
    while time.time() < end:
        math_worker(0.01)
        string_worker(0.01)
    return None

def syscall_worker(seconds):
    end = time.time() + seconds
    while time.time() < end:
        for i in range(5000):
            os.getpid()
    return None

if __name__ == '__main__':
    mode = sys.argv[1] if len(sys.argv) > 1 else 'mixed'
    dur = int(sys.argv[2]) if len(sys.argv) > 2 else 30
    print(f"[Workload] mode={mode} duration={dur}s PID={os.getpid()}")

    workers = {
        'math': math_worker,
        'string': string_worker,
        'mixed': mixed_worker,
        'syscall': syscall_worker,
    }

    fn = workers.get(mode, mixed_worker)
    fn(dur)
    print(f"[Workload] Done.")
CPU_WORKLOAD

COPY <<'PROFILE_SCRIPT' /perf/profile_workload.sh
#!/bin/bash
# profile_workload.sh — Run perf on workload and generate flame graph.
set -e

DURATION=${1:-15}
MODE=${2:-mixed}
OUTDIR=${3:-/perf/output}

mkdir -p "$OUTDIR"

echo "=== Performance Profiling Workflow ==="
echo "  Duration:  ${DURATION}s"
echo "  Workload:  $MODE"
echo "  Output:    $OUTDIR"
echo ""

echo "── Step 1: Run workload with perf stat (counter overview) ──"
perf stat -e cycles,instructions,cache-references,cache-misses,\
branch-misses,page-faults,context-switches,cpu-migrations \
    -o "$OUTDIR/perf_stat.txt" -- \
    python3 /perf/cpu_workload.py "$MODE" "$DURATION" 2>/dev/null || \
    echo "  perf stat failed (needs --privileged)"
echo ""
if [ -f "$OUTDIR/perf_stat.txt" ]; then
    cat "$OUTDIR/perf_stat.txt"
fi

echo ""
echo "── Step 2: Run perf record (sampling profiler) ──"
perf record -F 99 -g -o "$OUTDIR/perf.data" -- \
    python3 /perf/cpu_workload.py "$MODE" "$DURATION" 2>/dev/null || \
    echo "  perf record failed (needs --privileged)"

echo ""
echo "── Step 3: perf report (top functions) ──"
if [ -f "$OUTDIR/perf.data" ]; then
    perf report --stdio -i "$OUTDIR/perf.data" -n --no-children \
        --sort comm,dso,symbol 2>/dev/null | head -40 || echo "  report failed"
fi

echo ""
echo "── Step 4: Generate flame graph ──"
if [ -f "$OUTDIR/perf.data" ] && [ -f /perf/FlameGraph/stackcollapse-perf.pl ]; then
    echo "  Collapsing stacks..."
    perf script -i "$OUTDIR/perf.data" 2>/dev/null | \
        /perf/FlameGraph/stackcollapse-perf.pl > "$OUTDIR/folded.txt" 2>/dev/null || \
        echo "    stackcollapse failed"

    if [ -f "$OUTDIR/folded.txt" ] && [ -s "$OUTDIR/folded.txt" ]; then
        echo "  Generating flame graph SVG..."
        /perf/FlameGraph/flamegraph.pl "$OUTDIR/folded.txt" > \
            "$OUTDIR/flamegraph.svg" 2>/dev/null && \
            echo "  Flame graph: $OUTDIR/flamegraph.svg ($(stat -c%s "$OUTDIR/flamegraph.svg") bytes)" || \
            echo "    flamegraph.pl failed"
    else
        echo "  No stack data to fold (perf record may have failed)"
    fi
else
    echo "  Skipped — perf.data or flamegraph tools not available"
fi
echo ""

echo "── Step 5: Differential flame graph (compare two runs) ──"
echo "  # Profile workload A:"
echo "  perf record -o perf_a.data -- python3 cpu_workload.py math 15"
echo "  perf script -i perf_a.data | stackcollapse-perf.pl > a_folded.txt"
echo ""
echo "  # Profile workload B:"
echo "  perf record -o perf_b.data -- python3 cpu_workload.py string 15"
echo "  perf script -i perf_b.data | stackcollapse-perf.pl > b_folded.txt"
echo ""
echo "  # Generate diff (red = more in A, blue = more in B):"
echo "  difffolded.pl a_folded.txt b_folded.txt | flamegraph.pl > diff.svg"
echo ""

echo "── Output Files ──"
ls -la "$OUTDIR/" 2>/dev/null || echo "  (no output files)"
echo ""

echo "=== Profiling Complete ==="
PROFILE_SCRIPT

COPY <<'STRESS_PROFILE' /perf/stress_profile.sh
#!/bin/bash
# stress_profile.sh — Run stress-ng workloads and profile them.
set -e

DURATION=10

echo "=== Stress-ng Performance Profiling ==="
echo ""

echo "── CPU Stress (4 workers, ${DURATION}s) ──"
perf stat -e cycles,instructions,ipc,cache-misses,branch-misses \
    stress-ng --cpu 4 --timeout ${DURATION}s --metrics-brief 2>&1 || \
    echo "  (perf or stress-ng not available)"

echo ""
echo "── Memory Stress (2 workers, 512M each) ──"
perf stat -e page-faults,dTLB-load-misses,LLC-load-misses \
    stress-ng --vm 2 --vm-bytes 512M --timeout ${DURATION}s --metrics-brief 2>&1 || \
    echo "  (perf or stress-ng not available)"

echo ""
echo "── I/O Stress (2 workers, 1G) ──"
perf stat -e context-switches,cpu-migrations \
    stress-ng --hdd 2 --hdd-bytes 1G --timeout ${DURATION}s --metrics-brief 2>&1 || \
    echo "  (perf or stress-ng not available)"

echo ""
echo "── Mixed Stress ──"
perf stat -e cycles,instructions,cache-misses,page-faults,context-switches \
    stress-ng --cpu 2 --vm 2 --hdd 2 --timeout ${DURATION}s --metrics-brief 2>&1 || \
    echo "  (perf or stress-ng not available)"

echo ""
echo "=== Stress Profiling Complete ==="
STRESS_PROFILE

RUN chmod +x /perf/cpu_workload.py /perf/profile_workload.sh /perf/stress_profile.sh

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Performance Analysis Lab — Profiling & Flame Graphs ==="
echo ""
echo "This lab demonstrates Linux performance profiling with perf,"
echo "flame graph generation, and stress testing analysis."
echo ""

echo "── Performance Analysis Methodology ──"
echo ""
echo "  1. CHARACTERIZE:  What is the workload doing?"
echo "     (CPU-bound? I/O-bound? Memory-bound? Network-bound?)"
echo ""
echo "  2. BENCHMARK:     Establish a baseline."
echo "     (perf stat: IPC, cache-miss rate, context switches)"
echo ""
echo "  3. PROFILE:       Where is time being spent?"
echo "     (perf record + report: hot functions, call graphs)"
echo ""
echo "  4. ANALYZE:       Why is it slow?"
echo "     (Flame graph: visual heat map of CPU usage)"
echo ""
echo "  5. OPTIMIZE:      Fix the bottleneck."
echo ""
echo "  6. VERIFY:        Re-benchmark to confirm improvement."
echo ""

echo "── CPU Performance Metrics ──"
echo "  IPC (Instructions Per Cycle):"
echo "    > 1.0 = good (superscalar execution)"
echo "    < 0.5 = bad (stalls on memory/cache)"
echo ""
echo "  Cache miss rate:"
echo "    < 1%  = excellent"
echo "    1-5%  = typical"
echo "    > 10% = memory-bound bottleneck"
echo ""
echo "  Branch misprediction rate:"
echo "    < 1%  = good"
echo "    1-5%  = acceptable"
echo "    > 5%  = branch-heavy code (sorting, parsing)"
echo ""

echo "── Top-Down Performance Analysis (Intel) ──"
echo ""
echo "  Level 1:"
echo "    Retiring     — useful work (want this HIGH)"
echo "    Bad Spec     — wasted work (mispredicts)"
echo "    Front Bound  — instruction fetch stalls"
echo "    Back Bound   — data/memory stalls"
echo ""
echo "  Run:  perf stat --topdown <command>"
echo ""

echo "── Available Workload Modes ──"
echo "  python3 /perf/cpu_workload.py math 10     — CPU-bound math"
echo "  python3 /perf/cpu_workload.py string 10   — memory + string ops"
echo "  python3 /perf/cpu_workload.py mixed 10    — balanced workload"
echo "  python3 /perf/cpu_workload.py syscall 10  — syscall-heavy"
echo ""

echo "── Stress-ng Workload Generation ──"
echo "  stress-ng --cpu 4 --timeout 10s --metrics-brief    # CPU workers"
echo "  stress-ng --vm 2 --vm-bytes 1G --timeout 10s        # Memory stress"
echo "  stress-ng --hdd 4 --hdd-bytes 2G --timeout 10s      # I/O stress"
echo "  stress-ng --net 2 --timeout 10s                      # Network stress"
echo ""

echo "── Flame Graph Tutorial ──"
echo ""
echo "  Flame graphs show the call stack hierarchy, with width proportional"
echo "  to CPU time. This makes hotspots visually obvious."
echo ""
echo "  Colors (when using --colors=hot):"
echo "    Red    — User-space functions"
echo "    Orange — Kernel functions"
echo "    Yellow — Library functions (libc, libm)"
echo "    Green  — JIT-compiled / interpreted functions"
echo ""
echo "  Interactive usage: open flamegraph.svg in a browser"
echo "    - Click to zoom into a specific stack"
echo "    - Search with Ctrl+F to highlight functions"
echo "    - Right-click to reset zoom"
echo ""

echo "── Quick Profiling Run ──"
echo ""
echo "  Running a 5-second CPU workload with perf stat..."
perf stat -e cycles,instructions,cache-references,cache-misses,branch-misses \
    python3 /perf/cpu_workload.py mixed 5 2>&1 || \
    echo "  (perf not available — needs --privileged)"
echo ""

echo "── How to Read perf stat Output ──"
echo ""
echo "  cycles              — total CPU cycles consumed"
echo "  instructions        — total instructions executed"
echo "  IPC                 — instructions / cycles (higher = better)"
echo "  cache-references    — last-level cache accesses"
echo "  cache-misses        — last-level cache misses (went to RAM)"
echo "  cache-miss-rate     — cache-misses / cache-references (lower = better)"
echo "  branch-misses       — mispredicted branches"
echo "  branch-miss-rate    — branch-misses / branches (lower = better)"
echo "  page-faults         — page faults (major + minor)"
echo "  context-switches    — voluntary + involuntary"
echo "  cpu-migrations      — thread moved to another CPU"
echo ""

echo "── perf record Options ──"
echo "  -F 99        — sample at 99 Hz (default: 4000)"
echo "  -g           — capture call graph (stack traces)"
echo "  -a           — system-wide (all CPUs)"
echo "  -p <PID>     — attach to specific process"
echo "  -C <CPU>     — only sample specific CPU"
echo "  --call-graph dwarf  — use DWARF for call graphs (more accurate)"
echo "  --call-graph fp     — use frame pointer (faster, needs -fno-omit-frame-pointer)"
echo "  -e <event>   — sample on specific event (default: cycles)"
echo "  -- sleep N   — run for N seconds (after --)"
echo ""

echo "── perf report Options ──"
echo "  --stdio               — text output"
echo "  --tui                 — interactive ncurses (press ? for help)"
echo "  -n                    — show number of samples"
echo "  --sort comm,dso,symbol   — sort by command, DSO, symbol"
echo "  --no-children         — self time only (not cumulative)"
echo "  --percent-limit 1     — hide entries < 1%"
echo ""

echo "── FlameGraph Script Reference ──"
echo "  stackcollapse-perf.pl     — collapses perf call stacks"
echo "  stackcollapse-stap.pl     — for SystemTap output"
echo "  stackcollapse-jstack.pl   — for Java jstack output"
echo "  stackcollapse-gdb.pl      — for GDB backtraces"
echo "  flamegraph.pl             — generates SVG flame graph"
echo "  difffolded.pl             — generates diff between two profiles"
echo ""

echo "── Differential Flame Graphs ──"
echo ""
echo "  Compare before/after optimization:"
echo "  1. Profile baseline:"
echo "     perf record -o before.data -- ./myprogram"
echo "     perf script -i before.data | stackcollapse-perf.pl > before.folded"
echo ""
echo "  2. Profile optimized:"
echo "     perf record -o after.data -- ./myprogram"
echo "     perf script -i after.data | stackcollapse-perf.pl > after.folded"
echo ""
echo "  3. Generate diff flame graph:"
echo "     difffolded.pl before.folded after.folded | flamegraph.pl > diff.svg"
echo ""
echo "  Red = more samples in before (regression)"
echo "  Blue = more samples in after (improvement)"
echo ""

echo "── Full Profiling Pipeline ──"
echo ""
echo "  Run the complete profiling pipeline:"
echo "  /perf/profile_workload.sh 15 mixed /tmp/perf_out"
echo ""
echo "  This will:"
echo "    1. perf stat (counter overview)"
echo "    2. perf record (sampling)"
echo "    3. perf report (text report)"
echo "    4. Generate flamegraph.svg"
echo ""

echo "── Additional perf Subcommands ──"
echo "  perf sched record    — scheduler latency analysis"
echo "  perf sched latency   — display scheduling latencies"
echo "  perf lock record     — lock contention analysis"
echo "  perf lock report     — display lock contention"
echo "  perf kmem record     — kernel memory allocation analysis"
echo "  perf kmem stat       — kernel allocator statistics"
echo "  perf probe           — add dynamic tracepoints"
echo "  perf trace           — trace system calls (low-overhead strace)"
echo "  perf mem record      — memory access sampling"
echo "  perf c2c record      — cache-to-cache (false sharing) analysis"
echo ""

echo "── Performance Tuning Knobs ──"
echo "  CPU governor:    cpupower frequency-set -g performance"
echo "  IRQ affinity:    echo <mask> > /proc/irq/<N>/smp_affinity"
echo "  NUMA balancing:  echo 0 > /proc/sys/kernel/numa_balancing"
echo "  Transparent HP:  echo madvise > /sys/kernel/mm/transparent_hugepage/enabled"
echo "  Swappiness:      sysctl vm.swappiness=10"
echo "  I/O scheduler:   echo kyber > /sys/block/sda/queue/scheduler"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Run full profiling: /perf/profile_workload.sh 15 mixed"
echo "  2. Compare math vs string workload flame graphs"
echo "  3. Generate differential flame graph before/after optimization"
echo "  4. Use perf top to live-monitor CPU hotspots"
echo "  5. Profile stress-ng: /perf/stress_profile.sh"
echo "  6. Analyze lock contention: perf lock record -- stress-ng --cpu 8 --timeout 5s"
echo "  7. Profile false sharing: perf c2c record -- <workload>"
echo "  8. Open flamegraph.svg in a browser and explore interactively"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /perf
ENTRYPOINT ["/entrypoint.sh"]

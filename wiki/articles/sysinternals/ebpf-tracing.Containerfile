# ebpf-tracing.Containerfile - bpftrace scripts for process, file, and network tracing
# Purpose: Run ready-made bpftrace probes against live kernel tracepoints.
# Build:  podman build -f sysinternals/ebpf-tracing.Containerfile -t ebpf-tracing-lab .
# Run:    podman run -it --rm --privileged ebpf-tracing-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    bpftrace \
    bpf-tools \
    strace \
    procps-ng \
    util-linux \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /trace

COPY <<'PROCESS_TRACE' /trace/process_trace.bt
#!/usr/bin/env bpftrace
// process_trace.bt — Trace process lifecycle: exec, fork, exit.

BEGIN {
    printf("=== Process Lifecycle Tracer ===\n");
    printf("Tracing execve, clone, exit events... Ctrl+C to stop.\n\n");
}

tracepoint:syscalls:sys_enter_execve
{
    printf("EXEC  PID:%-6d PPID:%-6d CMD:%s\n",
        pid, curtask->parent->pid, str(args->filename));
}

tracepoint:syscalls:sys_enter_clone
{
    printf("FORK  PID:%-6d PPID:%-6d\n", pid, curtask->parent->pid);
}

tracepoint:syscalls:sys_enter_exit_group
{
    printf("EXIT  PID:%-6d COMM:%-16s CODE:%ld\n",
        pid, comm, args->error_code);
}

END {
    printf("\nTracing stopped.\n");
}
PROCESS_TRACE

COPY <<'FILE_TRACE' /trace/file_trace.bt
#!/usr/bin/env bpftrace
// file_trace.bt — Trace file open events with process info.

BEGIN {
    printf("=== File Open Tracer ===\n");
    printf("Tracing openat syscalls... Ctrl+C to stop.\n\n");
    printf("%-8s %-7s %-16s %-4s %s\n",
        "TIME", "PID", "COMM", "FLAGS", "FILENAME");
}

tracepoint:syscalls:sys_enter_openat
{
    $flags = args->flags;
    $mode_str = "?";

    if ($flags & 0x040000) { $mode_str = "DIR"; }
    else if ($flags & 0x8000) { $mode_str = "O_CLOEXEC"; }
    else if ($flags == 0) { $mode_str = "RDONLY"; }

    printf("%-8llu %-7d %-16s %-10s %s\n",
        elapsed, pid, comm, $mode_str, str(args->filename));
}

END {
    printf("\nTracing stopped.\n");
}
FILE_TRACE

COPY <<'NETWORK_TRACE' /trace/network_trace.bt
#!/usr/bin/env bpftrace
// network_trace.bt — Trace TCP connect and accept events.

BEGIN {
    printf("=== Network Connection Tracer ===\n");
    printf("Tracing connect/accept syscalls... Ctrl+C to stop.\n\n");
}

tracepoint:syscalls:sys_enter_connect
{
    // args->uservaddr is a struct sockaddr*
    // We can only show the fd and PID here reliably.
    printf("CONNECT  PID:%-6d COMM:%-16s FD:%d\n",
        pid, comm, args->fd);
}

tracepoint:syscalls:sys_enter_accept4
{
    printf("ACCEPT   PID:%-6d COMM:%-16s FD:%d\n",
        pid, comm, args->fd);
}

tracepoint:syscalls:sys_enter_sendto
{
    printf("SEND     PID:%-6d COMM:%-16s FD:%d LEN:%zu\n",
        pid, comm, args->fd, args->len);
}

tracepoint:syscalls:sys_enter_recvfrom
{
    printf("RECV     PID:%-6d COMM:%-16s FD:%d\n",
        pid, comm, args->fd);
}

END {
    printf("\nTracing stopped.\n");
}
NETWORK_TRACE

COPY <<'SYSCALL_COUNT' /trace/syscall_count.bt
#!/usr/bin/env bpftrace
// syscall_count.bt — Count system calls per process.

BEGIN {
    printf("Counting syscalls by process (top 20). Ctrl+C to stop.\n\n");
}

tracepoint:raw_syscalls:sys_enter
{
    @syscalls[pid, comm] = count();
}

interval:s:5 {
    printf("\033[2J\033[H");
    printf("=== Top 20 Syscall-Counting Processes (last 5s) ===\n\n");
    printf("%-8s %-16s %s\n", "PID", "COMM", "COUNT");
    printf("-----------------------------------------\n");
    print(@syscalls, 20);
    clear(@syscalls);
}

END {
    clear(@syscalls);
}
SYSCALL_COUNT

COPY <<'IO_SIZE_HIST' /trace/io_size_hist.bt
#!/usr/bin/env bpftrace
// io_size_hist.bt — Histogram of I/O sizes by process.

BEGIN {
    printf("I/O Size Histogram. Ctrl+C to stop.\n\n");
}

tracepoint:syscalls:sys_enter_read
{
    @read_sizes[comm] = hist(args->count);
}

tracepoint:syscalls:sys_enter_write
{
    @write_sizes[comm] = hist(args->count);
}

END {
    printf("\n=== Read Size Distribution ===\n");
    print(@read_sizes);
    printf("\n=== Write Size Distribution ===\n");
    print(@write_sizes);
    clear(@read_sizes);
    clear(@write_sizes);
}
IO_SIZE_HIST

RUN chmod +x /trace/process_trace.bt /trace/file_trace.bt /trace/network_trace.bt /trace/syscall_count.bt /trace/io_size_hist.bt

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== eBPF Tracing Lab — Practical bpftrace Scripts ==="
echo ""
echo "This lab provides ready-to-use bpftrace scripts for common"
echo "tracing tasks: process lifecycle, file opens, network connections."
echo ""

echo "── bpftrace Quick Reference ──"
echo ""
echo "  SYNTAX:   bpftrace -e 'PROBE { ACTION }'"
echo "  PROBES:   kprobe:<func>   uprobe:<path>:<func>"
echo "            kretprobe:<func> uretprobe:<path>:<func>"
echo "            tracepoint:<cat>:<event>"
echo "            profile:hz:99   interval:s:1"
echo "            software:<event> hardware:<event>"
echo "            BEGIN / END"
echo ""
echo "  VARIABLES: pid, tid, uid, comm, nsecs, elapsed, kstack, ustack"
echo "  BUILT-INS: count(), sum(), avg(), min(), max(), hist(), lhist()"
echo "             stats(), printf(), str(), join(), ksym(), usym()"
echo ""

echo "── One-Liner Examples ──"
echo ""
echo "  # What files are being opened right now?"
echo "  bpftrace -e 't:syscalls:sys_enter_openat { printf(\"%s %s\\n\", comm, str(args->filename)); }'"
echo ""
echo "  # Count syscalls by process:"
echo "  bpftrace -e 't:raw_syscalls:sys_enter { @[comm] = count(); }'"
echo ""
echo "  # Who is calling kmalloc?"
echo "  bpftrace -e 'kprobe:kmalloc { @[kstack] = count(); }'"
echo ""
echo "  # I/O latency histogram (block layer):"
echo "  bpftrace -e 'kprobe:blk_account_io_start { @start[arg0] = nsecs; }"
echo "              kprobe:blk_account_io_done /@start[arg0]/ {"
echo "              @lat = hist((nsecs - @start[arg0]) / 1000); delete(@start[arg0]); }'"
echo ""
echo "  # CPU frequency distribution:"
echo "  bpftrace -e 'profile:hz:99 { @[kstack] = count(); }'"
echo ""
echo "  # Trace signals:"
echo "  bpftrace -e 't:syscalls:sys_enter_kill { printf(\"SIG %d → PID %d\\n\", args->sig, args->pid); }'"
echo ""

echo "── Available Scripts ──"
echo "  /trace/process_trace.bt     — exec, fork, exit events"
echo "  /trace/file_trace.bt        — file open events"
echo "  /trace/network_trace.bt     — connect, accept, send, recv"
echo "  /trace/syscall_count.bt     — top syscall counters per process"
echo "  /trace/io_size_hist.bt      — I/O size distribution histogram"
echo ""

echo "── Running a Demo: Process Trace ──"
echo "  Start the process tracer (runs for 5 seconds in background):"
bpftrace /trace/process_trace.bt &
BPPID=$!
sleep 1

echo "  Generating some process activity..."
bash -c "echo hello" &
bash -c "ls /tmp" &
sleep 0.5
sleep 1

kill $BPPID 2>/dev/null || true
wait $BPPID 2>/dev/null || true
echo ""
echo "  Demo complete."
echo ""

echo "── Running a Demo: File Trace ──"
echo "  Start file trace (5 second background run):"
bpftrace /trace/file_trace.bt &
BPPID=$!
sleep 1

echo "  Generating file opens..."
cat /etc/hostname > /dev/null
ls /etc/ > /dev/null
head -1 /etc/passwd > /dev/null
sleep 2

kill $BPPID 2>/dev/null || true
wait $BPPID 2>/dev/null || true
echo ""
echo "  Demo complete."
echo ""

echo "── Probe Types Reference ──"
echo "  kprobe:<function>        — kernel function entry"
echo "  kretprobe:<function>     — kernel function return"
echo "  uprobe:<binary>:<func>   — user function entry"
echo "  uretprobe:<binary>:<func> — user function return"
echo "  tracepoint:<cat>:<event> — static tracepoint"
echo "  profile:hz:<rate>        — timed sampling"
echo "  interval:s:<sec>         — timed interval"
echo "  BEGIN / END              — startup / shutdown"
echo "  usdt:<path>:<provider>:<name> — USDT probe"
echo "  software:<event>         — software event (e.g. cpu-clock)"
echo "  hardware:<event>         — hardware event (e.g. cache-misses)"
echo ""

echo "── Map Types in bpftrace ──"
echo "  @x = count()              — count occurrences"
echo "  @x = sum(value)           — sum of values"
echo "  @x = avg(value)           — average"
echo "  @x = min(value)           — minimum"
echo "  @x = max(value)           — maximum"
echo "  @x = stats(value)         — min/max/avg/count/total"
echo "  @x = hist(value)          — power-of-2 histogram"
echo "  @x = lhist(value, min, max, step) — linear histogram"
echo "  @x[key] = value           — explicit assignment"
echo "  delete(@x[key])           — delete entry"
echo "  clear(@x)                 — clear map"
echo "  print(@x, top)            — print top N entries"
echo ""

echo "── Listing Available Probes ──"
echo "  List all kprobes:"
echo "    bpftrace -l 'kprobe:*' | head -40"
echo ""
echo "  List all tracepoints:"
echo "    bpftrace -l 'tracepoint:*' | head -40"
echo ""
echo "  List syscall tracepoints:"
echo "    bpftrace -l 'tracepoint:syscalls:*'"
echo ""
echo "  Count available probes:"
echo "    bpftrace -l | wc -l"
echo ""

echo "── Practical Debugging Recipes ──"
echo ""
echo "  # Why is my disk busy?"
echo "  bpftrace -e 't:block:block_rq_issue { @[comm] = count(); }'"
echo ""
echo "  # Which processes are creating the most threads?"
echo "  bpftrace -e 't:syscalls:sys_enter_clone { @[comm] = count(); }'"
echo ""
echo "  # Who is sending signals?"
echo "  bpftrace -e 't:syscalls:sys_enter_kill { printf(\"%s → %d (sig %d)\\n\", comm, args->pid, args->sig); }'"
echo ""
echo "  # Page fault analysis:"
echo "  bpftrace -e 's:page-faults:1 { @[comm, kstack] = count(); }'"
echo ""
echo "  # Slow file I/O (reads > 10ms):"
echo "  bpftrace -e 'kprobe:vfs_read { @start[tid] = nsecs; }"
echo "              kretprobe:vfs_read /@start[tid]/ {"
echo "              $ms = (nsecs - @start[tid]) / 1000000;"
echo "              if ($ms > 10) { printf(\"SLOW: %s %dms\\n\", comm, $ms); }"
echo "              delete(@start[tid]); }'"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Run /trace/process_trace.bt and start/stop processes in another terminal"
echo "  2. Run /trace/file_trace.bt and browse files: find /etc -name '*.conf'"
echo "  3. Run /trace/network_trace.bt and curl a website"
echo "  4. Run /trace/io_size_hist.bt and generate I/O with dd"
echo "  5. Write a custom one-liner to trace a specific kernel function"
echo "  6. Combine multiple probes: trace connect → send → recv → close"
echo "  7. Count unique stack traces: @[kstack, ustack] = count();"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /trace
ENTRYPOINT ["/entrypoint.sh"]

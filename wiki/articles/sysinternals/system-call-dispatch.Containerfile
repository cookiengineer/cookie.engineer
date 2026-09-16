# system-call-dispatch.Containerfile
# Purpose: Trace and measure syscall dispatch with strace, bpftrace, and perf.
# Build:  podman build -f system-call-dispatch.Containerfile -t syscall-lab .
# Run:    podman run -it --rm --privileged syscall-lab
# Notes:  --privileged is needed for bpftrace and ftrace access. The lab runs strace,
#         bpftrace, and perf benchmarks against a small syscall-heavy test program.

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    strace \
    bpftrace \
    perl \
    procps-ng \
    util-linux \
    python \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /test

COPY <<'SYSCALL_TEST' /test/syscall_test.c
/*
 * syscall_test.c - A small program that exercises various system calls.
 * Used with strace and bpftrace to observe syscall dispatch.
 */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>
#include <errno.h>

int main(void) {
    int fd, sock, status;
    char buf[128];
    pid_t pid;
    struct stat st;
    struct timespec ts;
    void *map;

    printf("=== Syscall Test Program (PID=%d) ===\n", getpid());

    /* 1. open() + write() + read() + close() */
    printf("\n[1] File operations\n");
    fd = open("/tmp/syscall_test.txt", O_CREAT | O_RDWR | O_TRUNC, 0644);
    printf("    open()  -> fd=%d\n", fd);
    write(fd, "Hello from syscall_test!\n", 24);
    printf("    write() -> %d bytes\n", 24);
    lseek(fd, 0, SEEK_SET);
    read(fd, buf, sizeof(buf));
    printf("    read()  -> '%s'", buf);
    close(fd);

    /* 2. stat() */
    printf("\n[2] File metadata\n");
    stat("/tmp/syscall_test.txt", &st);
    printf("    stat()  -> size=%ld inode=%lu\n", st.st_size, st.st_ino);

    /* 3. fork() + waitpid() */
    printf("\n[3] Process creation\n");
    pid = fork();
    if (pid == 0) {
        printf("    Child: PID=%d PPID=%d\n", getpid(), getppid());
        _exit(42);
    } else {
        printf("    fork()  -> child PID=%d\n", pid);
        waitpid(pid, &status, 0);
        printf("    wait()  -> child exited with %d\n", WEXITSTATUS(status));
    }

    /* 4. mmap() + munmap() */
    printf("\n[4] Memory mapping\n");
    map = mmap(NULL, 4096, PROT_READ | PROT_WRITE,
               MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    printf("    mmap()  -> %p (anonymous, 4KB)\n", map);
    memcpy(map, "data", 4);
    munmap(map, 4096);
    printf("    munmap() -> ok\n");

    /* 5. gettimeofday / clock_gettime */
    printf("\n[5] Time syscalls\n");
    clock_gettime(CLOCK_REALTIME, &ts);
    printf("    clock_gettime() -> %ld.%09ld\n", ts.tv_sec, ts.tv_nsec);

    /* 6. socket() + bind() + connect() */
    printf("\n[6] Network syscalls\n");
    sock = socket(AF_INET, SOCK_STREAM, 0);
    printf("    socket() -> fd=%d\n", sock);
    close(sock);

    /* 7. getpid / getuid / getgid */
    printf("\n[7] Identity syscalls\n");
    printf("    getpid()   -> %d\n", getpid());
    printf("    getuid()   -> %d\n", getuid());
    printf("    getppid()  -> %d\n", getppid());

    /* 8. brk() / sbrk() - heap management */
    printf("\n[8] Heap allocation (brk)\n");
    void *old_break = sbrk(0);
    printf("    Program break (before): %p\n", old_break);
    void *ptr = malloc(4096);
    printf("    malloc(4096) -> %p\n", ptr);
    printf("    Program break (after):  %p\n", sbrk(0));
    free(ptr);

    /* 9. unlink */
    printf("\n[9] File removal\n");
    unlink("/tmp/syscall_test.txt");
    printf("    unlink() -> ok\n");

    /* 10. nanosleep */
    printf("\n[10] Sleep\n");
    printf("    nanosleep(0.01s)...\n");
    ts.tv_sec = 0; ts.tv_nsec = 10000000;
    nanosleep(&ts, NULL);
    printf("    ...done\n");

    printf("\n=== All syscalls exercised ===\n");
    return 0;
}
SYSCALL_TEST

COPY <<'BPFSCRIPT' /test/trace_syscalls.bt
#!/usr/bin/env bpftrace
/*
 * trace_syscalls.bt - Trace all syscall entries with PID and comm.
 *
 * Usage: bpftrace trace_syscalls.bt
 *   Or one-liner: bpftrace -e 'tracepoint:raw_syscalls:sys_enter { ... }'
 */

BEGIN {
    printf("=== BPF Syscall Tracer ===\n");
    printf("Tracing sys_enter events... Ctrl+C to stop.\n\n");
    printf("%-8s %-7s %-16s %s\n", "TIME", "PID", "COMM", "SYSCALL");
}

tracepoint:raw_syscalls:sys_enter
{
    $id = args->id;

    /* Only print known common syscalls to keep output readable */
    if ($id == 0   ||   /* read */
        $id == 1   ||   /* write */
        $id == 2   ||   /* open */
        $id == 3   ||   /* close */
        $id == 4   ||   /* stat */
        $id == 5   ||   /* fstat */
        $id == 9   ||   /* mmap */
        $id == 10  ||   /* mprotect */
        $id == 11  ||   /* munmap */
        $id == 12  ||   /* brk */
        $id == 14  ||   /* rt_sigprocmask */
        $id == 35  ||   /* nanosleep */
        $id == 39  ||   /* getpid */
        $id == 41  ||   /* socket */
        $id == 42  ||   /* connect */
        $id == 56  ||   /* clone */
        $id == 57  ||   /* fork */
        $id == 59  ||   /* execve */
        $id == 60  ||   /* exit */
        $id == 61  ||   /* wait4 */
        $id == 87  ||   /* unlink */
        $id == 228 ||   /* clock_gettime */
        $id == 231)     /* exit_group */
    {
        $name = "unknown";

        if ($id == 0)  { $name = "read"; }
        if ($id == 1)  { $name = "write"; }
        if ($id == 2)  { $name = "open"; }
        if ($id == 3)  { $name = "close"; }
        if ($id == 4)  { $name = "stat"; }
        if ($id == 9)  { $name = "mmap"; }
        if ($id == 11) { $name = "munmap"; }
        if ($id == 12) { $name = "brk"; }
        if ($id == 35) { $name = "nanosleep"; }
        if ($id == 39) { $name = "getpid"; }
        if ($id == 41) { $name = "socket"; }
        if ($id == 42) { $name = "connect"; }
        if ($id == 56) { $name = "clone"; }
        if ($id == 57) { $name = "fork"; }
        if ($id == 59) { $name = "execve"; }
        if ($id == 60) { $name = "exit"; }
        if ($id == 61) { $name = "wait4"; }
        if ($id == 87) { $name = "unlink"; }
        if ($id == 228){ $name = "clock_gettime"; }
        if ($id == 231){ $name = "exit_group"; }

        printf("%-8llu %-7d %-16s %s\n", elapsed, pid, comm, $name);
    }
}

END {
    printf("\nTracing stopped.\n");
}
BPFSCRIPT

COPY <<'BPF_COUNT' /test/count_syscalls.bt
#!/usr/bin/env bpftrace
/*
 * count_syscalls.bt - Count syscalls per process.
 *
 * Usage: bpftrace count_syscalls.bt
 */

BEGIN {
    printf("Counting syscalls per process... Ctrl+C to stop.\n\n");
}

tracepoint:raw_syscalls:sys_enter
{
    @counts[pid, comm] = count();
}

END {
    printf("\n%-8s %-16s %s\n", "PID", "COMM", "COUNT");
    print(@counts);
    clear(@counts);
}
BPF_COUNT

COPY <<'STRACE_DEMO' /test/strace_demo.sh
#!/bin/bash
# Demonstrate various strace modes on the test program
set -e

echo "-- strace Demonstration --"
echo ""

# Build the test program
gcc -o /test/syscall_test /test/syscall_test.c

echo "1. Basic strace - trace all syscalls:"
echo "   strace /test/syscall_test"
echo ""
strace -o /tmp/strace_full.log /test/syscall_test 2>/dev/null
echo "   Output saved to /tmp/strace_full.log"
echo "   Total lines: $(wc -l < /tmp/strace_full.log)"

echo ""
echo "2. Filter by syscall - only trace open, read, write, close:"
echo "   strace -e trace=open,openat,read,write,close /test/syscall_test"
echo ""
strace -e trace=open,openat,read,write,close -o /tmp/strace_filtered.log \
    /test/syscall_test 2>/dev/null
echo "   (filtered output in /tmp/strace_filtered.log)"

echo ""
echo "3. Count syscalls - summary mode:"
echo "   strace -c /test/syscall_test"
echo ""
strace -c -o /tmp/strace_summary.log /test/syscall_test 2>/dev/null
cat /tmp/strace_summary.log

echo ""
echo "4. Timestamp each call:"
echo "   strace -tt /test/syscall_test"
echo ""
strace -tt -e trace=open,read,write,close -o /tmp/strace_timed.log \
    /test/syscall_test 2>/dev/null
head -5 /tmp/strace_timed.log

echo ""
echo "5. Follow child processes:"
echo "   strace -f /test/syscall_test"
echo ""
strace -f -o /tmp/strace_follow.log /test/syscall_test 2>/dev/null
echo "   (child syscalls prefixed with [pid])"
grep "fork\|clone\|wait" /tmp/strace_follow.log | head -5

echo ""
echo "6. Show only failing calls:"
echo "   strace -z /test/syscall_test"
echo ""
strace -z -o /tmp/strace_errors.log /test/syscall_test 2>/dev/null
echo "   (errors-only output in /tmp/strace_errors.log)"

echo ""
echo "-- strace Demo Complete --"
STRACE_DEMO

RUN chmod +x /test/trace_syscalls.bt /test/count_syscalls.bt /test/strace_demo.sh

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== System Call Dispatch Lab - strace & bpftrace Tracing ==="
echo ""
echo "Exploring how Linux dispatches system calls from userspace to kernel."
echo ""

echo "-- Syscall Dispatch Architecture --"
echo "  Userspace:  write(fd, buf, len)     <- C library wrapper"
echo "  ------------------------------------- glibc syscall() --"
echo "  Assembly:   mov \$1, %eax           <- syscall number"
echo "              mov fd, %rdi            <- arg1"
echo "              mov buf, %rsi           <- arg2"
echo "              syscall                 <- instruction"
echo "  ------------------------------------- mode switch --"
echo "  Kernel:     entry_SYSCALL_64()      <- entry point"
echo "              do_syscall_64(nr, regs) <- dispatch"
echo "              sys_call_table[nr]()    <- handler"
echo ""

echo "-- Syscall Table (x86_64) --"
echo "  0  = read         1  = write        2  = open"
echo "  3  = close        4  = stat         9  = mmap"
echo "  11 = munmap      12 = brk          14 = rt_sigprocmask"
echo "  21 = access      39 = getpid        41 = socket"
echo "  42 = connect     56 = clone        57 = fork"
echo "  59 = execve      60 = exit         61 = wait4"
echo "  63 = uname       78 = getdents     102 = getuid"
echo "  Full list: /usr/include/asm/unistd_64.h"
echo ""

echo "-- Building Test Program --"
gcc -o /test/syscall_test /test/syscall_test.c 2>&1
echo "  Binary: /test/syscall_test"
echo ""

echo "-- Running strace Demo --"
/test/strace_demo.sh
echo ""

echo "-- strace Reference --"
echo "  strace <cmd>               - trace all syscalls"
echo "  strace -c <cmd>            - count/summary mode"
echo "  strace -e trace=open,read  - filter specific syscalls"
echo "  strace -e trace=file       - file-related syscalls"
echo "  strace -e trace=network    - network syscalls"
echo "  strace -e trace=process    - process-related (fork,exec,...)"
echo "  strace -e trace=signal     - signal-related"
echo "  strace -p <PID>            - attach to running process"
echo "  strace -f                  - follow children"
echo "  strace -ff -o <prefix>     - one file per child"
echo "  strace -tt                 - microsecond timestamps"
echo "  strace -T                  - time spent in each call"
echo "  strace -y                  - print fd paths"
echo "  strace -k                  - print call stack"
echo ""

echo "-- Syscall Dispatch Internals --"
echo "  On x86_64:"
echo "    - 'syscall' instruction: RCX <- RIP, RIP <- LSTAR MSR, R11 <- RFLAGS"
echo "    - entry_SYSCALL_64 saves all registers to pt_regs"
echo "    - do_syscall_64(nr, regs) looks up sys_call_table[nr]"
echo "    - SYSCALL_DEFINEn(...) macros define the handler"
echo "    - On return: restore regs, swapgs, sysretq"
echo ""
echo "  VDSO (virtual dynamic shared object):"
echo "    - Some syscalls (gettimeofday, clock_gettime) don't enter kernel"
echo "    - They use VDSO mappings for fast userspace execution"
echo "    - Check: cat /proc/self/maps | grep vdso"
echo ""

echo "-- bpftrace - Kernel-Dynamic Tracing --"
echo "  Syscall entry probe:"
echo "    bpftrace -e 'tracepoint:raw_syscalls:sys_enter {"
echo "        printf(\"syscall %d by %s (PID %d)\\n\", args->id, comm, pid); }'"
echo ""
echo "  Syscall exit probe (with return value):"
echo "    bpftrace -e 'tracepoint:raw_syscalls:sys_exit {"
echo "        printf(\"syscall return: %ld\\n\", args->ret); }'"
echo ""
echo "  Filter specific syscall (e.g. execve):"
echo "    bpftrace -e 'tracepoint:syscalls:sys_enter_execve {"
echo "        printf(\"%s (pid %d) exec: %s\\n\", comm, pid, str(args->filename)); }'"
echo ""
echo "  Count syscalls per program:"
echo "    bpftrace -e 'tracepoint:raw_syscalls:sys_enter {"
echo "        @[comm] = count(); }'"
echo ""
echo "  Available syscall tracepoints:"
echo "    ls /sys/kernel/debug/tracing/events/syscalls/"
echo ""

echo "-- Try bpftrace Now --"
echo "  In another terminal, run the test program while tracing:"
echo ""
echo "  # Terminal 1: Start syscall tracer"
echo "  bpftrace /test/trace_syscalls.bt"
echo ""
echo "  # Terminal 2: Run the test"
echo "  /test/syscall_test"
echo ""
echo ""

echo "-- Raw Syscall Invocation (bypassing libc) --"
echo "  perl -e 'syscall(39);'                    # getpid"
echo "  python3 -c 'import os; os.write(1,b\"hi\\n\")'  # write"
echo "  perl -e 'syscall(1, 1, \"hello\\n\", 6);'  # write(1, \"hello\", 6)"
echo ""
echo "  Running raw getpid:"
perl -e 'print "  getpid via syscall(39) = ", syscall(39), "\n"' 2>/dev/null || echo "  (perl syscall demo failed)"
echo ""

echo "-- Inspecting VDSO --"
echo "  cat /proc/self/maps | grep vdso"
cat /proc/self/maps | grep vdso || echo "  (no vdso found)"
echo ""
echo "-- Syscall Numbers on This Kernel --"
ARCH=$(uname -m)
if [ -f "/usr/include/asm/unistd_64.h" ]; then
    grep -E '#define __NR_' /usr/include/asm/unistd_64.h | head -20
elif [ -f "/usr/include/asm-generic/unistd.h" ]; then
    grep -E '#define __NR_' /usr/include/asm-generic/unistd.h | head -20
else
    echo "  Syscall header not found. Looking..."
    find /usr/include -name 'unistd*.h' 2>/dev/null | head -5
fi
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Strace a running process: strace -p \$(pgrep bash)"
echo "  2. Count syscalls per process: bpftrace /test/count_syscalls.bt"
echo "  3. Trace only network calls: strace -e trace=network curl http://example.com"
echo "  4. Compare strace -c for different programs (ls vs find vs cat)"
echo "  5. Trace execve calls system-wide: bpftrace -e 'tracepoint:syscalls:sys_enter_execve { printf(\"%s\\n\", str(args->filename)); }'"
echo "  6. Find the syscall table location: grep 'sys_call_table' /proc/kallsyms"
echo "  7. Study VDSO: objdump -d /proc/self/exe | grep -A5 '<'"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /test
ENTRYPOINT ["/entrypoint.sh"]

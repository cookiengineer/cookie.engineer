# dynamic-instrumentation.Containerfile - LD_PRELOAD hooking and Frida interception lab
# Purpose: Build an LD_PRELOAD hook library and a Frida attachment script.
# Build:  podman build -f sysinternals/dynamic-instrumentation.Containerfile -t dynamic-instrumentation-lab .
# Run:    podman run -it --rm --cap-add=SYS_PTRACE dynamic-instrumentation-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    python \
    python-pip \
    base-devel \
    procps-ng \
    strace \
    ltrace \
    util-linux \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN pip install --break-system-packages frida-tools 2>/dev/null || \
    pip install frida-tools 2>/dev/null || \
    echo "Frida installation may have failed — try manually"

RUN mkdir -p /lab

COPY <<'HOOK_C' /lab/hook.c
/*
 * hook.c — LD_PRELOAD hook library.
 *
 * Intercepts read(), write(), and open() calls to log them.
 * Compile: gcc -shared -fPIC -o libhook.so hook.c -ldl
 * Usage:   LD_PRELOAD=./libhook.so <program>
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdarg.h>
#include <sys/types.h>
#include <sys/stat.h>

/* Function pointer types for the real implementations */
typedef ssize_t (*orig_read_t)(int fd, void *buf, size_t count);
typedef ssize_t (*orig_write_t)(int fd, const void *buf, size_t count);
typedef int (*orig_open_t)(const char *pathname, int flags, mode_t mode);

static FILE *log_file = NULL;

static void ensure_log(void) {
    if (!log_file) {
        log_file = fopen("/tmp/hook_log.txt", "a");
        if (log_file) setbuf(log_file, NULL);  /* unbuffered */
    }
}

static void log_event(const char *event, const char *detail) {
    ensure_log();
    if (log_file)
        fprintf(log_file, "[PID %d] %s: %s\n", getpid(), event, detail);
}

/* Intercepted read() */
ssize_t read(int fd, void *buf, size_t count) {
    orig_read_t orig_read = (orig_read_t)dlsym(RTLD_NEXT, "read");
    ssize_t ret = orig_read(fd, buf, count);
    log_event("read", "");
    fprintf(log_file, "  fd=%d count=%zu ret=%zd\n", fd, count, ret);
    return ret;
}

/* Intercepted write() */
ssize_t write(int fd, const void *buf, size_t count) {
    orig_write_t orig_write = (orig_write_t)dlsym(RTLD_NEXT, "write");
    ssize_t ret = orig_write(fd, buf, count);
    log_event("write", "");
    fprintf(log_file, "  fd=%d count=%zu ret=%zd\n", fd, count, ret);
    return ret;
}

/* Intercepted open() */
int open(const char *pathname, int flags, ...) {
    orig_open_t orig_open = (orig_open_t)dlsym(RTLD_NEXT, "open");
    mode_t mode = 0;
    if (flags & O_CREAT) {
        va_list ap;
        va_start(ap, flags);
        mode = va_arg(ap, mode_t);
        va_end(ap);
    }
    int ret = orig_open(pathname, flags, mode);
    log_event("open", pathname);
    fprintf(log_file, "  flags=0x%x mode=0%o ret=%d\n", flags, mode, ret);
    return ret;
}
HOOK_C

COPY <<'MAKEFILE' /lab/Makefile
CC = gcc
CFLAGS = -shared -fPIC -Wall
LDFLAGS = -ldl

all: libhook.so hook_test

libhook.so: hook.c
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

hook_test: hook_test.c
	$(CC) -Wall -o $@ $<

clean:
	rm -f libhook.so hook_test /tmp/hook_log.txt
MAKEFILE

COPY <<'HOOK_TEST' /lab/hook_test.c
/*
 * hook_test.c — Simple test program for the LD_PRELOAD hook.
 * Performs file operations that the hook should intercept.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

int main(void) {
    int fd;
    char buf[64];

    printf("=== LD_PRELOAD Hook Test ===\n");
    printf("PID: %d\n\n", getpid());

    printf("[1] Opening file for write...\n");
    fd = open("/tmp/hook_test_file.txt", O_CREAT | O_WRONLY | O_TRUNC, 0644);
    printf("    fd = %d\n", fd);

    printf("[2] Writing data...\n");
    write(fd, "Hello from hook_test!\n", 21);

    printf("[3] Closing and reopening for read...\n");
    close(fd);
    fd = open("/tmp/hook_test_file.txt", O_RDONLY);
    printf("    fd = %d\n", fd);

    printf("[4] Reading data...\n");
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    buf[n] = '\0';
    printf("    read: '%s'", buf);

    close(fd);
    printf("\n=== Test Complete ===\n");
    printf("Check /tmp/hook_log.txt for intercepted calls.\n");
    return 0;
}
HOOK_TEST

COPY <<'FRIDA_SCRIPT' /lab/frida_hook.py
#!/usr/bin/env python3
"""
frida_hook.py — Frida dynamic instrumentation example.

Demonstrates:
  - Attaching to a process
  - Hooking libc functions (open, read, write)
  - Modifying function arguments and return values
  - Scripting Frida in Python

Usage:
  python3 frida_hook.py <process_name_or_pid>
"""

import frida
import sys
import time

JS_CODE = """
// Intercept libc's open() function
var openPtr = Module.findExportByName(null, 'open');
console.log('[+] Found open() at: ' + openPtr);

Interceptor.attach(openPtr, {
    onEnter: function(args) {
        this.path = Memory.readUtf8String(args[0]);
        this.flags = args[1].toInt32();
        console.log('[open]  path=' + this.path + ' flags=0x' + this.flags.toString(16));
    },
    onLeave: function(retval) {
        console.log('[open]  => fd=' + retval.toInt32());
    }
});

// Intercept read()
var readPtr = Module.findExportByName(null, 'read');
console.log('[+] Found read() at: ' + readPtr);

Interceptor.attach(readPtr, {
    onEnter: function(args) {
        this.fd = args[0].toInt32();
        this.count = args[2].toInt32();
    },
    onLeave: function(retval) {
        if (retval.toInt32() > 0) {
            var data = Memory.readUtf8String(this.context.rdi || this.context.esi);
            console.log('[read]  fd=' + this.fd + ' count=' + this.count +
                       ' ret=' + retval.toInt32() + ' data=' +
                       (data ? data.substring(0, 40) : '(null)'));
        }
    }
});

// Intercept write()
var writePtr = Module.findExportByName(null, 'write');
console.log('[+] Found write() at: ' + writePtr);

Interceptor.attach(writePtr, {
    onEnter: function(args) {
        this.fd = args[0].toInt32();
        this.count = args[2].toInt32();
        var data = Memory.readUtf8String(args[1], Math.min(this.count, 64));
        console.log('[write] fd=' + this.fd + ' count=' + this.count +
                   ' data=' + (data || '(null)'));
    },
    onLeave: function(retval) {
        console.log('[write] => wrote ' + retval.toInt32() + ' bytes');
    }
});

console.log('[+] All hooks installed. Waiting for events...');
"""

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <process_name|PID>")
        print(f"Example: {sys.argv[0]} cat")
        sys.exit(1)

    target = sys.argv[1]

    try:
        # Try as PID first
        if target.isdigit():
            session = frida.attach(int(target))
        else:
            session = frida.attach(target)
    except frida.ProcessNotFoundError:
        print(f"Process '{target}' not found. Spawning instead...")
        pid = frida.spawn([target])
        session = frida.attach(pid)
        frida.resume(pid)

    print(f"[*] Attached to process (session: {session})")
    script = session.create_script(JS_CODE)
    script.load()

    print("[*] Press Ctrl+C to detach.\n")
    try:
        sys.stdin.read()
    except KeyboardInterrupt:
        print("\n[*] Detaching...")
        session.detach()
        print("[*] Done.")

if __name__ == '__main__':
    main()
FRIDA_SCRIPT

COPY <<'LDPRELOAD_DEMO' /lab/ldpreload_demo.sh
#!/bin/bash
# LD_PRELOAD hook demonstration
set -e

echo "=== LD_PRELOAD Hook Demonstration ==="
echo ""
echo "LD_PRELOAD allows injecting a shared library that overrides"
echo "standard library functions (read, write, open, malloc, etc.)."
echo ""

# Build everything
cd /lab
make 2>&1

echo ""
echo "── Without LD_PRELOAD (normal execution) ──"
echo "  Running: ./hook_test"
./hook_test
echo ""

echo "── With LD_PRELOAD (hooked execution) ──"
echo "  Running: LD_PRELOAD=./libhook.so ./hook_test"
LD_PRELOAD=./libhook.so ./hook_test
echo ""

echo "── Hook Log ──"
if [ -f /tmp/hook_log.txt ]; then
    echo "  Contents of /tmp/hook_log.txt:"
    cat /tmp/hook_log.txt
else
    echo "  No log file generated (hook may not have fired)"
fi
echo ""

echo "── How It Works ──"
echo "  1. libhook.so is loaded BEFORE libc.so by the dynamic linker"
echo "  2. When the program calls read(), it resolves to our read() first"
echo "  3. Our read() uses dlsym(RTLD_NEXT, \"read\") to find the real read()"
echo "  4. We log the call, then invoke the real read(), and return its result"
echo "  5. RTLD_NEXT finds the next occurrence of 'read' in the search order"
echo ""

echo "── Common LD_PRELOAD Use Cases ──"
echo "  - Function call logging / debugging"
echo "  - malloc() tracing (memory leak detection)"
echo "  - Transparent encryption/compression"
echo "  - Sandbox bypass testing (hook dangerous functions)"
echo "  - Latency injection for testing fault tolerance"
echo "  - Replacing rand() with a deterministic version"
echo ""

echo "── Limitations ──"
echo "  - Only works on dynamically linked executables"
echo "  - Cannot intercept syscall() (direct syscall wrappers bypass libc)"
echo "  - Cannot intercept statically linked functions"
echo "  - setuid programs ignore LD_PRELOAD for security"
echo "  - Can be detected by checking /proc/self/maps"
echo ""

echo "── LD_PRELOAD Detection ──"
echo "  cat /proc/self/maps | grep -E '\.so'  # Look for unexpected .so files"
echo "  ldd <binary>                           # Check linked libraries"
echo "  cat /proc/self/environ | tr '\\0' '\\n' | grep LD_PRELOAD"
echo ""
LDPRELOAD_DEMO

RUN chmod +x /lab/frida_hook.py /lab/ldpreload_demo.sh

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Dynamic Instrumentation Lab — LD_PRELOAD & Frida ==="
echo ""
echo "This lab demonstrates two dynamic instrumentation techniques:"
echo "  1. LD_PRELOAD — function hooking via shared library injection"
echo "  2. Frida — runtime instrumentation framework with JavaScript"
echo ""

echo "── Dynamic Instrumentation Overview ──"
echo ""
echo "  Technique      │ Mechanism                  │ Granularity"
echo "  ───────────────┼────────────────────────────┼────────────"
echo "  LD_PRELOAD     │ Shared library injection   │ Libc functions"
echo "  ptrace         │ Process tracing            │ Syscalls (strace)"
echo "  uprobe         │ In-kernel breakpoint       │ Any user function"
echo "  Frida          │ JS VM injection + ptrace   │ Any function"
echo "  Dyninst        │ Binary rewriting           │ Any function"
echo "  PIN/Valgrind   │ JIT-based instrumentation  │ Every instruction"
echo ""

echo "── LD_PRELOAD Architecture ──"
echo ""
echo "  Command:                    Dynamic Linker:"
echo "  LD_PRELOAD=./hook.so cat    "
echo "       │                           │"
echo "       └─→ execve()                │"
echo "                                   ▼"
echo "                              Load ./hook.so FIRST (before libc)"
echo "                                   │"
echo "                              Resolve symbols:"
echo "                                read() → hook.so!read()"
echo "                                         (not libc.so.6!read())"
echo "                                   │"
echo "                              hook.so!read() calls dlsym(RTLD_NEXT)"
echo "                              to find libc.so.6!read()"
echo "                                   │"
echo "                              Call real read() + log + return"
echo ""

echo "── Building LD_PRELOAD Hook ──"
cd /lab
make 2>&1

if [ -f libhook.so ]; then
    echo ""
    echo "  libhook.so built: $(ls -lh libhook.so)"
    echo "  Exported symbols:"
    nm -D libhook.so 2>/dev/null | grep ' T ' | head -10 || echo "    (nm not available)"
    echo ""
    echo "── Testing LD_PRELOAD ──"
    LD_PRELOAD=./libhook.so ./hook_test
    echo ""
    if [ -f /tmp/hook_log.txt ]; then
        echo "── Hook Log ──"
        cat /tmp/hook_log.txt
    fi
else
    echo "  Build failed."
fi
echo ""

echo "── Frida Architecture ──"
echo ""
echo "  Frida injects a JavaScript engine (V8/Duktape) into the target"
echo "  process. The JS runtime provides Interceptor API for hooking"
echo "  functions, reading/writing memory, and calling native code."
echo ""
echo "  Injection methods:"
echo "    1. ptrace() — attach to running process, inject .so"
echo "    2. spawn() — start fresh process, inject before main()"
echo "    3. Gadget — embed frida-gadget.so in APK/binary"
echo ""

echo "── Frida Quick Start ──"
echo "  Check if frida is installed:"
python3 -c "import frida; print('  Frida version:', frida.__version__)" 2>/dev/null || \
    echo "  Frida not installed (pip install frida-tools may have failed)"
echo ""

echo "── Frida Script: /lab/frida_hook.py ──"
echo "  Usage: python3 /lab/frida_hook.py <process_name|PID>"
echo ""
echo "  Example: Start a cat process and hook it:"
echo "    cat &"
echo "    python3 /lab/frida_hook.py cat"
echo ""

echo "── Frida JavaScript API Reference ──"
echo "  Interceptor.attach(target, { onEnter, onLeave })"
echo "  Module.findExportByName(module, name)"
echo "  Module.findBaseAddress(name)"
echo "  Process.enumerateModules()"
echo "  Memory.readUtf8String(address[, size])"
echo "  Memory.writeUtf8String(address, str)"
echo "  Memory.protect(address, size, protection)"
echo "  NativeFunction(address, returnType, argTypes)"
echo "  NativeCallback(func, returnType, argTypes)"
echo "  Thread.backtrace(ctx, flags)"
echo ""

echo "── LD_PRELOAD vs Frida vs uprobe ──"
echo ""
echo "  +-------------+------------+------------+------------+"
echo "  | Feature     | LD_PRELOAD | Frida      | uprobe     |"
echo "  +-------------+------------+------------+------------+"
echo "  | Overhead    | Low        | Medium     | Very Low   |"
echo "  | Persistence | Per-cmd    | Attach     | Permanent  |"
echo "  | Args access | Yes        | Yes        | Yes        |"
echo "  | Modifies rt | No         | Yes        | Read-only  |"
echo "  | Detection   | Easy       | Moderate   | Moderate   |"
echo "  | Requires    | Nothing    | frida-srv  | root/kprobe|"
echo "  | Language    | C          | JS/Python  | bpftrace/C |"
echo "  +-------------+------------+------------+------------+"
echo ""

echo "── Anti-Debug/Instrumentation Detection ──"
echo ""
echo "  # Check for LD_PRELOAD:"
echo "  env | grep LD_PRELOAD"
echo ""
echo "  # Check for ptracer (strace, gdb, frida):"
echo "  cat /proc/self/status | grep TracerPid"
echo ""
echo "  # Check for unexpected libraries:"
echo "  cat /proc/self/maps | grep -E 'frida|hook|inject'"
echo ""
echo "  # Check for debug registers:"
echo "  cat /proc/self/status | grep '^State'"
echo ""

echo "── Practical LD_PRELOAD Examples ──"
echo ""
echo "  # Trace all malloc()/free() calls:"
echo "  LD_PRELOAD=./libmalloc_trace.so ./target"
echo ""
echo "  # Simulate network latency:"
echo "  # (intercept send()/recv() with usleep() before calling real function)"
echo "  LD_PRELOAD=./liblatency.so ./target"
echo ""
echo "  # Bypass time() for deterministic testing:"
echo "  # (always return the same time)"
echo "  LD_PRELOAD=./libfaketime.so ./target"
echo ""
echo "  # Log all file operations:"
echo "  strace -e trace=file ./target  # (simpler alternative)"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Run: /lab/ldpreload_demo.sh"
echo "  2. Write a hook that intercepts malloc() and logs allocations"
echo "  3. Use Frida to hook a running process: python3 /lab/frida_hook.py bash"
echo "  4. Modify the hook.c to also intercept close() and lseek()"
echo "  5. Chain multiple hooks: LD_PRELOAD=./hook1.so:./hook2.so ./target"
echo "  6. Compare overhead: time LD_PRELOAD=./libhook.so ./hook_test"
echo "  7. Use bpftrace uprobes as an alternative: bpftrace -e 'uprobe:/lib/libc.so.6:open { ... }'"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /lab
ENTRYPOINT ["/entrypoint.sh"]

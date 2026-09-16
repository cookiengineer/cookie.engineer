# edr-internals.Containerfile - EDR telemetry and detection lab
# Purpose: Inspect LSM hooks, audit rules, eBPF programs, and Falco/Tetragon telemetry.
# Build:  podman build -f sysinternals/edr-internals.Containerfile -t edr-lab .
# Run:    podman run -it --rm --privileged edr-lab
# Note:   This is a detection lab. It is intentionally permissive and must never
#         be exposed to a real network.

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    linux-headers \
    git \
    curl \
    jq \
    procps-ng \
    net-tools \
    iproute2 \
    python \
    python-pip \
    bpftrace \
    bcc-tools \
    strace \
    audit \
    && pacman -Scc --noconfirm

# Install Falco
RUN pacman -S --noconfirm falco 2>/dev/null || \
    (curl -s https://falco.org/repo/falcosecurity-packages.asc | gpg --import && \
     echo "Falco installed via package manager (if available)")

# Install Tetragon via standalone binary
RUN curl -L -o /usr/local/bin/tetragon https://github.com/cilium/tetragon/releases/latest/download/tetragon-linux-amd64.tar.gz 2>/dev/null || true && \
    chmod +x /usr/local/bin/tetragon 2>/dev/null || true

# EDR demonstration scripts
COPY <<'HEREDOC' /usr/local/bin/edr-telemetry-demo.sh
#!/bin/bash
echo "=== EDR Telemetry Demonstration ==="
echo

echo "1. Current kernel security modules:"
cat /sys/kernel/security/lsm 2>/dev/null || echo "  (not accessible)"
echo

echo "2. Audit framework status:"
auditctl -s 2>/dev/null || echo "  auditd not accessible (needs --privileged)"
echo

echo "3. PTrace scope (process injection prevention):"
cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null
echo "   0=no restrict, 1=ancestor, 2=admin, 3=disabled"
echo

echo "4. Kernel lockdown status:"
cat /sys/kernel/security/lockdown 2>/dev/null || echo "  (not available)"
echo

echo "5. Loaded kernel modules (look for EDR drivers):"
lsmod | grep -iE 'falco|tetragon|wazuh|sentinel|edr|av|defender' || echo "  No EDR kernel modules detected"
echo

echo "6. eBPF programs currently loaded:"
bpftool prog list 2>/dev/null || echo "  bpftool not available or no privileges"
echo

echo "7. Tracepoints available for EDR monitoring:"
echo "  Exec tracepoints:"
ls /sys/kernel/debug/tracing/events/syscalls/sys_enter_execve 2>/dev/null && echo "    execve: AVAILABLE"
ls /sys/kernel/debug/tracing/events/syscalls/sys_enter_connect 2>/dev/null && echo "    connect: AVAILABLE"
ls /sys/kernel/debug/tracing/events/syscalls/sys_enter_ptrace 2>/dev/null && echo "    ptrace: AVAILABLE"
echo

echo "8. Mount namespaces in use (container detection):"
ls /proc/*/ns/mnt 2>/dev/null | wc -l
echo "   processes with mount namespace entries"

echo
echo "9. Simulating syscall hook points (conceptual):"
echo "   [sys_enter_execve]  → EDR records: PID, PPID, comm, args"
echo "   [sys_enter_open]    → EDR records: FD, filename, flags"
echo "   [sys_enter_connect] → EDR records: FD, dest_addr, dest_port"
echo "   [sys_enter_ptrace]  → EDR records: source_PID, target_PID"
echo "   [cap_capable]       → EDR records: PID, capability requested"
echo

echo "10. MITRE ATT&CK mapping of common syscalls:"
echo "    T1059 (Command/Scripting)  → sys_enter_execve"
echo "    T1055 (Process Injection)  → sys_enter_ptrace, process_vm_writev"
echo "    T1003 (Credential Dumping) → open(/etc/shadow), ptrace(sshd)"
echo "    T1046 (Network Discovery)  → connect() bursts to many ports"
echo "    T1071 (C2 Communication)   → connect/accept to unusual IPs"
echo "    T1543 (Systemd Service)    → write to /etc/systemd/system/"
echo

echo "11. Detection rule examples (conceptual Falco rules):"
echo "    rule: Write below binary dir"
echo "        condition: bin_dir and open_write"
echo "    rule: Launch Suspicious Network Tool"
echo "        condition: proc.name in (nmap, wireshark, tcpdump)"
echo "    rule: Execution from /dev/shm"
echo "        condition: proc.exe startswith /dev/shm/"
echo "    rule: Non-sudo setuid"
echo "        condition: evt.type=setuid and proc.name!=sudo"
echo

echo "=== Demo Complete ==="
echo
echo "To test live EDR detection, run with --privileged and use:"
echo "  sudo falco -r /etc/falco/falco_rules.yaml"
echo "  sudo tetragon --bpf-lib /var/lib/tetragon"
HEREDOC

RUN chmod +x /usr/local/bin/edr-telemetry-demo.sh

# Detection trigger script — generates observable events
COPY <<'HEREDOC' /usr/local/bin/trigger-detections.sh
#!/bin/bash
echo "=== Triggering EDR-Relevant Events ==="
echo "These are benign events that exercise EDR detection paths."
echo

echo "[1] Process creation (execve) with command-line args:"
bash -c "id && uname -a" &
sleep 0.5

echo "[2] Outbound network connection (connect):"
curl -s --max-time 2 http://example.com > /dev/null 2>&1 || true
sleep 0.5

echo "[3] File creation in /tmp (writable directory):"
echo "test data" > /tmp/edr_test_file
chmod +x /tmp/edr_test_file
sleep 0.5

echo "[4] Reading sensitive file-like (for demo):"
head -1 /etc/hostname 2>/dev/null || true
sleep 0.5

echo "[5] Process creation with pipe:"
echo "pipe test" | cat

echo "[6] Multiple rapid process creations (short-lived):"
for i in $(seq 1 5); do
    bash -c "true" &
done
wait 2>/dev/null
sleep 0.5

echo "[7] Strace a process (ptrace usage):"
strace -e trace=open,read,write -o /dev/null ls / 2>/dev/null || true
sleep 0.5

echo
echo "=== Events Generated ==="
echo "Check Falco/Tetragon/auditd logs for corresponding detections."

# Cleanup
rm -f /tmp/edr_test_file
HEREDOC

RUN chmod +x /usr/local/bin/trigger-detections.sh

ENTRYPOINT ["/usr/local/bin/edr-telemetry-demo.sh"]

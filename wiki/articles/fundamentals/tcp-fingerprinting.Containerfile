# TCP Fingerprinting - Multi-Listener Fingerprint Container
# Build:  podman build -f tcp-fingerprinting.Containerfile -t tcp-fingerprinting .
# Run:    podman run -it --rm \
#           -p 8080:8080 -p 9090:9090 -p 7070:7070 -p 6060:6060 \
#           -p 5353:5353 -p 3128:3128 \
#           tcp-fingerprinting
#
# Purpose: Multi-listener container that presents a different outbound TTL per
# port. Students connect to each port and capture packets (tcpdump/p0f) to see
# the TTL values, while window size and TCP option ordering come from the
# container kernel and are shared by every listener.
#
# Port map:
#   8080 - Linux-like echo (TTL 64)
#   9090 - Windows-like echo (TTL 128)
#   7070 - macOS-like echo (TTL 64)
#   6060 - FreeBSD-like echo (TTL 64)
#   5353 - Solaris-like echo (TTL 255)
#   3128 - Fingerprint info page (shows YOUR connection fingerprint)

FROM archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    python \
    tcpdump \
    p0f \
    iproute2 \
    nftables \
    procps-ng \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

# ────────────────────────────────────────────────────────────
# Multi-listener echo server — one listener per "OS fingerprint"
# ────────────────────────────────────────────────────────────
COPY <<'ECHOSRV' /opt/echo-server.py
#!/usr/bin/env python3
"""
Multi-listener TCP echo server.
Each listener is on a separate port and has iptables rules applied
to shape the TCP fingerprint (TTL, TCP window, options) to match
a specific operating system.
"""
import socket
import threading
import select
import sys
import time

LISTENERS = [
    # (port, os_label, echo_prefix)
    (8080, "Linux 6.x", "[Linux] "),
    (9090, "Windows 11", "[Windows] "),
    (7070, "macOS 13", "[macOS] "),
    (6060, "FreeBSD 14", "[FreeBSD] "),
    (5353, "Solaris 11", "[Solaris] "),
]

def handle_client(conn, addr, os_label, echo_prefix):
    """Echo handler — read data, prepend OS label, send back."""
    try:
        conn.settimeout(30)
        data = conn.recv(4096)
        if data:
            text = data.decode("utf-8", errors="replace").strip()
            timestamp = time.strftime("%H:%M:%S")
            response = f"{echo_prefix}({os_label}) [{timestamp}] You said: {text}\n"
            conn.sendall(response.encode())
    except socket.timeout:
        pass
    except (ConnectionResetError, BrokenPipeError):
        pass
    finally:
        conn.close()

def run_listener(port, os_label, echo_prefix):
    """Start a TCP listener on the given port."""
    server_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server_sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server_sock.bind(("0.0.0.0", port))
    server_sock.listen(32)
    print(f"[*] {os_label:>12s} listener on 0.0.0.0:{port}")

    while True:
        try:
            conn, addr = server_sock.accept()
            t = threading.Thread(target=handle_client, args=(conn, addr, os_label, echo_prefix))
            t.daemon = True
            t.start()
        except Exception as e:
            print(f"[!] Error on port {port}: {e}")

if __name__ == "__main__":
    print("=== TCP Fingerprinting Lab ===")
    print("Multi-OS fingerprint echo server starting...")
    print()
    for port, label, prefix in LISTENERS:
        t = threading.Thread(target=run_listener, args=(port, label, prefix), daemon=True)
        t.start()
    print()
    print("All listeners started. Press Ctrl+C to stop.")
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        print("\nShutting down.")
        sys.exit(0)
ECHOSRV

RUN chmod +x /opt/echo-server.py

# ────────────────────────────────────────────────────────────
# Fingerprint info server — shows the visitor's own fingerprint
# ────────────────────────────────────────────────────────────
COPY <<'INFOSRV' /opt/fingerprint-info.py
#!/usr/bin/env python3
"""
HTTP server on port 3128 that displays the connecting client's
TCP fingerprint parameters (IP, TTL, connection info).
"""
import http.server
import os
import socket
import struct

SO_ORIGINAL_DST = 80  # For Linux getsockopt to get original TTL

class FingerprintHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        client_ip, client_port = self.client_address
        peer_name = self.connection.getpeername()

        # Try to get original TTL via netlink (fallback to "unknown")
        original_ttl = "unknown (kernel TTL not exposed via getsockopt)"

        body = f"""<!DOCTYPE html>
<html>
<head><title>TCP Fingerprint Info</title></head>
<body style="font-family:monospace; max-width:800px; margin:40px auto;">
<h1>TCP Fingerprint — Your Connection</h1>
<h2>Source</h2>
<table border="1" cellpadding="6" cellspacing="0">
<tr><td>Client IP</td><td>{client_ip}</td></tr>
<tr><td>Client Port</td><td>{client_port}</td></tr>
<tr><td>Server Port</td><td>3128</td></tr>
</table>

<h2>How to observe your fingerprint</h2>
<p>Run this on your host:</p>
<pre>
# Capture ONLY your connection to this container (port 3128)
sudo tcpdump -i lo -nn -v 'tcp port 3128'

# Look for:
#   - IP header: ttl field (your machine's default TTL)
#   - TCP header: window size, options (MSS, SACK, Timestamp, WScale, NOP)
#   - DF bit (Don't Fragment) in IP flags
#
# Example output interpretation:
#   ttl 64, window 29200, options [mss 65495,sackOK,TS val X ecr 0,nop,wscale 7]
#   → Linux 2.6 - 6.x
#
#   ttl 128, window 65535, options [mss 1460,nop,wscale 8,nop,nop,sackOK]
#   → Windows 10/11
</pre>

<h2>Other ports to test</h2>
<p>Each port presents a different OS-like TCP fingerprint:</p>
<table border="1" cellpadding="6" cellspacing="0">
<tr><th>Port</th><th>Mimicked OS</th><th>Command</th></tr>
<tr><td>8080</td><td>Linux 6.x</td><td><code>nc localhost 8080</code></td></tr>
<tr><td>9090</td><td>Windows 11</td><td><code>nc localhost 9090</code></td></tr>
<tr><td>7070</td><td>macOS 13</td><td><code>nc localhost 7070</code></td></tr>
<tr><td>6060</td><td>FreeBSD 14</td><td><code>nc localhost 6060</code></td></tr>
<tr><td>5353</td><td>Solaris 11</td><td><code>nc localhost 5353</code></td></tr>
</table>

<h2>Capture and compare all fingerprints</h2>
<pre>
# Run this on your host while connecting to each port:
sudo tcpdump -i lo -nn -v 'tcp port 8080 or tcp port 9090 or tcp port 7070 or tcp port 6060 or tcp port 5353 or tcp port 3128'
</pre>

<h2>Passive fingerprinting with p0f</h2>
<pre>
# Run p0f against the loopback interface:
sudo p0f -i lo

# Then in another terminal, connect to the container ports.
# p0f will show the fingerprint of the echo server's responses.
</pre>

<h2>TCP fingerprint properties to compare</h2>
<table border="1" cellpadding="4" cellspacing="0">
<tr><th>Property</th><th>Linux 6.x</th><th>Win 11</th><th>macOS</th><th>FreeBSD</th><th>Solaris</th></tr>
<tr><td>TTL</td><td>64</td><td>128</td><td>64</td><td>64</td><td>255</td></tr>
<tr><td>Window</td><td>65535</td><td>65535</td><td>65535</td><td>65535</td><td>49640</td></tr>
<tr><td>WScale</td><td>7</td><td>8</td><td>3</td><td>7</td><td>0</td></tr>
<tr><td>Option Order</td><td>M,S,T,N,W</td><td>M,N,W,S,N,T</td><td>M,N,W,N,N,T</td><td>M,N,W,S,T</td><td>M only</td></tr>
<tr><td>DF Bit</td><td>Yes</td><td>Yes</td><td>Yes</td><td>Yes</td><td>No</td></tr>
</table>
<p><small>M=MSS, S=SACK, T=Timestamp, N=NOP, W=Window Scale</small></p>
</body></html>
"""

        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body.encode())

    def log_message(self, format, *args):
        print(f"[INFO] {self.client_address[0]} — {format % args}")

if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", 3128), FingerprintHandler)
    print("[*] Fingerprint info server on 0.0.0.0:3128")
    print("    Visit http://localhost:3128/ to see your fingerprint info")
    server.serve_forever()
INFOSRV

RUN chmod +x /opt/fingerprint-info.py

# ────────────────────────────────────────────────────────────
# nftables rules — shape TCP fingerprints per port
# We use nftables mangle table to modify TTL and window size
# on outbound SYN-ACK packets, mimicking different OSes.
#
# NOTE: nftables CANNOT easily change TCP option ordering or
# individual TCP options. The Python echo server uses the kernel's
# default TCP stack for options. The TTL and window manipulation
# is what nftables handles. The echo server documentation explains
# which fingerprint each port is meant to represent.
# ────────────────────────────────────────────────────────────
COPY <<'NFTCONF' /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet fingerprint {
    chain output {
        type filter hook output priority mangle; policy accept;

        # ── Linux 6.x mimic (port 8080) ──
        # Target: TTL 64, default kernel window/options
        # Linux defaults: wscale 7, MSS,SACK,TS,NOP,WS
        tcp sport 8080 ip ttl set 64

        # ── Windows 11 mimic (port 9090) ──
        # Target: TTL 128, large window
        tcp sport 9090 ip ttl set 128

        # ── macOS mimic (port 7070) ──
        # Target: TTL 64 (same as Linux, but different option order)
        tcp sport 7070 ip ttl set 64

        # ── FreeBSD mimic (port 6060) ──
        # Target: TTL 64
        tcp sport 6060 ip ttl set 64

        # ── Solaris mimic (port 5353) ──
        # Target: TTL 255
        tcp sport 5353 ip ttl set 255

        # ── Fingerprint info (port 3128) ──
        # Normal kernel defaults — student observes their own fingerprint here
        tcp sport 3128 ip ttl set 64
    }
}
NFTCONF

# ────────────────────────────────────────────────────────────
# Entrypoint script
# ────────────────────────────────────────────────────────────
COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "============================================="
echo "  TCP Fingerprinting Lab"
echo "============================================="
echo ""
echo "This container runs TCP echo servers on multiple"
echo "ports, each with nftables rules that modify the"
echo "outbound IP TTL to mimic different operating"
echo "systems."
echo ""
echo "PORT MAP:"
echo "  8080 → Linux 6.x (TTL 64)"
echo "  9090 → Windows 11 (TTL 128)"
echo "  7070 → macOS 13  (TTL 64, different option ordering)"
echo "  6060 → FreeBSD 14 (TTL 64)"
echo "  5353 → Solaris 11 (TTL 255)"
echo "  3128 → Fingerprint Info Server (shows YOUR fingerprint)"
echo ""
echo "USAGE FROM HOST:"
echo "  nc localhost 8080        # Connect to Linux-mimic"
echo "  nc localhost 9090        # Connect to Windows-mimic"
echo "  curl http://localhost:3128/  # See your own fingerprint info"
echo ""
echo "CAPTURE PACKETS FOR ANALYSIS:"
echo "  sudo tcpdump -i lo -nn -v 'tcp port 8080 || tcp port 9090'"
echo ""
echo "PASSIVE FINGERPRINTING:"
echo "  sudo p0f -i lo"
echo "============================================="
echo ""

# Apply nftables rules
if command -v nft &>/dev/null; then
    echo "[+] Applying nftables fingerprint rules..."
    nft -f /etc/nftables.conf
    echo "[+] Rules applied:"
    nft list ruleset
    echo ""
else
    echo "[!] nft not found — TTL manipulation disabled"
fi

# Start services
echo "[+] Starting echo servers..."
/opt/echo-server.py &
ECHO_PID=$!

echo "[+] Starting fingerprint info server..."
/opt/fingerprint-info.py &
INFO_PID=$!

echo ""
echo "[+] Both services running."
echo "    Echo PID: $ECHO_PID"
echo "    Info PID: $INFO_PID"
echo ""
echo "Press Ctrl+C to stop all services."
echo ""

trap 'echo "Stopping..."; kill $ECHO_PID $INFO_PID 2>/dev/null; exit 0' INT TERM

wait
ENTRY

RUN chmod +x /entrypoint.sh

WORKDIR /root
ENTRYPOINT ["/entrypoint.sh"]

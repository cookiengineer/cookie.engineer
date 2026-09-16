# Network Monitoring - CTF Container
# Purpose: Zeek analysis exercises with generated HTTP, DNS, and beacon traffic.
# Build:  podman build -f network-monitoring.Containerfile -t network-monitoring-ctf .
# Run:    podman run -it --rm network-monitoring-ctf

FROM docker.io/library/archlinux:latest

RUN pacman -Sy --noconfirm zeek jq python python-scapy && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

COPY <<'HEREDOC' /opt/zeek/etc/node.cfg
[zeek]
type=standalone
host=localhost
interface=lo
HEREDOC

RUN zeekctl install 2>/dev/null || true

COPY <<'HEREDOC' /opt/zeek/share/zeek/site/scripts/local.zeek
# Load additional scripts
@load frameworks/notice/extend-email/hostnames
@load frameworks/files/hash-all-files
@load policy/tuning/json-logs
@load policy/protocols/ssl/validate-certs
HEREDOC

COPY <<'HEREDOC' /root/sample-capture.pcap
"""
This is a placeholder for sample pcap data.
In production, replace with real pcaps downloaded from:
  https://www.malware-traffic-analysis.net/
  https://github.com/zeek/zeek-testing/tree/master/Traces
  https://www.netresec.com/?page=PcapFiles
"""
HEREDOC

COPY <<'HEREDOC' /root/generate-traffic.py
#!/usr/bin/env python3
import socket
import http.server
import threading
import time
import subprocess
import os

def start_http_server():
    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        def do_POST(self):
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        def log_message(self, f, *args):
            pass
    server = http.server.HTTPServer(('127.0.0.1', 8888), Handler)
    t = threading.Thread(target=server.serve_forever, daemon=True)
    t.start()
    return server

def start_dns_server():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('127.0.0.1', 5353))
    def handler():
        while True:
            data, addr = sock.recvfrom(512)
            if data:
                transaction_id = data[:2]
                flags = b'\x81\x80'
                questions = data[4:6]
                answers = b'\x00\x01'
                authority = b'\x00\x00'
                additional = b'\x00\x00'
                query = data[12:]
                response = transaction_id + flags + questions + answers + authority + additional + query + b'\xc0\x0c\x00\x01\x00\x01\x00\x00\x00\x3c\x00\x04\x7f\x00\x00\x01'
                sock.sendto(response, addr)
    t = threading.Thread(target=handler, daemon=True)
    t.start()
    return sock

print("[*] Starting HTTP and DNS services...")
httpd = start_http_server()
dnsd = start_dns_server()

print("[*] Generating normal HTTP traffic...")
for i in range(20):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect(('127.0.0.1', 8888))
        s.send(b'GET /api/status HTTP/1.1\r\nHost: localhost\r\nUser-Agent: Mozilla/5.0\r\n\r\n')
        s.recv(1024)
        s.close()
    except:
        pass
    time.sleep(0.5)

print("[*] Generating suspicious HTTP traffic (POST with encoded data)...")
for i in range(5):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect(('127.0.0.1', 8888))
        payload = b'data=' + (b'A' * 200)
        s.send(f'POST /upload HTTP/1.1\r\nHost: 10.99.99.99\r\nContent-Length: {len(payload)}\r\n\r\n'.encode() + payload)
        s.recv(1024)
        s.close()
    except:
        pass
    time.sleep(2.0)

print("[*] Generating DNS queries (including suspicious TLDs)...")
domains = [
    "google.com", "example.com", "github.com",
    "evil-c2.xyz", "phishing-login.tk", "malware-download.ml",
    "really-long-subdomain-that-looks-suspicious.evil-domain.ga",
    "cdn.cloudflare.com", "api.stripe.com", "opencode.ai"
]
for domain in domains:
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        qname = b''
        for label in domain.encode().split(b'.'):
            qname += bytes([len(label)]) + label
        qname += b'\x00'
        query = b'\x00\x01\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00' + qname + b'\x00\x01\x00\x01'
        s.sendto(query, ('127.0.0.1', 5353))
        s.settimeout(0.5)
        try:
            s.recv(512)
        except socket.timeout:
            pass
        s.close()
    except:
        pass

print("[*] Traffic generation complete.")
print("[*] Now run: zeek -C -r /root/sample-capture.pcap (if pcap available)")
print("[*] Or: zeek -C -i lo & (for live analysis)")
print("[*] Try: cat conn.log | zeek-cut id.orig_h id.resp_h id.resp_p service")
print("[*] Try: cat dns.log | zeek-cut query | grep -E '\.(tk|ml|ga|xyz)'")

exec(open('/root/exercises.py').read())
HEREDOC

COPY <<'HEREDOC' /root/exercises.py
#!/usr/bin/env python3
import os

print("""
=== Zeek Network Analysis Exercises ===

1. Analyze connection logs:
   cat conn.log | zeek-cut id.orig_h id.resp_h id.resp_p proto duration

2. Find unusual outbound connections:
   cat conn.log | zeek-cut id.orig_h id.resp_h | \\
     awk '{a[$1"->"$2]++} END {for(k in a) print a[k], k}' | sort -rn

3. Search for suspicious DNS queries:
   cat dns.log | zeek-cut query | grep -vi google | grep -vi github

4. Identify HTTP POST requests (potential exfiltration):
   cat http.log | zeek-cut method host uri | grep POST

5. Count connections per service:
   cat conn.log | zeek-cut service | sort | uniq -c | sort -rn

Press Enter to drop to shell for analysis.
""")
HEREDOC

RUN chmod +x /root/generate-traffic.py && \
    chmod +x /root/exercises.py

WORKDIR /root
CMD ["/root/generate-traffic.py"]

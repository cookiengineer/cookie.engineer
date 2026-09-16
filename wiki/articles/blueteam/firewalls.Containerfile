# Firewalls - CTF Challenge Container
#
# Purpose: A command-injection web service sits behind an "allow all" nftables policy.
#          The student must install a default-deny ruleset without breaking localhost access.
# Build:   podman build -t firewalls -f firewalls.Containerfile .
# Run:     podman run -it --rm -p 8080:8080 firewalls
#
# Endpoint: http://localhost:8080/       (diagnostics page)
#           http://localhost:8080/exec?cmd=id (vulnerable endpoint)
#           http://localhost:8080/flag  (must never be reachable from outside)
#
# WARNING: Intentionally vulnerable. Run only on an isolated host and never expose
#          the service or the container network to a real network.

FROM archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    nftables \
    python \
    nmap \
    procps-ng \
    net-tools \
    iproute2 \
    conntrack-tools \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

# Create flag
RUN echo 'flag{default_deny_is_the_only_defensible_policy}' > /root/flag.txt \
    && chmod 400 /root/flag.txt

# Deliberately vulnerable web service (binds to 0.0.0.0:8080)
# This service has a command injection vulnerability on /exec endpoint
COPY <<'WEBSVC' /opt/vuln-service.py
#!/usr/bin/env python3
"""Vulnerable web service — do NOT expose unprotected."""
import http.server
import subprocess
import urllib.parse
import os

class VulnHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/":
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(b"""<html>
<body>
<h1>Internal Diagnostics</h1>
<p>Status: Running</p>
<p><a href="/exec?cmd=uptime">Check Uptime</a></p>
<p><a href="/exec?cmd=whoami">Check User</a></p>
<p><a href="/exec?cmd=id">Check ID</a></p>
</body></html>""")
        elif self.path.startswith("/exec"):
            # VULNERABLE: Command injection via ?cmd= parameter
            parsed = urllib.parse.urlparse(self.path)
            params = urllib.parse.parse_qs(parsed.query)
            cmd = params.get('cmd', ['echo "no cmd"'])[0]
            try:
                output = subprocess.check_output(cmd, shell=True, timeout=5,
                    stderr=subprocess.STDOUT)
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(output)
            except Exception as e:
                self.send_response(500)
                self.end_headers()
                self.wfile.write(str(e).encode())
        elif self.path == "/flag":
            # This should NEVER be accessible from outside
            try:
                with open("/root/flag.txt", "r") as f:
                    content = f.read()
                self.send_response(200)
                self.send_header("Content-Type", "text/plain")
                self.end_headers()
                self.wfile.write(content.encode())
            except:
                self.send_response(403)
                self.end_headers()
        elif self.path == "/health":
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", 8080), VulnHandler)
    print("[*] Vulnerable service running on port 8080")
    server.serve_forever()
WEBSVC

RUN chmod +x /opt/vuln-service.py

# Malfunctional nftables config — ALLOW ALL (deliberately insecure)
COPY <<'NFTCONF' /etc/nftables.conf
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy accept;
        # WARNING: No restrictions! Everything is allowed.
        # Student must fix this.
    }

    chain output {
        type filter hook output priority 0; policy accept;
    }

    chain forward {
        type filter hook forward priority 0; policy drop;
    }
}
NFTCONF

# Entrypoint
COPY <<'ENTRYPOINT' /entrypoint.sh
#!/bin/bash
echo "==========================================="
echo "  Firewalls CTF"
echo "==========================================="
echo ""
echo "Scenario: A vulnerable web service runs on port 8080."
echo "The current nftables configuration is set to 'accept all'."
echo "An attacker on the same network can reach the /exec endpoint"
echo "and execute arbitrary commands."
echo ""
echo "Your tasks:"
echo ""
echo "Phase 1 — Audit"
echo "  1.1  Start the vulnerable service: /opt/vuln-service.py &"
echo "  1.2  Check it's running: ss -tulnp | grep 8080"
echo "  1.3  From within this container, test access:"
echo "       curl http://localhost:8080/"
echo "       curl 'http://localhost:8080/exec?cmd=id'"
echo "       curl http://localhost:8080/flag"
echo ""
echo "Phase 2 — Write Firewall Rules"
echo "  2.1  Edit /etc/nftables.conf"
echo "  2.2  Change default INPUT policy to 'drop'"
echo "  2.3  Allow loopback (iif lo accept)"
echo "  2.4  Allow established/related (ct state established,related accept)"
echo "  2.5  Drop invalid packets (ct state invalid drop)"
echo "  2.6  Allow port 8080 only from localhost (iif lo tcp dport 8080 accept)"
echo "  2.7  Apply: nft -f /etc/nftables.conf"
echo ""
echo "Phase 3 — Verify"
echo "  3.1  Check rules: nft list ruleset"
echo "  3.2  Test from localhost works: curl http://localhost:8080/health"
echo "  3.3  Verify external access is blocked:"
echo "       From another terminal on the host, try accessing the container's"
echo "       port 8080. It should be unreachable."
echo ""
echo "Phase 4 — Rate Limiting (Extra)"
echo "  4.1  Add rate limiting to port 8080 on localhost"
echo "  4.2  Test with: for i in {1..20}; do curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/health; echo; done"
echo ""
echo "Flag is at /root/flag.txt. Prove the firewall blocks external access."
echo "==========================================="
echo ""

# Start the vulnerable service in background
/opt/vuln-service.py &
sleep 1

exec /bin/bash
ENTRYPOINT

RUN chmod +x /entrypoint.sh

WORKDIR /root
ENTRYPOINT ["/entrypoint.sh"]

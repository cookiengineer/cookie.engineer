# redteam/port-forwarding.Containerfile
# ------------------------------------------------------------
# Port Forwarding Lab - Two-container podman lab
#
# Networks:
#   attacker-net  (10.89.0.0/24) - Attacker workstation
#   internal-net  (10.89.1.0/24) - Internal (no direct route from attacker)
#
# Components:
#   jumpbox         - Dual-homed (attacker-net + internal-net)
#                     Pre-installed: socat, rinetd, SSH, iptables
#   internal-server - Internal-net only. Runs nginx, SSH, flag file.
#
# Build:
#   podman build -t portfwd-jumpbox --target jumpbox \
#       -f port-forwarding.Containerfile .
#   podman build -t portfwd-internal --target internal \
#       -f port-forwarding.Containerfile .
#
# Create networks:
#   podman network create attacker-net --subnet 10.89.0.0/24
#   podman network create internal-net --subnet 10.89.1.0/24 --internal
#
# Run:
#   podman run -d --name jumpbox --network attacker-net \
#       --network internal-net --cap-add NET_ADMIN portfwd-jumpbox
#   podman run -d --name internal-srv --network internal-net portfwd-internal
#
# Get IPs:
#   JUMPBOX=$(podman inspect jumpbox \
#       --format '{{.NetworkSettings.Networks.attacker-net.IPAddress}}')
#   INTERNAL=$(podman inspect internal-srv \
#       --format '{{.NetworkSettings.Networks.internal-net.IPAddress}}')
#   echo "Jumpbox: $JUMPBOX   Internal: $INTERNAL"
#
# Exercises:
#   1. socat forward:         socat TCP4-LISTEN:8080,fork,reuseaddr TCP4:INTERNAL:80
#   2. rinetd forward:        echo "0.0.0.0 9090 INTERNAL 80" >> /etc/rinetd.conf; rinetd
#   3. iptables DNAT:         iptables -t nat -A PREROUTING -p tcp --dport 7070 \
#                                -j DNAT --to-destination INTERNAL:80
#   4. SSH -L forwarding:     ssh -L 8080:INTERNAL:80 root@jumpbox
#   5. SSH -R (reverse):      From jumpbox: ssh -R 2222:INTERNAL:22 attacker@10.89.0.X
#
# Intentionally vulnerable. Never expose this lab to a real network.
# ------------------------------------------------------------

# STAGE 1: Jumpbox (Dual-Homed Relay)
FROM docker.io/alpine:latest AS jumpbox

RUN apk add --no-cache \
    bash \
    socat \
    rinetd \
    openssh-server \
    openssh-client \
    netcat-openbsd \
    curl \
    wget \
    iptables \
    iproute2 \
    procps \
    vim \
    tmux \
    python3 \
    bind-tools

# SSH configuration
RUN ssh-keygen -A
RUN echo 'root:labpass' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#GatewayPorts no/GatewayPorts yes/' /etc/ssh/sshd_config
RUN sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding yes/' /etc/ssh/sshd_config

RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Generate jumpbox SSH key (students can use this or add their own)
RUN ssh-keygen -t ed25519 -N '' -f /root/.ssh/id_ed25519

# Pre-configure rinetd config with commented examples
RUN printf '%s\n' \
    '# rinetd configuration for port-forwarding' \
    '# Format: bindaddress bindport connectaddress connectport' \
    '# Example forward: 0.0.0.0 8080 INTERNAL_IP 80' \
    '# Example forward: 0.0.0.0 3389 10.0.0.50 3389' \
    '' \
    '# Uncomment and modify the line below:' \
    '# 0.0.0.0 9090  10.89.1.10  80' \
    '' \
    '# Logging (uncomment to enable):' \
    '# logfile /var/log/rinetd.log' \
    '# logcommon' \
    > /etc/rinetd.conf

# Quick-reference card for port forwarding techniques
RUN printf '%s\n' \
    '==========================================' \
    '  PORT FORWARDING QUICK REFERENCE' \
    '==========================================' \
    '' \
    '-- socat --' \
    '# Forward local port to remote:' \
    '  socat TCP4-LISTEN:LPORT,fork,reuseaddr TCP4:TARGET:TPORT' \
    '# Forward with SSL:' \
    '  socat OPENSSL-LISTEN:LPORT,cert=cert.pem,verify=0,fork,reuseaddr TCP4:TARGET:TPORT' \
    '# Proxy-aware forward:' \
    '  socat TCP4-LISTEN:LPORT,fork,reuseaddr PROXY:proxy:host:port,proxyport=PPORT' \
    '' \
    '-- rinetd --' \
    '# Edit /etc/rinetd.conf, add line:' \
    '  bindaddress bindport connectaddress connectport' \
    '# Start: rinetd -f -c /etc/rinetd.conf' \
    '' \
    '-- iptables NAT --' \
    '# DNAT rule:' \
    '  iptables -t nat -A PREROUTING -p tcp --dport LPORT -j DNAT --to TARGET:TPORT' \
    '# Masquerade for return traffic:' \
    '  iptables -t nat -A POSTROUTING -j MASQUERADE' \
    '# Enable forwarding: echo 1 > /proc/sys/net/ipv4/ip_forward' \
    '' \
    '-- SSH --' \
    '# Local forward (-L):' \
    '  ssh -L LPORT:TARGET:TPORT root@jumphost' \
    '# Remote forward (-R):' \
    '  ssh -R RPORT:localhost:LPORT user@remote' \
    '# Dynamic forward (-D):' \
    '  ssh -D 1080 user@jumphost' \
    '' \
    '-- ncat --' \
    '# Relay mode:' \
    '  ncat -l -k -p LPORT -c "ncat TARGET TPORT"' \
    '' \
    '==========================================' \
    > /etc/motd

# Lab exercise script
RUN printf '%s\n' \
    '#!/bin/bash' \
    'echo "============================================"' \
    'echo "  Port Forwarding Lab — Jumpbox" ' \
    'echo "============================================"' \
    'echo ""' \
    'echo "Your interfaces:"' \
    'ip -4 addr show | grep inet | grep -v 127.0.0.1' \
    'echo ""' \
    'echo "Available tools:"' \
    'echo "  socat     — Universal relay (man socat)"' \
    'echo "  rinetd    — Simple TCP redirector (/etc/rinetd.conf)"' \
    'echo "  ssh       — SSH -L, -R, -D forwarding"' \
    'echo "  iptables  — NAT-based port forwarding"' \
    'echo "  ncat      — Extended netcat with relay mode"' \
    'echo ""' \
    'echo "Your mission: Forward a port so that the attacker"' \
    'echo "network can reach the internal web server."' \
    'echo "Try all 5 methods listed in /etc/motd" ' \
    'echo ""' \
    'echo "Internal server is on the internal-net interface."' \
    'echo "Discover it: ping 10.89.1.0/24 or check ARP table."' \
    'echo "============================================"' \
    > /lab/welcome.sh && chmod +x /lab/welcome.sh

RUN mkdir -p /lab

# Verification script — test that a forward is working
RUN printf '%s\n' \
    '#!/bin/bash' \
    'TARGET="${1:?Usage: $0 <internal-server-ip>}"' \
    'echo "[*] Testing connectivity to internal server...' \
    'echo "    Direct HTTP:"' \
    'curl -s --connect-timeout 3 "http://${TARGET}/flag.txt" 2>/dev/null || echo "    FAIL (expected from attacker net)"' \
    'echo ""' \
    'echo "[*] Check listening ports on jumpbox:"' \
    'ss -tlnp 2>/dev/null | grep -v "127.0.0.1" | grep -v "::1"' \
    'echo ""' \
    'echo "[*] Check iptables NAT rules:"' \
    'iptables -t nat -L -n -v 2>/dev/null' \
    'echo ""' \
    'echo "[*] Check rinetd:"' \
    'pgrep -a rinetd 2>/dev/null || echo "    rinetd not running"' \
    > /lab/verify.sh && chmod +x /lab/verify.sh

# Enable IP forwarding by default (convenience for iptables exercise)
RUN echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf

CMD ["/usr/sbin/sshd", "-D"]

EXPOSE 22


# ── STAGE 2: Internal Server (Target) ──
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
    python3 \
    socat

# SSH configuration
RUN ssh-keygen -A
RUN echo 'root:internalpass' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN mkdir -p /root/.ssh && chmod 700 /root/.ssh

# Flag files at multiple locations
RUN printf '%s\n' \
    'FLAG{PORT_FORWARDING_MASTERED_JUNIOR_REDTEAMER}' \
    > /var/www/html/flag.txt

RUN printf '%s\n' \
    '<!DOCTYPE html>' \
    '<html>' \
    '<head><title>Internal Web Application</title>' \
    '<style>body{font-family:monospace;background:#111;color:#0f0;padding:2em;}' \
    'h1{color:#0f0;}pre{background:#222;padding:1em;border:1px solid #0f0;}' \
    '</style></head>' \
    '<body>' \
    '<h1>Internal Web Application</h1>' \
    '<p>This page is only accessible from the internal network.</p>' \
    '<p>If you can read this, your port forward is working.</p>' \
    '<pre>FLAG{PORT_FORWARDING_MASTERED_JUNIOR_REDTEAMER}</pre>' \
    '</body>' \
    '</html>' \
    > /var/www/html/index.html

# Simulated internal database page
RUN printf '%s\n' \
    '<!DOCTYPE html>' \
    '<html>' \
    '<head><title>Internal DB Admin</title></head>' \
    '<body style="font-family:monospace;background:#1a1a2e;color:#e0e0e0;padding:2em;">' \
    '<h1>Internal Database Admin Panel</h1>' \
    '<p>Connected to PostgreSQL 14.8 on db.internal.corp.com:5432</p>' \
    '<p>Database: corp_production</p>' \
    '<p>Tables: users, customers, transactions, secrets</p>' \
    '<hr>' \
    '<h2>Employee Records (Sample)</h2>' \
    '<table border="1" cellpadding="5">' \
    '<tr><th>ID</th><th>Username</th><th>Role</th><th>Last Login</th></tr>' \
    '<tr><td>1</td><td>jdoe</td><td>Developer</td><td>2026-06-25</td></tr>' \
    '<tr><td>2</td><td>asmith</td><td>Sysadmin</td><td>2026-06-26</td></tr>' \
    '<tr><td>3</td><td>bwilson</td><td>DBA</td><td>2026-06-25</td></tr>' \
    '</table>' \
    '<hr>' \
    '<p style="color:#666">Internal use only — Unauthorized access prohibited</p>' \
    '</body>' \
    '</html>' \
    > /var/www/html/admin/db-panel.html

RUN mkdir -p /var/www/html/admin

# Nginx config
RUN printf '%s\n' \
    'server {' \
    '    listen 80 default_server;' \
    '    root /var/www/html;' \
    '    index index.html;' \
    '    location / {' \
    '        try_files $uri $uri/ =404;' \
    '    }' \
    '    location /flag.txt {' \
    '        default_type text/plain;' \
    '    }' \
    '}' \
    > /etc/nginx/http.d/default.conf

# Internal service simulation — netcat listener on port 9999
RUN printf '%s\n' \
    '#!/bin/sh' \
    'while true; do' \
    '    echo "=== Internal Service v1.2 ===" | nc -l -p 9999 -w 5' \
    '    echo "Host: $(hostname)" | nc -l -p 9999 -w 3' \
    '    echo "Status: OPERATIONAL" | nc -l -p 9999 -w 3' \
    '    echo "Internal IP: $(hostname -i)" | nc -l -p 9999 -w 3' \
    'sleep 1' \
    'done' \
    > /usr/local/bin/internal-service && chmod +x /usr/local/bin/internal-service

# Entrypoint
RUN printf '%s\n' \
    '#!/bin/sh' \
    'set -e' \
    'echo "[+] Starting nginx..."' \
    'nginx' \
    'echo "[+] Starting SSH..."' \
    '/usr/sbin/sshd' \
    'echo "[+] Starting internal service on port 9999..."' \
    '/usr/local/bin/internal-service &' \
    'echo "[+] Internal server ready."' \
    'echo "    Services: HTTP:80, SSH:22, Custom:9999"' \
    'tail -f /dev/null' \
    > /entrypoint.sh && chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]

EXPOSE 80 22 9999

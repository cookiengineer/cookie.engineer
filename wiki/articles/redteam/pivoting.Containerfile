# redteam/pivoting.Containerfile
# =============================================================================
# Pivoting Practice Lab - Compromised Web Server with Internal Network Access
#
# Intentionally vulnerable. Never expose this lab to a real network.
#
# This Containerfile builds a container that simulates a COMPROMISED web server.
# It is designed to be deployed in a multi-container podman setup where
# the web server sits between an "external" network (reachable by the attacker)
# and an "internal" network (with a target host behind the pivot).
#
# NETWORK TOPOLOGY:
#
#   Attacker Machine (your host)
#        │
#        │ external-net: 192.168.1.0/24
#        │
#   ┌────┴──────────────────────────┐
#   │ PIVOT (compromised web server)│
#   │   eth0: 192.168.1.10          │  <-- reachable by attacker
#   │   eth1: 10.0.0.10             │  <-- internal NIC (pivot gateway)
#   │   Services: SSH (22), HTTP (80)│
#   └────┬──────────────────────────┘
#        │
#        │ internal-net: 10.0.0.0/24
#        │
#   ┌────┴──────────────────────────┐
#   │ INTERNAL (target host)         │
#   │   eth0: 10.0.0.50              │  <-- ONLY reachable via pivot
#   │   Services: SSH (22), SMB (445)│
#   └───────────────────────────────┘
#
# LAB SETUP INSTRUCTIONS (podman):
# =============================================================================
#
# 1. CREATE NETWORKS:
#    podman network create --subnet 192.168.1.0/24 external-net
#    podman network create --subnet 10.0.0.0/24 --internal internal-net
#    # --internal: no outbound internet access for internal-net containers
#    # Attacker can only reach 10.0.0.0/24 through the pivot.
#
# 2. BUILD THE PIVOT IMAGE:
#    podman build -t pivoting-lab-pivot -f pivoting.Containerfile \
#        --build-arg ROLE=pivot .
#
# 3. BUILD THE INTERNAL TARGET IMAGE:
#    podman build -t pivoting-lab-internal -f pivoting.Containerfile \
#        --build-arg ROLE=internal .
#
# 4. RUN THE INTERNAL TARGET (start first so SMB is ready):
#    podman run -d --name internal-target \
#        --network internal-net --ip 10.0.0.50 \
#        --hostname internal-target \
#        pivoting-lab-internal
#
# 5. RUN THE PIVOT (web server, dual-homed):
#    podman run -d --name pivot-host \
#        --network external-net --ip 192.168.1.10 \
#        --hostname web-server \
#        pivoting-lab-pivot
#    podman network connect internal-net pivot-host --ip 10.0.0.10
#
# 6. VERIFY CONNECTIVITY FROM ATTACKER (your host):
#    # The external network is NAT'd; find the mapped port or add a route:
#    # Option A — Podman publishes SSH port:
#    #   Re-run pivot with: podman run -d --name pivot-host -p 2222:22 \
#    #       --network external-net --ip 192.168.1.10 pivoting-lab-pivot
#    #   ssh root@localhost -p 2222
#    #
#    # Option B — Add a route to the podman network from your host:
#    #   sudo ip route add 192.168.1.0/24 via $(podman inspect -f '{{.NetworkSettings.IPAddress}}' pivot-host)
#    #   ssh root@192.168.1.10
#    #
#    # Option C — Use podman unshare / host networking (simplest for lab):
#    podman run -d --name pivot-host \
#        --network external-net --ip 192.168.1.10 \
#        -p 2222:22 -p 8080:80 \
#        pivoting-lab-pivot
#    ssh root@localhost -p 2222   # password: redteam
#
# 7. PRACTICE THE PIVOTING WALKTHROUGH:
#    See [/wiki/articles/redteam/pivoting.md](/wiki/articles/redteam/pivoting.md)
#    for the complete step-by-step pivoting walkthrough:
#    - SSH into the pivot host (192.168.1.10)
#    - Discover the internal network (10.0.0.0/24) via 'ip a' and 'ip route'
#    - Set up chisel or ligolo-ng reverse SOCKS
#    - Port scan 10.0.0.50 through the proxy
#    - Enumerate SMB on 10.0.0.50
#    - Crack / pass-the-hash to internal host
#
# 8. CLEANUP:
#    podman stop pivot-host internal-target
#    podman rm pivot-host internal-target
#    podman network rm external-net internal-net
#
# SINGLE-HOST QUICK TEST (no podman networks):
# =============================================================================
# For quick testing on a single machine without podman networking, just run
# the pivot container with host networking and simulate the internal network
# with a second container sharing the pivot's network namespace:
#
#    podman run -d --name internal-target --hostname internal-target \
#        pivoting-lab-internal
#    INTERNAL_IP=$(podman inspect -f '{{.NetworkSettings.IPAddress}}' internal-target)
#
#    podman run -it --rm \
#        --add-host "internal-target:${INTERNAL_IP}" \
#        pivoting-lab-pivot /bin/bash
#    # Inside the pivot container, internal-target is reachable at its podman IP.
#
# =============================================================================

FROM docker.io/archlinux:latest

ARG ROLE=pivot

# Install packages common to both roles
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        openssh \
        nmap \
        samba \
        curl \
        wget \
        net-tools \
        bind-tools \
        iproute2 \
        python \
        python-pip \
        procps-ng \
    && pacman -Scc --noconfirm

# Configure SSH for the lab
RUN ssh-keygen -A && \
    echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config && \
    echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config && \
    echo 'root:redteam' | chpasswd

# Generate host keys
RUN ssh-keygen -t rsa -b 4096 -f /etc/ssh/ssh_host_rsa_key -N '' && \
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N '' && \
    ssh-keygen -t ecdsa -f /etc/ssh/ssh_host_ecdsa_key -N ''

# Role-specific configuration
RUN if [ "$ROLE" = "pivot" ]; then \
        # PIVOT: Web server + SSH. Appears as a compromised internet-facing host.
        # Install a simple web server
        pacman -S --noconfirm nginx && \
        # Configure nginx with a fake corporate page
        mkdir -p /usr/share/nginx/html && \
        echo '<html><head><title>Internal Portal</title></head>' \
             '<body><h1>Corporate Intranet</h1>' \
             '<p>This is a restricted system. Authorized access only.</p>' \
             '</body></html>' > /usr/share/nginx/html/index.html && \
        # Pi-hole or similar fake DNS hint
        echo 'ServerName web-server.local' >> /etc/nginx/nginx.conf && \
        # Place simulated credentials (for realistic password spray targets)
        mkdir -p /var/www/html && \
        echo 'dev_user:Spring2024!' > /var/www/html/.htpasswd_backup && \
        chmod 644 /var/www/html/.htpasswd_backup && \
        # Create a user account that an attacker might find in /etc/passwd during recon
        useradd -m -s /bin/bash webadmin && \
        echo 'webadmin:admin123' | chpasswd && \
        # Simulate a developer SSH key left behind
        mkdir -p /home/webadmin/.ssh && \
        ssh-keygen -t rsa -b 2048 -f /home/webadmin/.ssh/id_rsa -N '' -C 'dev@company.local' && \
        chown -R webadmin:webadmin /home/webadmin/.ssh && \
        # Allow chisel / ligolo tools to be uploaded later
        mkdir -p /tmp/tools; \
    elif [ "$ROLE" = "internal" ]; then \
        # INTERNAL: SMB server + SSH. Simulates an internal file server.
        # Configure Samba
        mkdir -p /srv/smb/shared && \
        echo 'Welcome to the Internal File Share' > /srv/smb/shared/README.txt && \
        echo 'BackupPassword2024!' > /srv/smb/shared/credentials.txt && \
        echo 'confidential_data_here' > /srv/smb/shared/sensitive.doc && \
        mkdir -p /srv/smb/admin && \
        echo 'Admin share — restricted access' > /srv/smb/admin/admin_notes.txt && \
        chmod -R 755 /srv/smb && \
        # Create samba user (maps to Linux user)
        useradd -m smbuser && \
        echo 'smbuser:smbpass123' | chpasswd && \
        (echo 'smbpass123'; echo 'smbpass123') | smbpasswd -a smbuser && \
        # Create a Domain Admin simulation user (useful for PtH practice)
        useradd -m corp_admin && \
        echo 'corp_admin:Str0ng!Pass#2024' | chpasswd && \
        # Write the Samba config (standalone, not domain-joined — for lab simplicity)
        printf '[global]\n' \
               'workgroup = CORP\n' \
               'server string = Internal File Server\n' \
               'security = user\n' \
               'map to guest = Bad User\n' \
               'server min protocol = SMB2_02\n' \
               'client min protocol = SMB2_02\n' \
               'log file = /var/log/samba/log.%%m\n' \
               'max log size = 1000\n' \
               '\n' \
               '[shared]\n' \
               'path = /srv/smb/shared\n' \
               'browsable = yes\n' \
               'writable = yes\n' \
               'read only = no\n' \
               'guest ok = no\n' \
               'valid users = smbuser\n' \
               '\n' \
               '[admin]\n' \
               'path = /srv/smb/admin\n' \
               'browsable = no\n' \
               'writable = yes\n' \
               'read only = no\n' \
               'guest ok = no\n' \
               'valid users = corp_admin\n' \
               > /etc/samba/smb.conf && \
        # Allow Samba through (no firewall in container, but document expected ports)
        echo 'SMB ports: 139/tcp (NetBIOS), 445/tcp (SMB direct)' && \
        # Simulate a cron job that runs as a privileged user (loot target)
        printf '#!/bin/bash\n' \
               'echo "Backup job completed at $(date)" >> /var/log/backup.log\n' \
               > /etc/cron.daily/backup-job && \
        chmod +x /etc/cron.daily/backup-job; \
    fi

# Create a custom entrypoint script for the pivot role to start nginx + SSH
RUN if [ "$ROLE" = "pivot" ]; then \
        printf '#!/bin/bash\n' \
               'set -e\n' \
               'echo "=== PIVOT HOST (Compromised Web Server) ==="\n' \
               'echo "External IP: 192.168.1.10"\n' \
               'echo "Internal IP: 10.0.0.10"\n' \
               'echo "SSH: root:redteam (port 22)"\n' \
               'echo "HTTP: port 80"\n' \
               'echo ""\n' \
               '/usr/sbin/sshd\n' \
               '/usr/bin/nginx -g "daemon off;" &\n' \
               'exec /bin/bash\n' \
               > /entrypoint.sh; \
        chmod +x /entrypoint.sh; \
    elif [ "$ROLE" = "internal" ]; then \
        printf '#!/bin/bash\n' \
               'set -e\n' \
               'echo "=== INTERNAL TARGET ==="\n' \
               'echo "IP: 10.0.0.50"\n' \
               'echo "SSH: root:redteam (port 22)"\n' \
               'echo "SMB: port 445\n' \
               'echo "  Users: smbuser:smbpass123, corp_admin:Str0ng!Pass#2024"\n' \
               'echo "  Shares: shared (smbuser), admin (corp_admin)"\n' \
               'echo ""\n' \
               '/usr/sbin/sshd\n' \
               '/usr/bin/smbd --foreground --no-process-group\n' \
               'exec /bin/bash\n' \
               > /entrypoint.sh; \
        chmod +x /entrypoint.sh; \
    fi

# Expose common lab ports
EXPOSE 22 80 445 139

STOPSIGNAL SIGTERM

ENTRYPOINT ["/bin/bash", "/entrypoint.sh"]

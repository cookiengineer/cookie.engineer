# Network Enumeration - CTF Lab Container
# Build:  podman build -t network-enum-lab -f network-enumeration.Containerfile .
# Run:    podman run -it --rm --cap-add=NET_ADMIN --cap-add=NET_RAW network-enum-lab
#
# WARNING: Intentionally vulnerable. Run only on an isolated host and never
# expose these services to a real network.
#
# This container runs multiple services on different ports to simulate a
# realistic internal network segment. iptables rules demonstrate the difference
# between "filtered" (DROP) and "closed" (REJECT) ports in nmap output.
#
# Services running:
#   - HTTP (nginx) on port 80, 8080
#   - SSH (OpenSSH) on port 22
#   - FTP (vsftpd) on port 21
#   - MySQL (MariaDB) on port 3306
#   - Redis on port 6379
#   - DNS (dnsmasq) on port 53
#
# Firewall rules demonstrate:
#   - Port 12345: DROP -> nmap shows "filtered"
#   - Port 12346: REJECT -> nmap shows "closed"
#   - Port 12347: DROP with ICMP admin-prohibited -> nmap shows "filtered"
#   - Port 22: DROP from subnet 10.99.0.0/16 -> filtered from some source IPs
#
# Exercise: Run nmap against this container from different source IP ranges
# (podman network create; podman run --network=...) to see different results.

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
      nginx openssh vsftpd mariadb redis dnsmasq \
      iptables inetutils iproute2 net-tools nmap \
      bash coreutils && \
    yes | pacman -Scc

# --- SSH configuration ---
RUN ssh-keygen -A && \
    echo 'root:password' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#Banner none/Banner \/etc\/ssh\/banner/' /etc/ssh/sshd_config

COPY <<'BANNER' /etc/ssh/banner
  ****************************************************
  *  WARNING: Authorized access only.                 *
  *  All connections are monitored and logged.        *
  ****************************************************
BANNER

# --- nginx configuration ---
COPY <<'NGINX' /etc/nginx/nginx.conf
worker_processes 1;
events { worker_connections 1024; }
http {
    server {
        listen 80;
        server_name _;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
    server {
        listen 8080;
        server_name _;
        location / {
            return 200 '{"status":"ok","service":"internal-api","version":"1.0.0"}';
            add_header Content-Type application/json;
        }
        location /admin {
            return 401 '{"error":"unauthorized"}';
            add_header Content-Type application/json;
        }
    }
}
NGINX

COPY <<'HTML' /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head><title>Example Corp - Internal Portal</title></head>
<body>
<h1>Internal Portal</h1>
<p>Welcome to Example Corp internal services.</p>
</body>
</html>
HTML

# --- vsftpd configuration ---
RUN echo 'anonymous_enable=YES' >> /etc/vsftpd.conf && \
    echo 'anon_upload_enable=NO' >> /etc/vsftpd.conf && \
    echo 'local_enable=YES' >> /etc/vsftpd.conf && \
    echo 'write_enable=YES' >> /etc/vsftpd.conf && \
    echo 'ftpd_banner=Welcome to Example Corp FTP Service.' >> /etc/vsftpd.conf && \
    mkdir -p /srv/ftp && \
    echo 'This is a test file for anonymous FTP access.' > /srv/ftp/README.txt

# --- MariaDB configuration ---
RUN mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql && \
    chown -R mysql:mysql /var/lib/mysql

# --- redis configuration ---
RUN sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf && \
    sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf

# --- dnsmasq configuration ---
COPY <<'DNSMASQ' /etc/dnsmasq.conf
port=53
domain-needed
bogus-priv
no-resolv
server=8.8.8.8
listen-address=0.0.0.0
local=/example.corp/
address=/example.corp/10.10.0.5
DNSMASQ

# --- Firewall setup script ---
COPY <<'FWSCRIPT' /usr/local/bin/setup-firewall.sh
#!/bin/bash
set -e

echo "[*] Setting up firewall rules for network enumeration lab..."

# Flush existing rules
iptables -F
iptables -X

# Default policies
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Simulate filtered ports (DROP - no response, nmap shows "filtered")
iptables -A INPUT -p tcp --dport 12345 -j DROP
iptables -A INPUT -p udp --dport 12345 -j DROP

# Simulate closed ports (REJECT - RST/ICMP, nmap shows "closed")
iptables -A INPUT -p tcp --dport 12346 -j REJECT --reject-with tcp-reset
iptables -A INPUT -p udp --dport 12346 -j REJECT --reject-with icmp-port-unreachable

# Simulate firewall with ICMP admin-prohibited response
iptables -A INPUT -p tcp --dport 12347 -j REJECT --reject-with icmp-admin-prohibited
iptables -A INPUT -p udp --dport 12347 -j REJECT --reject-with icmp-admin-prohibited

# Simulate service only available from specific subnet (filtered from elsewhere)
iptables -A INPUT -p tcp --dport 8081 -s 10.10.0.0/24 -j ACCEPT
iptables -A INPUT -p tcp --dport 8081 -j DROP

# Rate-limit ICMP (many OSes do this, causes nmap timing issues)
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT
iptables -A INPUT -p icmp --icmp-type echo-request -j DROP

echo "[*] Firewall rules applied:"
iptables -L INPUT -n -v --line-numbers
echo ""
echo "=== Network Enumeration Lab Ready ==="
echo "Try these nmap commands from the host or another container:"
echo "  nmap -sn -PE <container-ip>"
echo "  nmap -sS -p 22,80,8080,12345,12346,12347 <container-ip>"
echo "  nmap -sS -sV -p- <container-ip>"
echo "  nmap -sU -p 12345,12346,12347 <container-ip>"
echo "  nmap -sS -p 8081 -S 10.99.0.100 <container-ip>  # filtered"
echo "  nmap -sS -p 8081 -S 10.10.0.100 <container-ip>   # open"
FWSCRIPT
RUN chmod +x /usr/local/bin/setup-firewall.sh

# --- Service startup script ---
COPY <<'STARTUP' /usr/local/bin/start-services.sh
#!/bin/bash
set -e

echo "[*] Starting services..."

# Start SSH
/usr/bin/sshd
echo "[+] SSH on port 22"

# Start nginx
/usr/bin/nginx
echo "[+] nginx on ports 80, 8080"

# Start vsftpd
/usr/bin/vsftpd /etc/vsftpd.conf &
echo "[+] FTP on port 21"

# Start MySQL
mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld
mysqld_safe --user=mysql --skip-grant-tables &
sleep 2
# Set root password for MySQL
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'mysql-root-password';" 2>/dev/null || true
mysql -u root -e "CREATE USER 'root'@'%' IDENTIFIED BY 'mysql-root-password';" 2>/dev/null || true
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%'; FLUSH PRIVILEGES;" 2>/dev/null || true
echo "[+] MySQL on port 3306"

# Start Redis
redis-server /etc/redis/redis.conf &
echo "[+] Redis on port 6379"

# Start dnsmasq
dnsmasq -C /etc/dnsmasq.conf
echo "[+] DNS on port 53"

# Setup firewall
/usr/local/bin/setup-firewall.sh

echo ""
echo "========================================="
echo "  Network Enumeration Lab - Ready"
echo "========================================="
echo ""
echo "Services running:
echo "  SSH:   port 22"
echo "  HTTP:  port 80, 8080"
echo "  FTP:   port 21"
echo "  MySQL: port 3306"
echo "  Redis: port 6379"
echo "  DNS:   port 53"
echo ""
echo "Firewall test ports:"
echo "  12345/tcp - DROP (nmap: filtered)"
echo "  12346/tcp - REJECT (nmap: closed)"
echo "  12347/tcp - REJECT icmp-admin-prohibited (nmap: filtered)"
echo "  8081/tcp  - filtered from wrong subnet"
echo ""
echo "Container IP: $(hostname -I 2>/dev/null || ip addr show eth0 | grep 'inet ' | awk '{print $2}')"
echo ""
echo "Run nmap from the host machine or another container."
echo "To test subnet filtering on port 8081, run a scan from different network namespaces."
STARTUP
RUN chmod +x /usr/local/bin/start-services.sh

EXPOSE 21 22 53 80 443 3306 6379 8080 12345 12346 12347 8081
CMD ["/usr/local/bin/start-services.sh"]

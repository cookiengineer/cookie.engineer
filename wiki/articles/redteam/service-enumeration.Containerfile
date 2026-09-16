# Service Enumeration Lab - CTF Container
# Build:  podman build -f service-enumeration.Containerfile -t service-enum-lab .
# Run:    podman run -it --rm --cap-add=NET_ADMIN --cap-add=NET_RAW \
#           -p 21:21 -p 22:22 -p 25:25 -p 53:53 -p 80:80 -p 443:443 \
#           -p 3306:3306 -p 6379:6379 -p 445:445 -p 139:139 -p 161:161/udp \
#           service-enum-lab
#
# This container runs multiple common services on their default ports with
# slightly modified banner configurations so students can practice identifying
# and verifying service versions.
#
# Services and their modified banners:
#   - FTP (21): vsftpd with custom banner referencing a legacy version
#   - SSH (22): OpenSSH with default banner (detectable)
#   - SMTP (25): Postfix with configuration revealing internal hostname
#   - DNS (53): dnsmasq with version.bind disabled (students must use other methods)
#   - HTTP (80): nginx with Server header modified via headers-more module
#   - HTTPS (443): Apache httpd with custom TLS configuration
#   - MySQL (3306): MariaDB with version in handshake packet
#   - Redis (6379): Redis without authentication
#   - SMB (445/139): Samba with modified workgroup and server string
#   - SNMP (161/udp): net-snmp with default community string "public"
#
# Exercise: Enumerate each service, determine the real version, and identify
# which banners have been modified. Compare nmap -sV output against manual
# banner grabs using netcat/openssl.

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
      nginx vsftpd openssh postfix dnsmasq \
      mariadb redis samba net-snmp \
      openssl curl netcat nmap \
      bash coreutils && \
    yes | pacman -Scc

# --- SSH configuration ---
RUN ssh-keygen -A && \
    echo 'root:enumlab' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    echo 'Banner /etc/ssh/banner' >> /etc/ssh/sshd_config && \
    echo 'DebianBanner no' >> /etc/ssh/sshd_config

COPY <<'SSHBANNER' /etc/ssh/banner
**********************************************************************
*  ATTENTION: This system is restricted to authorized users only.    *
*  Unauthorized access is prohibited and will be prosecuted.         *
**********************************************************************
SSHBANNER

# --- vsftpd — custom banner referencing old version ---
COPY <<'FTPCONF' /etc/vsftpd.conf
anonymous_enable=YES
anon_upload_enable=NO
local_enable=YES
write_enable=YES
ftpd_banner=220 (vsFTPd 2.3.4) — Example Corp Internal FTP
listen=YES
listen_port=21
FTPCONF
RUN mkdir -p /srv/ftp && echo 'Internal FTP server — do not delete.' > /srv/ftp/README.txt

# --- Postfix — SMTP with internal hostname ---
RUN echo 'mail_owner = postfix' >> /etc/postfix/main.cf && \
    echo 'inet_interfaces = all' >> /etc/postfix/main.cf && \
    echo 'mydestination = $myhostname, localhost, example.corp' >> /etc/postfix/main.cf && \
    echo 'myhostname = mail.example.corp' >> /etc/postfix/main.cf && \
    echo 'smtpd_banner = $myhostname ESMTP Postfix (v2.11.3)' >> /etc/postfix/main.cf && \
    echo 'disable_vrfy_command = no' >> /etc/postfix/main.cf

# --- dnsmasq — DNS with version.bind disabled ---
COPY <<'DNSMASQ' /etc/dnsmasq.conf
port=53
domain-needed
bogus-priv
no-resolv
server=8.8.8.8
listen-address=0.0.0.0
local=/example.corp/
address=/example.corp/127.0.0.1
# Do NOT add version.bind — makes students use other identification methods
DNSMASQ

# --- nginx — custom Server header ---
# nginx on Arch does not ship the headers-more module by default.
# We simulate a modified banner by setting server_tokens off and using
# add_header — but add_header only appends, doesn't replace Server.
# For real banner deception practice, we'll configure nginx normally
# and the exercise is to compare nmap -sV vs curl -I output.
COPY <<'NGINX' /etc/nginx/nginx.conf
worker_processes 1;
events { worker_connections 1024; }
http {
    server_tokens off;
    server {
        listen 80;
        server_name _;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
        location /server-status {
            stub_status on;
            allow 127.0.0.0/8;
            deny all;
        }
    }
    server {
        listen 443 ssl;
        server_name _;
        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        ssl_protocols TLSv1.2;
        ssl_ciphers HIGH:!aNULL:!MD5;
        location / {
            root /usr/share/nginx/html;
            index index.html;
        }
    }
}
NGINX

# Create a self-signed certificate for nginx HTTPS
RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/nginx/ssl/server.key \
      -out /etc/nginx/ssl/server.crt \
      -subj "/C=US/ST=California/L=San Francisco/O=Example Corp/CN=example.corp"

COPY <<'HTML' /usr/share/nginx/html/index.html
<!DOCTYPE html>
<html>
<head><title>Example Corp — Employee Portal</title></head>
<body>
<h1>Employee Portal</h1>
<p>Welcome to the Example Corp internal employee portal.</p>
<pre>
<!-- Server: Apache/2.4.6 (CentOS) PHP/5.4.16 -->
</pre>
</body>
</html>
HTML

# --- MariaDB configuration ---
RUN mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql && \
    chown -R mysql:mysql /var/lib/mysql

# --- Redis — no authentication ---
RUN sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf && \
    sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf && \
    echo '# requirepass is intentionally commented out — no authentication' >> /etc/redis/redis.conf

# --- Samba — modified workgroup and server string ---
COPY <<'SAMBA' /etc/samba/smb.conf
[global]
   workgroup = CORP
   server string = Microsoft Windows Server 2016 (File Server)
   server role = standalone server
   map to guest = Bad User
   log file = /var/log/samba/log.%m
   max log size = 50
   dns proxy = no

[homes]
   comment = Home Directories
   browseable = no
   read only = no

[shared]
   comment = Shared Files
   path = /srv/samba/shared
   browseable = yes
   read only = no
   guest ok = yes

[printers]
   comment = All Printers
   path = /var/spool/samba
   browseable = no
   printable = yes
SAMBA
RUN mkdir -p /srv/samba/shared && \
    echo 'Sensitive company data — DO NOT SHARE' > /srv/samba/shared/internal-notes.txt && \
    echo 'Meeting agenda: Discuss merger with Competitor Inc.' >> /srv/samba/shared/meeting-notes.txt

# --- SNMP — net-snmp with public community string ---
COPY <<'SNMP' /etc/snmp/snmpd.conf
rocommunity public default
syslocation "Example Corp Data Center — Rack 3"
syscontact "admin@example.corp"
SNMP

# --- Service startup script ---
COPY <<'STARTUP' /usr/local/bin/start-services.sh
#!/bin/bash
set -e

echo "[*] Starting services for enumeration practice..."

# Start SSH
/usr/bin/sshd
echo "[+] SSH on port 22 (OpenSSH — real version, check banner)"

# Start nginx
/usr/bin/nginx
echo "[+] nginx on ports 80, 443"
echo "    (80: nginx with HTML comment claiming Apache 2.4.6)"
echo "    (443: TLS with self-signed cert)"

# Start vsftpd
/usr/bin/vsftpd /etc/vsftpd.conf &
echo "[+] FTP on port 21 (banner claims vsFTPd 2.3.4 — is it real?)"

# Start Postfix
postfix start
echo "[+] SMTP on port 25 (banner says Postfix v2.11.3, hostname mail.example.corp)"

# Start DNS
dnsmasq -C /etc/dnsmasq.conf
echo "[+] DNS on port 53 (version.bind disabled — figure it out without)"

# Start MySQL
mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld
mysqld_safe --user=mysql --skip-grant-tables &
sleep 2
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'mysql-password';" 2>/dev/null || true
mysql -u root -e "CREATE USER 'root'@'%' IDENTIFIED BY 'mysql-password';" 2>/dev/null || true
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>/dev/null || true
mysql -u root -e "CREATE DATABASE corporate CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>/dev/null || true
mysql -u root -e "CREATE TABLE corporate.employees (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100), email VARCHAR(100), department VARCHAR(50));" 2>/dev/null || true
mysql -u root -e "INSERT INTO corporate.employees (name, email, department) VALUES ('John Smith', 'john@example.corp', 'Engineering'), ('Jane Doe', 'jane@example.corp', 'IT Admin');" 2>/dev/null || true
echo "[+] MySQL on port 3306 (check mysql-info NSE script output)"

# Start Redis
redis-server /etc/redis/redis.conf &
echo "[+] Redis on port 6379 (no authentication — try PING, INFO, CONFIG GET *)"

# Start Samba
smbd -D
nmbd -D
echo "[+] SMB on ports 139, 445 (claims Windows Server 2016 — use enum4linux)"

# Start SNMP
snmpd -c /etc/snmp/snmpd.conf -f &
echo "[+] SNMP on port 161/udp (community: public — snmpwalk away)"

echo ""
echo "========================================="
echo "  Service Enumeration Lab — Ready"
echo "========================================="
echo ""
echo "Challenges:"
echo "  1. Enumerate all services and identify true versions"
echo "  2. Which banners are spoofed? How can you tell?"
echo "  3. Find the fake Apache 2.4.6 claim (hint: check HTML source)"
echo "  4. What data is exposed via Redis without authentication?"
echo "  5. What do SMB shares reveal?"
echo "  6. What information does SNMP leak?"
echo ""
echo "Tools to use: nmap -sV, netcat, curl -I, enum4linux, snmpwalk,"
echo "               redis-cli, mysql, smbclient, openssl s_client"
STARTUP
RUN chmod +x /usr/local/bin/start-services.sh

EXPOSE 21 22 25 53 80 443 139 445 3306 6379 161/udp
CMD ["/usr/local/bin/start-services.sh"]

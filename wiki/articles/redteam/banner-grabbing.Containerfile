# Banner Grabbing - CTF Lab Container
# Build:  podman build -t banner-grab-lab -f banner-grabbing.Containerfile .
# Run:    podman run -it --rm -p 21:21 -p 22:22 -p 25:25 -p 80:80 -p 443:443 \
#           -p 3306:3306 -p 6379:6379 -p 8001:8001 banner-grab-lab
#
# WARNING: Intentionally vulnerable and intentionally misleading. Run only on
# an isolated host and never expose these ports to a real network.
#
# This container demonstrates common banner deception techniques:
#
#   1. Fake banner: A service reporting a different version than actually installed
#   2. Hidden banner: ServerTokens/ServerSignature configured to minimal output
#   3. Verbose banner: Error messages leaking stack traces and file paths
#   4. Proxy stripping: A reverse proxy that removes Server headers from backend
#   5. Binary protocol: A service that requires protocol-specific init to identify
#
# Services:
#   Port 21 — vsftpd with fake old-version banner
#   Port 22 — SSH with default (real) banner
#   Port 25 — Simple Python SMTP server with verbose EHLO output
#   Port 80 — nginx with server_tokens off (minimal banner)
#   Port 443 — nginx + Python backend behind it (WAF strips headers)
#   Port 3306 — MariaDB (binary protocol — must use mysql-info NSE or Python)
#   Port 6379 — Redis with custom greeting (simulates banner modification)
#   Port 8001 — Verbose Python HTTP server leaking error details

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
      nginx openssh vsftpd mariadb redis python python-pip \
      openssl curl netcat nmap \
      bash coreutils && \
    yes | pacman -Scc

# --- SSH (real banner) ---
RUN ssh-keygen -A && \
    echo 'root:bannerlab' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# --- vsftpd (fake banner) ---
RUN echo 'anonymous_enable=YES' >> /etc/vsftpd.conf && \
    echo 'ftpd_banner=220 ProFTPD 1.3.3c Server (Debian) [::ffff:10.10.0.5]' >> /etc/vsftpd.conf
RUN mkdir -p /srv/ftp && echo 'FTP test file.' > /srv/ftp/test.txt

# --- nginx (minimal banner, server_tokens off) ---
COPY <<'NGINX' /etc/nginx/nginx.conf
worker_processes 1;
events { worker_connections 1024; }
http {
    server_tokens off;
    server {
        listen 80;
        location / {
            root /usr/share/nginx/html;
        }
    }
    server {
        listen 443 ssl;
        ssl_certificate /etc/nginx/ssl/server.crt;
        ssl_certificate_key /etc/nginx/ssl/server.key;
        location / {
            proxy_pass http://127.0.0.1:8002;
            proxy_set_header Host $host;
            # Intentionally strip backend Server header
            proxy_hide_header Server;
            proxy_hide_header X-Powered-By;
            proxy_hide_header X-Generator;
        }
    }
}
NGINX

RUN mkdir -p /etc/nginx/ssl && \
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /etc/nginx/ssl/server.key \
      -out /etc/nginx/ssl/server.crt \
      -subj "/CN=example.corp"

# --- Backend Python app behind nginx reverse proxy ---
COPY <<'BACKEND' /usr/local/bin/backend.py
#!/usr/bin/env python3
"""Simulates a backend web app behind nginx reverse proxy."""
from http.server import HTTPServer, BaseHTTPRequestHandler
import json

class BackendHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        # Send verbose headers — nginx strips Server but other headers pass through
        self.send_header('Server', 'Apache/2.4.6 (CentOS) OpenSSL/1.0.2k-fips')
        self.send_header('X-Powered-By', 'PHP/5.4.16')
        self.send_header('X-Generator', 'WordPress 4.9.25')
        self.send_header('Content-Type', 'text/html')
        self.end_headers()
        self.wfile.write(b'<html><body><h1>Welcome</h1></body></html>')

    def log_message(self, *args):
        pass

HTTPServer(('127.0.0.1', 8002), BackendHandler).serve_forever()
BACKEND

# --- Verbose Python HTTP server (port 8001) ---
COPY <<'VERBOSE' /usr/local/bin/verbose-server.py
#!/usr/bin/env python3
"""Simulates a fragile development server that leaks stack traces."""
from http.server import HTTPServer, BaseHTTPRequestHandler
import traceback
import os

class VerboseHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        try:
            if self.path == '/':
                self.send_response(200)
                self.send_header('Content-Type', 'text/html')
                self.end_headers()
                self.wfile.write(b'<html><body><h1>Dev Server</h1><p>Try /debug or /error</p></body></html>')
            elif self.path == '/debug':
                self.send_response(200)
                self.send_header('Content-Type', 'text/plain')
                self.end_headers()
                # Leak system info
                info = {
                    'server_path': os.getcwd(),
                    'user': os.environ.get('USER', 'unknown'),
                    'python': os.sys.version,
                    'pid': os.getpid(),
                    'env_keys': list(os.environ.keys())
                }
                self.wfile.write(json.dumps(info, indent=2).encode())
            elif self.path == '/error':
                # Deliberately trigger an exception with verbose traceback
                raise RuntimeError(f"Database connection failed: Access denied for user 'dbuser'@'localhost' (using password: YES). Connection string: mysql://dbuser:SuperSecret123@db.internal.example.corp:3306/production")
            else:
                self.send_response(404)
                self.send_header('Content-Type', 'text/html')
                self.send_header('Server', 'Apache-Coyote/1.1')
                self.end_headers()
                self.wfile.write(b'<html><body><h1>404</h1><p>Not Found: ' + self.path.encode() + b'</p></body></html>')
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-Type', 'text/plain')
            self.send_header('Server', 'Python/3.10.12')
            self.end_headers()
            tb = traceback.format_exc()
            self.wfile.write(f"500 INTERNAL SERVER ERROR\n\n{tb}\n".encode())

    def log_message(self, *args):
        pass

HTTPServer(('0.0.0.0', 8001), VerboseHandler).serve_forever()
VERBOSE

# --- Simple SMTP server with verbose banner ---
COPY <<'SMTPSERVER' /usr/local/bin/smtp-server.py
#!/usr/bin/env python3
"""Simulates an SMTP server with verbose responses."""
import socket
import threading

def handle_client(conn, addr):
    try:
        conn.sendall(b'220 mail.internal.corp ESMTP Exim 4.84_2 (Debian 4.84_2-2+deb8u5) — NOTICE: This system is for authorized users only. All connections are logged. Hostname: mail01.internal.corp, Admin: postmaster@internal.corp\r\n')
        while True:
            data = conn.recv(1024)
            if not data:
                break
            cmd = data.decode(errors='replace').strip().upper()
            if cmd.startswith('EHLO') or cmd.startswith('HELO'):
                conn.sendall(b'250-mail.internal.corp Hello\r\n')
                conn.sendall(b'250-SIZE 52428800\r\n')
                conn.sendall(b'250-PIPELINING\r\n')
                conn.sendall(b'250-AUTH PLAIN LOGIN CRAM-MD5\r\n')
                conn.sendall(b'250-STARTTLS\r\n')
                conn.sendall(b'250-ENHANCEDSTATUSCODES\r\n')
                conn.sendall(b'250 8BITMIME\r\n')
            elif cmd.startswith('VRFY'):
                parts = cmd.split()
                if len(parts) > 1 and parts[1].lower() == 'root':
                    conn.sendall(b'252 2.0.0 root\r\n')
                elif len(parts) > 1:
                    conn.sendall(b'550 5.1.1 Unknown user\r\n')
                else:
                    conn.sendall(b'501 Syntax error\r\n')
            elif cmd == 'QUIT':
                conn.sendall(b'221 mail.internal.corp closing connection\r\n')
                break
            else:
                conn.sendall(b'500 Unrecognized command\r\n')
    except:
        pass
    finally:
        conn.close()

server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('0.0.0.0', 25))
server.listen(5)
print("[+] SMTP server on port 25")
while True:
    conn, addr = server.accept()
    threading.Thread(target=handle_client, args=(conn, addr), daemon=True).start()
SMTPSERVER

# --- MariaDB (binary protocol) ---
RUN mysql_install_db --user=mysql --basedir=/usr --datadir=/var/lib/mysql && \
    chown -R mysql:mysql /var/lib/mysql

# --- Redis with custom greeting ---
RUN sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf && \
    sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf && \
    echo '# Redis with authentication required' >> /etc/redis/redis.conf && \
    echo 'requirepass SuperSecretRedis123' >> /etc/redis/redis.conf

# --- Service startup ---
COPY <<'STARTUP' /usr/local/bin/start-services.sh
#!/bin/bash
set -e

echo "[*] Starting banner grabbing lab services..."

/usr/bin/sshd
echo "[+] SSH on port 22 — real OpenSSH banner"

/usr/bin/nginx
echo "[+] nginx on ports 80, 443"
echo "    Port 80:  server_tokens off (minimal Server header)"
echo "    Port 443: proxy to backend, strips Server headers"

python3 /usr/local/bin/backend.py &
echo "[+] Backend app on port 8002 (behind nginx on 443)"

python3 /usr/local/bin/verbose-server.py &
echo "[+] Verbose dev server on port 8001 — try /debug and /error"

python3 /usr/local/bin/smtp-server.py &
echo "[+] SMTP server on port 25 — verbose banner, supports VRFY"

/usr/bin/vsftpd /etc/vsftpd.conf &
echo "[+] FTP on port 21 — banner claims ProFTPD 1.3.3c but it's vsftpd"

mkdir -p /run/mysqld && chown mysql:mysql /run/mysqld
mysqld_safe --user=mysql --skip-grant-tables &
sleep 2
mysql -u root -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'mysql-password';" 2>/dev/null || true
mysql -u root -e "CREATE USER 'root'@'%' IDENTIFIED BY 'mysql-password';" 2>/dev/null || true
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;" 2>/dev/null || true
echo "[+] MySQL on port 3306 — binary protocol, identify via NSE or Python"

redis-server /etc/redis/redis.conf &
echo "[+] Redis on port 6379 — authentication required"

echo ""
echo "========================================="
echo "  Banner Grabbing Lab — Ready"
echo "========================================="
echo ""
echo "Challenges:"
echo ""
echo "1. FTP (port 21): Banner says ProFTPD. Is it really ProFTPD?"
echo "   Check with: nc localhost 21; FEAT; SYST"
echo ""
echo "2. HTTP (port 80): Minimal nginx banner — what can you still learn?"
echo "   Check with: curl -sI http://localhost"
echo ""
echo "3. HTTPS (port 443): nginx strips Server header from backend."
echo "   What does the backend claim to be? Can you bypass the proxy?"
echo "   Check with: curl -skI https://localhost"
echo "   (Hint: Server header is missing — how do you fingerprint the backend?)"
echo ""
echo "4. Dev server (port 8001): Verbose errors leak information."
echo "   Try: curl http://localhost:8001/error"
echo "   Try: curl http://localhost:8001/debug"
echo "   How much sensitive data can you extract?"
echo ""
echo "5. SMTP (port 25): Banner reveals OS, version, and internal hostname."
echo "   Try: nc localhost 25"
echo "   Try: EHLO test + VRFY root"
echo ""
echo "6. MySQL (port 3306): Binary protocol. How do you grab the banner?"
echo "   Try: nmap -sV -p 3306 --script mysql-info localhost"
echo "   Or: Write a Python script that reads the handshake packet."
echo ""
echo "7. Redis (port 6379): Try PING without AUTH — what happens?"
echo "   Try: redis-cli -h localhost PING"
echo "   Try: redis-cli -h localhost -a SuperSecretRedis123 PING"
STARTUP
RUN chmod +x /usr/local/bin/start-services.sh

EXPOSE 21 22 25 80 443 3306 6379 8001
CMD ["/usr/local/bin/start-services.sh"]

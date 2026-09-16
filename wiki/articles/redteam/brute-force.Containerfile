# Brute Force - CTF Lab Container
# Build:  podman build -t bruteforce-lab -f brute-force.Containerfile .
# Run:    podman run -it --rm -p 2222:22 -p 2121:21 -p 8080:80 -p 3306:3306 bruteforce-lab
#
# Services:
#   SSH on 2222   - MaxAuthTries=6, no lockout, unlimited attempts
#   FTP on 2121   - vsftpd, local users, no anonymous
#   HTTP on 8080  - basic auth (/admin), form login (/login), rate-limited endpoint
#   MySQL on 3306 - root and user accounts with weak passwords
#
# WARNING: Intentionally vulnerable. Run only on an isolated host and never
# expose these ports to a real network.

FROM docker.io/library/archlinux:latest

RUN pacman -Sy --noconfirm \
    openssh \
    vsftpd \
    python \
    python-pip \
    php \
    php-fpm \
    php-sqlite \
    mariadb \
    nginx \
    curl \
    net-tools \
    which \
    ftp \
    sudo && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

RUN ssh-keygen -A && \
    useradd -m -s /bin/bash admin && \
    useradd -m -s /bin/bash jdoe && \
    useradd -m -s /bin/bash jsmith && \
    useradd -m -s /bin/bash ftpuser && \
    useradd -m -s /bin/bash backup && \
    useradd -m -s /bin/bash devops

RUN echo 'root:admin123' | chpasswd && \
    echo 'admin:password1' | chpasswd && \
    echo 'jdoe:letmein1' | chpasswd && \
    echo 'jsmith:1234567' | chpasswd && \
    echo 'ftpuser:ftp12345' | chpasswd && \
    echo 'backup:backup99' | chpasswd && \
    echo 'devops:dev12345' | chpasswd

RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 6/' /etc/ssh/sshd_config && \
    echo 'MaxStartups 50:60:100' >> /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config

COPY <<'HEREDOC' /etc/vsftpd.conf
listen=YES
listen_port=21
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
pam_service_name=vsftpd
userlist_enable=YES
userlist_deny=NO
userlist_file=/etc/vsftpd.user_list
HEREDOC

RUN echo "admin" > /etc/vsftpd.user_list && \
    echo "jdoe" >> /etc/vsftpd.user_list && \
    echo "ftpuser" >> /etc/vsftpd.user_list && \
    echo "backup" >> /etc/vsftpd.user_list

COPY <<'HEREDOC' /opt/web-server.py
#!/usr/bin/env python3
"""Multi-endpoint web server for brute force practice.
- /admin → HTTP Basic Auth
- /login → POST form with username/password
- /rate-limited → POST form with 429 after 5 attempts
"""

import http.server
import base64
import json
import os
import time
from urllib.parse import parse_qs, urlparse

USERS = {
    "admin": "password1",
    "jdoe": "letmein1",
    "jsmith": "1234567",
    "webmaster": "web12345",
    "operator": "op12345",
}

# Rate limiting state
RATE_LIMIT = {}    # IP → (count, window_start)

class MultiAuthHandler(http.server.BaseHTTPRequestHandler):

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path == "/":
            self._serve_index()
        elif parsed.path == "/login":
            self._serve_login_form()
        elif parsed.path == "/admin":
            self._handle_basic_auth()
        elif parsed.path == "/rate-limited":
            self._serve_rate_limited_form()
        else:
            self.send_error(404)

    def do_POST(self):
        parsed = urlparse(self.path)

        if parsed.path == "/login":
            self._handle_form_login()
        elif parsed.path == "/rate-limited":
            self._handle_rate_limited()
        else:
            self.send_error(404)

    def _serve_index(self):
        html = """<!DOCTYPE html>
<html><head><title>Brute Force Lab</title>
<style>
body { font-family: monospace; max-width: 600px; margin: 30px auto; }
a { display: block; padding: 8px; }
input { width: 100%; padding: 8px; margin: 5px 0; }
input[type=submit] { background: #4CAF50; color: white; border: none; cursor: pointer; }
</style></head><body>
<h1>Brute Force Lab — Web Endpoints</h1>
<ul>
<li><a href="/login">/login</a> — Standard POST form login</li>
<li><a href="/admin">/admin</a> — HTTP Basic Auth protected</li>
<li><a href="/rate-limited">/rate-limited</a> — Rate-limited form login</li>
</ul>
</body></html>"""
        self._respond(200, html)

    def _serve_login_form(self):
        html = """<!DOCTYPE html>
<html><head><title>Login</title>
<style>
body { font-family: monospace; max-width: 500px; margin: 50px auto; }
input { width: 100%; padding: 8px; margin: 5px 0; }
input[type=submit] { background: #4CAF50; color: white; border: none; cursor: pointer; }
</style></head><body>
<h1>Standard Login</h1>
<form method="POST" action="/login">
<input type="text" name="username" placeholder="Username" />
<input type="password" name="password" placeholder="Password" />
<input type="submit" value="Login" />
</form>
</body></html>"""
        self._respond(200, html)

    def _serve_rate_limited_form(self):
        html = """<!DOCTYPE html>
<html><head><title>Rate Limited Login</title>
<style>
body { font-family: monospace; max-width: 500px; margin: 50px auto; }
input { width: 100%; padding: 8px; margin: 5px 0; }
input[type=submit] { background: #4CAF50; color: white; border: none; cursor: pointer; }
</style></head><body>
<h1>Rate-Limited Login</h1>
<p>5 attempts per 60 seconds. Will return HTTP 429.</p>
<form method="POST" action="/rate-limited">
<input type="text" name="username" placeholder="Username" />
<input type="password" name="password" placeholder="Password" />
<input type="submit" value="Login" />
</form>
</body></html>"""
        self._respond(200, html)

    def _handle_form_login(self):
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode()
        params = parse_qs(body)
        username = params.get("username", [""])[0]
        password = params.get("password", [""])[0]

        if username in USERS and USERS[username] == password:
            self._respond(200, f"<h1>Login Successful</h1><p>Welcome, {username}!</p>")
        else:
            # Deliberately ambiguous when username doesn't exist
            if username in USERS:
                msg = "Invalid password"
            else:
                msg = "Invalid username or password"
            self._respond(200, f"<h1>Login Failed</h1><p>{msg}</p>")

    def _handle_basic_auth(self):
        auth_header = self.headers.get("Authorization", "")
        if auth_header.startswith("Basic "):
            encoded = auth_header[6:]
            decoded = base64.b64decode(encoded).decode("utf-8")
            username, password = decoded.split(":", 1)

            if username in USERS and USERS[username] == password:
                self._respond(200, f"<h1>Admin Panel</h1><p>Welcome, {username}!</p><p>flag{{basic_auth_cracked}}</p>")
                return

        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="Admin Area"')
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(b"<h1>401 Unauthorized</h1><p>Invalid credentials</p>")

    def _handle_rate_limited(self):
        client_ip = self.client_address[0]
        now = time.time()

        # Rate limit: 5 attempts per 60 seconds per IP
        if client_ip not in RATE_LIMIT:
            RATE_LIMIT[client_ip] = (0, now)

        count, window_start = RATE_LIMIT[client_ip]
        if now - window_start > 60:
            count = 0
            window_start = now

        if count >= 5:
            self.send_response(429)
            self.send_header("Retry-After", "60")
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            retry_in = int(60 - (now - window_start))
            self.wfile.write(f"<h1>429 Too Many Requests</h1><p>Rate limit exceeded. Retry in {retry_in}s.</p>".encode())
            return

        count += 1
        RATE_LIMIT[client_ip] = (count, window_start)

        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length).decode()
        params = parse_qs(body)
        username = params.get("username", [""])[0]
        password = params.get("password", [""])[0]

        if username in USERS and USERS[username] == password:
            self._respond(200, f"<h1>Login Successful</h1><p>Welcome, {username}!</p>")
        else:
            self._respond(200, f"<h1>Login Failed</h1><p>Invalid credentials (attempt {count}/5)</p>")

    def _respond(self, code, body):
        self.send_response(code)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(body.encode("utf-8"))

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    server = http.server.HTTPServer(("0.0.0.0", 80), MultiAuthHandler)
    print("[*] Web server listening on port 80")
    print("    /login        — form-based login")
    print("    /admin        — HTTP Basic Auth")
    print("    /rate-limited — rate-limited form login")
    server.serve_forever()
HEREDOC

COPY <<'HEREDOC' /opt/setup-mariadb.sh
#!/bin/bash
set -e

mysql_install_db --user=mysql --datadir=/var/lib/mysql
mysqld_safe --skip-grant-tables &
sleep 3

mysql -u root << 'SQL'
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY 'rootpass';

CREATE USER 'admin'@'%' IDENTIFIED BY 'password1';
CREATE USER 'jdoe'@'%' IDENTIFIED BY 'letmein1';
CREATE USER 'jsmith'@'%' IDENTIFIED BY '1234567';
CREATE USER 'webapp'@'%' IDENTIFIED BY 'webapp99';

GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO 'jdoe'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'jsmith'@'%';
GRANT ALL PRIVILEGES ON *.* TO 'webapp'@'%';
FLUSH PRIVILEGES;
SQL

mysqladmin -u root -prootpass shutdown
echo "[*] MariaDB configured"
HEREDOC

COPY <<'HEREDOC' /opt/start-lab.sh
#!/bin/bash
set -e

echo "========================================"
echo "  Brute Force Lab"
echo "========================================"
echo ""
echo "Services:"
echo "  SSH    — port 22  (MaxAuthTries=6, no lockout)"
echo "  FTP    — port 21  (vsftpd, local users)"
echo "  Web    — port 80  (/login, /admin, /rate-limited)"
echo "  MySQL  — port 3306 (weak root + user passwords)"
echo ""
echo "Credentials (deliberately weak):"
echo "  root:admin123 / admin:password1 / jdoe:letmein1"
echo "  jsmith:1234567 / ftpuser:ftp12345 / backup:backup99"
echo "  devops:dev12345"
echo "========================================"
echo ""

# Start MariaDB
bash /opt/setup-mariadb.sh
mysqld_safe &
sleep 2
echo "[*] MariaDB started"

# Start web server
python3 /opt/web-server.py &
echo "[*] Web server started on port 80"

# Start FTP
vsftpd /etc/vsftpd.conf &
echo "[*] FTP started on port 21"

# Start SSH
/usr/sbin/sshd -D &
echo "[*] SSH started on port 22"

echo ""
echo "[*] Lab ready. Try:"
echo "    hydra -l root -P passwords.txt ssh://localhost:2222"
echo "    hydra -L users.txt -P passwords.txt ftp://localhost:2121"
echo "    hydra -l admin -P passwords.txt http-get://localhost:8080/admin"
echo ""

exec /bin/bash
HEREDOC

RUN chmod +x /opt/setup-mariadb.sh /opt/web-server.py /opt/start-lab.sh

WORKDIR /opt
CMD ["/opt/start-lab.sh"]

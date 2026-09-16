# Password Attacks - CTF Lab Container
# Build:  podman build -t password-lab -f password-attacks.Containerfile .
#
# WARNING: Intentionally vulnerable. Run only on an isolated host and never
# expose these services to a real network.
# Run:    podman run -it --rm -p 2222:22 -p 8080:80 -p 3306:3306 password-lab
#
# Services:
#   SSH on 2222   - user accounts with passwords from rockyou top 100
#   HTTP on 8080  - web login form with informative error messages
#   MySQL on 3306 - database with weak credentials

FROM docker.io/library/archlinux:latest

RUN pacman -Sy --noconfirm \
    openssh \
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
    sudo && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

RUN ssh-keygen -A && \
    useradd -m -s /bin/bash alice && \
    useradd -m -s /bin/bash bob && \
    useradd -m -s /bin/bash charlie && \
    useradd -m -s /bin/bash david && \
    useradd -m -s /bin/bash eve && \
    useradd -m -s /bin/bash frank && \
    useradd -m -s /bin/bash grace && \
    useradd -m -s /bin/bash heidi && \
    useradd -m -s /bin/bash ivan && \
    useradd -m -s /bin/bash judy && \
    useradd -m -s /bin/bash karl && \
    useradd -m -s /bin/bash linda && \
    useradd -m -s /bin/bash mallory && \
    useradd -m -s /bin/bash nancy && \
    useradd -m -s /bin/bash oscar && \
    useradd -m -s /bin/bash peggy && \
    useradd -m -s /bin/bash quincy && \
    useradd -m -s /bin/bash robert && \
    useradd -m -s /bin/bash sarah && \
    useradd -m -s /bin/bash trudy && \
    useradd -m -s /bin/bash victor

COPY <<'HEREDOC' /opt/populate-users.sh
#!/bin/bash
set -e
# Populate users with passwords from rockyou top 100

USERS=(
    "root"
    "alice" "bob" "charlie" "david" "eve"
    "frank" "grace" "heidi" "ivan" "judy"
    "karl" "linda" "mallory" "nancy" "oscar"
    "peggy" "quincy" "robert" "sarah" "trudy"
    "victor"
)

# Passwords from rockyou top 100 (first 22 unique, realistic ones)
# These are intentionally weak passwords for practice
PASSWORDS=(
    "password"
    "123456"
    "12345678"
    "qwerty"
    "abc123"
    "monkey"
    "1234567"
    "letmein"
    "trustno1"
    "dragon"
    "baseball"
    "iloveyou"
    "master"
    "sunshine"
    "ashley"
    "bailey"
    "shadow"
    "123123"
    "654321"
    "superman"
    "qazwsx"
    "michael"
)

echo "[*] Setting user passwords..."
for i in "${!USERS[@]}"; do
    user="${USERS[$i]}"
    pass="${PASSWORDS[$i]:-password}"
    echo "${user}:${pass}" | chpasswd
    echo "  [+] ${user} <- ${pass}"
done

echo "[*] Configuring PAM faillock (lockout after 5 failures)..."
cat > /etc/security/faillock.conf << 'FAILLOCK'
deny = 5
unlock_time = 300
fail_interval = 900
FAILLOCK

# Enable faillock in PAM
cp /etc/pam.d/system-auth /etc/pam.d/system-auth.bak
sed -i 's/^auth.*required.*pam_unix\.so.*$/&\nauth        required    pam_faillock.so preauth/' /etc/pam.d/system-auth
sed -i 's/^auth.*required.*pam_unix\.so.*$/auth        [default=die]    pam_faillock.so authfail/' /etc/pam.d/system-auth
sed -i 's/^account.*required.*pam_unix\.so.*$/&\naccount    required    pam_faillock.so/' /etc/pam.d/system-auth

echo "[*] Configuring SSH..."
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 6/' /etc/ssh/sshd_config
# Disable key authentication so students must use passwords
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication no/' /etc/ssh/sshd_config

echo "[*] SSH user accounts configured."
HEREDOC

COPY <<'HEREDOC' /opt/web-app.py
#!/usr/bin/env python3
"""Flask web app with deliberately informative error messages
for practicing username enumeration and password spraying.
"""
import sqlite3
import os
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs

DATABASE = "/opt/users.db"
HOST = "0.0.0.0"
PORT = 80

class LoginHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/" or self.path == "/login":
            self._serve_login_page()
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path == "/login":
            content_length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(content_length).decode("utf-8")
            params = parse_qs(body)
            username = params.get("username", [""])[0]
            password = params.get("password", [""])[0]

            if not username or not password:
                self._login_response(400, "Missing username or password")
                return

            conn = sqlite3.connect(DATABASE)
            cursor = conn.cursor()
            cursor.execute("SELECT id, password FROM users WHERE username = ?", (username,))
            row = cursor.fetchone()
            conn.close()

            if row is None:
                # DELIBERATELY informative - reveals username does not exist
                self._login_response(200, "Invalid username - user does not exist")
                return

            if row[1] == password:
                self._login_response(200, f"Login successful! Welcome, {username}.")
            else:
                # DELIBERATELY informative - reveals password is wrong, user exists
                self._login_response(200, "Invalid password - user exists, password incorrect")
        else:
            self.send_error(404)

    def _login_response(self, code, message):
        html = f"""<!DOCTYPE html>
<html><head><title>Login</title>
<style>
    body {{ font-family: monospace; max-width: 500px; margin: 50px auto; }}
    input {{ width: 100%%; padding: 8px; margin: 5px 0; }}
    input[type=submit] {{ background: #4CAF50; color: white; border: none; cursor: pointer; }}
    .message {{ padding: 10px; margin: 10px 0; border-radius: 4px; }}
    .success {{ background: #d4edda; color: #155724; }}
    .error {{ background: #f8d7da; color: #721c24; }}
</style></head><body>
<h1>Corporate Login Portal</h1>
<form method="POST" action="/login">
    <input type="text" name="username" placeholder="Username" />
    <input type="password" name="password" placeholder="Password" />
    <input type="submit" value="Login" />
</form>
<div class="message {'success' if 'successful' in message.lower() else 'error'}">{message}</div>
</body></html>"""
        self.send_response(code)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(html.encode("utf-8"))

    def log_message(self, format, *args):
        # Suppress HTTP access logs for cleaner output
        pass

    def _serve_login_page(self):
        html = """<!DOCTYPE html>
<html><head><title>Login</title>
<style>
    body { font-family: monospace; max-width: 500px; margin: 50px auto; }
    input { width: 100%; padding: 8px; margin: 5px 0; }
    input[type=submit] { background: #4CAF50; color: white; border: none; cursor: pointer; }
</style></head><body>
<h1>Corporate Login Portal</h1>
<form method="POST" action="/login">
    <input type="text" name="username" placeholder="Username" />
    <input type="password" name="password" placeholder="Password" />
    <input type="submit" value="Login" />
</form>
</body></html>"""
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.end_headers()
        self.wfile.write(html.encode("utf-8"))

def init_db():
    os.makedirs(os.path.dirname(DATABASE), exist_ok=True)
    conn = sqlite3.connect(DATABASE)
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL
        )
    """)
    # Populate with the same users as the system accounts
    users_passwords = [
        ("root", "password"),
        ("alice", "123456"),
        ("bob", "12345678"),
        ("charlie", "qwerty"),
        ("david", "abc123"),
        ("eve", "monkey"),
        ("frank", "1234567"),
        ("grace", "letmein"),
        ("heidi", "trustno1"),
        ("ivan", "dragon"),
        ("judy", "baseball"),
        ("karl", "iloveyou"),
        ("linda", "master"),
        ("mallory", "sunshine"),
        ("nancy", "ashley"),
        ("oscar", "bailey"),
        ("peggy", "shadow"),
        ("quincy", "123123"),
        ("robert", "654321"),
        ("sarah", "superman"),
        ("trudy", "qazwsx"),
        ("victor", "michael"),
    ]
    for user, pw in users_passwords:
        cursor.execute("INSERT OR IGNORE INTO users (username, password) VALUES (?, ?)", (user, pw))
    conn.commit()
    conn.close()
    print(f"[*] Database initialized with {len(users_passwords)} users")

if __name__ == "__main__":
    init_db()
    server = HTTPServer((HOST, PORT), LoginHandler)
    print(f"[*] Web login app listening on http://{HOST}:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        server.server_close()
HEREDOC

COPY <<'HEREDOC' /opt/setup-mariadb.sh
#!/bin/bash
set -e

echo "[*] Initializing MariaDB..."
mysql_install_db --user=mysql --datadir=/var/lib/mysql
mysqld_safe --skip-grant-tables &
sleep 3

echo "[*] Setting root password and creating test users..."
mysql -u root << 'SQL'
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY 'admin123';

CREATE DATABASE IF NOT EXISTS corporate;
USE corporate;

CREATE TABLE IF NOT EXISTS employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) UNIQUE,
    password VARCHAR(100),
    department VARCHAR(50)
);

INSERT INTO employees (username, password, department) VALUES
    ('admin', 'password', 'IT'),
    ('jsmith', 'letmein', 'HR'),
    ('jdoe', '123456', 'Sales'),
    ('awilson', 'abc123', 'Finance'),
    ('bthomas', 'dragon', 'Engineering'),
    ('cgarcia', 'monkey', 'Marketing'),
    ('dlee', 'master', 'Operations'),
    ('emartinez', 'sunshine', 'Legal');

CREATE USER 'jsmith'@'%' IDENTIFIED BY 'letmein';
CREATE USER 'jdoe'@'%' IDENTIFIED BY '123456';
CREATE USER 'awilson'@'%' IDENTIFIED BY 'abc123';
CREATE USER 'bthomas'@'%' IDENTIFIED BY 'dragon';
CREATE USER 'cgarcia'@'%' IDENTIFIED BY 'monkey';

GRANT ALL PRIVILEGES ON corporate.* TO 'jsmith'@'%';
GRANT ALL PRIVILEGES ON corporate.* TO 'jdoe'@'%';
GRANT ALL PRIVILEGES ON corporate.* TO 'awilson'@'%';
GRANT ALL PRIVILEGES ON corporate.* TO 'bthomas'@'%';
GRANT ALL PRIVILEGES ON corporate.* TO 'cgarcia'@'%';

FLUSH PRIVILEGES;
SQL

mysqladmin -u root -padmin123 shutdown
echo "[*] MariaDB configured with weak credentials"
HEREDOC

COPY <<'HEREDOC' /opt/start-lab.sh
#!/bin/bash
set -e

echo "========================================"
echo "  Password Attacks Lab"
echo "========================================"
echo ""
echo "Services:"
echo "  SSH    - port 22  (pw auth, lockout after 5 failures)"
echo "  Web    - port 80  (login form with info-leak errors)"
echo "  MySQL  - port 3306 (weak credentials)"
echo ""
echo "Users populated with passwords from rockyou top 100"
echo "========================================"
echo ""

# Set up system users
bash /opt/populate-users.sh

# Initialize and start MariaDB
bash /opt/setup-mariadb.sh
mysqld_safe &
sleep 2
echo "[*] MariaDB started"

# Start web app in background
python3 /opt/web-app.py &
echo "[*] Web app started on port 80"

# Start SSH
/usr/sbin/sshd -D &
echo "[*] SSH started on port 22"

echo ""
echo "[*] Lab is ready. Dropping to shell."
echo "[*] Try enumerating users via the web app, then spray SSH."
echo "[*] From host: curl http://localhost:8080/login"
echo "[*] From host: hydra -L users.txt -p 'password' ssh://localhost:2222"
echo ""

exec /bin/bash
HEREDOC

RUN chmod +x /opt/populate-users.sh /opt/setup-mariadb.sh /opt/web-app.py /opt/start-lab.sh

WORKDIR /opt
CMD ["/opt/start-lab.sh"]

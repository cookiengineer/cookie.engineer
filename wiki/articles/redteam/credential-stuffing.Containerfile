# Credential Stuffing - CTF Lab Container
# Build:  podman build -t credstuff-lab -f credential-stuffing.Containerfile .
# Run:    podman run -it --rm -p 8080:80 credstuff-lab
#
# A realistic web application login page with:
#   - CSRF token protection
#   - Session cookies
#   - Different response patterns for valid/invalid credentials
#   - MFA emulation on some accounts
#   - Rate limiter (5 attempts per 60s per IP)
#   - Pre-populated database with 100 email:password pairs
#
# WARNING: Intentionally vulnerable. Run only on an isolated host and never
# expose this port to a real network.

FROM docker.io/library/archlinux:latest

RUN pacman -Sy --noconfirm \
    python \
    python-pip \
    python-flask \
    curl \
    net-tools && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

# Generate fake user database
COPY <<'HEREDOC' /opt/generate-users.py
#!/usr/bin/env python3
"""Generate a realistic user database with 100 email:password pairs"""
import sqlite3
import random
import hashlib
import os

DB_PATH = "/opt/users.db"
COMBO_OUTPUT = "/opt/combos.txt"

FIRST_NAMES = [
    "james", "john", "robert", "michael", "william", "david", "richard", "joseph",
    "thomas", "charles", "christopher", "daniel", "matthew", "anthony", "donald",
    "mark", "paul", "steven", "andrew", "kenneth", "joshua", "kevin", "brian",
    "george", "edward", "ronald", "timothy", "jason", "jeffrey", "ryan",
    "mary", "patricia", "jennifer", "linda", "barbara", "elizabeth", "susan",
    "jessica", "sarah", "karen", "lisa", "nancy", "betty", "margaret", "sandra",
    "ashley", "dorothy", "kimberly", "emily", "donna", "michelle", "carol",
]

LAST_NAMES = [
    "smith", "johnson", "williams", "brown", "jones", "garcia", "miller",
    "davis", "rodriguez", "martinez", "hernandez", "lopez", "gonzalez",
    "wilson", "anderson", "thomas", "taylor", "moore", "jackson", "martin",
    "lee", "perez", "thompson", "white", "harris", "sanchez", "clark",
    "ramirez", "lewis", "robinson", "walker", "young", "allen", "king",
]

DOMAINS = ["example.com", "corp.example.com", "test.org", "mail.net"]

# Top 100 common passwords (subset of rockyou for the lab)
COMMON_PASSWORDS = [
    "password", "123456", "12345678", "qwerty", "abc123",
    "monkey", "1234567", "letmein", "trustno1", "dragon",
    "baseball", "iloveyou", "master", "sunshine", "ashley",
    "bailey", "shadow", "123123", "654321", "superman",
    "qazwsx", "michael", "football", "password1", "welcome",
    "admin", "login", "princess", "starwars", "access",
    "passw0rd", "mypass", "hello", "charlie", "donald",
    "mustang", "letmein1", "trustme", "secret", "batman",
]

def generate_users(count=100):
    users = []
    emails_seen = set()

    for i in range(count):
        first = random.choice(FIRST_NAMES)
        last = random.choice(LAST_NAMES)

        if i < 10:
            # First 10 users: predictable pattern (easy to guess)
            email = f"{first}.{last}@{random.choice(DOMAINS)}"
        elif i < 30:
            # Next 20: first initial + last name
            email = f"{first[0]}{last}@{random.choice(DOMAINS)}"
        else:
            # Rest: first name + random digit
            digit = random.randint(1, 999)
            email = f"{first}{digit}@{random.choice(DOMAINS)}"

        if email in emails_seen:
            email = f"{first}.{last}{random.randint(1, 99)}@{random.choice(DOMAINS)}"

        emails_seen.add(email)
        password = random.choice(COMMON_PASSWORDS)

        # 20% of accounts have MFA enabled
        mfa_enabled = i < 20

        users.append({
            "email": email,
            "password": password,
            "mfa_enabled": mfa_enabled,
            "first_name": first.capitalize(),
            "last_name": last.capitalize(),
        })

    return users

if __name__ == "__main__":
    os.makedirs("/opt", exist_ok=True)

    users = generate_users(100)
    random.shuffle(users)

    conn = sqlite3.connect(DB_PATH)
    c = conn.cursor()
    c.execute("""CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT UNIQUE,
        password TEXT,
        mfa_enabled INTEGER DEFAULT 0,
        first_name TEXT,
        last_name TEXT
    )""")

    for u in users:
        c.execute(
            "INSERT INTO users (email, password, mfa_enabled, first_name, last_name) VALUES (?, ?, ?, ?, ?)",
            (u["email"], u["password"], int(u["mfa_enabled"]), u["first_name"], u["last_name"]),
        )

    conn.commit()
    conn.close()

    # Write combo file for practice (80% valid, 20% invalid)
    with open(COMBO_OUTPUT, "w") as f:
        for u in users[:80]:
            f.write(f"{u['email']}:{u['password']}\n")
        # Add 20 invalid combos
        for i in range(20):
            random_first = random.choice(FIRST_NAMES)
            random_last = random.choice(LAST_NAMES)
            fake_email = f"{random_first}.{random_last}{random.randint(100, 999)}@{random.choice(DOMAINS)}"
            f.write(f"{fake_email}:wrongpassword{i}\n")

    print(f"[*] Generated {len(users)} user accounts")
    print(f"[*] Combo file: {COMBO_OUTPUT} (80 valid + 20 invalid)")
HEREDOC

# Flask web application
COPY <<'HEREDOC' /opt/web-app.py
#!/usr/bin/env python3
"""Realistic login page for credential stuffing practice.
Features:
- CSRF token per session
- Session cookies
- Informative error messages ('Invalid password' vs 'User not found')
- MFA emulation on selected accounts
- Rate limiter: 5 attempts per 60s per IP
"""
import flask
import sqlite3
import time
import secrets
import hashlib
import os

app = flask.Flask(__name__)
app.secret_key = secrets.token_hex(32)

DATABASE = "/opt/users.db"

# Rate limiting state: {ip: [timestamps]}
rate_limit_state: dict[str, list[float]] = {}

def get_db():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    return conn

def check_rate_limit(ip: str, max_attempts: int = 5, window: int = 60) -> bool:
    """Return True if rate limit exceeded"""
    now = time.time()
    if ip not in rate_limit_state:
        rate_limit_state[ip] = []

    # Purge old entries
    rate_limit_state[ip] = [t for t in rate_limit_state[ip] if now - t < window]

    if len(rate_limit_state[ip]) >= max_attempts:
        return True

    rate_limit_state[ip].append(now)
    return False

def generate_csrf_token():
    if "_csrf_token" not in flask.session:
        flask.session["_csrf_token"] = secrets.token_hex(32)
    return flask.session["_csrf_token"]

@app.route("/")
def index():
    return flask.render_template_string("""
<!DOCTYPE html>
<html>
<head>
    <title>Corporate SSO Portal</title>
    <style>
        * { box-sizing: border-box; }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #f0f2f5;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
        }
        .login-container {
            background: white;
            padding: 40px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            width: 400px;
        }
        .logo { text-align: center; font-size: 24px; font-weight: bold; margin-bottom: 30px; color: #1a73e8; }
        input[type="text"], input[type="password"] {
            width: 100%;
            padding: 12px;
            margin: 8px 0;
            border: 1px solid #dadce0;
            border-radius: 4px;
            font-size: 16px;
        }
        input[type="submit"] {
            width: 100%;
            padding: 12px;
            background: #1a73e8;
            color: white;
            border: none;
            border-radius: 4px;
            font-size: 16px;
            cursor: pointer;
            margin-top: 16px;
        }
        input[type="submit"]:hover { background: #1557b0; }
        .error {
            color: #d93025;
            background: #fce8e6;
            padding: 10px;
            border-radius: 4px;
            margin-top: 15px;
        }
        .success {
            color: #1e8e3e;
            background: #e6f4ea;
            padding: 10px;
            border-radius: 4px;
            margin-top: 15px;
        }
        .warning {
            color: #f9ab00;
            background: #fef7e0;
            padding: 10px;
            border-radius: 4px;
            margin-top: 15px;
        }
    </style>
</head>
<body>
    <div class="login-container">
        <div class="logo">&#128274; CorpSSO</div>
        <form method="POST" action="/login">
            <input type="hidden" name="csrf_token" value="{{ csrf_token }}" />
            <input type="hidden" name="return_url" value="/dashboard" />
            <input type="text" name="email" placeholder="Email address" autofocus />
            <input type="password" name="password" placeholder="Password" />
            <input type="submit" value="Sign In" />
        </form>
        {% if message %}
        <div class="{{ message_type }}">{{ message }}</div>
        {% endif %}
        <p style="text-align: center; margin-top: 20px; color: #5f6368; font-size: 13px;">
            Forgot password? Contact IT Helpdesk
        </p>
    </div>
</body>
</html>
""", csrf_token=generate_csrf_token(), message=flask.request.args.get("message", ""),
   message_type=flask.request.args.get("type", ""))

@app.route("/login", methods=["POST"])
def login():
    ip = flask.request.remote_addr

    # Rate limit check
    if check_rate_limit(ip):
        return flask.redirect("/?message=Too+many+login+attempts.+Please+wait+60+seconds.&type=error")

    email = flask.request.form.get("email", "").strip().lower()
    password = flask.request.form.get("password", "")

    # CSRF validation
    form_csrf = flask.request.form.get("csrf_token", "")
    if form_csrf != flask.session.get("_csrf_token", ""):
        return flask.redirect("/?message=Invalid+security+token.+Please+refresh+the+page.&type=error")

    if not email or not password:
        return flask.redirect("/?message=Please+enter+email+and+password.&type=error")

    # Regenerate CSRF after each attempt
    flask.session.pop("_csrf_token", None)

    db = get_db()
    user = db.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
    db.close()

    if user is None:
        # User does not exist
        return flask.redirect("/?message=Invalid+username+or+password&type=error")

    if user["password"] != password:
        # User exists, wrong password
        return flask.redirect("/?message=Invalid+password&type=error")

    # Successful authentication
    flask.session["user_id"] = user["id"]
    flask.session["email"] = user["email"]
    flask.session["first_name"] = user["first_name"]

    if user["mfa_enabled"]:
        # MFA emulation
        flask.session["mfa_pending"] = True
        return flask.redirect("/mfa")

    flask.session["authenticated"] = True
    return flask.redirect("/dashboard")

@app.route("/mfa", methods=["GET", "POST"])
def mfa():
    if not flask.session.get("mfa_pending"):
        return flask.redirect("/")

    if flask.request.method == "GET":
        return flask.render_template_string("""
<!DOCTYPE html>
<html><head><title>Multi-Factor Authentication</title>
<style>
    body { font-family: 'Segoe UI', sans-serif; background: #f0f2f5;
           display: flex; justify-content: center; align-items: center; min-height: 100vh; }
    .mfa-box { background: white; padding: 40px; border-radius: 8px;
               box-shadow: 0 2px 10px rgba(0,0,0,0.1); width: 400px; text-align: center; }
    input[type="text"] { width: 200px; padding: 12px; margin: 10px 0;
                         border: 1px solid #dadce0; border-radius: 4px; font-size: 24px; text-align: center; }
    input[type="submit"] { padding: 12px 30px; background: #1a73e8; color: white;
                           border: none; border-radius: 4px; cursor: pointer; }
</style></head><body>
<div class="mfa-box">
    <h2>Two-Factor Authentication</h2>
    <p>A verification code has been sent to your device.</p>
    <p style="color: #888;">Hint: code is always "123456" for this lab</p>
    <form method="POST">
        <input type="text" name="code" placeholder="6-digit code" maxlength="6" />
        <br/>
        <input type="submit" value="Verify" />
    </form>
    {% if error %}<p style="color: #d93025;">{{ error }}</p>{% endif %}
</div>
</body></html>
""", error=flask.request.args.get("error", ""))

    code = flask.request.form.get("code", "")
    if code == "123456":
        flask.session["authenticated"] = True
        flask.session.pop("mfa_pending", None)
        return flask.redirect("/dashboard")
    else:
        return flask.redirect("/mfa?error=Invalid+code")

@app.route("/dashboard")
def dashboard():
    if not flask.session.get("authenticated"):
        return flask.redirect("/?message=Please+log+in+first.&type=error")

    email = flask.session.get("email", "unknown")
    first_name = flask.session.get("first_name", "User")

    return flask.render_template_string("""
<!DOCTYPE html>
<html><head><title>Dashboard</title>
<style>
    body { font-family: 'Segoe UI', sans-serif; background: #f0f2f5; padding: 30px; }
    .dash { max-width: 800px; margin: 0 auto; background: white;
            padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
    .flag { background: #e6f4ea; padding: 10px; border-radius: 4px;
            font-family: monospace; margin: 20px 0; }
    a { color: #1a73e8; }
</style></head><body>
<div class="dash">
    <h1>Welcome, {{ first_name }}!</h1>
    <p>Logged in as: {{ email }}</p>
    <div class="flag">FLAG{{credential_stuffing_success_{{ email | replace('@', '_') | replace('.', '_') }}}}</div>
    <p><a href="/logout">Sign Out</a></p>
</div>
</body></html>
""", email=email, first_name=first_name)

@app.route("/logout")
def logout():
    flask.session.clear()
    return flask.redirect("/")

if __name__ == "__main__":
    # Generate database if not exists
    if not os.path.exists(DATABASE):
        import subprocess
        subprocess.run(["python3", "/opt/generate-users.py"])

    print("[*] Credential Stuffing Lab starting...")
    print("[*] Login page: http://localhost:80/")
    print("[*] Combo list: /opt/combos.txt")
    print("[*] Rate limit: 5 attempts / 60 seconds per IP")
    print("[*] MFA enabled on first 20 accounts (code: 123456)")
    app.run(host="0.0.0.0", port=80, debug=False)
HEREDOC

COPY <<'HEREDOC' /opt/start-lab.sh
#!/bin/bash
set -e

echo "========================================"
echo "  Credential Stuffing Lab"
echo "========================================"
echo ""
echo "A realistic corporate SSO portal with:"
echo "  - CSRF token protection"
echo "  - Session cookies"
echo "  - Informative error messages"
echo "  - MFA emulation on some accounts"
echo "  - Rate limiter (5/60s per IP)"
echo ""
echo "Login page: http://localhost:80/"
echo "Combo list: /opt/combos.txt (80 valid + 20 invalid)"
echo ""
echo "User database has 100 accounts."
echo "First 20 accounts have MFA enabled (code: 123456)"
echo "========================================"
echo ""

# Generate users
python3 /opt/generate-users.py

# Start web app
exec python3 /opt/web-app.py
HEREDOC

RUN chmod +x /opt/generate-users.py /opt/web-app.py /opt/start-lab.sh

WORKDIR /opt
CMD ["/opt/start-lab.sh"]

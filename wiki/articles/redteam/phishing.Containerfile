# redteam/phishing.Containerfile
# Purpose: Phishing simulation lab with GoPhish, a fake login page, a credential capture API,
#          and a MailHog SMTP relay.
# Build:  podman build -f phishing.Containerfile -t phishing .
# Run:    podman run -it --rm -p 3333:3333 -p 8080:80 -p 5000:5000 -p 1025:25 -p 8025:8025 phishing
#
# Services:
#   GoPhish admin UI     - https://localhost:3333 (login: admin / gophish)
#   Phishing landing     - http://localhost:8080 (fake corporate login)
#   Credential capture   - http://localhost:5000/capture (Flask API)
#   SMTP relay (MailHog) - localhost:1025 (catches emails, no actual sending)
#   MailHog web UI       - http://localhost:8025 (view sent emails)
#
# Intentionally vulnerable. Never expose this lab to a real network.

FROM docker.io/library/archlinux:latest

RUN pacman -Sy --noconfirm \
    python \
    python-pip \
    python-flask \
    which \
    curl \
    wget \
    unzip \
    go \
    openssl \
    net-tools \
    nginx && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

# Download and set up GoPhish
RUN mkdir -p /opt/gophish && \
    wget -q https://github.com/gophish/gophish/releases/download/v0.12.1/gophish-v0.12.1-linux-64bit.zip \
      -O /tmp/gophish.zip && \
    unzip -q /tmp/gophish.zip -d /opt/gophish && \
    rm /tmp/gophish.zip && \
    chmod +x /opt/gophish/gophish

COPY <<'HEREDOC' /opt/gophish/config.json
{
    "admin_server": {
        "listen_url": "0.0.0.0:3333",
        "use_tls": true,
        "cert_path": "gophish_admin.crt",
        "key_path": "gophish_admin.key"
    },
    "phish_server": {
        "listen_url": "0.0.0.0:80",
        "use_tls": false
    },
    "db_name": "sqlite3",
    "db_path": "gophish.db",
    "migrations_prefix": "db/db_",
    "contact_address": ""
}
HEREDOC

# Generate TLS cert for GoPhish admin
RUN openssl req -newkey rsa:2048 -nodes \
    -keyout /opt/gophish/gophish_admin.key \
    -x509 -days 365 \
    -out /opt/gophish/gophish_admin.crt \
    -subj "/CN=gophish.local"

# Set up MailHog (catches all SMTP traffic — no real emails sent)
RUN wget -q https://github.com/mailhog/MailHog/releases/download/v1.0.1/MailHog_linux_amd64 \
      -O /usr/local/bin/mailhog && \
    chmod +x /usr/local/bin/mailhog && \
    wget -q https://github.com/mailhog/mhsendmail/releases/download/v0.2.0/mhsendmail_linux_amd64 \
      -O /usr/local/bin/mhsendmail && \
    chmod +x /usr/local/bin/mhsendmail

# Flask phishing capture server
COPY <<'HEREDOC' /opt/phish/capture-server.py
#!/usr/bin/env python3
"""Phishing credential capture server with Telegram/Discord notification"""

import flask
import datetime
import json
import os
import threading

app = flask.Flask(__name__)
app.secret_key = os.urandom(32).hex()
LOG_FILE = "/opt/phish/credentials.jsonl"

def log_credential(data: dict):
    data["timestamp"] = datetime.datetime.now().isoformat()
    data["ip"] = flask.request.headers.get("X-Forwarded-For", flask.request.remote_addr)
    data["user_agent"] = flask.request.headers.get("User-Agent", "")

    with open(LOG_FILE, "a") as f:
        f.write(json.dumps(data) + "\n")
    print(f"\n[+] CAPTURE: {data.get('email', '?')}:{data.get('password', '?')}")

@app.route("/")
def index():
    return flask.render_template_string(LOGIN_PAGE_HTML)

@app.route("/login", methods=["POST"])
def login():
    email = flask.request.form.get("username", "")
    password = flask.request.form.get("password", "")
    log_credential({"step": "login", "email": email, "password": password})
    flask.session["email"] = email
    # Show MFA prompt
    return flask.render_template_string(MFA_PAGE_HTML)

@app.route("/mfa", methods=["POST"])
def mfa():
    code = flask.request.form.get("code", "")
    email = flask.session.get("email", "unknown")
    log_credential({"step": "mfa", "email": email, "mfa_code": code})
    return flask.render_template_string(SUCCESS_PAGE_HTML, email=email)

LOGIN_PAGE_HTML = """<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sign In — Corporate Portal</title>
<style>
*{box-sizing:border-box;}body{font-family:'Segoe UI',Tahoma,sans-serif;background:#f0f0f0;margin:0}
.header{background:#0078d4;padding:16px 44px;color:#fff;font-size:20px}
.container{max-width:440px;margin:40px auto;background:#fff;padding:44px;box-shadow:0 2px 6px rgba(0,0,0,.2)}
h2{font-weight:600;font-size:1.5rem;margin-top:0}
input:not([type=submit]){width:100%;padding:6px 10px;height:36px;margin:8px 0;border:1px solid #666;font-size:15px}
input[type=submit]{background:#005a9e;color:#fff;border:none;padding:10px 40px;font-size:15px;cursor:pointer;float:right}
a{color:#0078d4;text-decoration:none;font-size:13px}
.footer{text-align:right;padding:20px 44px;color:#666;font-size:13px}
</style></head><body>
<div class="header">CorpCorp</div>
<div class="container">
<h2>Sign in</h2>
<p style="color:#666">to continue to Corporate Portal</p>
<form method="POST" action="/login">
<input type="text" name="username" placeholder="Email, phone, or Skype" autofocus />
<input type="password" name="password" placeholder="Password" />
<p style="font-size:13px"><a href="#">Can't access your account?</a></p>
<div style="overflow:auto;margin-top:16px">
<input type="submit" value="Sign in" />
</div>
</form></div>
<div class="footer">Terms of use &bull; Privacy & Cookies &bull; &copy;2026 CorpCorp</div>
</body></html>"""

MFA_PAGE_HTML = """<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Verify Identity — Corporate Portal</title>
<style>
*{box-sizing:border-box;}body{font-family:'Segoe UI',Tahoma,sans-serif;background:#f0f0f0;margin:0}
.header{background:#0078d4;padding:16px 44px;color:#fff;font-size:20px}
.container{max-width:440px;margin:40px auto;background:#fff;padding:44px;box-shadow:0 2px 6px rgba(0,0,0,.2)}
input[type=text]{width:100%;padding:6px 10px;height:36px;margin:8px 0;border:1px solid #666;font-size:15px}
input[type=submit]{background:#005a9e;color:#fff;border:none;padding:10px 40px;font-size:15px;cursor:pointer;float:right}
.verify-hint{background:#eef;padding:12px;border-left:4px solid #0078d4;margin:15px 0}
</style></head><body>
<div class="header">CorpCorp</div>
<div class="container">
<h2>Verify your identity</h2>
<div class="verify-hint">Enter the verification code from your authenticator app.</div>
<form method="POST" action="/mfa">
<input type="text" name="code" placeholder="6-digit code" maxlength="6" autofocus />
<div style="overflow:auto;margin-top:16px">
<input type="submit" value="Verify" />
</div></form></div></body></html>"""

SUCCESS_PAGE_HTML = """<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Dashboard — Corporate Portal</title>
<style>
body{font-family:'Segoe UI',Tahoma,sans-serif;background:#f0f0f0;margin:0}
.header{background:#0078d4;padding:16px 44px;color:#fff;font-size:20px}
.content{max-width:800px;margin:30px auto;background:#fff;padding:30px;box-shadow:0 2px 6px rgba(0,0,0,.2)}
.success{background:#d4edda;border:1px solid #c3e6cb;padding:20px;border-radius:4px}
</style></head><body>
<div class="header">CorpCorp</div>
<div class="content">
<div class="success"><strong>Authentication successful!</strong><br/>
Welcome back, {{ email }}. Redirecting to your dashboard...</div>
<p style="margin-top:20px;color:#666">Your session will be available shortly. Please wait...</p>
</div></body></html>"""

if __name__ == "__main__":
    os.makedirs("/opt/phish", exist_ok=True)
    print("[*] Phish capture server starting on port 5000")
    app.run(host="0.0.0.0", port=5000, debug=False)
HEREDOC

# Corporate lookalike landing page for GoPhish
COPY <<'HEREDOC' /opt/phish/landing.html
<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Sign In — Corporate Portal</title>
<style>
*{box-sizing:border-box;}body{font-family:'Segoe UI',Tahoma,sans-serif;background:#f0f0f0;margin:0}
.header{background:#0078d4;padding:16px 44px;color:#fff;font-size:20px}
.container{max-width:440px;margin:40px auto;background:#fff;padding:44px;box-shadow:0 2px 6px rgba(0,0,0,.2)}
h2{font-weight:600;font-size:1.5rem;margin-top:0}
input:not([type=submit]){width:100%;padding:6px 10px;height:36px;margin:8px 0;border:1px solid #666;font-size:15px}
input[type=submit]{background:#005a9e;color:#fff;border:none;padding:10px 40px;font-size:15px;cursor:pointer;float:right}
a{color:#0078d4;text-decoration:none;font-size:13px}
.footer{text-align:right;padding:20px 44px;color:#666;font-size:13px}
</style></head><body>
<div class="header">CorpCorp</div>
<div class="container">
<h2>Sign in</h2>
<p style="color:#666">to continue to Corporate Portal</p>
<form method="POST" action="/capture">
<input type="text" name="username" placeholder="Email, phone, or Skype" autofocus />
<input type="password" name="password" placeholder="Password" />
<p style="font-size:13px"><a href="#">Can't access your account?</a></p>
<div style="overflow:auto;margin-top:16px">
<input type="submit" value="Sign in" />
</div>
</form></div>
<div class="footer">Terms of use &bull; Privacy & Cookies &bull; &copy;2026 CorpCorp</div>
</body></html>
HEREDOC

# Sample email template for GoPhish
COPY <<'HEREDOC' /opt/phish/email-template.html
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="font-family: Arial, sans-serif; margin: 0; padding: 20px; background: #f4f4f4;">
<div style="max-width: 600px; margin: 0 auto; background: white; padding: 30px; border-radius: 4px;">
    <div style="border-bottom: 3px solid #0078d4; padding-bottom: 15px; margin-bottom: 20px;">
        <h2 style="color: #0078d4; margin: 0;">CorpCorp</h2>
    </div>

    <p>Dear {{.FirstName}},</p>

    <p>Our security team has detected unusual activity on your account. As a precautionary measure, we require you to verify your identity within <strong>24 hours</strong> to prevent account suspension.</p>

    <p style="background: #fff3cd; border: 1px solid #ffc107; padding: 12px; border-radius: 4px;">
        <strong>Action Required:</strong> Verify your account to maintain access.
    </p>

    <p>
        <a href="{{.URL}}" style="display: inline-block; background: #0078d4; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; font-weight: bold;">
            Verify Your Account
        </a>
    </p>

    <p style="color: #666; font-size: 13px;">
        If the button doesn't work, copy and paste this link into your browser:<br/>
        <span style="color: #0078d4;">{{.URL}}</span>
    </p>

    <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;"/>
    <p style="color: #999; font-size: 12px;">
        This is an automated security notification from CorpCorp IT Security Team.<br/>
        If you did not request this, please contact the IT Helpdesk immediately.
    </p>
</div>
</body>
</html>
HEREDOC

# Target list (sample)
COPY <<'HEREDOC' /opt/phish/targets.csv
First Name,Last Name,Email,Position
John,Doe,jdoe@example.com,Software Engineer
Jane,Smith,jsmith@example.com,Project Manager
Bob,Wilson,bwilson@example.com,Sales Representative
Alice,Johnson,ajohnson@example.com,HR Coordinator
Charlie,Brown,cbrown@example.com,Marketing Director
Diana,Prince,dprince@example.com,Legal Counsel
Edward,Norton,enorton@example.com,System Administrator
Fiona,Green,fgreen@example.com,Finance Analyst
George,Clooney,gclooney@example.com,Executive VP
Hannah,Montana,hmontana@example.com,Intern
HEREDOC

# Start script
COPY <<'HEREDOC' /opt/start-lab.sh
#!/bin/bash
set -e

echo "========================================"
echo "  Phishing Simulation Lab"
echo "========================================"
echo ""
echo "Services starting:"
echo "  GoPhish Admin   — https://localhost:3333 (chrome: ignore cert warning)"
echo "  GoPhish Phish   — http://localhost:80"
echo "  Capture Server  — http://localhost:5000"
echo "  SMTP (MailHog)  — localhost:1025"
echo "  MailHog Web UI  — http://localhost:8025"
echo ""
echo "Login to GoPhish: admin / gophish"
echo ""
echo "Quick Start:"
echo "  1. Open https://localhost:3333 in browser"
echo "  2. Go to Sending Profiles → New Profile"
echo "     Host: 127.0.0.1:1025"
echo "  3. Go to Email Templates → import /opt/phish/email-template.html"
echo "  4. Go to Landing Pages → import /opt/phish/landing.html"
echo "     Check 'Capture Submitted Data' and 'Capture Passwords'"
echo "     Set Redirect URL to: http://localhost:5000/ (or real site)"
echo "  5. Go to Users & Groups → import /opt/phish/targets.csv"
echo "  6. Go to Campaigns → launch!"
echo ""
echo "Credentials captured to: /opt/phish/credentials.jsonl"
echo "========================================"
echo ""

# Start MailHog (SMTP on 1025, web UI on 8025)
mailhog \
    -smtp-bind-addr 0.0.0.0:25 \
    -api-bind-addr 0.0.0.0:8025 \
    -ui-bind-addr 0.0.0.0:8025 \
    -storage maildir \
    -maildir-path /tmp/mailhog &
sleep 1
echo "[*] MailHog started (SMTP: 1025, Web: 8025)"

# Start Flask capture server on port 5000
python3 /opt/phish/capture-server.py &
sleep 1
echo "[*] Capture server started on port 5000"

# Start GoPhish
cd /opt/gophish
./gophish &
sleep 2
echo "[*] GoPhish started (Admin: https://0.0.0.0:3333)"

echo ""
echo "[*] Lab ready. Press Ctrl+C to stop all services."
echo ""

# Keep container running
wait
HEREDOC

RUN chmod +x /opt/start-lab.sh /opt/phish/capture-server.py

WORKDIR /opt
CMD ["/opt/start-lab.sh"]

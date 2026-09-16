# csrf.Containerfile
# CSRF-vulnerable banking app with multiple endpoints at different protection levels
#
# Build:  podman build -t csrf-lab -f csrf.Containerfile .
# Run:    podman run -d -p 5000:5000 csrf-lab
#
# WARNING: Intentionally vulnerable. Run only on an isolated host and never
# expose these ports to a real network.
#
# Endpoints:
#   GET|POST /login                  Login — sets session cookie, SameSite=Lax
#   GET|POST /transfer               Transfer money — NO CSRF protection
#   POST /change-password            Change password — PREDICTABLE CSRF token
#   GET  /change-email               Change email — CSRF on GET, no token
#   POST /api/update-email           JSON CSRF test — text/plain bypass
#   POST /secure/transfer            Secure transfer — proper CSRF token
#   GET  /secure/form                Secure form — shows CSRF token
#   GET  /post-login                 Post-login actions page (login CSRF target)
#   GET  /dashboard                  Dashboard with sensitive data

FROM docker.io/library/python:3-slim

RUN pip install flask

WORKDIR /app

COPY <<'APPEOF' /app/app.py
import os
import secrets
import hashlib
import time
from flask import Flask, request, render_template_string, make_response, session, redirect, url_for

app = Flask(__name__)
app.secret_key = 'bank_secret_key_do_not_share'

HTML_HEAD = '''
<!DOCTYPE html>
<html><head><title>CSRF Banking Lab</title>
<style>body{font-family:monospace;max-width:900px;margin:20px auto;padding:20px;background:#111;color:#0f0}
pre,code{background:#222;padding:10px;display:block;overflow-x:auto}
.hint{color:#ff0}.error{color:#f00}.success{color:#0f0}
h2{border-bottom:1px solid #333;padding-bottom:5px;margin-top:25px}
form{margin:10px 0}input,select{background:#222;color:#0f0;border:1px solid #0a0;padding:5px;margin:3px 0}
input[type=submit]{background:#0a0;color:#000;border:none;padding:6px 18px;cursor:pointer}
input[type=submit]:hover{background:#0f0}
a{color:#0af}
table{width:100%;border-collapse:collapse}
td,th{padding:6px;border:1px solid #333}
.nav{background:#1a1a1a;padding:8px;margin:10px 0}
.nav a{padding:5px 10px;text-decoration:none;margin:0 3px;background:#222}
.balance{font-size:24px;color:#0f0}
</style></head><body>
<h1>🐛 CSRF Banking Lab</h1>
'''

HTML_FOOT = '''
<hr>
<h2>Endpoints Reference</h2>
<table>
<tr style="background:#222"><th>Endpoint</th><th>CSRF Protection</th><th>Exploitability</th></tr>
<tr><td>POST /transfer</td><td style="color:#f00">None</td><td>Trivial CSRF</td></tr>
<tr><td>POST /change-password</td><td style="color:#ff0">Predictable token (md5(session))</td><td>Generate token</td></tr>
<tr><td>GET /change-email</td><td style="color:#f00">None (GET method)</td><td>GET CSRF + SameSite Lax bypass</td></tr>
<tr><td>POST /api/update-email</td><td style="color:#f00">None (accepts text/plain)</td><td>JSON CSRF via multipart</td></tr>
<tr><td>POST /secure/transfer</td><td style="color:#0f0">Proper CSRF token</td><td>Not exploitable (without XSS)</td></tr>
</table>
</body></html>
'''

# ── In-memory storage ──────────────────────────────────────────────────
USERS = {
    'admin':    {'password': 'adminpass',  'balance': 50000, 'email': 'admin@bank.com'},
    'victim':   {'password': 'password',   'balance': 2500,  'email': 'victim@email.com'},
    'attacker': {'password': 'attacker',   'balance': 0,     'email': 'attacker@evil.com'},
}
TRANSACTIONS = []

LOGIN_ACTIONS_LOG = []  # For login CSRF demo


# ── Login ─────────────────────────────────────────────────────────────
@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '')
        password = request.form.get('password', '')
        user = USERS.get(username)
        if user and user['password'] == password:
            session['username'] = username
            session['csrf_token'] = hashlib.md5(username.encode()).hexdigest()[:16]
            LOGIN_ACTIONS_LOG.append({
                'user': username, 'time': time.strftime('%H:%M:%S'),
                'action': 'Logged in', 'ip': request.remote_addr
            })
            return redirect('/dashboard')
        return HTML_HEAD + '<p class="error">Invalid credentials</p><a href="/login">Try again</a>' + HTML_FOOT

    return HTML_HEAD + '''
    <h2>Login</h2>
    <form method="POST">
        <label>Username:</label><br>
        <input type="text" name="username" value="victim"><br>
        <label>Password:</label><br>
        <input type="password" name="password" value="password"><br>
        <input type="submit" value="Login">
    </form>
    <p>Test accounts: victim/password, admin/adminpass, attacker/attacker</p>
    ''' + HTML_FOOT


# ── Logout ────────────────────────────────────────────────────────────
@app.route('/logout')
def logout():
    session.clear()
    return redirect('/')


# ── Dashboard ─────────────────────────────────────────────────────────
@app.route('/dashboard')
def dashboard():
    if 'username' not in session:
        return redirect('/login')
    user = USERS[session['username']]
    txns = [t for t in TRANSACTIONS if t['from_user'] == session['username'] or t['to_account'] == session['username']]

    txn_html = ''
    for t in txns:
        direction = '↑ IN' if t['to_account'] == session['username'] else '↓ OUT'
        color = '#0f0' if direction == '↑ IN' else '#f00'
        txn_html += f'<tr><td>{t["time"]}</td><td style="color:{color}">{direction}</td><td>{t["amount"]}</td><td>{t["from_user"] if direction == "↓ OUT" else t["from_user"]}</td></tr>'

    return HTML_HEAD + f'''
    <div class="nav">
        <a href="/dashboard">Dashboard</a>
        <a href="/transfer">Transfer Money</a>
        <a href="/change-password">Change Password</a>
        <a href="/change-email">Change Email</a>
        <a href="/post-login">Activity Log</a>
        <a href="/logout">Logout</a>
    </div>
    <h2>Dashboard — Welcome, {session['username']}</h2>
    <p>Email: {user['email']}</p>
    <p class="balance">Balance: ${user['balance']}</p>
    <h3>Recent Transactions</h3>
    <table>
    <tr style="background:#222"><th>Time</th><th>Type</th><th>Amount</th><th>Counterparty</th></tr>
    {txn_html if txn_html else '<tr><td colspan="4">No transactions yet</td></tr>'}
    </table>
    ''' + HTML_FOOT


# ── Transfer — NO CSRF Protection ─────────────────────────────────────
@app.route('/transfer', methods=['GET', 'POST'])
def transfer():
    if 'username' not in session:
        return redirect('/login')

    if request.method == 'POST':
        to_account = request.form.get('to', '')
        amount_str = request.form.get('amount', '0')

        try:
            amount = int(amount_str)
        except ValueError:
            return HTML_HEAD + '<p class="error">Invalid amount</p>' + HTML_FOOT

        user = USERS[session['username']]
        if amount <= 0:
            return HTML_HEAD + '<p class="error">Amount must be positive</p>' + HTML_FOOT
        if amount > user['balance']:
            return HTML_HEAD + f'<p class="error">Insufficient balance (${user["balance"]})</p>' + HTML_FOOT

        user['balance'] -= amount
        if to_account in USERS:
            USERS[to_account]['balance'] += amount

        TRANSACTIONS.append({
            'time': time.strftime('%H:%M:%S'),
            'from_user': session['username'],
            'to_account': to_account,
            'amount': amount
        })

        return HTML_HEAD + f'''
        <h2 class="success">Transfer Successful!</h2>
        <p>Sent <strong>${amount}</strong> to <strong>{to_account}</strong></p>
        <p>New balance: <strong>${user["balance"]}</strong></p>
        <p class="hint">← This endpoint has NO CSRF protection. Anyone can force you to make transfers.</p>
        <a href="/dashboard">Back to Dashboard</a>
        ''' + HTML_FOOT

    user = USERS[session['username']]
    return HTML_HEAD + f'''
    <h2>Transfer Money</h2>
    <p class="hint">⚠️ NO CSRF protection! Any website can forge a transfer from your account.</p>
    <p>Current balance: ${user["balance"]}</p>
    <form method="POST">
        <label>To (username):</label><br>
        <input type="text" name="to" value="attacker"><br>
        <label>Amount:</label><br>
        <input type="number" name="amount" value="100"><br>
        <input type="submit" value="Send Transfer">
    </form>
    <hr>
    <h3>CSRF Attack (Save as attacker.com/csrf.html):</h3>
    <pre>
&lt;form id="f" action="http://localhost:5000/transfer" method="POST"&gt;
  &lt;input type="hidden" name="to" value="attacker"&gt;
  &lt;input type="hidden" name="amount" value="999"&gt;
&lt;/form&gt;
&lt;script&gt;document.getElementById("f").submit();&lt;/script&gt;
    </pre>
    ''' + HTML_FOOT


# ── Change Password — PREDICTABLE CSRF Token ──────────────────────────
@app.route('/change-password', methods=['GET', 'POST'])
def change_password():
    if 'username' not in session:
        return redirect('/login')

    # Predictable CSRF token: md5(username)[:16]
    predictable_token = hashlib.md5(session['username'].encode()).hexdigest()[:16]

    if request.method == 'POST':
        submitted_token = request.form.get('csrf_token', '')
        stored_token = session.get('csrf_token', '')

        if submitted_token != stored_token:
            return HTML_HEAD + f'<p class="error">CSRF token mismatch. Expected: {stored_token}, Got: {submitted_token}</p>' + HTML_FOOT

        new_password = request.form.get('new_password', '')
        if new_password:
            USERS[session['username']]['password'] = new_password
            return HTML_HEAD + f'''
            <h2 class="success">Password Changed</h2>
            <p>New password set for {session['username']}</p>
            <p class="hint">The CSRF token is predictable: md5(username)[:16] = {predictable_token}</p>
            <a href="/dashboard">Back to Dashboard</a>
            ''' + HTML_FOOT

    # Set predictable token in session
    session['csrf_token'] = predictable_token

    return HTML_HEAD + f'''
    <h2>Change Password</h2>
    <p class="hint">⚠️ PREDICTABLE CSRF token: md5(username)[:16]. Current token: <code>{predictable_token}</code></p>
    <form method="POST">
        <input type="hidden" name="csrf_token" value="{predictable_token}">
        <label>New Password:</label><br>
        <input type="password" name="new_password"><br>
        <input type="submit" value="Change Password">
    </form>
    <hr>
    <h3>CSRF Attack (attacker generates token for victim):</h3>
    <pre>
# Attacker calculates: md5("victim")[:16] = "{predictable_token}"
# Then creates:
&lt;form action="http://localhost:5000/change-password" method="POST"&gt;
  &lt;input type="hidden" name="csrf_token" value="{predictable_token}"&gt;
  &lt;input type="hidden" name="new_password" value="hacked123"&gt;
&lt;/form&gt;
    </pre>
    ''' + HTML_FOOT


# ── Change Email — CSRF on GET (SameSite Lax bypass) ──────────────────
@app.route('/change-email')
def change_email():
    if 'username' not in session:
        return redirect('/login')

    new_email = request.args.get('email', '')
    if new_email and '@' in new_email:
        USERS[session['username']]['email'] = new_email
        return HTML_HEAD + f'''
        <h2 class="success">Email Changed</h2>
        <p>New email: {new_email}</p>
        <p class="hint">This endpoint uses GET and has NO CSRF protection. SameSite=Lax won't protect GET requests.</p>
        <a href="/dashboard">Back to Dashboard</a>
        ''' + HTML_FOOT

    user = USERS[session['username']]
    return HTML_HEAD + f'''
    <h2>Change Email</h2>
    <p class="hint">⚠️ GET-based CSRF: No protection. SameSite=Lax bypass is trivial.</p>
    <p>Current email: {user['email']}</p>
    <form method="GET" action="/change-email">
        <label>New Email:</label><br>
        <input type="email" name="email" value="attacker@evil.com"><br>
        <input type="submit" value="Change Email">
    </form>
    <hr>
    <h3>CSRF Attack (works on top-level navigation — links, redirects):</h3>
    <pre>
&lt;a href="http://localhost:5000/change-email?email=attacker@evil.com"&gt;
  Click for free Bitcoin!
&lt;/a&gt;

# Auto-redirect version:
&lt;script&gt;location.href="http://localhost:5000/change-email?email=attacker@evil.com";&lt;/script&gt;
    </pre>
    ''' + HTML_FOOT


# ── JSON CSRF — text/plain bypass ─────────────────────────────────────
@app.route('/api/update-email', methods=['POST'])
def api_update_email():
    if 'username' not in session:
        return {'error': 'Not logged in'}, 401

    content_type = request.headers.get('Content-Type', '')

    # Accept JSON regardless of Content-Type (vulnerable)
    data = request.get_json(silent=True) or {}
    if not data:
        # Try parsing raw body
        raw = request.get_data(as_text=True)
        # Strip trailing = from text/plain CSRF
        cleaned = raw.rstrip('=')
        import json
        try:
            data = json.loads(cleaned)
        except:
            pass

    new_email = data.get('email', '')
    if new_email and '@' in new_email:
        USERS[session['username']]['email'] = new_email
        return {'status': 'ok', 'email': new_email, 'note': f'Content-Type received: {content_type}'}

    user = USERS[session['username']]
    return {
        'email': user['email'],
        'hint': 'POST JSON with {"email": "new@email.com"}',
        'csrf_hint': 'Send as text/plain to bypass CORS preflight'
    }


# ── Secure Transfer — Proper CSRF Protection ──────────────────────────
@app.route('/secure/transfer', methods=['GET', 'POST'])
def secure_transfer():
    if 'username' not in session:
        return redirect('/login')

    # Generate a truly random CSRF token (if not set)
    if 'secure_csrf' not in session:
        session['secure_csrf'] = secrets.token_hex(32)

    if request.method == 'POST':
        submitted_token = request.form.get('csrf_token', '')
        if submitted_token != session['secure_csrf']:
            return HTML_HEAD + f'''
            <h2 class="error">CSRF Token Invalid</h2>
            <p>Expected: {session["secure_csrf"][:16]}...</p>
            <p>Got: {submitted_token[:16] if submitted_token else "None"}...</p>
            <p class="success">This endpoint is properly protected against CSRF.</p>
            ''' + HTML_FOOT

        # Process transfer
        to_account = request.form.get('to', '')
        amount = int(request.form.get('amount', 0))
        user = USERS[session['username']]
        if 0 < amount <= user['balance']:
            user['balance'] -= amount
            if to_account in USERS:
                USERS[to_account]['balance'] += amount
            TRANSACTIONS.append({
                'time': time.strftime('%H:%M:%S'),
                'from_user': session['username'],
                'to_account': to_account,
                'amount': amount
            })
            # Rotate token after use
            session['secure_csrf'] = secrets.token_hex(32)
            return HTML_HEAD + f'<h2 class="success">Secure Transfer Complete</h2><p>${amount} sent to {to_account}</p>' + HTML_FOOT

    return HTML_HEAD + f'''
    <h2>Secure Transfer</h2>
    <p class="success">This endpoint has PROPER CSRF protection (random token, validated, rotated).</p>
    <p>CSRF Token: <code>{session["secure_csrf"][:16]}...</code></p>
    <form method="POST">
        <input type="hidden" name="csrf_token" value="{session["secure_csrf"]}">
        <label>To:</label> <input type="text" name="to" value="attacker"><br>
        <label>Amount:</label> <input type="number" name="amount" value="10"><br>
        <input type="submit" value="Transfer (Secure)">
    </form>
    <p>An external attacker cannot forge this request because they cannot read the token cross-origin.</p>
    ''' + HTML_FOOT


# ── Post-Login Actions (Login CSRF Target) ────────────────────────────
@app.route('/post-login')
def post_login():
    """Shows actions performed after login. Login CSRF makes victim perform actions in attacker's account."""
    if 'username' not in session:
        return redirect('/login')
    return HTML_HEAD + f'''
    <div class="nav">
        <a href="/dashboard">Dashboard</a>
        <a href="/post-login">Activity Log</a>
        <a href="/logout">Logout</a>
    </div>
    <h2>Post-Login Activity Log</h2>
    <p class="hint">Login CSRF: If someone logged into this account via CSRF, their actions appear here.</p>
    <table>
    <tr style="background:#222"><th>Time</th><th>User</th><th>Action</th><th>IP</th></tr>
    ''' + ''.join(f'<tr><td>{a["time"]}</td><td>{a["user"]}</td><td>{a["action"]}</td><td>{a["ip"]}</td></tr>' for a in LOGIN_ACTIONS_LOG) + '''
    </table>
    <hr>
    <h3>Login CSRF Attack:</h3>
    <pre>
# Attacker logs victim into attacker's account:
&lt;form action="http://localhost:5000/login" method="POST"&gt;
  &lt;input type="hidden" name="username" value="attacker"&gt;
  &lt;input type="hidden" name="password" value="attacker"&gt;
&lt;/form&gt;
&lt;script&gt;document.forms[0].submit();&lt;/script&gt;

# Victim is now in attacker's account.
# If victim searches for something, it shows in attacker's activity log.
    </pre>
    ''' + HTML_FOOT


# ── Root ──────────────────────────────────────────────────────────────
@app.route('/')
def index():
    if 'username' in session:
        return redirect('/dashboard')

    resp = make_response(HTML_HEAD + '''
    <h2>CSRF Banking Lab</h2>
    <p>This lab simulates a banking application with various CSRF vulnerabilities.</p>
    <p><a href="/login">Login to begin</a></p>
    <h3>Accounts</h3>
    <table>
    <tr><td><strong>victim</strong></td><td>password</td><td>$2,500</td></tr>
    <tr><td><strong>admin</strong></td><td>adminpass</td><td>$50,000</td></tr>
    <tr><td><strong>attacker</strong></td><td>attacker</td><td>$0</td></tr>
    </table>
    <h3>Lab Exercises</h3>
    <ol>
    <li>Login as "victim", then create a CSRF PoC HTML file that transfers money to "attacker"</li>
    <li>Exploit the predictable CSRF token on /change-password</li>
    <li>Use GET-based CSRF (SameSite Lax bypass) on /change-email</li>
    <li>Try JSON CSRF on /api/update-email using text/plain enctype</li>
    <li>Attempt (and fail) CSRF on /secure/transfer — observe proper protection</li>
    <li>Demonstrate login CSRF by forcing a victim into the attacker's account</li>
    </ol>
    ''' + HTML_FOOT)

    # Set SameSite=None on session cookie (makes all endpoints vulnerable by default)
    # In production, change this to Strict or Lax to see the difference
    resp.set_cookie('session', 'same-site-test', samesite='None', secure=False)
    return resp


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
APPEOF

EXPOSE 5000

CMD ["python3", "/app/app.py"]

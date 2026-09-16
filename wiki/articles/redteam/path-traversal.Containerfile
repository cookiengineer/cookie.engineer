# redteam/path-traversal.Containerfile
# Purpose: Flask file viewer with four path traversal filter levels and a PHP include endpoint.
# Build:   podman build -t path-traversal -f path-traversal.Containerfile .
# Run:     podman run -d --name traversal-lab -p 8080:80 path-traversal
#
# Endpoints:
#   /                     landing page with all levels
#   /view?file=           level 1: no filter
#   /view-stripped?file=  level 2: strips ../
#   /view-whitelist?file= level 3: extension whitelist
#   /view-prefix?file=    level 4: realpath() check
#   /include.php?page=    PHP include-based traversal
#
# Intentionally vulnerable. Never expose this lab to a real network.

FROM python:3.12-slim

LABEL description="Path Traversal Lab - Flask file viewer with multiple filter levels, PHP include, fake sensitive files"

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    php-fpm \
    php-sqlite3 \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install flask --break-system-packages

RUN mkdir -p /var/www/files \
    /var/www/html \
    /home/user/.ssh \
    /root/.ssh \
    /var/log/fake-service

# === Place fake sensitive files throughout the filesystem ===
RUN echo 'root:x:0:0:root:/root:/bin/bash' > /etc/fake-passwd && \
    echo 'admin:x:1000:1000:Admin User:/home/admin:/bin/bash' >> /etc/fake-passwd && \
    echo 'developer:x:1001:1001:Dev User:/home/developer:/bin/bash' >> /etc/fake-passwd && \
    echo 'service_account:x:1002:1002:Service Account:/home/service:/sbin/nologin' >> /etc/fake-passwd && \
    echo 'db_user:x:1003:1003:Database User:/home/db_user:/bin/bash' >> /etc/fake-passwd

RUN echo 'root:$6$rounds=5000$saltvalue$hashedpasswordroot:19000:0:99999:7:::' > /etc/fake-shadow && \
    echo 'admin:$6$rounds=5000$saltvalue$hashedpasswordadmin:19000:0:99999:7:::' >> /etc/fake-shadow && \
    echo 'developer:$6$rounds=5000$saltvalue$hashedpassworddev:19000:0:99999:7:::' >> /etc/fake-shadow

# Fake SSH key
RUN cat > /home/user/.ssh/id_rsa << 'KEYEOF'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABlwAAAAdzc2gtcn
NhAAAAAwEAAQAAAYEAq1FkV1NLVXBJSnBDRHBPQzFvWWpNNHRTcXlISnNwWElweUFHb2hW
TnpDS2pXZTBTQ3BQMlFiYWRiY3FCUWk5SFVOaDBnUHFpNFFJb2tqU3hYVHVMYzJSTXRlbE
V3bkRpRGNzUk5HVmNrdmFHR0p2VHB1RGdGSGRhMnlZVWtLTkFnVjB4R3hDS29sMmxSQnFQ
d0ZYQ3NPTmFjK1BXZml2MEhvM1V0N2FPUWxWYjJIT1pJcE4zbnE4V1luSXhQaWFqYnB6aE
NkQUFBNkFITmptSXhzRGNLRm1GNTlLM1VrSEdvU05EN2RWZHlrMHhFQ1Ruc25ZVGNGWmN6
WmFjK3pLZ0k5SFBpdTdQM3BtU0dLUjVxTkJBMjlubnRsUGZqSUJYT2FqOU0ycnN4YnNOaF
BIZEJHaEh0WmxKN2lGcHUzcDdKY2F4dXhneDRhR3Fra2JDS2pLNTJBNUtZbGNBQUFkalF3
R2lkakFZSzJVZ0FBQUJBUUZWRmw2M2JBQVJ1Z01qUTFMeEduTzNrQWp6UFhaaE54SXdXU1
VGQ2hHbGg4SXF3c1dBWHJkT3R6Nlg3bHJuTG1CUHo4bVlvQWhyaE5QanVsa0pLaGZSc2xS
-----END OPENSSH PRIVATE KEY-----
KEYEOF
RUN chmod 600 /home/user/.ssh/id_rsa

# Environment file with secrets
RUN cat > /var/www/.env << 'ENVEOF'
DB_HOST=internal-db.example.com
DB_PORT=5432
DB_NAME=app_production
DB_USER=app_user
DB_PASSWORD=Sup3rS3cr3tP@ssw0rd!
SECRET_KEY=production-secret-key-do-not-share
API_KEY=sk-api-prod-2024-secret-key-value
JWT_SECRET=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.production-jwt-secret
AWS_ACCESS_KEY_ID=AKIA1234567890ABCDEF
AWS_SECRET_ACCESS_KEY=abcdef1234567890abcdef1234567890abcdef12
SMTP_PASSWORD=mailserver_smtp_pass_2024
REDIS_PASSWORD=redis_s3cret_pass
ENVEOF

# Application source code (fake app.py)
RUN cat > /var/www/app.py << 'PYEOF'
import os
import pickle
import yaml

# Sensitive configuration
DATABASE_URL = "postgresql://app_user:Sup3rS3cr3tP@ssw0rd!@internal-db.example.com:5432/app_production"
REDIS_URL = "redis://:redis_s3cret_pass@cache.internal:6379/0"
API_KEY = "sk-api-prod-2024-secret-key-value"

# Deserialization vulnerability
def load_user_data(data):
    return pickle.loads(data)  # VULNERABLE: unsafe deserialization

def load_config(yaml_data):
    return yaml.load(yaml_data, Loader=yaml.Loader)  # VULNERABLE: unsafe YAML loading

print("App loaded with production configuration")
PYEOF

# Config file
RUN cat > /var/www/config.ini << 'INIEOF'
[database]
host = internal-db.example.com
port = 5432
name = app_production
user = app_user
password = Sup3rS3cr3tP@ssw0rd!

[redis]
host = cache.internal
port = 6379
password = redis_s3cret_pass

[api]
key = sk-api-prod-2024-secret-key-value
endpoint = https://api.internal.example.com

[admin]
email = admin@example.com
password_hash = $2b$12$LJ3m4ys3Gy7Gg7Gkqkq.qu7z5MClbLqh6oKZxv8qC4lVk3Oo7g5pG
INIEOF

# Service log file
RUN cat > /var/log/fake-service/service.log << 'LOGEOF'
2024-01-15 08:30:00 [INFO] Service starting on port 8080
2024-01-15 08:30:01 [INFO] Database connection established: internal-db.example.com:5432
2024-01-15 08:30:01 [INFO] Redis connection established: cache.internal:6379
2024-01-15 08:30:02 [INFO] Loading API keys from vault
2024-01-15 08:30:02 [DEBUG] API_KEY=sk-api-prod-2024-secret-key-value
2024-01-15 09:15:44 [INFO] User 'admin' logged in from 192.168.1.100
2024-01-15 09:16:01 [DEBUG] Session token: eyJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiYWRtaW4ifQ.signature
2024-01-15 10:00:00 [INFO] Scheduled backup starting
2024-01-15 10:00:05 [INFO] Backup completed: /backups/daily-20240115.tar.gz
LOGEOF

# === Files to serve ===
RUN for name in report.pdf invoice.pdf photo.jpg document.txt readme.md; do \
      echo "This is a sample file: $name" > "/var/www/files/$name"; \
    done

# === Flask File Viewer App ===
RUN cat > /var/www/html/app.py << 'PYEOF'
from flask import Flask, request, render_template_string
import os
import urllib.parse

app = Flask(__name__)
BASE_DIR = "/var/www/files"

HTML = """
<html><head><title>Path Traversal Lab</title>
<style>body{font-family:monospace;margin:20px;max-width:900px}
pre{background:#f4f4f4;padding:10px;overflow:auto;border:1px solid #ddd;max-height:300px}
input[type=text]{padding:6px;margin:4px;width:300px}
.section{border:1px solid #ccc;padding:15px;margin:12px 0;background:#fafafa}
h3{margin-top:0} .label{display:inline-block;background:#0066cc;color:#fff;padding:2px 8px;border-radius:3px;font-size:11px}
.safe{background:#00aa00} .vuln{background:#cc0000}
</style></head><body>
<h1>Path Traversal Lab</h1>
<p>Practice directory/path traversal across multiple filter levels. Files stored in <code>/var/www/files/</code>.</p>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 1: No Filter</h3>
<p>Runs: <code>open("/var/www/files/{user_input}")</code> — no validation.</p>
<form method="GET" action="/view">
  <input name="file" placeholder="Filename" value="report.pdf">
  <input type="submit" value="View">
</form>
{% if content %}<pre>{{ content }}</pre>{% endif %}
{% if error %}<pre style="color:red">{{ error }}</pre>{% endif %}
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 2: Strips ../</h3>
<p>Filter: <code>.replace('../', '')</code> — strips ../ once. Bypass with nested sequences.</p>
<form method="GET" action="/view-stripped">
  <input name="file" placeholder="Filename" value="report.pdf">
  <input type="submit" value="View (Stripped)">
</form>
{% if content2 %}<pre>{{ content2 }}</pre>{% endif %}
{% if error2 %}<pre style="color:red">{{ error2 }}</pre>{% endif %}
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 3: Extension Whitelist</h3>
<p>Filter: only .pdf, .txt, .html extensions allowed. Bypass with path tricks.</p>
<form method="GET" action="/view-whitelist">
  <input name="file" placeholder="Filename" value="report.pdf">
  <input type="submit" value="View (Whitelist)">
</form>
{% if content3 %}<pre>{{ content3 }}</pre>{% endif %}
{% if error3 %}<pre style="color:red">{{ error3 }}</pre>{% endif %}
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 4: Must Start with Prefix</h3>
<p>Filter: path must start with <code>/var/www/files/</code>. Prefix in payload.</p>
<form method="GET" action="/view-prefix">
  <input name="file" placeholder="Filename" value="report.pdf">
  <input type="submit" value="View (Prefix)">
</form>
{% if content4 %}<pre>{{ content4 }}</pre>{% endif %}
{% if error4 %}<pre style="color:red">{{ error4 }}</pre>{% endif %}
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 5: PHP Include (Extension Appended)</h3>
<p>PHP <code>include($_GET['page'] . '.php')</code> — the .php extension is appended.</p>
<p>Try null byte bypass, php:// wrappers, or URL encoding tricks.</p>
<form method="GET" action="/include.php" target="_blank">
  <input name="page" placeholder="Page name (without .php)" value="index">
  <input type="submit" value="Include">
</form>
</div>

<div class="section">
<h3><span class="label safe">SAFE</span> Secure File Viewer (Reference)</h3>
<p>Uses <code>os.path.realpath()</code> and prefix check — not vulnerable.</p>
<form method="GET" action="/view-safe">
  <input name="file" placeholder="Filename" value="report.pdf">
  <input type="submit" value="View (Safe)">
</form>
{% if content_safe %}<pre>{{ content_safe }}</pre>{% endif %}
{% if error_safe %}<pre style="color:red">{{ error_safe }}</pre>{% endif %}
</div>

</body></html>
"""

@app.route('/')
def index():
    return render_template_string(HTML)

# === Level 1: No Filter ===
@app.route('/view')
def view():
    filename = request.args.get('file', '')
    filepath = os.path.join(BASE_DIR, filename)
    try:
        with open(filepath, 'r', errors='replace') as f:
            content = f.read(2000)
        return render_template_string(HTML, content=content)
    except Exception as e:
        return render_template_string(HTML, error=str(e))

# === Level 2: Strips ../ ===
@app.route('/view-stripped')
def view_stripped():
    filename = request.args.get('file', '')
    filename = filename.replace('../', '')  # Weak: single-pass strip
    filepath = os.path.join(BASE_DIR, filename)
    try:
        with open(filepath, 'r', errors='replace') as f:
            content = f.read(2000)
        return render_template_string(HTML, content2=content)
    except Exception as e:
        return render_template_string(HTML, error2=str(e))

# === Level 3: Extension Whitelist ===
@app.route('/view-whitelist')
def view_whitelist():
    filename = request.args.get('file', '')
    allowed = ('.pdf', '.txt', '.html', '.md')
    if not any(filename.lower().endswith(ext) for ext in allowed):
        return render_template_string(HTML, error3="Only .pdf, .txt, .html, .md files allowed")
    filepath = os.path.join(BASE_DIR, filename)
    try:
        with open(filepath, 'r', errors='replace') as f:
            content = f.read(2000)
        return render_template_string(HTML, content3=content)
    except Exception as e:
        return render_template_string(HTML, error3=str(e))

# === Level 4: Must start with prefix ===
@app.route('/view-prefix')
def view_prefix():
    filename = request.args.get('file', '')
    filepath = os.path.join(BASE_DIR, filename)
    # Weak: only checks startswith, not realpath
    if not filepath.startswith(BASE_DIR):
        return render_template_string(HTML, error4=f"Access denied: path must start with {BASE_DIR}")
    try:
        with open(filepath, 'r', errors='replace') as f:
            content = f.read(2000)
        return render_template_string(HTML, content4=content)
    except Exception as e:
        return render_template_string(HTML, error4=str(e))

# === Safe Reference ===
@app.route('/view-safe')
def view_safe():
    filename = request.args.get('file', '')
    filepath = os.path.join(BASE_DIR, filename)
    real = os.path.realpath(filepath)
    if not real.startswith(os.path.realpath(BASE_DIR)):
        return render_template_string(HTML, error_safe="Access denied")
    try:
        with open(real, 'r', errors='replace') as f:
            content = f.read(2000)
        return render_template_string(HTML, content_safe=content)
    except Exception as e:
        return render_template_string(HTML, error_safe=str(e))

if __name__ == '__main__':
    os.makedirs(BASE_DIR, exist_ok=True)
    app.run(host='0.0.0.0', port=5000, debug=False)
PYEOF

# === PHP Include Page ===
RUN cat > /var/www/html/include.php << 'PHPEOF'
<?php
// PHP include traversal — appends .php to the page parameter

$allowed_pages = ['index', 'about', 'contact'];

$page = $_GET['page'] ?? 'index';

// VULNERABLE: includes user-controlled path with .php appended
// Try: ../../../etc/fake-passwd%00 (null byte for PHP < 5.3.4)
// Try: php://filter/convert.base64-encode/resource=index
// Try: /proc/self/environ with PHP code in User-Agent header
?>
<!DOCTYPE html>
<html><head><title>PHP Include Test</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}</style></head>
<body>
<h2>PHP Include Traversal Test</h2>
<p>Requested page: <code><?php echo htmlspecialchars($page); ?></code></p>
<pre>
<?php
$file = $page . '.php';
echo "Attempting to include: " . htmlspecialchars($file) . "\n\n";

// Check if it's a PHP wrapper
if (strpos($page, 'php://') === 0 || strpos($page, 'data://') === 0) {
    include($page);
} else {
    // Try to include normally
    @include($file);
}

// Show what files exist in the current directory
echo "\n\nFiles in current directory:\n";
$files = scandir(__DIR__);
foreach ($files as $f) {
    if ($f !== '.' && $f !== '..') {
        echo "  - $f\n";
    }
}

// Show environment (if accessible via /proc)
echo "\n\nServer environment:\n";
echo "DOCUMENT_ROOT: " . ($_SERVER['DOCUMENT_ROOT'] ?? 'not set') . "\n";
echo "SCRIPT_FILENAME: " . ($_SERVER['SCRIPT_FILENAME'] ?? 'not set') . "\n";
echo "PHP version: " . phpversion() . "\n";
?>
</pre>
<a href="/">← Back to Path Traversal Lab</a>
</body></html>
PHPEOF

# === Simple PHP pages for include ===
RUN echo '<h2>Index Page</h2><p>This is the index page content.</p>' > /var/www/html/index.php && \
    echo '<h2>About Page</h2><p>About this application.</p><p>Secret hint: check /var/log/fake-service/service.log</p>' > /var/www/html/about.php && \
    echo '<h2>Contact Page</h2><p>Contact us at admin@example.com</p>' > /var/www/html/contact.php

# === Landing page ===
RUN cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html><head><title>Path Traversal Lab</title>
<style>body{font-family:monospace;margin:30px;max-width:800px}
.section{border:1px solid #ccc;padding:15px;margin:15px 0;background:#f9f9f9}
h3{margin-top:0} a{color:#0066cc}
li{margin:5px 0} code{background:#eee;padding:1px 4px}</style></head><body>
<h1>Path Traversal Practice Lab</h1>
<p>Five vulnerability levels + PHP include endpoint. Fake sensitive files are pre-placed throughout the container.</p>

<div class="section">
<h3>Vulnerability Levels</h3>
<ul>
  <li><a href="/view?file=report.pdf">Level 1: No Filter</a> — Bypass: <code>../../../etc/fake-passwd</code></li>
  <li><a href="/view-stripped?file=report.pdf">Level 2: Strips ../</a> — Bypass: <code>....//....//....//etc/fake-passwd</code></li>
  <li><a href="/view-whitelist?file=report.pdf">Level 3: Extension Whitelist</a> — Bypass: <code>../../../etc/fake-passwd</code> (why does this work?)</li>
  <li><a href="/view-prefix?file=report.pdf">Level 4: Prefix Required</a> — Bypass: <code>/var/www/files/../../../etc/fake-passwd</code></li>
  <li><a href="/include.php?page=index">Level 5: PHP Include</a> — Bypass: null byte, wrappers, /proc paths</li>
</ul>
</div>

<div class="section">
<h3>Target Files to Read</h3>
<ul>
  <li><code>/etc/fake-passwd</code> — Fake user database</li>
  <li><code>/etc/fake-shadow</code> — Fake password hashes</li>
  <li><code>/home/user/.ssh/id_rsa</code> — Fake SSH private key</li>
  <li><code>/var/www/.env</code> — Environment secrets</li>
  <li><code>/var/www/config.ini</code> — Configuration with credentials</li>
  <li><code>/var/www/app.py</code> — Application source code</li>
  <li><code>/var/log/fake-service/service.log</code> — Service logs with tokens</li>
  <li><code>/proc/self/environ</code> — Current process environment</li>
  <li><code>/proc/self/cmdline</code> — Command line</li>
</ul>
</div>

<p><strong>Hint for Level 3:</strong> The path provided is joined with <code>/var/www/files/</code> prefix. The extension check only looks at the final <code>file</code> parameter. What path satisfies both the prefix constraint and an extension whitelist?</p>

</body></html>
HTMLEOF

# === Nginx config ===
RUN cat > /etc/nginx/sites-available/default << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/html;
    index index.html index.php;

    # Flask app for file viewer levels
    location /view {
        proxy_pass http://127.0.0.1:5000/view;
        proxy_set_header Host $host;
    }

    location /view-stripped {
        proxy_pass http://127.0.0.1:5000/view-stripped;
        proxy_set_header Host $host;
    }

    location /view-whitelist {
        proxy_pass http://127.0.0.1:5000/view-whitelist;
        proxy_set_header Host $host;
    }

    location /view-prefix {
        proxy_pass http://127.0.0.1:5000/view-prefix;
        proxy_set_header Host $host;
    }

    location /view-safe {
        proxy_pass http://127.0.0.1:5000/view-safe;
        proxy_set_header Host $host;
    }

    # PHP include endpoint
    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location / {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host $host;
    }
}
NGINXEOF

RUN mkdir -p /etc/nginx/sites-enabled && \
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default && \
    mkdir -p /run/php

# === Start script ===
RUN cat > /start.sh << 'STARTEOF'
#!/bin/bash
set -e

# Start PHP-FPM
mkdir -p /run/php
php-fpm8.2 -D

# Start Flask file viewer
cd /var/www/html
python3 app.py &

# Start nginx
nginx -g 'daemon off;'
STARTEOF
RUN chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]

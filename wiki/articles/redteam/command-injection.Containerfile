# Command Injection - CTF Lab Container
# Build:  podman build -t cmd-inj-lab -f command-injection.Containerfile .
# Run:    podman run -d --name cmd-inj-lab -p 8080:80 cmd-inj-lab
#
# Services:
#   HTTP on 8080 - ping utility (unfiltered, filtered, blind), image converter,
#                  cron scheduler with injectable parameters
#
# WARNING: Intentionally vulnerable. Run only on an isolated host and never
# expose this port to a real network.

FROM python:3.12-slim

LABEL description="Command Injection Lab - ping utility, image converter, cron scheduler with multiple filter levels"

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    curl \
    imagemagick \
    iputils-ping \
    cron \
    && rm -rf /var/lib/apt/lists/*

RUN pip install flask --break-system-packages

RUN mkdir -p /var/www/html /var/www/uploads /var/www/logs

# === Main Flask App — Network Diagnostic Tool ===
RUN cat > /var/www/html/app.py << 'PYEOF'
from flask import Flask, request, render_template_string, Response
import subprocess
import os
import re
import time

app = Flask(__name__)

HTML_INDEX = """
<html><head><title>Command Injection Lab</title>
<style>body{font-family:monospace;margin:20px;max-width:900px}
pre{background:#f4f4f4;padding:10px;overflow:auto;border:1px solid #ddd}
input,select{padding:6px;margin:4px} .section{border:1px solid #ccc;padding:15px;margin:12px 0;background:#fafafa}
h3{margin-top:0} .label{display:inline-block;background:#0066cc;color:#fff;padding:2px 8px;border-radius:3px;font-size:11px}
.safe{background:#00aa00} .vuln{background:#cc0000}
</style></head><body>
<h1>Command Injection Lab</h1>
<p>Practice command injection across different filter levels and application contexts.</p>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 1: Basic Ping (No Filter)</h3>
<p>Runs: <code>ping -c 4 {user_input}</code></p>
<form method="POST" action="/ping">
  <input name="host" placeholder="IP address" value="8.8.8.8" size="40">
  <input type="submit" value="Ping">
</form>
{% if ping1 %}<pre>{{ ping1 }}</pre>{% endif %}
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 2: Filtered Ping (Spaces & ; stripped)</h3>
<p>Runs: <code>ping -c 4 {filtered_input}</code> | Filter: strips spaces and semicolons</p>
<form method="POST" action="/ping-filtered">
  <input name="host" placeholder="IP address" size="40">
  <input type="submit" value="Ping (Filtered)">
</form>
{% if ping2 %}<pre>{{ ping2 }}</pre>{% endif %}
{% if ping2_error %}<pre style="color:red">{{ ping2_error }}</pre>{% endif %}
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 3: Blind Ping (No Output)</h3>
<p>Runs: <code>ping -c 4 {user_input} &gt; /dev/null 2&gt;&amp;1 &amp;</code></p>
<p>No output visible. Use OOB techniques (curl/wget to attacker server) or time-based detection.</p>
<form method="POST" action="/ping-blind">
  <input name="host" placeholder="IP address" size="40">
  <input type="submit" value="Ping (Blind)">
</form>
{% if ping3_msg %}<p>{{ ping3_msg }}</p>{% endif %}
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Level 4: Character Blacklist</h3>
<p>Blocks: <code>; | &amp; $ \` ( )</code></p>
<form method="POST" action="/ping-blacklist">
  <input name="host" placeholder="IP address" size="40">
  <input type="submit" value="Ping (Blacklist)">
</form>
{% if ping4 %}<pre>{{ ping4 }}</pre>{% endif %}
{% if ping4_error %}<pre style="color:red">{{ ping4_error }}</pre>{% endif %}
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Image Converter (Filename Injection)</h3>
<p>Converts uploaded images. The output filename parameter is injectable.</p>
<form method="POST" action="/convert" enctype="multipart/form-data">
  <input type="file" name="image"><br>
  <input name="output_name" placeholder="output filename" value="converted.png">
  <input type="submit" value="Convert">
</form>
{% if conv_msg %}<pre>{{ conv_msg }}</pre>{% endif %}
</div>

<div class="section">
<h3><span class="label vuln">VULNERABLE</span> Cron Scheduler</h3>
<p>Schedule a task. The cron expression is passed directly to crontab.</p>
<form method="POST" action="/schedule">
  <input name="cron_expr" placeholder="* * * * *" size="30">
  <input name="command" placeholder="echo hello" size="40">
  <input type="submit" value="Schedule">
</form>
{% if sched_msg %}<pre>{{ sched_msg }}</pre>{% endif %}
</div>

<div class="section">
<h3><span class="label safe">SAFE</span> Secure Ping (Reference)</h3>
<p>Uses <code>subprocess.run()</code> with argument list — not vulnerable.</p>
<form method="POST" action="/ping-safe">
  <input name="host" placeholder="IP address" value="8.8.8.8" size="40">
  <input type="submit" value="Ping (Secure)">
</form>
{% if ping_safe %}<pre>{{ ping_safe }}</pre>{% endif %}
</div>

</body></html>
"""

@app.route('/')
def index():
    return render_template_string(HTML_INDEX)

# === Level 1: No Filter ===
@app.route('/ping', methods=['POST'])
def ping():
    host = request.form.get('host', '8.8.8.8')
    # VULNERABLE: os.popen passes string to shell
    import os
    result = os.popen(f"ping -c 4 {host} 2>&1").read()
    return render_template_string(HTML_INDEX, ping1=result)

# === Level 2: Space + Semicolon Filter ===
@app.route('/ping-filtered', methods=['POST'])
def ping_filtered():
    host = request.form.get('host', '8.8.8.8')
    # Weak filter: strips spaces and semicolons
    host = host.replace(' ', '').replace(';', '')
    try:
        result = subprocess.getoutput(f"ping -c 4 {host} 2>&1")
        return render_template_string(HTML_INDEX, ping2=result)
    except Exception as e:
        return render_template_string(HTML_INDEX, ping2_error=str(e))

# === Level 3: Blind (no output) ===
@app.route('/ping-blind', methods=['POST'])
def ping_blind():
    host = request.form.get('host', '8.8.8.8')
    # VULNERABLE: os.system — output discarded
    os.system(f"ping -c 4 {host} > /dev/null 2>&1 &")
    return render_template_string(HTML_INDEX, ping3_msg="Ping sent to background. No output will be shown — use OOB detection.")

# === Level 4: Character Blacklist ===
@app.route('/ping-blacklist', methods=['POST'])
def ping_blacklist():
    host = request.form.get('host', '8.8.8.8')
    blocked_chars = [';', '|', '&', '$', '`', '(', ')']
    for char in blocked_chars:
        if char in host:
            return render_template_string(HTML_INDEX, ping4_error=f"Blocked character detected: {char}")
    try:
        result = subprocess.getoutput(f"ping -c 4 {host} 2>&1")
        return render_template_string(HTML_INDEX, ping4=result)
    except Exception as e:
        return render_template_string(HTML_INDEX, ping4_error=str(e))

# === Image Converter (Filename Injection) ===
@app.route('/convert', methods=['POST'])
def convert():
    output_name = request.form.get('output_name', 'converted.png')
    if 'image' in request.files:
        image = request.files['image']
        input_path = f"/var/www/uploads/{image.filename}"
        image.save(input_path)
        # VULNERABLE: output_name injected into shell command
        import os
        cmd = f"convert {input_path} -resize 200x200 {output_name} 2>&1"
        result = os.popen(cmd).read()
        return render_template_string(HTML_INDEX, conv_msg=f"Conversion attempted.\nCommand: {cmd}\nResult: {result}")
    return render_template_string(HTML_INDEX, conv_msg="No image uploaded.")

# === Cron Scheduler ===
@app.route('/schedule', methods=['POST'])
def schedule():
    cron_expr = request.form.get('cron_expr', '')
    command = request.form.get('command', '')
    if cron_expr and command:
        # VULNERABLE: cron expression passed directly to shell
        import os
        full_cron = f"{cron_expr} root {command} 2>&1"
        try:
            result = os.popen(f"/bin/echo '{full_cron}' > /tmp/scheduled_cron.txt 2>&1").read()
            os.popen(f"cat /tmp/scheduled_cron.txt 2>&1").read()
            return render_template_string(HTML_INDEX, sched_msg=f"Task written: {full_cron}\n(Note: cron not actually running in this lab)")
        except Exception as e:
            return render_template_string(HTML_INDEX, sched_msg=f"Error: {e}")
    return render_template_string(HTML_INDEX, sched_msg="Missing cron expression or command.")

# === Secure Reference ===
@app.route('/ping-safe', methods=['POST'])
def ping_safe():
    host = request.form.get('host', '8.8.8.8')
    # SAFE: argument list, no shell
    result = subprocess.run(
        ["ping", "-c", "4", host],
        capture_output=True, text=True, timeout=10
    )
    return render_template_string(HTML_INDEX, ping_safe=result.stdout + result.stderr)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
PYEOF

# === Nginx configuration ===
RUN cat > /etc/nginx/sites-available/default << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/html;
    index index.html;

    location / {
        proxy_pass http://127.0.0.1:5000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /uploads/ {
        alias /var/www/uploads/;
        autoindex on;
    }
}
NGINXEOF

RUN mkdir -p /etc/nginx/sites-enabled && \
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# === Start script ===
RUN cat > /start.sh << 'STARTEOF'
#!/bin/bash
set -e

# Start Flask app
cd /var/www/html
python3 app.py &

# Start nginx
nginx -g 'daemon off;'
STARTEOF
RUN chmod +x /start.sh

# Create placeholder files with real content for verification
RUN echo 'This is /var/www/html/flag.txt — you found it via command injection!' > /var/www/html/flag.txt && \
    echo 'DB_USER=prod_db_user' > /var/www/html/.env && \
    echo 'DB_PASS=env_password_2024!' >> /var/www/html/.env && \
    echo 'SECRET_KEY=secret_from_env_file' >> /var/www/html/.env

EXPOSE 80

CMD ["/start.sh"]

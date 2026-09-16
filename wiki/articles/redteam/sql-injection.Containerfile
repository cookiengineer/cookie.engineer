# sql-injection.Containerfile
# SQL Injection Lab — SQLite (Flask), MySQL (PHP), MongoDB (Flask)
# Build: podman build -t sql-injection -f sql-injection.Containerfile .
# Run:   podman run --rm -it -p 8080:8080 -p 8081:8081 -p 8082:8082 sql-injection
FROM python:3.12-slim

LABEL description="SQL Injection Lab — SQLite (Flask), MySQL (PHP), MongoDB (Flask) vulnerable applications"

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    php-fpm \
    php-mysql \
    php-sqlite3 \
    default-mysql-server \
    curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install flask pymongo mysql-connector-python --break-system-packages

# === Initialize MySQL ===
RUN mkdir -p /run/mysqld /var/lib/mysql && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql && \
    mysqld --initialize-insecure --user=mysql --datadir=/var/lib/mysql 2>/dev/null || \
    mysql_install_db --user=mysql --datadir=/var/lib/mysql

# === Create directory structure ===
RUN mkdir -p /var/www/html/sqlite \
    /var/www/html/php \
    /var/www/html/mongo \
    /var/www/sqlite-logs

# === Flask App 1: SQLite SQLi (login bypass, UNION, blind) ===
RUN cat > /var/www/html/sqlite/app.py << 'PYEOF'
from flask import Flask, request, render_template_string
import sqlite3
import hashlib

app = Flask(__name__)

HTML_INDEX = """
<html><head><title>SQL Injection Lab — SQLite</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}
input{padding:5px;margin:3px} .section{border:1px solid #ccc;padding:15px;margin:10px 0}</style></head><body>
<h2>SQL Injection Lab — SQLite + Flask</h2>
<p><a href="/">← Back to all labs</a></p>

<div class="section">
<h3>Login Bypass</h3>
<form method="GET" action="/sqlite/login">
  <input name="username" placeholder="Username"><br>
  <input name="password" type="password" placeholder="Password"><br>
  <input type="submit" value="Login">
</form>
{% if login_msg %}<pre>{{ login_msg }}</pre>{% endif %}
</div>

<div class="section">
<h3>UNION-Based Injection</h3>
<form method="GET" action="/sqlite/search">
  <input name="query" placeholder="Search users"><br>
  <input type="submit" value="Search">
</form>
{% if search_results %}
<pre>{{ search_results }}</pre>
{% endif %}
{% if search_error %}<pre style="color:red">{{ search_error }}</pre>{% endif %}
</div>

<div class="section">
<h3>Blind Boolean-Based SQLi</h3>
<p>The page shows normal content for TRUE conditions and nothing for FALSE.</p>
<form method="GET" action="/sqlite/product">
  <input name="id" placeholder="Product ID" value="1"><br>
  <input type="submit" value="View Product">
</form>
{% if product %}<pre>{{ product }}</pre>{% endif %}
{% if product_error %}<pre style="color:red">{{ product_error }}</pre>{% endif %}
</div>
</body></html>
"""

def get_db():
    conn = sqlite3.connect('/var/www/sqlite-logs/sqlite_lab.db')
    conn.row_factory = sqlite3.Row
    return conn

def init_sqlite_db():
    conn = sqlite3.connect('/var/www/sqlite-logs/sqlite_lab.db')
    c = conn.cursor()
    c.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            username TEXT,
            password TEXT,
            email TEXT,
            role TEXT
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY,
            name TEXT,
            description TEXT,
            price REAL,
            secret_flag TEXT
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS internal_config (
            id INTEGER PRIMARY KEY,
            config_key TEXT,
            config_value TEXT
        )
    """)
    # Seed data
    c.execute("INSERT OR IGNORE INTO users VALUES (1,'admin','c4ca4238a0b923820dcc509a6f75849b','admin@company.local','administrator')")
    c.execute("INSERT OR IGNORE INTO users VALUES (2,'developer','e10adc3949ba59abbe56e057f20f883e','dev@company.local','developer')")
    c.execute("INSERT OR IGNORE INTO users VALUES (3,'analyst','5f4dcc3b5aa765d61d8327deb882cf99','analyst@company.local','analyst')")
    c.execute("INSERT OR IGNORE INTO users VALUES (4,'manager','21232f297a57a5a743894a0e4a801fc3','manager@company.local','administrator')")
    c.execute("INSERT OR IGNORE INTO products VALUES (1,'Widget','A nice widget for your needs',9.99,'CTF{widget_secret_flag_123}')")
    c.execute("INSERT OR IGNORE INTO products VALUES (2,'Gadget','Advanced gadget with AI features',29.99,'CTF{gadget_ai_secret_456}')")
    c.execute("INSERT OR IGNORE INTO products VALUES (3,'Thingamajig','The ultimate thingamajig',99.99,'CTF{premium_flag_789}')")
    c.execute("INSERT OR IGNORE INTO internal_config VALUES (1,'api_key','sk-internal-api-key-2024-secret')")
    c.execute("INSERT OR IGNORE INTO internal_config VALUES (2,'db_password','SQLiteSuP3rS3cr3t!')")
    c.execute("INSERT OR IGNORE INTO internal_config VALUES (3,'admin_token','eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.sqllite-admin')")
    conn.commit()
    conn.close()

init_sqlite_db()

@app.route('/sqlite/login')
def sqlite_login():
    conn = get_db()
    username = request.args.get('username', '')
    password = request.args.get('password', '')
    msg = "Invalid credentials"
    if username and password:
        # VULNERABLE: string concatenation
        hashed = hashlib.md5(password.encode()).hexdigest()
        query = f"SELECT * FROM users WHERE username='{username}' AND password='{hashed}'"
        try:
            user = conn.execute(query).fetchone()
            if user:
                msg = f"SUCCESS: Welcome, {user['username']} (role: {user['role']}, email: {user['email']})"
        except Exception as e:
            msg = f"SQL Error: {e}"
    conn.close()
    return render_template_string(HTML_INDEX, login_msg=msg)

@app.route('/sqlite/search')
def sqlite_search():
    conn = get_db()
    query_param = request.args.get('query', '')
    if query_param:
        # VULNERABLE: string concatenation
        query = f"SELECT id, username, email, role FROM users WHERE username LIKE '%{query_param}%'"
        try:
            results = conn.execute(query).fetchall()
            if results:
                output = "\n".join([f"ID:{r['id']} | User:{r['username']} | Email:{r['email']} | Role:{r['role']}" for r in results])
                conn.close()
                return render_template_string(HTML_INDEX, search_results=output)
        except Exception as e:
            conn.close()
            return render_template_string(HTML_INDEX, search_error=str(e))
    conn.close()
    return render_template_string(HTML_INDEX)

@app.route('/sqlite/product')
def sqlite_product():
    conn = get_db()
    product_id = request.args.get('id', '1')
    # VULNERABLE: string concatenation
    query = f"SELECT * FROM products WHERE id={product_id}"
    try:
        result = conn.execute(query).fetchone()
        if result:
            output = f"Name: {result['name']}\nDescription: {result['description']}\nPrice: ${result['price']}\nFlag: {result['secret_flag']}"
            conn.close()
            return render_template_string(HTML_INDEX, product=output)
        else:
            conn.close()
            return render_template_string(HTML_INDEX, product="Product not found.")
    except Exception as e:
        conn.close()
        return render_template_string(HTML_INDEX, product_error=str(e))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
PYEOF

# === PHP App: MySQL SQLi ===
RUN cat > /var/www/html/php/config.php << 'PHPEOF'
<?php
$db_host = '127.0.0.1';
$db_user = 'root';
$db_pass = '';
$db_name = 'mysql_lab';

try {
    $pdo = new PDO("mysql:host=$db_host;dbname=$db_name", $db_user, $db_pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_WARNING
    ]);
} catch(PDOException $e) {
    die("DB connection failed: " . $e->getMessage());
}
?>
PHPEOF

RUN cat > /var/www/html/php/index.php << 'PHPEOF'
<!DOCTYPE html>
<html><head><title>SQL Injection Lab — MySQL</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}
input,select{padding:5px;margin:3px} .section{border:1px solid #ccc;padding:15px;margin:10px 0}</style></head>
<body>
<h2>SQL Injection Lab — PHP + MySQL</h2>
<p><a href="/">← Back to all labs</a></p>

<div class="section">
<h3>Error-Based SQLi</h3>
<form method="GET" action="/php/search.php">
  <input name="id" placeholder="User ID" value="1">
  <input type="submit" value="Search">
</form>
<?php if(isset($_GET['id'])): ?>
<pre><?php
require 'config.php';
$id = $_GET['id'];
// VULNERABLE: direct string concatenation
$query = "SELECT id, username, email FROM users WHERE id=$id";
try {
    $stmt = $pdo->query($query);
    while($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        echo "ID:{$row['id']} | User:{$row['username']} | Email:{$row['email']}\n";
    }
} catch(PDOException $e) {
    echo "SQL Error: " . $e->getMessage();
}
?></pre>
<?php endif; ?>
</div>

<div class="section">
<h3>Boolean-Based Blind SQLi</h3>
<form method="GET" action="/php/product.php">
  <input name="id" placeholder="Product ID" value="1">
  <input type="submit" value="View Product">
</form>
<?php if(isset($_GET['id'])): ?>
<pre><?php
require 'config.php';
$id = $_GET['id'];
// VULNERABLE: direct string concatenation
$query = "SELECT name, price FROM products WHERE id=$id";
try {
    $stmt = $pdo->query($query);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if($row) {
        echo "Product: " . $row['name'] . "\n";
        echo "Price: $" . $row['price'] . "\n";
    } else {
        echo "Product not found.";
    }
} catch(PDOException $e) {
    // Suppress errors in blind scenario
    echo "Product not found.";
}
?></pre>
<?php endif; ?>
</div>

<div class="section">
<h3>Time-Based Blind SQLi</h3>
<form method="GET" action="/php/delay.php">
  <input name="id" placeholder="User ID" value="1">
  <input type="submit" value="Query">
</form>
<?php if(isset($_GET['id'])): ?>
<pre><?php
require 'config.php';
$id = $_GET['id'];
$query = "SELECT username FROM users WHERE id=$id";
try {
    $stmt = $pdo->query($query);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if($row) {
        echo "User: " . $row['username'];
    }
} catch(PDOException $e) {
    // No error output
}
?></pre>
<?php endif; ?>
</div>

<div class="section">
<h3>File Read (LOAD_FILE)</h3>
<form method="GET" action="/php/file-read.php">
  <input name="filename" placeholder="File path" value="/etc/passwd">
  <input type="submit" value="Read File">
</form>
<?php if(isset($_GET['filename'])): ?>
<pre><?php
require 'config.php';
$filename = $_GET['filename'];
// VULNERABLE: UNION injection to read file
$query = "SELECT id, LOAD_FILE('$filename') as content FROM users WHERE id=1";
try {
    $stmt = $pdo->query($query);
    $row = $stmt->fetch(PDO::FETCH_ASSOC);
    if($row && $row['content']) {
        echo htmlspecialchars($row['content']);
    } else {
        echo "No data returned (file may not exist or FILE privilege missing)";
    }
} catch(PDOException $e) {
    echo "Error: " . $e->getMessage();
}
?></pre>
<?php endif; ?>
</div>

<div class="section">
<h3>INTO OUTFILE (Webshell Upload)</h3>
<form method="GET" action="/php/outfile.php">
  <input name="code" placeholder="PHP code" value="<?php echo 'FLAG-TEST'; ?>">
  <input type="submit" value="Write File">
</form>
<?php if(isset($_GET['code'])): ?>
<pre><?php
require 'config.php';
$code = $_GET['code'];
$query = "SELECT '$code' INTO OUTFILE '/var/www/html/php/output.php'";
try {
    $pdo->exec($query);
    echo "File written to /php/output.php — <a href='/php/output.php' target='_blank'>check it</a>";
} catch(PDOException $e) {
    echo "Error: " . $e->getMessage();
}
?></pre>
<?php endif; ?>
</div>

</body></html>
PHPEOF

# === Flask App 2: MongoDB NoSQL Injection ===
RUN cat > /var/www/html/mongo/app.py << 'PYEOF'
from flask import Flask, request, render_template_string, session, redirect
from pymongo import MongoClient
import hashlib
import secrets

app = Flask(__name__)
app.secret_key = secrets.token_hex(16)

client = MongoClient('127.0.0.1', 27017, serverSelectionTimeoutMS=5000)
db = client.mongo_lab

HTML_LOGIN = """
<html><head><title>NoSQL Injection Lab — MongoDB</title>
<style>body{font-family:monospace;margin:20px} pre{background:#eee;padding:10px}
input{padding:5px;margin:3px} .section{border:1px solid #ccc;padding:15px;margin:10px 0}</style></head><body>
<h2>NoSQL Injection Lab — Flask + MongoDB</h2>
<p><a href="/">← Back to all labs</a></p>

<div class="section">
<h3>Login ($ne / $regex bypass)</h3>
<form method="POST" action="/mongo/login">
  <input name="username" placeholder="Username"><br>
  <input name="password" type="password" placeholder="Password"><br>
  <input type="submit" value="Login">
</form>
{% if login_msg %}<pre>{{ login_msg }}</pre>{% endif %}
</div>

<div class="section">
<h3>User Search ($where injection)</h3>
<form method="GET" action="/mongo/search">
  <input name="q" placeholder="Search users by username">
  <input type="submit" value="Search">
</form>
{% if search_results %}<pre>{{ search_results }}</pre>{% endif %}
{% if search_error %}<pre style="color:red">{{ search_error }}</pre>{% endif %}
</div>

<div class="section">
<h3>User Profile ($regex extraction)</h3>
<form method="POST" action="/mongo/profile">
  <input name="username" placeholder="Username">
  <input type="submit" value="View Profile">
</form>
{% if profile %}<pre>{{ profile }}</pre>{% endif %}
{% if profile_error %}<pre style="color:red">{{ profile_error }}</pre>{% endif %}
</div>
</body></html>
"""

def init_mongo():
    """Seed MongoDB with sample data."""
    try:
        if db.users.count_documents({}) == 0:
            db.users.insert_many([
                {"username": "admin", "password": "admin_secret_pass_2024!", "email": "admin@mongo.local", "role": "admin"},
                {"username": "developer", "password": "dev_password_123", "email": "dev@mongo.local", "role": "developer"},
                {"username": "analyst", "password": "analysis_s3cret", "email": "analyst@mongo.local", "role": "analyst"},
                {"username": "dba", "password": "mongodb_adm1n!", "email": "dba@mongo.local", "role": "admin"},
            ])
        if db.products.count_documents({}) == 0:
            db.products.insert_many([
                {"name": "Widget Pro", "price": 19.99, "flag": "CTF{mongo_widget_flag}"},
                {"name": "Gadget X", "price": 49.99, "flag": "CTF{mongo_gadget_flag}"},
                {"name": "SuperTool", "price": 199.99, "flag": "CTF{mongo_supertool_flag}"},
            ])
    except Exception as e:
        print(f"MongoDB init error: {e}")

init_mongo()

@app.route('/mongo/login', methods=['POST'])
def mongo_login():
    # Check if JSON payload
    if request.is_json:
        data = request.get_json()
        username = data.get('username', '')
        password = data.get('password', '')
    else:
        username = request.form.get('username', '')
        password = request.form.get('password', '')

    # VULNERABLE: pass user-controlled dicts directly to find_one
    # If JSON payload provides $ne, $regex operators, they pass through
    try:
        user = db.users.find_one({'username': username, 'password': password})
        if user:
            msg = f"SUCCESS: Welcome, {user['username']} (role: {user['role']})"
        else:
            msg = "Invalid credentials"
    except Exception as e:
        msg = f"Error: {e}"

    return render_template_string(HTML_LOGIN, login_msg=msg)

@app.route('/mongo/search')
def mongo_search():
    q = request.args.get('q', '')
    if q:
        # VULNERABLE: $where injection possible via string interpolation
        try:
            # Use regex for normal search, but also allows injection
            results = list(db.users.find({'username': {'$regex': q}}))
            if results:
                output = "\n".join([f"User:{r['username']} | Email:{r['email']} | Role:{r['role']}" for r in results])
                return render_template_string(HTML_LOGIN, search_results=output)
        except Exception as e:
            return render_template_string(HTML_LOGIN, search_error=str(e))
    return render_template_string(HTML_LOGIN)

@app.route('/mongo/profile', methods=['POST'])
def mongo_profile():
    # VULNERABLE: pass user dict directly
    if request.is_json:
        data = request.get_json()
    else:
        data = request.form.to_dict()

    username = data.get('username', '')
    try:
        user = db.users.find_one({'username': username})
        if user:
            profile = f"Username: {user['username']}\nEmail: {user['email']}\nRole: {user['role']}\nPassword: {user['password']}"
            return render_template_string(HTML_LOGIN, profile=profile)
        else:
            return render_template_string(HTML_LOGIN, profile_error="User not found")
    except Exception as e:
        return render_template_string(HTML_LOGIN, profile_error=str(e))

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)
PYEOF

# === Landing page ===
RUN cat > /var/www/html/index.html << 'HTMLEOF'
<!DOCTYPE html>
<html><head><title>SQL Injection Lab</title>
<style>body{font-family:monospace;margin:30px;max-width:800px}
h1{border-bottom:2px solid #333} a{color:#0066cc}
.section{border:1px solid #ccc;padding:15px;margin:15px 0;background:#f9f9f9}
h3{margin-top:0} li{margin:5px 0}</style></head><body>
<h1>SQL Injection Practice Lab</h1>
<p>Three applications with different database backends and injection types.</p>

<div class="section">
<h3><a href="/sqlite/">SQLite + Flask</a></h3>
<ul>
  <li>Login Bypass (authentication bypass via OR injection)</li>
  <li>UNION-Based Injection (product search with visible output)</li>
  <li>Boolean-Based Blind SQLi (TRUE/FALSE page response difference)</li>
</ul>
</div>

<div class="section">
<h3><a href="/php/">MySQL + PHP</a></h3>
<ul>
  <li>Error-Based SQLi (error messages reveal data)</li>
  <li>Boolean-Based Blind SQLi (page content vs empty response)</li>
  <li>Time-Based Blind SQLi (SLEEP() function)</li>
  <li>File Read via LOAD_FILE()</li>
  <li>Webshell via INTO OUTFILE</li>
</ul>
</div>

<div class="section">
<h3><a href="/mongo/">MongoDB + Flask</a></h3>
<ul>
  <li>NoSQL Login Bypass ($ne, $regex operators)</li>
  <li>$regex Blind Extraction (character-by-character credential extraction)</li>
  <li>User Search with $where injection potential</li>
  <li>Profile lookup with NoSQL operator injection</li>
</ul>
</div>

<p><strong>Hint:</strong> For NoSQL injection, send JSON requests with:
<code>curl -X POST http://localhost:8080/mongo/login -H 'Content-Type: application/json' -d '{"username":{"$ne":""},"password":{"$ne":""}}'</code></p>

</body></html>
HTMLEOF

# === MySQL initialization script ===
RUN cat > /init-mysql.sql << 'SQLEOF'
CREATE DATABASE IF NOT EXISTS mysql_lab;
USE mysql_lab;

CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(64),
    password VARCHAR(64),
    email VARCHAR(128),
    role VARCHAR(32)
);

CREATE TABLE products (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(128),
    description TEXT,
    price DECIMAL(10,2),
    secret_flag VARCHAR(255)
);

CREATE TABLE internal_config (
    id INT PRIMARY KEY AUTO_INCREMENT,
    config_key VARCHAR(64),
    config_value VARCHAR(255)
);

INSERT INTO users VALUES (1,'admin','admin_secret_mysql','admin@company.local','administrator');
INSERT INTO users VALUES (2,'developer','dev_pass_123','dev@company.local','developer');
INSERT INTO users VALUES (3,'analyst','analyze_this!','analyst@company.local','analyst');
INSERT INTO users VALUES (4,'manager','p@ssw0rd!','manager@company.local','administrator');
INSERT INTO users VALUES (5,'service_user','S3rviceMysqlP@ss','service@internal.local','service');

INSERT INTO products VALUES (1,'Widget','A basic widget',9.99,'CTF{mysql_widget_secret}');
INSERT INTO products VALUES (2,'Gadget','An advanced gadget',49.99,'CTF{mysql_gadget_secret}');
INSERT INTO products VALUES (3,'SuperWidget','The ultimate widget',199.99,'CTF{mysql_super_secret}');

INSERT INTO internal_config VALUES (1,'api_key','mysql-api-key-2024-secret');
INSERT INTO internal_config VALUES (2,'db_password','MySQL_Internal_P@ss!');
INSERT INTO internal_config VALUES (3,'admin_token','mysql-admin-jwt-token-2024');

-- Grant FILE privilege for LOAD_FILE/INTO OUTFILE
GRANT FILE ON *.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
SQLEOF

# === Nginx config ===
RUN cat > /etc/nginx/sites-available/default << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/html;
    index index.html index.php;

    # SQLite lab (Flask on port 5000)
    location /sqlite/ {
        proxy_pass http://127.0.0.1:5000/sqlite/;
        proxy_set_header Host $host;
    }

    location /sqlite {
        proxy_pass http://127.0.0.1:5000/sqlite;
        proxy_set_header Host $host;
    }

    # MongoDB lab (Flask on port 5001)
    location /mongo/ {
        proxy_pass http://127.0.0.1:5001/mongo/;
        proxy_set_header Host $host;
    }

    location /mongo {
        proxy_pass http://127.0.0.1:5001/mongo;
        proxy_set_header Host $host;
    }

    # PHP MySQL lab
    location /php/ {
        try_files $uri $uri/ /php/index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location / {
        try_files $uri $uri/ =404;
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

# Start MySQL
mysqld_safe --datadir=/var/lib/mysql &
sleep 3

# Initialize MySQL database
mysql -u root < /init-mysql.sql 2>/dev/null || true

# Start MongoDB (minimal — use mongod if installed, else skip)
if command -v mongod &>/dev/null; then
    mkdir -p /data/db
    mongod --fork --logpath /var/log/mongod.log --dbpath /data/db 2>/dev/null || true
fi

# Start PHP-FPM
mkdir -p /run/php
php-fpm8.2 -D

# Start Flask apps
cd /var/www/html/sqlite && python3 app.py &
cd /var/www/html/mongo && python3 app.py &

# Start nginx
nginx -g 'daemon off;'
STARTEOF
RUN chmod +x /start.sh

EXPOSE 80 3306 27017

CMD ["/start.sh"]

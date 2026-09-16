# web-enumeration.Containerfile
# Web Enumeration Lab - realistic web app with hidden directories, virtual
# hosts, CMS installs, backup files, git exposure, and API endpoints
#
# Build:  podman build -t web-enum -f web-enumeration.Containerfile .
# Run:    podman run -d --name enum-lab -p 8080:80 web-enum
#
# The image serves nginx on port 80 with PHP-FPM and a Flask API behind it.
# Virtual hosts: admin.example.com, staging.example.com, dev.example.com,
# api.example.com (map these names to 127.0.0.1 to use them).
#
# WARNING: This container is intentionally vulnerable. Run it only on an isolated
# host or lab network. Never expose it to the internet or a production network.
#
FROM python:3.12-slim

LABEL description="Web Enumeration Lab - realistic web app with hidden directories, virtual hosts, CMS, backup files, git exposure, APIs"

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    php-fpm \
    php-sqlite3 \
    php-xml \
    php-mbstring \
    dnsmasq \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Create directory structure
RUN mkdir -p /var/www/html/uploads \
    /var/www/html/files \
    /var/www/html/admin \
    /var/www/html/api/v1 \
    /var/www/html/api/v2 \
    /var/www/html/dev \
    /var/www/html/staging \
    /var/www/html/backup \
    /var/www/html/.git/objects/pack \
    /var/www/html/.git/refs/heads \
    /var/www/html/wordpress/wp-content/plugins \
    /var/www/html/wordpress/wp-admin \
    /var/www/html/drupal/sites/default \
    /var/www/html/private \
    /var/www/api-gateway \
    /var/log/superfake

# === Fake CMS installations ===

# WordPress stub
RUN echo '<?php /* WordPress config stub */' > /var/www/html/wordpress/wp-config.php && \
    echo "define('DB_NAME', 'wordpress');" >> /var/www/html/wordpress/wp-config.php && \
    echo "define('DB_USER', 'wp_admin');" >> /var/www/html/wordpress/wp-config.php && \
    echo "define('DB_PASSWORD', 'SuperSecretWpPass2024!');" >> /var/www/html/wordpress/wp-config.php && \
    echo "define('DB_HOST', 'db-internal.example.com'); ?>" >> /var/www/html/wordpress/wp-config.php

# Fake wp-config backup
RUN cp /var/www/html/wordpress/wp-config.php /var/www/html/wordpress/wp-config.php.bak && \
    cp /var/www/html/wordpress/wp-config.php /var/www/html/wordpress/wp-config.php.old && \
    cp /var/www/html/wordpress/wp-config.php /var/www/html/wordpress/wp-config.php~

# Drupal settings stub
RUN echo '<?php $databases["default"]["default"] = array(' > /var/www/html/drupal/sites/default/settings.php && \
    echo '  "database" => "drupal_db",' >> /var/www/html/drupal/sites/default/settings.php && \
    echo '  "username" => "drupal_user",' >> /var/www/html/drupal/sites/default/settings.php && \
    echo '  "password" => "DrupalSecretP@ss2024!",' >> /var/www/html/drupal/sites/default/settings.php && \
    echo '  "host" => "db-internal.example.com",' >> /var/www/html/drupal/sites/default/settings.php && \
    echo '  "port" => "3306",' >> /var/www/html/drupal/sites/default/settings.php && \
    echo ');' >> /var/www/html/drupal/sites/default/settings.php

# === .env files with credentials ===
RUN cat > /var/www/html/.env << 'ENVEOF'
DB_HOST=db-internal.example.com
DB_PORT=3306
DB_NAME=production_db
DB_USER=prod_user
DB_PASSWORD=aJ8xK3mP9vR2qW7y
SECRET_KEY=sk-9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d
API_KEY=api-d3f4a5b6c7e8f9a0b1c2d3e4f5a6b7c8
JWT_SECRET=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.supersecret
SMTP_PASSWORD=mail_smtp_pass_2024
ENVEOF

RUN cat > /var/www/.env << 'ENVEOF'
APP_ENV=production
APP_KEY=base64:abcdefghijklmnopqrstuvwxyz1234567890ABCDEFGH=
APP_DEBUG=false
APP_URL=https://app.example.com
ENVEOF

# === Fake SSH keys ===
RUN mkdir -p /home/admin/.ssh /root/.ssh && \
    echo '-----BEGIN OPENSSH PRIVATE KEY-----' > /home/admin/.ssh/id_rsa && \
    echo 'b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABlwAAAAdzc2gtcn' >> /home/admin/.ssh/id_rsa && \
    echo 'NhAAAAAwEAAQAAAYEAq1FkV1NLVXBJSnBDRHBPQzFvWWpNNHRTcXlISnNwWElweUFHb2hW' >> /home/admin/.ssh/id_rsa && \
    echo 'TnpDS2pXZTBTQ3BQMlFiYWRiY3FCUWk5SFVOaDBnUHFpNFFJb2tqU3hYVHVMYzJSTQ==' >> /home/admin/.ssh/id_rsa && \
    echo '-----END OPENSSH PRIVATE KEY-----' >> /home/admin/.ssh/id_rsa && \
    cp /home/admin/.ssh/id_rsa /root/.ssh/id_rsa && \
    chmod 600 /home/admin/.ssh/id_rsa

# === Git repository exposure ===
RUN cd /var/www/html && \
    git init && \
    git config user.email "dev@example.com" && \
    git config user.name "Developer" && \
    git add -A && \
    git commit -m "Initial commit" && \
    git add -A && \
    git commit -m "Add configuration and source files" && \
    echo "AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE" >> .env && \
    echo "AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" >> .env && \
    git add .env && \
    git commit -m "Add AWS credentials (whoops)"

# === robots.txt with disallowed paths containing sensitive info ===
RUN cat > /var/www/html/robots.txt << 'ROBOTSEOF'
User-agent: *
Disallow: /admin
Disallow: /admin/panel
Disallow: /backup
Disallow: /config
Disallow: /private
Disallow: /staging
Disallow: /dev
Disallow: /api/v1/internal
Disallow: /phpmyadmin
Disallow: /wp-admin
Disallow: /administrator
Disallow: /temp
Disallow: /logs
Disallow: /debug
Allow: /public
Sitemap: https://example.com/sitemap.xml
ROBOTSEOF

# === sitemap.xml ===
RUN cat > /var/www/html/sitemap.xml << 'SITEMAPEOF'
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>https://example.com/</loc></url>
  <url><loc>https://example.com/blog</loc></url>
  <url><loc>https://example.com/contact</loc></url>
  <url><loc>https://example.com/products</loc></url>
  <url><loc>https://example.com/api/v1/docs</loc></url>
  <url><loc>https://example.com/api/v2/</loc></url>
</urlset>
SITEMAPEOF

# === Sensitive backup files ===
RUN echo '<?php // Database backup config' > /var/www/html/backup/config.php.bak && \
    echo 'CREATE DATABASE backup_2023;' > /var/www/html/backup/dump.sql && \
    echo 'INSERT INTO users VALUES (1,"admin","hash_here","admin@example.com");' >> /var/www/html/backup/dump.sql && \
    echo 'password_hash: $2y$10$abcdefghijklmnopqrstuvwxyz12345' > /var/www/html/dev/secret-notes.txt && \
    echo 'CREATE USER "service_account" WITH PASSWORD "S3rv1ceP@ss#2024!";' > /var/www/html/backup/dbv2.sql

# === Hidden admin panel ===
RUN cat > /var/www/html/admin/index.html << 'ADMINEOF'
<!DOCTYPE html>
<html><head><title>Admin Panel</title></head>
<body>
<h1>Internal Admin Panel</h1>
<form action="/admin/login.php" method="POST">
  <input type="text" name="username" placeholder="Username">
  <input type="password" name="password" placeholder="Password">
  <button type="submit">Login</button>
</form>
<!-- TODO: remove hardcoded credentials -->
<!-- dev:dev1234 -->
</body></html>
ADMINEOF

# === API endpoints ===
RUN mkdir -p /var/www/html/api/v1 && \
    mkdir -p /var/www/html/api/v2 && \
    mkdir -p /var/www/html/api/internal

RUN cat > /var/www/html/api/v1/docs.html << 'APIDOCSEOF'
<!DOCTYPE html>
<html><head><title>API v1 — Internal Documentation</title></head>
<body>
<h1>API v1 Documentation</h1>
<h2>Endpoints</h2>
<ul>
  <li>GET /api/v1/users — List all users</li>
  <li>GET /api/v1/users/:id — Get user by ID</li>
  <li>POST /api/v1/auth — Authenticate (token: test-api-key-2024)</li>
  <li>GET /api/v1/internal/health — Health check</li>
  <li>GET /api/v1/internal/stats — Server statistics</li>
</ul>
</body></html>
APIDOCSEOF

RUN cat > /var/www/html/swagger.json << 'SWAGGEREOF'
{
  "openapi": "3.0.0",
  "info": {"title": "Example API", "version": "1.0.0"},
  "paths": {
    "/api/v1/users": {
      "get": {"summary": "List users", "parameters": [{"name": "role", "in": "query", "schema": {"type": "string"}}]}
    },
    "/api/v1/users/{id}": {
      "get": {"summary": "Get user", "parameters": [{"name": "id", "in": "path", "required": true, "schema": {"type": "integer"}}]}
    },
    "/api/v1/admin/users": {
      "get": {"summary": "Admin user management", "security": [{"ApiKeyAuth": []}]}
    }
  }
}
SWAGGEREOF

# === GraphQL endpoint ===
RUN cat > /var/www/html/graphql/index.php << 'GRAPHQLEOF'
<?php
header('Content-Type: application/json');

$query = json_decode(file_get_contents('php://input'), true);
$query_text = $query['query'] ?? '';

if (strpos($query_text, '__schema') !== false) {
    echo json_encode([
        'data' => [
            '__schema' => [
                'queryType' => ['name' => 'Query'],
                'types' => [
                    ['name' => 'User', 'fields' => [
                        ['name' => 'id', 'args' => []],
                        ['name' => 'username', 'args' => []],
                        ['name' => 'email', 'args' => []],
                        ['name' => 'password', 'args' => []],
                        ['name' => 'role', 'args' => []],
                        ['name' => 'apiToken', 'args' => []]
                    ]],
                    ['name' => 'Post', 'fields' => [
                        ['name' => 'id', 'args' => []],
                        ['name' => 'title', 'args' => []],
                        ['name' => 'content', 'args' => []],
                        ['name' => 'authorId', 'args' => []]
                    ]]
                ]
            ]
        ]
    ]);
} else {
    echo json_encode(['data' => ['users' => []]]);
}
GRAPHQLEOF

# === Source map file ===
RUN cat > /var/www/html/static/js/app.js << 'JSEOF'
(function() {
  var App = {
    init: function() {
      this.apiBase = "/api/v1";
      this.authToken = localStorage.getItem("auth_token");
      this.setupRoutes();
    },
    setupRoutes: function() {
      this.routes = {
        login: this.apiBase + "/auth",
        users: this.apiBase + "/users",
        admin: this.apiBase + "/admin/users",
        internal: this.apiBase + "/internal/stats",
        search: this.apiBase + "/search",
        exportData: this.apiBase + "/export",
        debugMode: this.apiBase + "/debug/config"
      };
    }
  };
  window.App = App;
  App.init();
})();
//# sourceMappingURL=app.js.map
JSEOF

RUN cat > /var/www/html/static/js/app.js.map << 'MAPEOF'
{"version":3,"sources":["src/js/config.js","src/js/auth.js","src/js/api.js","src/js/router.js","src/js/admin.js","src/js/debug.js"],"names":["apiKey","secretToken","baseUrl"],"mappings":"AAAA,CAAC,...","sourcesContent":["export const API_CONFIG = { baseUrl: '/api/v1', apiKey: 'sk-internal-dev-key-2024', secretToken: 'eyJhbGciOiJIUzI1NiJ9.dev-secret' };","export class AuthService { constructor() { this.loginEndpoint = '/api/v1/auth'; this.adminOverride = 'admin:admin123'; } }","export class ApiClient { constructor() { this.internalToken = 'Bearer internal-service-token-2024'; this.adminHeaders = { 'X-Admin-Key': 'admin-secret-key-2024' }; } }","export const ROUTES = { adminDashboard: '/admin/panel', debugConsole: '/dev/debug', phpInfo: '/admin/phpinfo.php', backupDownload: '/backup/download', configView: '/dev/config' };","export const ADMIN_CONFIG = { defaultPassword: 'ChangeMe123!', maintenanceMode: false, allowedIPs: ['10.0.0.0/8', '192.168.1.0/24'] };","export function enableDebug() { window.DEBUG = true; window.DEBUG_CONFIG = { dbHost: 'db-internal.example.com', dbUser: 'debug_user', dbPass: 'debug_pass_2024' }; }"]}
MAPEOF

# === Hidden PHP info page ===
RUN echo '<?php phpinfo(); ?>' > /var/www/html/admin/phpinfo.php

# === Nginx configuration with multiple server blocks (virtual hosts) ===
RUN cat > /etc/nginx/sites-available/default << 'NGINXEOF'
server {
    listen 80 default_server;
    server_name _;

    root /var/www/html;
    index index.html index.php;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:9000/;
    }

    location /graphql {
        try_files $uri /graphql/index.php?$query_string;
    }

    # Directory listing for uploads (easy to find uploaded files)
    location /uploads {
        autoindex on;
    }

    # Directory listing for backup
    location /backup {
        autoindex on;
    }

    # Expose .git directory (vulnerability)
    location ~ /\.git {
        autoindex on;
    }
}

# Virtual host: admin.example.com
server {
    listen 80;
    server_name admin.example.com;

    root /var/www/html/admin;
    index index.html index.php;

    location / {
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        fastcgi_pass unix:/run/php/php8.2-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}

# Virtual host: staging.example.com
server {
    listen 80;
    server_name staging.example.com;

    root /var/www/html/staging;
    index index.html index.php;

    location / {
        try_files $uri $uri/ =404;
    }
}

# Virtual host: dev.example.com
server {
    listen 80;
    server_name dev.example.com;

    root /var/www/html/dev;
    index index.html;

    location / {
        try_files $uri $uri/ =404;
    }
}

# Virtual host: api.example.com
server {
    listen 80;
    server_name api.example.com;

    location / {
        return 200 '{"status":"ok","version":"2.1.0","server":"api-gateway-v2"}';
        add_header Content-Type application/json;
    }

    location /v1/ {
        return 200 '{"endpoints":["/users","/auth","/products","/orders"]}';
        add_header Content-Type application/json;
    }
}
NGINXEOF

RUN ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default && \
    rm -f /etc/nginx/sites-enabled/default 2>/dev/null; \
    mkdir -p /etc/nginx/sites-enabled && \
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default

# === Fake internal Python API (different tech on subpath) ===
RUN pip install flask --break-system-packages

RUN cat > /var/www/api-gateway/app.py << 'PYEOF'
from flask import Flask, jsonify, request

app = Flask(__name__)

@app.route('/')
def index():
    return jsonify({
        "service": "API Gateway",
        "version": "2.1.0",
        "status": "operational",
        "internal_endpoints": ["/health", "/metrics", "/config", "/debug/pprof"]
    })

@app.route('/health')
def health():
    return jsonify({
        "status": "healthy",
        "database": "connected",
        "redis": "disconnected",
        "queue_depth": 42,
        "uptime_seconds": 86400
    })

@app.route('/healthz')
def healthz():
    return "OK", 200

@app.route('/metrics')
def metrics():
    return """# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="POST",handler="/api/login",status="200"} 1542
http_requests_total{method="POST",handler="/api/login",status="401"} 327
# HELP db_connection_active Active database connections
# TYPE db_connection_active gauge
db_connection_active{host="db-internal.example.com",user="api_user"} 12
""", 200, {'Content-Type': 'text/plain'}

@app.route('/debug/pprof/')
def debug_pprof():
    return jsonify({
        "goroutines": 23,
        "heap_alloc_mb": 14.2,
        "thread_count": 8
    })

@app.route('/config')
def config():
    return jsonify({
        "db_host": "db-internal.example.com",
        "db_user": "api_user",
        "db_name": "api_gateway",
        "log_level": "debug",
        "internal_auth_token": "Bearer eyJhbGciOiJIUzI1NiJ9.some-internal-token"
    })

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=9000, debug=True)
PYEOF

# === Staging environment content ===
RUN echo '<h1>Staging Environment</h1><p>This is the staging server. Database: staging-db.internal</p>' > /var/www/html/staging/index.html && \
    echo 'DB_HOST=staging-db.internal' > /var/www/html/staging/.env && \
    echo 'DB_USER=staging_user' >> /var/www/html/staging/.env && \
    echo 'DB_PASS=staging_pass_123' >> /var/www/html/staging/.env

# === Dev environment content ===
RUN echo '<h1>Development Server</h1><p>Debug mode enabled.</p>' > /var/www/html/dev/index.html && \
    echo 'API_KEY=dev-api-key-12345' > /var/www/html/dev/.env && \
    echo 'DEBUG=true' >> /var/www/html/dev/.env && \
    echo 'ADMIN_PASSWORD=devadmin123' >> /var/www/html/dev/.env

# === Private directory with secrets ===
RUN echo 'Internal document: VPN access credentials' > /var/www/html/private/vpn-access.txt && \
    echo 'VPN_USER: service_vpn' >> /var/www/html/private/vpn-access.txt && \
    echo 'VPN_PASS: VpnS3cur3P@ss!' >> /var/www/html/private/vpn-access.txt && \
    echo 'VPN_ENDPOINT: vpn.internal.example.com' >> /var/www/html/private/vpn-access.txt

# === Start script ===
RUN cat > /start.sh << 'STARTEOF'
#!/bin/bash
set -e

# Start PHP-FPM
mkdir -p /run/php
php-fpm8.2 -D

# Start Flask API gateway (Python)
cd /var/www/api-gateway
python3 app.py &

# Start nginx
nginx -g 'daemon off;'
STARTEOF
RUN chmod +x /start.sh

# Create a basic PHP page that handles non-existent subpaths
RUN cat > /var/www/html/index.php << 'INDEXEOF'
<?php
$path = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
if ($path === '/') {
    echo "<h1>Web Enumeration Lab</h1>";
    echo "<p>This lab contains hidden directories, virtual hosts, backup files, APIs, and Technology stack diversity.</p>";
    echo "<p>Use the enumeration techniques to discover all hidden content.</p>";
    echo "<ul>
        <li>Hidden directories: /admin, /backup, /dev, /staging, /private</li>
        <li>Virtual hosts: admin.example.com, staging.example.com, dev.example.com, api.example.com</li>
        <li>CMS: WordPress at /wordpress/, Drupal at /drupal/</li>
        <li>APIs: /api/v1/, /api/v2/, /graphql/, /swagger.json</li>
        <li>Sensitive files: .git/, .env, config backups, SSH keys</li>
    </ul>";
    echo "<p>Start with: <code>curl -s -D - http://localhost/</code></p>";
}
?>
INDEXEOF

EXPOSE 80

CMD ["/start.sh"]

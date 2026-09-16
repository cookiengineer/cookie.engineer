# TLS - Multi-Configuration TLS Endpoint Container
# Build:  podman build -t tls -f tls.Containerfile .
# Run:    podman run -it --rm \
#           -p 8443:8443 -p 9443:9443 -p 10443:10443 \
#           -p 11443:11443 -p 12443:12443 -p 8888:8888 \
#           tls
#
# Purpose: Multi-listener nginx container with different TLS configurations
# on different ports. Students use openssl s_client to connect to each
# and observe handshake differences, cipher suites, certificate properties,
# and TLS version negotiation.
#
# Port map:
#   8443  — TLS 1.2 only (no TLS 1.3), RSA cert
#   9443  — TLS 1.3 only (no TLS 1.2 fallback), ECDSA cert
#   10443 — mTLS endpoint (requires client certificate)
#   11443 — Self-signed certificate (invalid, observe openssl error)
#   12443 — Let's-Encrypt-style valid cert (simulated with CA-signed cert)

FROM archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    nginx \
    openssl \
    tcpdump \
    curl \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

# ────────────────────────────────────────────────────────────
# Certificate Authority (simulated trusted root)
# ────────────────────────────────────────────────────────────
RUN mkdir -p /etc/nginx/certs && \
    cd /etc/nginx/certs && \
    \
    # Generate CA key and self-signed cert
    openssl genrsa -out ca.key 4096 && \
    openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
        -subj "/C=US/O=TLS Lab Root CA/CN=TLS Lab Root CA" && \
    \
    # ── Server cert for port 8443 (RSA, TLS 1.2 only) ──
    openssl genrsa -out server-rsa.key 2048 && \
    openssl req -new -key server-rsa.key -out server-rsa.csr \
        -subj "/C=US/O=TLS Lab/CN=tls12-only.lab" && \
    openssl x509 -req -in server-rsa.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out server-rsa.crt -days 365 && \
    \
    # ── Server cert for port 9443 (ECDSA, TLS 1.3 only) ──
    openssl ecparam -genkey -name prime256v1 -out server-ecdsa.key && \
    openssl req -new -key server-ecdsa.key -out server-ecdsa.csr \
        -subj "/C=US/O=TLS Lab/CN=tls13-only.lab" && \
    openssl x509 -req -in server-ecdsa.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out server-ecdsa.crt -days 365 && \
    \
    # ── Server cert for port 10443 (mTLS, RSA) ──
    openssl genrsa -out server-mtls.key 2048 && \
    openssl req -new -key server-mtls.key -out server-mtls.csr \
        -subj "/C=US/O=TLS Lab/CN=mtls.lab" && \
    openssl x509 -req -in server-mtls.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out server-mtls.crt -days 365 && \
    \
    # ── Server cert for port 11443 (self-signed) ──
    openssl genrsa -out selfsigned.key 2048 && \
    openssl req -new -x509 -days 365 -key selfsigned.key \
        -out selfsigned.crt \
        -subj "/C=US/O=Fake Corp/CN=selfsigned.lab" && \
    \
    # ── Server cert for port 12443 (Let's-Encrypt-style valid cert) ──
    openssl genrsa -out server-le.key 2048 && \
    openssl req -new -key server-le.key -out server-le.csr \
        -subj "/C=US/O=TLS Lab/CN=letsencrypt-sim.lab" && \
    openssl x509 -req -in server-le.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out server-le.crt -days 90 && \
    \
    # ── Client cert for mTLS (port 10443) ──
    openssl genrsa -out client.key 2048 && \
    openssl req -new -key client.key -out client.csr \
        -subj "/C=US/O=TLS Lab Client/CN=authorized-client" && \
    openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out client.crt -days 365

# ────────────────────────────────────────────────────────────
# nginx Configuration
# ────────────────────────────────────────────────────────────
RUN mkdir -p /etc/nginx/sites

COPY <<'NGINX_CONF' /etc/nginx/nginx.conf
worker_processes 1;
pid /run/nginx.pid;
error_log /dev/stdout info;

events {
    worker_connections 128;
}

http {
    access_log /dev/stdout;
    include /etc/nginx/sites/*.conf;
}
NGINX_CONF

# ── Port 8443: TLS 1.2 only ──
COPY <<'TLS12' /etc/nginx/sites/tls12.conf
server {
    listen 8443 ssl;
    server_name tls12-only.lab;

    ssl_certificate     /etc/nginx/certs/server-rsa.crt;
    ssl_certificate_key /etc/nginx/certs/server-rsa.key;

    # Force TLS 1.2, disable TLS 1.3
    ssl_protocols TLSv1.2;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256;
    ssl_prefer_server_ciphers on;

    location / {
        default_type text/plain;
        return 200 "TLS 1.2 ONLY ENDPOINT\nServer: nginx\nCertificate: RSA 2048-bit, signed by TLS Lab Root CA\nTLS Version: $ssl_protocol\nCipher: $ssl_cipher\nClient IP: $remote_addr\n";
    }
}
TLS12

# ── Port 9443: TLS 1.3 only ──
COPY <<'TLS13' /etc/nginx/sites/tls13.conf
server {
    listen 9443 ssl;
    server_name tls13-only.lab;

    ssl_certificate     /etc/nginx/certs/server-ecdsa.crt;
    ssl_certificate_key /etc/nginx/certs/server-ecdsa.key;

    # Force TLS 1.3 only
    ssl_protocols TLSv1.3;
    ssl_ciphers TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256;
    ssl_prefer_server_ciphers off;

    location / {
        default_type text/plain;
        return 200 "TLS 1.3 ONLY ENDPOINT\nServer: nginx\nCertificate: ECDSA P-256, signed by TLS Lab Root CA\nTLS Version: $ssl_protocol\nCipher: $ssl_cipher\nClient IP: $remote_addr\n";
    }
}
TLS13

# ── Port 10443: mTLS ──
COPY <<'MTLS' /etc/nginx/sites/mtls.conf
server {
    listen 10443 ssl;
    server_name mtls.lab;

    ssl_certificate     /etc/nginx/certs/server-mtls.crt;
    ssl_certificate_key /etc/nginx/certs/server-mtls.key;

    ssl_protocols TLSv1.2 TLSv1.3;

    # Require client certificate, verify against our CA
    ssl_client_certificate /etc/nginx/certs/ca.crt;
    ssl_verify_client on;
    ssl_verify_depth 2;

    location / {
        default_type text/plain;
        return 200 "mTLS ENDPOINT — YOU ARE AUTHENTICATED\nServer: nginx\nTLS Version: $ssl_protocol\nCipher: $ssl_cipher\nClient Certificate Subject: $ssl_client_s_dn\nClient Certificate Issuer: $ssl_client_i_dn\nClient Certificate Serial: $ssl_client_serial\nClient IP: $remote_addr\n";
    }
}
MTLS

# ── Port 11443: Self-signed certificate ──
COPY <<'SELFSIGNED' /etc/nginx/sites/selfsigned.conf
server {
    listen 11443 ssl;
    server_name selfsigned.lab;

    ssl_certificate     /etc/nginx/certs/selfsigned.crt;
    ssl_certificate_key /etc/nginx/certs/selfsigned.key;

    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        default_type text/plain;
        return 200 "SELF-SIGNED CERT ENDPOINT\nServer: nginx\nCertificate: Self-signed (NOT trusted by any CA)\nTLS Version: $ssl_protocol\nCipher: $ssl_cipher\nClient IP: $remote_addr\n\nTry: openssl s_client -connect localhost:11443\n(Observe verification error)\n";
    }
}
SELFSIGNED

# ── Port 12443: Let's-Encrypt-style valid cert ──
COPY <<'LETSENCRYPT' /etc/nginx/sites/letsencrypt.conf
server {
    listen 12443 ssl;
    server_name letsencrypt-sim.lab;

    ssl_certificate     /etc/nginx/certs/server-le.crt;
    ssl_certificate_key /etc/nginx/certs/server-le.key;

    ssl_protocols TLSv1.2 TLSv1.3;

    location / {
        default_type text/plain;
        return 200 "LET'S ENCRYPT STYLE ENDPOINT\nServer: nginx\nCertificate: RSA 2048-bit, signed by TLS Lab Root CA\nTLS Version: $ssl_protocol\nCipher: $ssl_cipher\nClient IP: $remote_addr\n\nThis endpoint simulates a valid, CA-signed certificate.\nConnect with: openssl s_client -connect localhost:12443 -CAfile /etc/nginx/certs/ca.crt\n";
    }
}
LETSENCRYPT

# ────────────────────────────────────────────────────────────
# Static index page on port 8888 (plain HTTP — no TLS)
# Shows summary of all TLS endpoints and test commands
# ────────────────────────────────────────────────────────────
COPY <<'INDEX' /etc/nginx/sites/index.conf
server {
    listen 8888;
    server_name _;

    location / {
        default_type text/html;
        return 200 "<!DOCTYPE html>
<html>
<head><title>TLS Lab — Container Index</title></head>
<body style=\"font-family:monospace; max-width:900px; margin:40px auto;\">
<h1>TLS Lab — Multi-Configuration TLS Container</h1>
<h2>Endpoints</h2>
<table border=\"1\" cellpadding=\"8\" cellspacing=\"0\">
<tr><th>Port</th><th>Configuration</th><th>Test Command</th></tr>
<tr><td>8443</td><td>TLS 1.2 only (RSA cert)</td>
<td><code>openssl s_client -connect localhost:8443 -CAfile /etc/nginx/certs/ca.crt</code></td></tr>
<tr><td>9443</td><td>TLS 1.3 only (ECDSA cert)</td>
<td><code>openssl s_client -connect localhost:9443 -CAfile /etc/nginx/certs/ca.crt</code></td></tr>
<tr><td>10443</td><td>mTLS (client cert required)</td>
<td><code>openssl s_client -connect localhost:10443 -cert client.crt -key client.key -CAfile ca.crt</code></td></tr>
<tr><td>11443</td><td>Self-signed cert</td>
<td><code>openssl s_client -connect localhost:11443</code></td></tr>
<tr><td>12443</td><td>CA-signed (Let's Encrypt style)</td>
<td><code>openssl s_client -connect localhost:12443 -CAfile /etc/nginx/certs/ca.crt</code></td></tr>
</table>

<h2>Student Exercises</h2>
<h3>1. Compare TLS Versions</h3>
<pre>
# Connect to TLS 1.3 only endpoint
openssl s_client -connect localhost:9443 -CAfile /etc/nginx/certs/ca.crt

# Attempt TLS 1.2 connection (should fail)
openssl s_client -connect localhost:9443 -tls1_2 -CAfile /etc/nginx/certs/ca.crt
</pre>

<h3>2. Inspect Certificate Chains</h3>
<pre>
# Show certificate details for each endpoint
echo | openssl s_client -connect localhost:8443 -CAfile /etc/nginx/certs/ca.crt 2>/dev/null | openssl x509 -text -noout

echo | openssl s_client -connect localhost:9443 -CAfile /etc/nginx/certs/ca.crt 2>/dev/null | openssl x509 -text -noout
</pre>

<h3>3. Observe TLS 1.3 Handshake</h3>
<pre>
# Verbose connection shows the handshake steps
openssl s_client -connect localhost:9443 -CAfile /etc/nginx/certs/ca.crt -msg
</pre>

<h3>4. Test mTLS</h3>
<pre>
# Without client cert (should fail)
openssl s_client -connect localhost:10443 -CAfile /etc/nginx/certs/ca.crt

# With client cert (should succeed)
openssl s_client -connect localhost:10443 \
    -cert /etc/nginx/certs/client.crt \
    -key /etc/nginx/certs/client.key \
    -CAfile /etc/nginx/certs/ca.crt
</pre>

<h3>5. Self-Signed Certificate Errors</h3>
<pre>
# Without -CAfile (verification fails)
openssl s_client -connect localhost:11443
# Observe: verify error:num=18:self-signed certificate

# With -CAfile pointing to the self-signed cert (works)
openssl s_client -connect localhost:11443 -CAfile /etc/nginx/certs/selfsigned.crt
</pre>

<h3>6. Cipher Suite Inspection</h3>
<pre>
# See negotiated cipher for each port
for port in 8443 9443 10443 11443 12443; do
    echo -n \"Port $port: \"
    echo | openssl s_client -connect localhost:$port -CAfile /etc/nginx/certs/ca.crt 2>/dev/null | grep -E '^[[:space:]]*Cipher'
done
</pre>

<h3>7. Capture and Analyze TLS Traffic</h3>
<pre>
# Capture TLS handshake packets
tcpdump -i lo -nn -w /tmp/tls-capture.pcap 'tcp port 8443 or tcp port 9443'
# Then in another terminal: openssl s_client -connect localhost:8443
# Analyze with Wireshark: tshark -r /tmp/tls-capture.pcap -V
</pre>

</body></html>";
    }
}
INDEX

# ────────────────────────────────────────────────────────────
# Entrypoint
# ────────────────────────────────────────────────────────────
COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

CERT_DIR="/etc/nginx/certs"

echo "============================================="
echo "  TLS Lab — Multi-Configuration TLS Endpoints"
echo "============================================="
echo ""
echo "This container runs nginx with 5 TLS endpoints"
echo "and 1 plain HTTP info page on port 8888."
echo ""
echo "PORT MAP:"
echo "  8443  → TLS 1.2 only (RSA cert)"
echo "  9443  → TLS 1.3 only (ECDSA cert)"
echo "  10443 → mTLS (client certificate required)"
echo "  11443 → Self-signed certificate"
echo "  12443 → CA-signed (Let's Encrypt simulation)"
echo "  8888  → HTTP info page (no TLS)"
echo ""
echo "─────────────────────────────────────────────"
echo "INTERACTIVE EXERCISES"
echo "─────────────────────────────────────────────"
echo ""
echo "1. Compare TLS 1.2 vs 1.3 handshakes:"
echo "   openssl s_client -connect localhost:8443 -CAfile $CERT_DIR/ca.crt"
echo "   openssl s_client -connect localhost:9443 -CAfile $CERT_DIR/ca.crt"
echo ""
echo "2. Try downgrade attack (TLS 1.2 to 1.3-only):"
echo "   openssl s_client -connect localhost:9443 -tls1_2 -CAfile $CERT_DIR/ca.crt"
echo "   # Should fail — server only speaks TLS 1.3"
echo ""
echo "3. mTLS with and without client cert:"
echo "   # Without cert (fails):"
echo "   openssl s_client -connect localhost:10443 -CAfile $CERT_DIR/ca.crt"
echo "   # With cert (succeeds):"
echo "   openssl s_client -connect localhost:10443 -cert $CERT_DIR/client.crt -key $CERT_DIR/client.key -CAfile $CERT_DIR/ca.crt"
echo ""
echo "4. Observe self-signed cert error:"
echo "   openssl s_client -connect localhost:11443"
echo "   # Look for: verify error:num=18:self-signed certificate"
echo ""
echo "5. CA-signed valid cert (simulated Let's Encrypt):"
echo "   openssl s_client -connect localhost:12443 -CAfile $CERT_DIR/ca.crt"
echo ""
echo "6. Inspect certificates:"
echo "   echo | openssl s_client -connect localhost:8443 2>/dev/null | openssl x509 -text -noout"
echo ""
echo "7. See all negotiated ciphers:"
echo "   for port in 8443 9443 10443 11443 12443; do"
echo "       echo -n \"Port \$port: \""
echo "       echo | openssl s_client -connect localhost:\$port -CAfile $CERT_DIR/ca.crt 2>/dev/null | grep 'Cipher'"
echo "   done"
echo ""
echo "8. Plain HTTP info page:"
echo "   curl http://localhost:8888/"
echo ""
echo "9. Copy client cert to host for use:"
echo "   podman cp <container>:$CERT_DIR/client.crt ."
echo "   podman cp <container>:$CERT_DIR/client.key ."
echo "   podman cp <container>:$CERT_DIR/ca.crt ."
echo ""
echo "10. Capture TLS with tcpdump:"
echo "    tcpdump -i lo -nn -w tls.pcap 'tcp port 8443 or tcp port 9443'"
echo "    # Then connect: openssl s_client -connect localhost:8443"
echo "    # Analyze: tshark -r tls.pcap -V | less"
echo "============================================="
echo ""

# Start nginx
echo "[+] Starting nginx..."
exec nginx -g "daemon off;"
ENTRY

RUN chmod +x /entrypoint.sh

EXPOSE 8443 9443 10443 11443 12443 8888

WORKDIR /etc/nginx/certs
ENTRYPOINT ["/entrypoint.sh"]

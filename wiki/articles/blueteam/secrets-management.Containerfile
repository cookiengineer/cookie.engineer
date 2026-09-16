# Secrets Management - CTF Container
# Purpose: Alpine image with a Git repository full of intentionally leaked
#          secrets. Find, categorize, and remediate them.
# Build:   podman build -f secrets-management.Containerfile -t secrets-management .
# Run:     podman run -it --rm secrets-management
# Repo:    /home/student/repo (read /home/student/README)

FROM docker.io/alpine:3.20

ARG GITLEAKS_VERSION=8.18.4

RUN apk add --no-cache git openssh-client curl jq bash python3 && \
    curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
      | tar -xz -C /usr/local/bin gitleaks

RUN adduser -D -s /bin/bash student && \
    mkdir -p /home/student/repo && \
    chown -R student:student /home/student

WORKDIR /home/student/repo

COPY <<'HEREDOC' /home/student/repo/init.sh
#!/bin/bash
# Initialize a Git repo with intentionally leaked secrets

git init --initial-branch=main

echo "# My Application" > README.md

# .env file with database credentials
cat > .env <<'EOF'
DATABASE_HOST=prod-db.internal
DATABASE_PORT=5432
DATABASE_USER=app_user
DATABASE_PASSWORD=s3cret_db_p4ssw0rd_2026
REDIS_PASSWORD=redis_prod_pass_123
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
EOF

# config.json with API keys
cat > config.json <<'JSON'
{
  "stripe": {
    "publishable_key": "pk_test_abcdefghijklmnop",
    "secret_key": "sk_live_51H6Z4kK8j9L2mN3pQ4rS5tU6vW7xY8z"
  },
  "github": {
    "token": "ghp_1A2b3C4d5E6f7G8h9I0jK1L2M3N4O5P6Q7R8S"
  },
  "jwt_secret": "super-secret-jwt-signing-key-do-not-share"
}
JSON

# .ssh directory with private key
mkdir -p .ssh
cat > .ssh/id_rsa <<'PEM'
-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAABlwAAAAdzc2gtcn
NhAAAAAwEAAQAAAYEAvO8q5tqQtZfO8X5P7wM0wKX5B0uI2ZT+bqy9XwqGZpHdLqB5vwLp
h2QJH4G6ks0jV8dL5kWVTmN0Oz5V8LRxGPMJ6Y0gX2JfJHFxgX4M6B0UjRWyN5SfU9zqj0
-----END OPENSSH PRIVATE KEY-----
PEM

# Python script with embedded credentials
cat > app.py <<'PYTHON'
import os
import requests

# TODO: Remove before production
API_KEY = "sk-prod-abc123def456ghi789jkl012mno345pqr678"
DB_PASSWORD = "p@ssw0rd123!"
GITHUB_TOKEN = "github_pat_11ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890"

def connect_db():
    return f"postgresql://admin:{DB_PASSWORD}@localhost:5432/app"

def call_api():
    headers = {"Authorization": f"Bearer {API_KEY}"}
    return requests.get("https://api.internal.example.com/v1/data", headers=headers)
PYTHON

# CI/CD config with secrets
mkdir -p .github/workflows
cat > .github/workflows/deploy.yml <<'YAML'
name: Deploy
on: push
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy to production
        run: |
          export DOCKER_PASSWORD="prod_registry_pass_123"
          export KUBECONFIG="${{ secrets.KUBECONFIG }}"
          echo $REGISTRY_PASSWORD | podman login -u admin --password-stdin
YAML

# Terraform state with secrets
mkdir -p terraform
cat > terraform/terraform.tfstate <<'HCL'
{
  "version": 4,
  "terraform_version": "1.5.0",
  "outputs": {
    "db_password": {
      "value": "tf-managed-db-password-super-secret",
      "sensitive": true
    },
    "api_key": {
      "value": "tf-api-key-abcdef123456",
      "sensitive": true
    }
  }
}
HCL

# Kubernetes Secret manifest
mkdir -p k8s
cat > k8s/secrets.yaml <<'YAML'
apiVersion: v1
kind: Secret
metadata:
  name: app-secrets
type: Opaque
data:
  DATABASE_URL: cG9zdGdyZXNxbDovL2FwcDpwYXNzd29yZDEyM0BkYi5pbnRlcm5hbDo1NDMyL2FwcA==
  REDIS_URL: cmVkaXM6Ly86cmVkaXNfcGFzc3dvcmRAMTkyLjE2OC4xLjEwMDo2Mzc5
  JWT_SECRET: czNjcjN0LWp3dC1zZWNyZXQ=
YAML

# Old backup with credentials
mkdir -p backups
cat > backups/database-backup-2026-03.sql <<'SQL'
-- Database backup from 2026-03-15
-- CREATE USER app_user WITH PASSWORD 'old_backup_password_2025';
-- Never expired, still valid
SQL

# Certificate and key
mkdir -p certs
cat > certs/server.key <<'KEY'
-----BEGIN PRIVATE KEY-----
MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQC7VJUdQZ+N4Xj4
bG9yZWFwcCBUcm91YmxlIHNob290IGEgY2VydGlmaWNhdGUgcGxhbnRlZCBpbiBw
cm9kLg0K
-----END PRIVATE KEY-----
KEY

# Commit everything
git add -A 2>/dev/null
git -c user.name="developer" -c user.email="dev@company.com" commit -m "Initial commit with all the things"
HEREDOC

RUN chown -R student:student /home/student && \
    chmod +x /home/student/repo/init.sh

USER student
WORKDIR /home/student/repo

RUN bash /home/student/repo/init.sh && rm /home/student/repo/init.sh

COPY <<'HEREDOC' /home/student/README
========================================
 SECRETS MANAGEMENT — PRACTICE EXERCISE
========================================

You are a security engineer auditing a Git repository.
A developer committed their entire project including
secrets. Your tasks:

1. Find all leaked secrets in the repository
   Hint: Use gitleaks, trufflehog, or git log -p

2. Categorize each secret by type:
   - API keys (stripe, github, aws)
   - Passwords (db, redis, docker)
   - Private keys (SSH, TLS)
   - Tokens (JWT, PAT)

3. For each secret, determine the remediation:
   - Rotate immediately (secret is in git)
   - Rotate before next deploy (secret might be exposed)
   - Mark as compromised, rotate, audit logs

4. Fix the repository:
   - Remove all secrets from working tree
   - Add proper .gitignore
   - Rewrite history with git filter-branch or BFG Repo-Cleaner
   - Force-push the cleaned history

5. Prevent recurrence:
   - Set up pre-commit hooks (gitleaks)
   - Set up pre-receive hooks on the server
   - Add secrets to Vault / SOPS

Available tools inside the container:
  - gitleaks
  - git log -p | grep
  - grep -r "password\|secret\|key\|token"

Get started:
  cd /home/student/repo
  gitleaks detect --verbose
========================================
HEREDOC

CMD ["/bin/bash"]

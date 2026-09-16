# Logging - CTF Container
# Purpose: Practice log triage with journald, rsyslog, and auditd.
# Build:  podman build -f logging.Containerfile -t logging-ctf .
# Run:    podman run -it --rm --cap-add AUDIT_WRITE --cap-add AUDIT_CONTROL logging-ctf

FROM docker.io/library/archlinux:latest

RUN pacman -Sy --noconfirm audit openssh rsyslog jq && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

RUN ssh-keygen -A && \
    echo 'root:ctf' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

COPY <<'HEREDOC' /etc/audit/rules.d/99-security.rules
-D
-b 8192
-f 1
-a always,exit -F arch=b64 -S execve -k process_execution
-a always,exit -F arch=b32 -S execve -k process_execution
-w /etc/passwd -p wa -k identity_changes
-w /etc/shadow -p wa -k identity_changes
-w /etc/sudoers -p wa -k sudoers_changes
-a always,exit -F arch=b64 -S setuid -S setgid -k privilege_change
-w /tmp -p x -k tmp_execution
HEREDOC

COPY <<'HEREDOC' /etc/systemd/journald.conf
[Journal]
Storage=persistent
Compress=yes
Seal=no
SystemMaxUse=500M
RateLimitIntervalSec=0
RateLimitBurst=0
HEREDOC

COPY <<'HEREDOC' /root/simulate-activity.sh
#!/bin/bash
set -e

echo "[*] Starting auditd and sshd..."
auditd
/usr/sbin/sshd -D &
sleep 2

echo "[*] Simulating normal activity..."
logger -t app "User alice logged in from 10.0.0.1"
logger -t app "Database query completed in 45ms"
touch /tmp/legit-file && rm /tmp/legit-file
id nobody

echo "[*] Simulating suspicious activity..."
logger -t app "User root attempted to access /etc/shadow"
touch /tmp/suspicious-script.sh && chmod +x /tmp/suspicious-script.sh
/tmp/suspicious-script.sh 2>/dev/null || true

echo "[*] Simulating privilege escalation..."
su nobody -c "id" 2>/dev/null || true

echo "[*] Simulating failed auths..."
ssh root@localhost -o StrictHostKeyChecking=no -o ConnectTimeout=1 2>/dev/null || true

echo "[*] Generating log entries complete. Dropping to shell."
echo "[*] Try: journalctl -u sshd -p err"
echo "[*] Try: ausearch -k process_execution"
echo "[*] Try: journalctl _COMM=sudo -o json | jq ."
exec /bin/bash
HEREDOC

RUN chmod +x /root/simulate-activity.sh

WORKDIR /root
CMD ["/root/simulate-activity.sh"]

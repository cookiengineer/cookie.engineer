# Linux Hardening - CTF Container
# Purpose: Harden a deliberately insecure host and verify each step.
# Build:   podman build -t linux-hardening -f linux-hardening.Containerfile .
# Run:     podman run -it --rm linux-hardening
# Users:   defender:defender123, bob:bob123
# Flag:    /root/flag.txt
#
# WARNING: Intentionally insecure training lab. Run only on an isolated host
# and never expose it to a real network.

FROM archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    openssh \
    sudo \
    apparmor \
    audit \
    libcap \
    procps-ng \
    findutils \
    acl \
    vim \
    coreutils \
    libseccomp \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

# Create users
RUN useradd -m -s /bin/bash defender \
    && echo "defender:defender123" | chpasswd \
    && echo "defender ALL=(ALL:ALL) ALL" > /etc/sudoers.d/defender

# Create the flag
RUN echo 'flag{kernel_hardening_is_a_continuous_process}' > /root/flag.txt \
    && chmod 400 /root/flag.txt

# === DELIBERATE INSECURITIES ===

# 1. SSH with root login and password auth enabled
RUN ssh-keygen -A \
    && echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config \
    && echo 'PasswordAuthentication yes' >> /etc/ssh/sshd_config \
    && echo 'root:root123' | chpasswd
# ||PermitRootLogin=yes||
# ||AllowRootLogin=yes||

# 2. World-writable /etc/shadow (info leak)
RUN chmod 666 /etc/shadow || true
RUN ls -la /etc/shadow
# ||ShadowWorldWritable=true||

# 3. /tmp with exec permissions and no separate mount
RUN chmod 1777 /tmp
# ||TmpExecutable=true||

# 4. World-writable /etc/sudoers.d
RUN chmod 777 /etc/sudoers.d/
# ||SudoersDirWorldWritable=true||

# 5. Default sysctl — no hardening
# (kptr_restrict defaults to 0, ASLR may not be fully enabled)
RUN mkdir -p /etc/sysctl.d

# 6. SUID binary on a script (shell can be exploited)
COPY <<'SHELLSCRIPT' /usr/local/bin/status.sh
#!/bin/bash
# System status script — runs as root (SUID)
echo "=== System Status ==="
echo "Date: $(date)"
echo "Uptime: $(uptime)"
echo "Disk: $(df -h /)"
echo "Memory: $(free -h | head -2)"
SHELLSCRIPT

RUN chmod 4755 /usr/local/bin/status.sh
# ||VulnerableSuidScript=true||

# 7. No auditd rules loaded
RUN mkdir -p /etc/audit/rules.d

# 8. Core dumps enabled (info leak)
RUN echo '* soft core unlimited' >> /etc/security/limits.conf

# 9. AppArmor installed but not enabled
# (no profiles loaded, service not started)

# Setup entrypoint script with hardening checklist
COPY <<'ENTRYPOINT' /entrypoint.sh
#!/bin/bash
echo "==========================================="
echo "  Linux Hardening CTF"
echo "==========================================="
echo ""
echo "This container starts in a deliberately insecure state."
echo "As user 'defender' (password: defender123), your tasks:"
echo ""
echo "Phase 1 — Basic Audit"
echo "  1.1  Find SUID binaries: find / -perm -4000 -ls 2>/dev/null"
echo "  1.2  Check file permissions: ls -la /etc/shadow"
echo "  1.3  Check listening ports: ss -tulnp"
echo "  1.4  Check running services: systemctl list-units --state=running"
echo ""
echo "Phase 2 — Fix Insecurities"
echo "  2.1  Fix /etc/shadow permissions (chmod 000 /etc/shadow)"
echo "  2.2  Remove SUID from status.sh (chmod -s /usr/local/bin/status.sh)"
echo "  2.3  Fix sudoers.d permissions (chmod 750 /etc/sudoers.d)"
echo "  2.4  Harden SSH (/etc/ssh/sshd_config.d/99-hard.conf)"
echo "  2.5  Disable password auth, disable root login"
echo ""
echo "Phase 3 — Kernel Hardening"
echo "  3.1  Write sysctl hardening (kptr_restrict=2, ASLR=2)"
echo "  3.2  Apply: sysctl -p /etc/sysctl.d/99-hardening.conf"
echo "  3.3  Remount /tmp noexec: mount -o remount,noexec /tmp"
echo ""
echo "Phase 4 — Audit Rules"
echo "  4.1  Write auditd rules for /etc/shadow, /etc/sudoers"
echo "  4.2  Load with auditctl -R /etc/audit/rules.d/99-hard.rules"
echo "  4.3  Verify with auditctl -l"
echo ""
echo "Phase 5 — Verify"
echo "  5.1  Run: find / -perm -4000 -ls 2>/dev/null (check SUID cleanup)"
echo "  5.2  Can attacker user 'bob' (password: bob123) read /etc/shadow?"
echo "  5.3  Can bob exploit the SUID status.sh script?"
echo "  5.4  Is /root/flag.txt readable by bob?"
echo ""
echo "Goal: Bob cannot read /root/flag.txt through any path."
echo "==========================================="
echo ""

exec /bin/bash
ENTRYPOINT

RUN chmod +x /entrypoint.sh

# Create an attacker user for testing
RUN useradd -m -s /bin/bash bob \
    && echo "bob:bob123" | chpasswd

WORKDIR /root
ENTRYPOINT ["/entrypoint.sh"]

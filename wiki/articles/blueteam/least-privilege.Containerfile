# Least Privilege - CTF Container
# Purpose: Find and fix several privilege escalation paths.
# Build:   podman build -t least-privilege -f least-privilege.Containerfile .
# Run:     podman run -it --rm least-privilege
# Users:   alice:alice123, bob:bob123
# Flag:    /root/flag.txt
#
# WARNING: Intentionally insecure training lab. Run only on an isolated host
# and never expose it to a real network.

FROM archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    sudo \
    vim \
    findutils \
    coreutils \
    acl \
    libcap \
    procps-ng \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

# Create users
RUN useradd -m -s /bin/bash alice \
    && echo "alice:alice123" | chpasswd \
    && useradd -m -s /bin/bash bob \
    && echo "bob:bob123" | chpasswd

# Create the flag
RUN echo 'flag{least_privilege_is_not_just_sudoers}' > /root/flag.txt \
    && chmod 400 /root/flag.txt

# DELIBERATELY INSECURE — these must be identified and fixed by the student
# Vulnerability 1: Overly permissive sudo for alice (can run ANYTHING)
RUN echo 'alice ALL=(ALL:ALL) ALL' > /etc/sudoers.d/alice

# Vulnerability 2: bob can run vim as root (shell escape via :!bash)
RUN echo 'bob ALL=(root) /usr/bin/vim' > /etc/sudoers.d/bob

# Vulnerability 3: SUID binary on a custom script
COPY <<'SCRIPT' /usr/local/bin/cleanup.sh
#!/bin/bash
# Cleanup temporary files — runs as root due to SUID
find /tmp -type f -mtime +7 -delete 2>/dev/null
SCRIPT

RUN chmod 4755 /usr/local/bin/cleanup.sh

# Vulnerability 4: World-writable sudoers.d directory
RUN chmod 777 /etc/sudoers.d/

# Vulnerability 5: Unnecessary capabilities on ping (cap_net_raw)
# (ping already has capabilities by default, but this is a teaching point)

# Vulnerability 6: alice's home directory is world-readable
RUN chmod 755 /home/alice

# Setup entrypoint
COPY <<'ENTRYPOINT' /entrypoint.sh
#!/bin/bash
echo "=== Least Privilege CTF ==="
echo ""
echo "Users: alice (password: alice123), bob (password: bob123)"
echo ""
echo "This container has multiple privilege escalation paths:"
echo "  1. Overly permissive sudo rules"
echo "  2. SUID binaries with shell-escapes"
echo "  3. World-writable configuration directories"
echo "  4. Home directory permission issues"
echo ""
echo "Your task:"
echo "  1. Audit the system (sudo -l, find SUID, check perms)"
echo "  2. Identify ALL privilege escalation paths"
echo "  3. Fix each vulnerability"
echo "  4. Goal: prove alice and bob cannot reach /root/flag.txt"
echo ""
echo "Hint: 'su - alice' or 'su - bob' to switch users"
echo ""

exec /bin/bash
ENTRYPOINT

RUN chmod +x /entrypoint.sh

WORKDIR /root
ENTRYPOINT ["/entrypoint.sh"]

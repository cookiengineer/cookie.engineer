# Container Internals Lab - Namespace isolation and escape education
# Build:  podman build -f sysinternals/containers-internals.Containerfile -t container-escape-lab .
# Run:    podman run -it --rm container-escape-lab
#
# Purpose: Inspects the namespace inodes, capability mask, cgroup membership, and overlay
# mounts of the running container, then explains the escape vectors that a weak container
# configuration exposes. Educational only; never run it privileged on a real host.
#
# WARNING: This image is intentionally used to study escape surfaces. Never expose it to a
# real network and never run it with --privileged outside a disposable lab VM.

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    iproute2 \
    util-linux \
    procps-ng \
    jq \
    curl \
    && pacman -Scc --noconfirm

# Container escape education lab
COPY <<'HEREDOC' /usr/local/bin/container-escape-lab.sh
#!/bin/bash
echo "=== Container Escape Education Lab ==="
echo "This demonstrates isolation & escape concepts safely."
echo

echo "--- Namespace Inspection ---"
echo "1. Current PID namespace:"
readlink /proc/self/ns/pid
echo "2. Current mount namespace:"
readlink /proc/self/ns/mnt
echo "3. Current network namespace:"
readlink /proc/self/ns/net
echo "4. Current user namespace:"
readlink /proc/self/ns/user
echo "5. Current UTS namespace:"
readlink /proc/self/ns/uts
echo "6. Current IPC namespace:"
readlink /proc/self/ns/ipc
echo "7. Current cgroup namespace:"
readlink /proc/self/ns/cgroup
echo

echo "--- Capability Analysis ---"
echo "Effective capabilities:"
capsh --print 2>/dev/null | grep 'Effective:' || \
  grep CapEff /proc/self/status
echo

echo "--- Cgroup Inspection ---"
echo "Current cgroup path:"
cat /proc/self/cgroup
echo

echo "--- Device Access ---"
echo "Available devices (in container):"
ls /dev/ 2>/dev/null | head -20
echo

echo "--- Mount Analysis ---"
echo "Overlay mounts active:"
cat /proc/self/mountinfo | grep overlay | head -5 || \
  echo "  No overlay mounts visible"
echo

echo "--- Escape Vector Awareness ---"
echo ""
echo "Escape Vector 1: Privileged mode (--privileged)"
echo "  An attacker with --privileged can:"
echo "  - nsenter --target 1 --mount --uts --net --pid bash"
echo "  - mount /dev/sda1 /mnt && chroot /mnt"
echo "  Detection: check CapEff for all caps (capsh --print)"
echo

echo "Escape Vector 2: CAP_SYS_ADMIN"
echo "  With CAP_SYS_ADMIN, an attacker can mount host block devices."
echo "  Detection: check if CAP_SYS_ADMIN (bit 21) is set"
echo "  cat /proc/self/status | grep -i CapEff"
echo

echo "Escape Vector 3: Mounted container runtime socket"
echo "  If /run/podman/podman.sock is mounted, attacker can spawn"
echo "  privileged containers on the host."
echo "  Detection: ls -la /run/podman/podman.sock"
echo

echo "Escape Vector 4: Host PID namespace (--pid=host)"
echo "  Attacker can see all host processes including host PID 1."
echo "  Detection: compare /proc with readlink /proc/self/ns/pid"
echo "  against readlink /proc/1/ns/pid — if same, in host PID NS"
echo

echo "Escape Vector 5: Cgroup release_agent (--privileged)"
echo "  When a cgroup's last task exits, notify_on_release triggers"
echo "  release_agent which executes on the HOST."
echo "  Detection: check if cgroups are mounted writable"
echo "  mount | grep cgroup"
echo

echo "Escape Vector 6: Kernel exploit"
echo "  Since container shares the host kernel, any kernel LPE works."
echo "  Detection: compare uname -r inside vs outside — always same."
echo "  uname -r inside container: $(uname -r)"
echo

echo "--- Mitigation Checklist ---"
echo "  [ ] --read-only rootfs"
echo "  [ ] --no-new-privileges"
echo "  [ ] --cap-drop=ALL with selective --cap-add"
echo "  [ ] --user=<non-root-uid>"
echo "  [ ] --userns=auto (rootless)"
echo "  [ ] AppArmor/SELinux profile applied"
echo "  [ ] seccomp profile applied"
echo "  [ ] No host devices mounted"
echo "  [ ] No host namespaces shared (--pid=host, --net=host)"
echo "  [ ] No privileged mode"
echo "  [ ] /proc and /sys mounted with restricted visibility"
echo

echo "--- Practical Escape Demonstrations (educational) ---"
echo "These would work on a system with vulnerable configuration:"
echo ""
echo "# If --privileged, escape with:"
echo "  nsenter --target 1 --mount --uts --ipc --net --pid bash"
echo ""
echo "# If CAP_SYS_ADMIN, escape by mounting host root:"
echo "  mkdir /tmp/host && mount /dev/sda2 /tmp/host && chroot /tmp/host"
echo ""
echo "# If a container runtime socket is mounted:"
echo "  podman run -it -v /:/host alpine chroot /host"
echo ""
echo "# If --pid=host, enumerate host processes:"
echo "  ps aux"

echo
echo "=== Lab Complete ==="
echo "Run with --privileged to see what extra access you gain."
HEREDOC

RUN chmod +x /usr/local/bin/container-escape-lab.sh

COPY <<'HEREDOC' /usr/local/bin/verify-ns-isolation.sh
#!/bin/bash
echo "=== Namespace Isolation Verification ==="
echo

echo "Parent PID namespace:"; readlink /proc/1/ns/pid
echo "Self PID namespace:  "; readlink /proc/self/ns/pid
echo "Self mount namespace:"; readlink /proc/self/ns/mnt
echo "Self net namespace:  "; readlink /proc/self/ns/net
echo "Self user namespace: "; readlink /proc/self/ns/user
echo

# Check if in host PID namespace
if [ "$(readlink /proc/self/ns/pid)" = "$(readlink /proc/1/ns/pid)" ]; then
    echo "WARNING: Running in HOST PID namespace — can see all processes"
else
    echo "OK: Isolated PID namespace"
fi

# Check capabilities
cap_eff=$(grep CapEff /proc/self/status | awk '{print $2}')
if [ "$cap_eff" = "000001ffffffffff" ] || [ "$cap_eff" = "0000003fffffffff" ]; then
    echo "WARNING: Many capabilities present — possible privileged container"
fi
echo "CapEff: $cap_eff"

# Check if privileged
if [ -w /proc/sysrq-trigger ] 2>/dev/null; then
    echo "CRITICAL: /proc/sysrq-trigger is writable — privileged access"
fi

# Check for mounted sockets
for sock in /run/podman/podman.sock /run/docker.sock /var/run/docker.sock; do
    if [ -S "$sock" ]; then
        echo "CRITICAL: Container socket $sock accessible — escape vector"
    fi
done

# Check mount propagation
cat /proc/self/mountinfo | grep shared > /dev/null && \
  echo "NOTE: Shared mount propagation detected"

echo "Verification complete."
HEREDOC

RUN chmod +x /usr/local/bin/verify-ns-isolation.sh

ENTRYPOINT ["/usr/local/bin/container-escape-lab.sh"]

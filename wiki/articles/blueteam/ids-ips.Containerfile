# IDS/IPS - CTF Container
# Purpose: Suricata rule-writing lab over a mixed normal/attack PCAP.
# Build:   podman build -t ids-ips -f ids-ips.Containerfile .
# Run:     podman run -it --rm ids-ips
# Input:   /opt/training-traffic.pcap (generated at build time)
# Flag:    /root/flag.txt
#
# WARNING: Intentionally insecure training lab. Run only on an isolated host
# and never expose it to a real network.

FROM archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    suricata \
    jq \
    python \
    python-scapy \
    tcpdump \
    procps-ng \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN echo 'flag{ids_ips_is_pattern_matching_with_context}' > /root/flag.txt \
    && chmod 400 /root/flag.txt

RUN mkdir -p /var/lib/suricata/rules /var/log/suricata

COPY <<'SURICONF' /etc/suricata/suricata.yaml
%YAML 1.1
---

vars:
  address-groups:
    HOME_NET: "[10.0.0.0/8,192.168.0.0/16]"
    EXTERNAL_NET: "!$HOME_NET"
    HTTP_SERVERS: "$HOME_NET"
    SQL_SERVERS: "$HOME_NET"

default-rule-path: /var/lib/suricata/rules
rule-files:
  - local.rules

af-packet:
  - interface: eth0
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes

outputs:
  - fast:
      enabled: yes
      filename: fast.log
  - eve-log:
      enabled: yes
      filetype: regular
      filename: eve.json
      types:
        - alert
        - http
        - dns

logging:
  default-log-level: notice
SURICONF

COPY <<'LOCALRULES' /var/lib/suricata/rules/local.rules
alert tcp any any -> any 22 (msg:"SSH Connection Attempt"; flow:to_server,established; sid:1000000; rev:1;)
LOCALRULES

COPY <<'GENPCAP' /opt/generate-traffic.py
#!/usr/bin/env python3
import struct
import socket
import os

PCAP_MAGIC = b'\xd4\xc3\xb2\xa1'
PCAP_HEADER = PCAP_MAGIC + b'\x02\x00\x04\x00' + b'\x00' * 8 + b'\xff\xff\x00\x00\x01\x00\x00\x00'
TS = 1730000000

def write_pcap(fname, packets):
    with open(fname, 'wb') as f:
        f.write(PCAP_HEADER)
        for data in packets:
            sec = int(TS)
            usec = (TS - sec) * 1_000_000
            length = len(data)
            f.write(struct.pack('<IIII', sec, int(usec), length, length))
            f.write(data)

def syn(ip_dst, port):
    ip = b'\x45\x00\x00\x34\x00\x01\x00\x00\x40\x06\x00\x00\x0a\x00\x00\x01' + socket.inet_aton(ip_dst)
    tcp = struct.pack('>HHIIHHHH', 12345, port, 0, 0, 0x50, 0xffff, 0, 0)
    return ip + tcp

def http_get(path, host="10.0.0.5"):
    req = f"GET {path} HTTP/1.1\r\nHost: {host}\r\nUser-Agent: curl/7.88\r\n\r\n".encode()
    ip = b'\x45\x00\x00\x00\x00\x01\x00\x00\x40\x06\x00\x00\x0a\x00\x64\x01' + socket.inet_aton('10.0.0.5')
    ip = ip[:2] + struct.pack('>H', 0x28 + len(req)) + ip[4:]
    tcp = struct.pack('>HHIIHHHH', 55555, 80, 0, 0, 0x50, 0xffff, 0, 0)
    return ip + tcp + req

def ssh_root_packet():
    data = b"sshd: root login attempt from 192.168.1.100"
    ip = b'\x45\x00\x00\x00\x00\x01\x00\x00\x40\x06\x00\x00\x0a\x00\x64\x01' + socket.inet_aton('10.0.0.5')
    ip = ip[:2] + struct.pack('>H', 0x28 + len(data)) + ip[4:]
    tcp = struct.pack('>HHIIHHHH', 44444, 22, 0, 0, 0x50, 0xffff, 0, 0)
    return ip + tcp + data

packets = [
    http_get("/"),
    http_get("/admin"),
    http_get("/admin?user=admin'+OR+'1'='1"),
    http_get("/cmd?exec=cat+/etc/passwd"),
    ssh_root_packet(),
]

write_pcap("/opt/training-traffic.pcap", packets)
print("[+] Generated /opt/training-traffic.pcap with", len(packets), "packets")
print("    Contains: normal HTTP, SQLi attempt, command injection, SSH root login")
GENPCAP

RUN chmod +x /opt/generate-traffic.py && python3 /opt/generate-traffic.py

COPY <<'ENTRYPOINT' /entrypoint.sh
#!/bin/bash
echo "==========================================="
echo "  IDS/IPS CTF — Suricata Rule Writing"
echo "==========================================="
echo ""
echo "A PCAP file has been generated at /opt/training-traffic.pcap"
echo "It contains a mix of normal and attack traffic."
echo ""
echo "Your tasks:"
echo ""
echo "Phase 1 — Run baseline scan"
echo "  1.1  suricata -r /opt/training-traffic.pcap -l /tmp/out1/"
echo "  1.2  Check alerts: cat /tmp/out1/fast.log"
echo "  1.3  Check eve.json: cat /tmp/out1/eve.json | jq ."
echo "  1.4  Notice: default rules only catch SSH"
echo ""
echo "Phase 2 — Write detection rules"
echo "  2.1  Edit /var/lib/suricata/rules/local.rules"
echo "  2.2  Create rules for:"
echo "       - SQL injection in HTTP URIs"
echo "       - Command injection patterns (cat, /etc/passwd)"
echo "       - Requests to /admin paths"
echo "  2.3  Use flow:to_server,established to reduce noise"
echo "  2.4  Use http.uri for HTTP-specific matching"
echo ""
echo "Phase 3 — Verify detection"
echo "  3.1  Re-run: suricata -r /opt/training-traffic.pcap -l /tmp/out2/"
echo "  3.2  cat /tmp/out2/fast.log"
echo "  3.3  Goal: all 4 attack packets should generate alerts"
echo ""
echo "Phase 4 — Tune and reduce false positives"
echo "  4.1  Add depth/within keywords to limit search scope"
echo "  4.2  Add classtype for proper categorization"
echo ""
echo "Tips:"
echo "  - Content matches are case-sensitive unless you add nocase"
echo "  - Use pcre for complex patterns: pcre:\"/(or|union|select)/i\""
echo "  - tcpdump -r /opt/training-traffic.pcap -X to inspect packets"
echo "==========================================="
echo ""

exec /bin/bash
ENTRYPOINT

RUN chmod +x /entrypoint.sh

WORKDIR /root
ENTRYPOINT ["/entrypoint.sh"]

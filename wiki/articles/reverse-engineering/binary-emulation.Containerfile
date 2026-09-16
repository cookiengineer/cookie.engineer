# binary-emulation.Containerfile
# Cross-architecture reverse engineering lab
# Build: podman build -t binary-emulation -f binary-emulation.Containerfile .
# Run:   podman run --rm -it -v $(pwd):/workspace:Z binary-emulation

FROM archlinux:latest

LABEL org.opencontainers.image.description="Cross-architecture binary emulation lab for reverse engineering"
LABEL org.opencontainers.image.authors="reverse-engineering-lab"

# Install base system and development tools
RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    python python-pip python-virtualenv \
    qemu-user qemu-user-binfmt qemu-user-static \
    binutils file readelf gdb \
    git curl wget \
    vim nano \
    xxd hexdump

# Install Python reverse engineering tools in a virtualenv
RUN python -m venv /opt/renv && \
    /opt/renv/bin/pip install --no-cache-dir \
    unicorn==2.1.1 \
    capstone==5.0.3 \
    pyelftools==0.31 \
    pwntools==4.13.1 \
    keystone-engine==0.9.2 \
    qiling==1.4.8 \
    angr==9.2.101

# Set virtualenv in PATH
ENV PATH="/opt/renv/bin:$PATH"

# ===== Cross-architecture sample binaries =====
# Build simple test programs for each architecture

RUN mkdir -p /opt/samples/src

# Sample: hello-world for x86-64
RUN echo '#include <stdio.h>\n\
int main(void) {\n\
    printf("Hello from x86_64\\n");\n\
    return 0;\n\
}' > /opt/samples/src/hello_x64.c && \
    gcc -o /opt/samples/hello_x64 /opt/samples/src/hello_x64.c && \
    strip /opt/samples/hello_x64

# Sample: XOR decode algorithm (simulates malware decoder)
RUN echo '#include <stdio.h>\n\
#include <string.h>\n\
\n\
void decode(char *buf, size_t len, unsigned char key) {\n\
    for (size_t i = 0; i < len; i++) buf[i] ^= key;\n\
}\n\
\n\
int main(void) {\n\
    char secret[] = {0x9e,0x91,0x9a,0x9b,0x96,0x91,0xff,0x9e,0x8c,0x91,0x8e,0x87,0xff,0x00};\n\
    decode(secret, strlen(secret), 0xfe);\n\
    printf("Decoded: %s\\n", secret);\n\
    return 0;\n\
}' > /opt/samples/src/xor_decode.c && \
    gcc -O0 -o /opt/samples/xor_decode /opt/samples/src/xor_decode.c && \
    strip /opt/samples/xor_decode

# Sample: simple license key checker
RUN echo '#include <stdio.h>\n\
#include <string.h>\n\
\n\
unsigned int check_key(const char *key) {\n\
    size_t len = strlen(key);\n\
    if (len < 8) return 0;\n\
    unsigned int hash = 0x811c9dc5;\n\
    for (size_t i = 0; i < len; i++) {\n\
        hash ^= (unsigned char)key[i];\n\
        hash *= 0x01000193;\n\
    }\n\
    return hash == 0xdeadbeef;\n\
}\n\
\n\
int main(int argc, char **argv) {\n\
    if (argc != 2) { printf("Usage: %s <key>\\n", argv[0]); return 1; }\n\
    if (check_key(argv[1])) { printf("Valid key!\\n"); return 0; }\n\
    else { printf("Invalid key.\\n"); return 1; }\n\
}' > /opt/samples/src/key_checker.c && \
    gcc -O0 -o /opt/samples/key_checker /opt/samples/src/key_checker.c && \
    strip /opt/samples/key_checker

# Sample: UPX-packed binary (pack key_checker)
RUN if ! command -v upx >/dev/null 2>&1; then \
        curl -L -o /usr/local/bin/upx \
        https://github.com/upx/upx/releases/download/v4.2.4/upx-4.2.4-amd64_linux.tar.xz \
        || true; \
    fi && \
    pacman -S --noconfirm upx 2>/dev/null || true && \
    (upx -o /opt/samples/packed_key_checker /opt/samples/key_checker 2>/dev/null || \
     cp /opt/samples/key_checker /opt/samples/packed_key_checker)

# ===== Analysis scripts =====

# Script: analyze-arch.sh — Detect architecture of a binary
RUN cat > /opt/scripts/analyze-arch.sh << 'SCRIPT'
#!/bin/bash
# analyze-arch.sh — Determine architecture and recommend emulation approach
BINARY="$1"

if [ ! -f "$BINARY" ]; then
    echo "Usage: $0 <binary>"
    exit 1
fi

echo "=== File Type ==="
file "$BINARY"

echo ""
echo "=== ELF Header ==="
readelf -h "$BINARY" 2>/dev/null | grep -E "Class:|Machine:|Entry point"

MACHINE=$(readelf -h "$BINARY" 2>/dev/null | grep "Machine:" | awk '{print $NF}')

echo ""
echo "=== Emulation Recommendation ==="
case "$MACHINE" in
    "Advanced Micro Devices X86-64"|"X86-64")
        echo "  Native:   ./$BINARY"
        echo "  QEMU:     qemu-x86_64 ./$BINARY"
        echo "  Debug:    qemu-x86_64 -g 1234 ./$BINARY"
        ;;
    "Intel 80386"|"Intel 80386 (i386)")
        echo "  QEMU:     qemu-i386 ./$BINARY"
        ;;
    "ARM"|"ARM (ARM)"|"ARM AArch64")
        LINKS=$(readelf -d "$BINARY" 2>/dev/null | grep NEEDED || echo "static")
        if echo "$LINKS" | grep -q "NEEDED"; then
            echo "  QEMU:     qemu-arm -L /opt/sysroots/arm ./$BINARY"
            echo "  (Library dependencies detected — provide ARM rootfs with -L)"
        else
            echo "  QEMU:     qemu-arm ./$BINARY  (statically linked)"
        fi
        ;;
    "AArch64")
        echo "  QEMU:     qemu-aarch64 ./$BINARY"
        ;;
    "MIPS R3000"|"MIPS R4000"|"MIPS I"|"MIPS II")
        echo "  QEMU:     qemu-mips ./$BINARY"
        ;;
    *)
        echo "  Unknown architecture: $MACHINE"
        echo "  Try: qemu-x86_64, qemu-aarch64, qemu-arm, qemu-mips"
        ;;
esac
SCRIPT
RUN chmod +x /opt/scripts/analyze-arch.sh

# Script: extract-function.py — Extract a function's bytes from ELF
RUN cat > /opt/scripts/extract-function.py << 'PYEOF'
#!/opt/renv/bin/python3
"""Extract raw bytes of a named function from an ELF binary."""
import sys
from elftools.elf.elffile import ELFFile

def extract_function(elf_path: str, func_name: str) -> tuple:
    """Return (bytes, address, size) for a function by name."""
    with open(elf_path, 'rb') as f:
        elf = ELFFile(f)

        symtab = elf.get_section_by_name('.symtab')
        if not symtab:
            print("[-] No .symtab found (stripped?)", file=sys.stderr)
            sys.exit(1)

        symbols = symtab.get_symbol_by_name(func_name)
        if not symbols:
            print(f"[-] Symbol '{func_name}' not found", file=sys.stderr)
            sys.exit(1)

        sym = symbols[0]
        func_addr = sym['st_value']
        func_size = sym['st_size']

        if func_size == 0:
            print(f"[-] Function '{func_name}' has size 0 (stripped?)", file=sys.stderr)
            sys.exit(1)

        # Find the segment containing this address
        for seg in elf.iter_segments():
            seg_start = seg['p_vaddr']
            seg_end = seg_start + seg['p_filesz']
            if seg_start <= func_addr < seg_end:
                offset = func_addr - seg_start + seg['p_offset']
                f.seek(offset)
                code = f.read(func_size)
                print(f"[+] {func_name}: 0x{func_addr:x} ({func_size} bytes)")
                return code, func_addr, func_size

    print(f"[-] Address 0x{func_addr:x} not in any segment", file=sys.stderr)
    sys.exit(1)

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <elf> <function_name>")
        sys.exit(1)

    code, addr, size = extract_function(sys.argv[1], sys.argv[2])

    # Output as binary to stdout or to file
    if len(sys.argv) >= 4:
        with open(sys.argv[3], 'wb') as out:
            out.write(code)
        print(f"  → written to {sys.argv[3]}")
    else:
        sys.stdout.buffer.write(code)
PYEOF
RUN chmod +x /opt/scripts/extract-function.py

# Script: cross-arch-workflow.sh — Full cross-architecture analysis workflow
RUN cat > /opt/scripts/cross-arch-workflow.sh << 'SCRIPT'
#!/bin/bash
# cross-arch-workflow.sh — Analyze an unknown binary end-to-end
set -e

BINARY="$1"
if [ ! -f "$BINARY" ]; then
    echo "Usage: $0 <binary>"
    echo "  Full cross-architecture analysis workflow: identify → emulate → extract"
    exit 1
fi

OUTDIR="analysis_$(basename "$BINARY")_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

echo "======================================================================="
echo " Cross-Architecture Analysis Workflow"
echo " Target: $BINARY"
echo " Output: $OUTDIR/"
echo "======================================================================="

# Phase 1: Architecture identification
echo ""
echo "--- Phase 1: Architecture Identification ---"
/opt/scripts/analyze-arch.sh "$BINARY" | tee "$OUTDIR/01_architecture.txt"

# Phase 2: Static information extraction
echo ""
echo "--- Phase 2: Static Information ---"
echo "Strings extraction..."
strings "$BINARY" > "$OUTDIR/02_strings.txt" 2>/dev/null || true
echo "  → Strings: $(wc -l < "$OUTDIR/02_strings.txt") lines"

echo "Sections:"
readelf -S "$BINARY" > "$OUTDIR/02_sections.txt" 2>/dev/null || true

echo "Symbols:"
readelf -s "$BINARY" > "$OUTDIR/02_symbols.txt" 2>/dev/null || true
echo "  → Symbols: $(grep -c 'FUNC' "$OUTDIR/02_symbols.txt" 2>/dev/null || echo 0) functions"

echo "Imports (dynamic):"
readelf -d "$BINARY" 2>/dev/null | grep NEEDED > "$OUTDIR/02_imports.txt" || true

# Phase 3: Try basic emulation
echo ""
echo "--- Phase 3: Emulation Test ---"
MACHINE=$(readelf -h "$BINARY" 2>/dev/null | grep "Machine:" | awk '{print $NF}')

case "$MACHINE" in
    "Advanced Micro Devices X86-64"|"X86-64")
        EMU="qemu-x86_64"
        ;;
    "ARM"|"ARM (ARM)")
        EMU="qemu-arm"
        ;;
    "AArch64")
        EMU="qemu-aarch64"
        ;;
    *)
        echo "  Skipping emulation — unknown/incompatible architecture"
        EMU=""
        ;;
esac

if [ -n "$EMU" ]; then
    echo "  Running: $EMU $BINARY --help"
    timeout 5 "$EMU" "$BINARY" --help > "$OUTDIR/03_emulation.txt" 2>&1 || true
    cat "$OUTDIR/03_emulation.txt"
fi

# Phase 4: Crypto detection
echo ""
echo "--- Phase 4: Crypto Constants ---"
python3 -c "
import sys
data = open('$BINARY', 'rb').read()
AES_SBOX = bytes([
    0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,
    0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
])
pos = data.find(AES_SBOX)
if pos >= 0:
    print(f'  AES S-box at offset 0x{pos:x}')
else:
    print('  No AES S-box found')

# Check for XOR patterns (simple heuristic)
xor_patterns = 0
for i in range(len(data) - 3):
    if data[i] == 0x32 and data[i+1] == 0x04:  # XOR AL, byte
        xor_patterns += 1
        if xor_patterns <= 5:
            print(f'  XOR instruction at 0x{i:x}')
if xor_patterns > 0:
    print(f'  Total XOR instructions: {xor_patterns}')
" > "$OUTDIR/04_crypto.txt" 2>&1
cat "$OUTDIR/04_crypto.txt"

echo ""
echo "======================================================================="
echo " Analysis complete. Results in: $OUTDIR/"
echo "======================================================================="
SCRIPT
RUN chmod +x /opt/scripts/cross-arch-workflow.sh

# ===== Working directory =====
WORKDIR /workspace

# ===== Default entrypoint =====
RUN echo '#!/bin/bash\n\
echo "================================================"\n\
echo " Cross-Architecture Binary Emulation Lab"\n\
echo "================================================"\n\
echo ""\n\
echo "Available tools:"\n\
echo "  QEMU user-mode emulators:"\n\
ls -1 /usr/bin/qemu-* 2>/dev/null | while read f; do\n\
    echo "    $(basename $f)"\n\
done\n\
echo ""\n\
echo "Analysis scripts:"\n\
echo "    /opt/scripts/analyze-arch.sh <binary>"\n\
echo "    /opt/scripts/cross-arch-workflow.sh <binary>"\n\
echo "    /opt/scripts/extract-function.py <elf> <function> [output]"\n\
echo ""\n\
echo "Sample binaries:"\n\
echo "    /opt/samples/hello_x64 — x86-64 hello world"\n\
echo "    /opt/samples/xor_decode — XOR string decoder (malware-like)"\n\
echo "    /opt/samples/key_checker — License key checker"\n\
echo "    /opt/samples/packed_key_checker — UPX-packed key checker"\n\
echo ""\n\
echo "Python environment: /opt/renv/"\n\
echo "  Packages: unicorn, capstone, pyelftools, pwntools, keystone, qiling, angr"\n\
echo ""\n\
echo "Mount your samples: -v $(pwd):/workspace:Z"\n\
echo "================================================"\n' > /entrypoint.sh && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

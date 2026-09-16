# Kernel Architecture Lab — Kernel inspection, symbols, and module analysis
# Build:  podman build -f sysinternals/kernel-architecture.Containerfile -t kernel-architecture-lab .
# Run:    podman run -it --rm --privileged kernel-architecture-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    linux-headers \
    procps-ng \
    util-linux \
    kmod \
    pciutils \
    usbutils \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

COPY <<'DIAGRAM' /usr/local/bin/kernel-diagram.sh
#!/bin/bash
# Render a kernel architecture diagram in ASCII art
cat << 'EOF'

 ╔═══════════════════════════════════════════════════════════════╗
 ║                     Linux Kernel Architecture                ║
 ╠═══════════════════════════════════════════════════════════════╣
 ║                                                              ║
 ║  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐        ║
 ║  │  Process │ │  Process   │ │  daemon  │ │  daemon  │ ...    ║
 ║  │   (bash) │ │  (python)  │ │ (systemd)│ │ (sshd)   │        ║
 ║  └────┬─────┘ └────┬──────┘ └────┬─────┘ └────┬─────┘        ║
 ║       │             │             │             │             ║
 ║  ┌────┴─────────────┴─────────────┴─────────────┴────┐       ║
 ║  │              SYSCALL INTERFACE (int 0x80/syscall)  │       ║
 ║  └──────────────────────┬────────────────────────────┘       ║
 ║                         │                                    ║
 ║  ┌──────────────────────┴────────────────────────────┐       ║
 ║  │                  VFS (Virtual File System)        │       ║
 ║  │   ┌──────────┐ ┌──────────┐ ┌──────────┐         │       ║
 ║  │   │   ext4   │ │   btrfs  │ │   proc   │  ...    │       ║
 ║  │   └──────────┘ └──────────┘ └──────────┘         │       ║
 ║  └──────────────────────┬────────────────────────────┘       ║
 ║                         │                                    ║
 ║  ┌──────────────────────┴────────────────────────────┐       ║
 ║  │              PROCESS / MEMORY / NETWORK           │       ║
 ║  │ ┌──────────┐ ┌──────────┐ ┌────────────────────┐  │       ║
 ║  │ │Scheduler │ │ MM/Slab  │ │   Netfilter/TCP    │  │       ║
 ║  │ └──────────┘ └──────────┘ └────────────────────┘  │       ║
 ║  └──────────────────────┬────────────────────────────┘       ║
 ║                         │                                    ║
 ║  ┌──────────────────────┴────────────────────────────┐       ║
 ║  │              DEVICE DRIVERS / MODULES             │       ║
 ║  │ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐          │       ║
 ║  │ │block  │ │  net  │ │  usb  │ │other..│          │       ║
 ║  │ └───────┘ └───────┘ └───────┘ └───────┘          │       ║
 ║  └──────────────────────┬────────────────────────────┘       ║
 ║                         │                                    ║
 ║  ┌──────────────────────┴────────────────────────────┐       ║
 ║  │                    HARDWARE                       │       ║
 ║  └───────────────────────────────────────────────────┘       ║
 ║                                                              ║
 ╚═══════════════════════════════════════════════════════════════╝

EOF
echo "Kernel version: $(uname -r)"
echo "Architecture:   $(uname -m)"
echo "Kernel type:    $(uname -s)"
echo "Kernel config:  $(zcat /proc/config.gz 2>/dev/null | grep CONFIG_HZ= | head -1 || echo 'config.gz not available')"
echo
DIAGRAM

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Kernel Architecture Lab ==="
echo ""
echo "Exploring the Linux kernel build, symbol tables, and module layout."
echo ""
/usr/local/bin/kernel-diagram.sh

echo "── Kernel Image Information ──"
echo "Kernel release:      $(uname -r)"
echo "Kernel version:      $(uname -v)"
echo "Build date:          $(uname -v | sed 's/SMP.*//')"
echo "Boot arguments:      $(cat /proc/cmdline)"
echo

echo "── Kernel Config (if available) ──"
if [ -f /proc/config.gz ]; then
    zcat /proc/config.gz | grep -E '^CONFIG_HZ=|^CONFIG_PREEMPT|^CONFIG_SMP=|^CONFIG_NR_CPUS=|^CONFIG_PAGE_SIZE' 2>/dev/null || true
else
    echo "  /proc/config.gz not available (enable CONFIG_IKCONFIG_PROC)"
fi
echo

echo "── Kernel Symbol Table (first 15 entries) ──"
if [ -f /proc/kallsyms ]; then
    head -15 /proc/kallsyms
    echo "  ... (total symbols: $(wc -l < /proc/kallsyms))"
else
    echo "  /proc/kallsyms not accessible (needs kernel.kptr_restrict=0 or --privileged)"
fi
echo

echo "── Kernel Symbols by Type ──"
if [ -f /proc/kallsyms ]; then
    echo "  'T' / 't' (code/text):  $(grep -c ' [Tt] ' /proc/kallsyms)"
    echo "  'D' / 'd' (data):        $(grep -c ' [Dd] ' /proc/kallsyms)"
    echo "  'B' / 'b' (bss):         $(grep -c ' [Bb] ' /proc/kallsyms)"
    echo "  'R' / 'r' (readonly):    $(grep -c ' [Rr] ' /proc/kallsyms)"
    echo "  'W' / 'w' (weak):        $(grep -c ' [Ww] ' /proc/kallsyms)"
    echo "  'A' (absolute):          $(grep -c ' [Aa] ' /proc/kallsyms)"
fi
echo

echo "── Key Kernel Address Lookups ──"
if [ -f /proc/kallsyms ]; then
    for sym in _text _stext _etext _sinittext _einittext system_call sys_call_table do_syscall_64; do
        ADDR=$(grep " $sym$" /proc/kallsyms 2>/dev/null | awk '{print $1}' | head -1)
        [ -n "$ADDR" ] && echo "  $sym = 0x$ADDR" || echo "  $sym = (not found)"
    done
fi
echo

echo "── Loaded Kernel Modules ──"
lsmod 2>/dev/null || echo "  (lsmod not available)"
echo

echo "── Module Information ──"
echo "Modules directory: /lib/modules/$(uname -r)/"
echo "Module dependency map:"
if [ -f "/lib/modules/$(uname -r)/modules.dep" ]; then
    wc -l "/lib/modules/$(uname -r)/modules.dep" 2>/dev/null
fi
echo

echo "── PCI Devices (hardware topology) ──"
lspci 2>/dev/null || echo "  (lspci not available)"
echo

echo "── USB Devices ──"
lsusb 2>/dev/null || echo "  (lsusb not available)"
echo

echo "── CPU Information ──"
echo "CPUs:    $(nproc)"
echo "Model:   $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2-)"
echo "Caches:"
echo "  L1d: $(lscpu 2>/dev/null | grep 'L1d cache' | awk '{print $3$4}')"
echo "  L1i: $(lscpu 2>/dev/null | grep 'L1i cache' | awk '{print $3$4}')"
echo "  L2:  $(lscpu 2>/dev/null | grep 'L2 cache' | awk '{print $3$4}')"
echo "  L3:  $(lscpu 2>/dev/null | grep 'L3 cache' | awk '{print $3$4}')"
echo

echo "── Memory Layout ──"
echo "Total RAM:    $(grep MemTotal /proc/meminfo | awk '{print $2/1024 " MB"}')"
echo "Kernel code:  $(grep -i kernelcode /proc/meminfo 2>/dev/null | awk '{print $2, $3}' || echo 'unavailable')"
echo

echo "── Kernel Address Space Layout ──"
if [ -f /proc/kallsyms ]; then
    echo "  _text (start of kernel text):  0x$(grep ' _text$' /proc/kallsyms | awk '{print $1}' | head -1)"
    echo "  _etext (end of kernel text):    0x$(grep ' _etext$' /proc/kallsyms | awk '{print $1}' | head -1)"
    echo "  __bss_start:                    0x$(grep ' __bss_start$' /proc/kallsyms | awk '{print $1}' | head -1)"
    echo "  _end:                           0x$(grep ' _end$' /proc/kallsyms | awk '{print $1}' | head -1)"
fi
echo

echo "── Security Features ──"
echo "SMEP (Supervisor Mode Exec Prev): $(grep -c smep /proc/cpuinfo && echo supported || echo unknown)"
echo "SMAP (Supervisor Mode Acc Prev):  $(grep -c smap /proc/cpuinfo && echo supported || echo unknown)"
echo "KPTI (Page Table Isolation):      $(cat /sys/devices/system/cpu/vulnerabilities/meltdown 2>/dev/null || echo unknown)"
echo "KASLR:                            $(dmesg 2>/dev/null | grep -i 'KASLR' | head -1 || echo 'dmesg not readable')"

echo ""
echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Compare /proc/kallsyms between boots to observe KASLR changes"
echo "  2. Inspect a specific kernel symbol: grep ' sys_call_table' /proc/kallsyms"
echo "  3. Browse the kernel source structure: ls /usr/src/linux*/"
echo "  4. Count exported symbols: grep ' T ' /proc/kallsyms | wc -l"
echo "  5. Explore module parameters: ls /sys/module/"
echo ""
echo "Use kprobes with: bpftrace -e 'kprobe:schedule { printf(\"sched\\n\"); }'"
echo

exec bash
ENTRY

RUN chmod +x /usr/local/bin/kernel-diagram.sh /entrypoint.sh
WORKDIR /root
ENTRYPOINT ["/entrypoint.sh"]

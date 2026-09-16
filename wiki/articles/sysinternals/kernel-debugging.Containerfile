# Kernel Debugging Lab — QEMU + GDB kernel debugging environment
# Build:  podman build -f sysinternals/kernel-debugging.Containerfile -t kernel-debug-lab .
# Run:    podman run -it --rm kernel-debug-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    qemu-system-x86 \
    gdb \
    python \
    procps-ng \
    base-devel \
    wget \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /lab

COPY <<'GDBINIT' /lab/.gdbinit
# GDB init script for kernel debugging with QEMU
# Usage: gdb -x /lab/.gdbinit /path/to/vmlinux

set pagination off
set print pretty on
set print array on
set print array-indexes on
set disassembly-flavor intel

# Connect to QEMU gdbstub (default: localhost:1234)
echo === Connecting to QEMU gdbstub at localhost:1234 ===\n
target remote :1234

# Optional: load kernel symbols
# file /path/to/vmlinux

echo === Connected! ===\n
echo \n
echo Useful GDB commands:\n
echo   info registers        — dump all CPU registers\n
echo   info threads          — list active CPUs (QEMU: one thread per vCPU)\n
echo   bt                    — backtrace of current stack\n
echo   bt full               — backtrace with local variables\n
echo   info locals           — dump local variables\n
echo   info args             — dump function arguments\n
echo   info proc mappings    — kernel memory mappings\n
echo   p/x \$cr3             — page table base (CR3 register)\n
echo   p/x \$cr2             — page fault address (CR2 register)\n
echo   p/x \$(unsigned long)init_task  — address of init_task\n
echo   monitor system_reset  — reset the VM\n
echo   monitor quit          — quit QEMU\n
echo   lx-ps                 — (if Python helper loaded) list processes\n
echo   lx-lsmod              — list loaded modules\n
echo   lx-dmesg              — kernel log buffer\n
echo \n

# Define custom helper commands
define dump_regs
    printf "RAX=0x%016lx  RBX=0x%016lx  RCX=0x%016lx\n", $rax, $rbx, $rcx
    printf "RDX=0x%016lx  RSI=0x%016lx  RDI=0x%016lx\n", $rdx, $rsi, $rdi
    printf "RSP=0x%016lx  RBP=0x%016lx  R8 =0x%016lx\n", $rsp, $rbp, $r8
    printf "R9 =0x%016lx  R10=0x%016lx  R11=0x%016lx\n", $r9, $r10, $r11
    printf "R12=0x%016lx  R13=0x%016lx  R14=0x%016lx\n", $r12, $r13, $r14
    printf "R15=0x%016lx  RIP=0x%016lx\n", $r15, $rip
    printf "CS =0x%04x      SS =0x%04x\n", $cs, $ss
end

document dump_regs
    Dump all x86_64 general-purpose registers in a readable format.
end

define show_cr
    printf "CR0=0x%016lx  CR2=0x%016lx  CR3=0x%016lx  CR4=0x%016lx\n", $cr0, $cr2, $cr3, $cr4
end

document show_cr
    Display control registers CR0-CR4.
end

define syscall_nr
    printf "Syscall number (RAX): %ld (0x%lx)\n", $rax, $rax
    printf "  RDI (arg1) = 0x%lx\n", $rdi
    printf "  RSI (arg2) = 0x%lx\n", $rsi
    printf "  RDX (arg3) = 0x%lx\n", $rdx
    printf "  R10 (arg4) = 0x%lx\n", $r10
    printf "  R8  (arg5) = 0x%lx\n", $r8
    printf "  R9  (arg6) = 0x%lx\n", $r9
end

document syscall_nr
    Display syscall number and arguments from registers.
end
GDBINIT

COPY <<'QEMU_HELP' /lab/qemu_debug_guide.sh
#!/bin/bash
# QEMU + GDB Kernel Debugging Quick Reference
echo "=== QEMU + GDB Kernel Debugging Setup ==="
echo ""
echo "1. BUILD A DEBUG KERNEL:"
echo "   git clone https://github.com/torvalds/linux.git"
echo "   cd linux"
echo "   make defconfig"
echo "   # Enable debug options:"
echo "   scripts/config -e CONFIG_DEBUG_INFO"
echo "   scripts/config -e CONFIG_DEBUG_INFO_DWARF4"
echo "   scripts/config -e CONFIG_GDB_SCRIPTS"
echo "   scripts/config -e CONFIG_KGDB"
echo "   scripts/config -e CONFIG_FRAME_POINTER"
echo "   make -j\$(nproc)"
echo ""
echo "2. CREATE A MINIMAL ROOTFS:"
echo "   mkdir rootfs"
echo "   # Use busybox or buildroot for a minimal initrd"
echo "   # Or download a prebuilt one:"
echo "   wget https://busybox.net/downloads/binaries/latest/busybox-x86_64"
echo ""
echo "3. START QEMU WITH GDB STUB:"
echo "   qemu-system-x86_64 \\"
echo "     -kernel arch/x86_64/boot/bzImage \\"
echo "     -initrd rootfs.cpio.gz \\"
echo "     -append 'console=ttyS0 nokaslr' \\"
echo "     -nographic \\"
echo "     -s -S"
echo ""
echo "   -s   = shorthand for -gdb tcp::1234"
echo "   -S   = freeze CPU at startup (wait for GDB)"
echo "   nokaslr = disable KASLR for stable addresses"
echo ""
echo "4. CONNECT GDB:"
echo "   gdb vmlinux"
echo "   (gdb) target remote :1234"
echo "   (gdb) hbreak start_kernel"
echo "   (gdb) continue"
echo ""
echo "5. COMMON QEMU OPTIONS:"
echo "   -smp 4            — 4 CPUs"
echo "   -m 2048           — 2 GB RAM"
echo "   -enable-kvm       — hardware acceleration"
echo "   -monitor stdio    — QEMU monitor on same terminal"
echo "   -serial stdio     — kernel console on same terminal"
echo "   -netdev user,...  — user-mode networking"
echo ""
echo "6. QEMU MONITOR COMMANDS (Ctrl+A C):"
echo "   info registers    — CPU registers"
echo "   info cpus         — CPU states"
echo "   info mem          — memory regions"
echo "   stop / cont       — pause / resume VM"
echo "   gdbserver         — toggle gdb server"
echo "   quit              — exit QEMU"
echo ""
QEMU_HELP

RUN chmod +x /lab/qemu_debug_guide.sh

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Kernel Debugging Lab — QEMU + GDB ==="
echo ""
echo "This lab sets up a kernel debugging environment using QEMU"
echo "and GDB. Learn how kernel developers debug crashes, analyze"
echo "race conditions, and inspect kernel state."
echo ""

echo "── Debugging Tools Overview ──"
echo "  KGDB:        Kernel GDB stub — debug over serial"
echo "  KDB:         Kernel debugger (built into kernel)"
echo "  QEMU gdbstub: Debug kernel running in QEMU via -s flag"
echo "  crash:       Analyze vmcore dumps post-mortem"
echo "  ftrace:      Function graph tracing"
echo "  kprobes:     Dynamic breakpoints"
echo "  printk:      The old standby (less invasive)"
echo ""

echo "── KGDB vs GDB Stub ──"
echo "  KGDB:   Built into the kernel. Enable with kgdboc=..."
echo "          Connect via: gdb vmlinux → target remote /dev/ttyS0"
echo "          Useful for debugging on real hardware."
echo ""
echo "  QEMU gdbstub: Built into QEMU. Enable with -s -S."
echo "          Connect via: gdb vmlinux → target remote :1234"
echo "          Useful for VM-based kernel development."
echo ""

echo "── GDB Initialization File ──"
echo "  Created at /lab/.gdbinit with custom commands."
echo ""
grep "^define " /lab/.gdbinit | sed 's/define /  /'
echo ""

echo "── Quick Start Guide ──"
/lab/qemu_debug_guide.sh
echo ""

echo "── GDB Commands Reference ──"
echo "  COMMAND              │ DESCRIPTION"
echo "  ─────────────────────┼──────────────────────────────────"
echo "  target remote :1234  │ Connect to QEMU / KGDB"
echo "  hbreak <func>        │ Set hardware breakpoint"
echo "  break <func>         │ Set software breakpoint"
echo "  watch <var>          │ Watch variable for changes"
echo "  continue / c         │ Resume execution"
echo "  stepi / si           │ Step one instruction"
echo "  nexti / ni           │ Step over function call"
echo "  finish               │ Run until current function returns"
echo "  bt                   │ Print stack backtrace"
echo "  bt full              │ Backtrace with locals"
echo "  frame <N>            │ Switch to stack frame N"
echo "  info registers       │ Show all registers"
echo "  info threads         │ Show all vCPUs"
echo "  p/x <expr>           │ Print expression in hex"
echo "  x/Ngx <addr>         │ Examine N giant words at addr"
echo "  set \$var=value      │ Set a GDB convenience variable"
echo "  disas <func>         │ Disassemble function"
echo "  list <func>          │ Show source code (needs debuginfo)"
echo "  monitor <qemu-cmd>   │ Send command to QEMU monitor"
echo "  add-symbol-file <.ko> <.text_addr>  │ Load module symbols"
echo ""

echo "── Kernel Module Symbol Loading ──"
echo "  # Find .text address:"
echo "  cat /sys/module/<name>/sections/.text"
echo "  # Load symbols from GDB:"
echo "  (gdb) add-symbol-file /path/to/module.ko 0xffffffffc0000000"
echo ""

echo "── Common Debugging Workflows ──"
echo ""
echo "  Bug: Kernel panic / OOPS"
echo "   1. Reproduce under QEMU with -s -S"
echo "   2. Set breakpoint before crash site"
echo "   3. bt full → inspect call chain"
echo "   4. info registers → check faulting instruction (RIP)"
echo "   5. Check page fault address: p/x \$cr2"
echo ""
echo "  Bug: Deadlock"
echo "   1. info threads → find which vCPU is stuck"
echo "   2. thread <N> → switch to that vCPU"
echo "   3. bt → find where it's waiting (mutex_lock, semaphore, etc.)"
echo "   4. Find lock holder: Search for 'lock' variables"
echo ""
echo "  Bug: Use-after-free"
echo "   1. hardware watchpoint on freed address"
echo "   2. (gdb) watch *0xffff88807abc0000"
echo "   3. continue → GDB breaks on access"
echo "   4. bt → who accessed it"
echo ""

echo "── Printk Log Levels ──"
echo "  KERN_EMERG   (0)  — System is unusable"
echo "  KERN_ALERT   (1)  — Action must be taken immediately"
echo "  KERN_CRIT    (2)  — Critical conditions"
echo "  KERN_ERR     (3)  — Error conditions"
echo "  KERN_WARNING (4)  — Warning conditions"
echo "  KERN_NOTICE  (5)  — Normal but significant"
echo "  KERN_INFO    (6)  — Informational"
echo "  KERN_DEBUG   (7)  — Debug-level messages"
echo ""
echo "  Control output: echo 7 > /proc/sys/kernel/printk"
echo ""

echo "── Dynamic Debug (CONFIG_DYNAMIC_DEBUG) ──"
echo "  Control per-file debug output without recompiling:"
echo "  echo 'file kernel/sched/core.c +p' > /sys/kernel/debug/dynamic_debug/control"
echo "  echo 'func schedule +p' > /sys/kernel/debug/dynamic_debug/control"
echo "  echo 'module my_module +p' > /sys/kernel/debug/dynamic_debug/control"
echo ""

echo "── KGDB Kernel Boot Parameters ──"
echo "  kgdboc=ttyS0,115200    — KGDB over serial port"
echo "  kgdbcon                 — KGDB console"
echo "  kgdbwait                — Wait for KGDB at boot"
echo "  nokaslr                 — Disable KASLR (essential for symbol matching)"
echo "  nosmep nosmap           — Disable SMEP/SMAP for debugging"
echo "  nopti                   — Disable page table isolation"
echo ""

echo "── Crash Dump Analysis ──"
echo "  If you have a vmcore from kdump:"
echo "  crash /path/to/vmlinux /var/crash/vmcore"
echo ""
echo "  Common crash commands:"
echo "  bt      — backtrace of crashed task"
echo "  log     — kernel log buffer"
echo "  ps      — process list"
echo "  files   — open files of current task"
echo "  kmem -i — memory usage summary"
echo "  mod     — loaded modules"
echo "  struct  — display structure definition"
echo "  foreach — iterate over kernel objects"
echo ""

echo "── Debugging with QEMU Trace Options ──"
echo "  -d cpu_reset       — trace CPU resets"
echo "  -d int             — trace interrupts"
echo "  -d guest_errors    — trace invalid guest behavior"
echo "  -d in_asm          — trace executed instructions (heavy!)"
echo "  -D /tmp/qemu.log   — write trace to file"
echo ""
echo "  Example: qemu-system-x86_64 -d int,cpu_reset -D trace.log ..."
echo ""

echo "── Python GDB Extensions ──"
echo "  If CONFIG_GDB_SCRIPTS=y, the kernel provides Python helpers:"
echo "  lx-ps           — list processes"
echo "  lx-lsmod        — list modules"
echo "  lx-dmesg        — kernel log"
echo "  lx-cmdline      — boot command line"
echo "  lx-version      — kernel version"
echo "  lx-symbols      — load all current module symbols"
echo ""

echo "── Installing Kernel Debug Symbols ──"
echo "  On Arch:"
echo "  pacman -S linux-debug"
echo "  # Or use debuginfod:"
echo "  export DEBUGINFOD_URLS=https://debuginfod.archlinux.org"
echo ""
echo "  On Debian/Ubuntu:"
echo "  apt install linux-image-\$(uname -r)-dbg"
echo "  # Or:"
echo "  echo 'deb http://ddebs.ubuntu.com \$(lsb_release -cs) main restricted' >> /etc/apt/sources.list.d/ddebs.list"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Download a minimal kernel + initrd for QEMU debugging practice"
echo "  2. Start QEMU with -s -S and connect GDB"
echo "  3. Set a breakpoint at start_kernel, step through early boot"
echo "  4. Break at do_syscall_64, inspect syscall dispatch"
echo "  5. Watch a variable across contexts: watch *(&jiffies)"
echo "  6. Install kernel-debug package and debug a running kernel with KGDB"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /lab
ENTRYPOINT ["/entrypoint.sh"]

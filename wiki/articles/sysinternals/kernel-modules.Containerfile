# Kernel Modules Lab - Build, signature, parameters, and EXPORT_SYMBOL demo
# Build:  podman build -f kernel-modules.Containerfile -t kernel-modules-lab .
# Run:    podman run -it --rm --privileged kernel-modules-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    linux-headers \
    base-devel \
    kmod \
    openssl \
    procps-ng \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /src

COPY <<'MAKEFILE' /src/Makefile
obj-m += demo_module.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
MAKEFILE

COPY <<'MODSOURCE' /src/demo_module.c
/*
 * demo_module.c — Kernel module demo with parameters and symbol export.
 *
 * Demonstrates:
 *   - module_param() for runtime configuration
 *   - EXPORT_SYMBOL / EXPORT_SYMBOL_GPL for inter-module dependencies
 *   - module license, author, description macros
 *   - __init / __exit section markers
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/jiffies.h>
#include <linux/delay.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Kernel Modules Lab");
MODULE_DESCRIPTION("Kernel module demo with parameters and exported symbols");
MODULE_VERSION("1.0");

/* ── Module Parameters ── */

static int    demo_count = 1;
static char  *demo_name  = "world";
static int    demo_array[4] = { 1, 2, 3, 4 };
static int    demo_arr_len = 4;

module_param(demo_count, int, 0644);
MODULE_PARM_DESC(demo_count, "How many times to print the greeting");

module_param(demo_name, charp, 0644);
MODULE_PARM_DESC(demo_name, "Name to greet in the demo message");

module_param_array(demo_array, int, &demo_arr_len, 0644);
MODULE_PARM_DESC(demo_array, "An array of integers for demonstration");

/* ── Exported Symbols ── */

/*
 * Exported function: can be called by OTHER kernel modules
 * that depend on this module.
 */
int demo_add_numbers(int a, int b)
{
    return a + b;
}
EXPORT_SYMBOL(demo_add_numbers);

/*
 * Exported with GPL-only restriction: only GPL-licensed modules
 * can call this function.
 */
int demo_multiply_numbers(int a, int b)
{
    return a * b;
}
EXPORT_SYMBOL_GPL(demo_multiply_numbers);

/*
 * Exported global variable.
 */
int demo_global_counter = 0;
EXPORT_SYMBOL(demo_global_counter);

/* ── Module Init ── */

static int __init demo_init(void)
{
    int i;
    unsigned long then, now, elapsed;

    pr_info("========================================\n");
    pr_info("demo_module: Initializing...\n");
    pr_info("========================================\n");

    pr_info("demo_module: License:     %s\n", THIS_MODULE->name);
    pr_info("demo_module: Kernel ver:  %s\n", UTS_RELEASE);
    pr_info("demo_module: Build time:  %s %s\n", __DATE__, __TIME__);

    pr_info("demo_module: Parameters received:\n");
    pr_info("demo_module:   demo_count = %d\n", demo_count);
    pr_info("demo_module:   demo_name  = '%s'\n", demo_name);
    pr_info("demo_module:   demo_array = [");
    for (i = 0; i < demo_arr_len; i++)
        pr_cont("%d%s", demo_array[i], (i < demo_arr_len - 1) ? ", " : "");
    pr_cont("] (len=%d)\n", demo_arr_len);

    /* Demonstrate exported symbol usage internally */
    pr_info("demo_module:   demo_add_numbers(10, 20) = %d\n",
        demo_add_numbers(10, 20));
    pr_info("demo_module:   demo_multiply_numbers(5, 6) = %d\n",
        demo_multiply_numbers(5, 6));

    /* Demonstrate jiffies */
    pr_info("demo_module: Jiffies at load: %lu\n", jiffies);
    pr_info("demo_module: HZ = %d (jiffies per second)\n", HZ);

    /* Timing demo */
    then = jiffies;
    mdelay(100);
    now = jiffies;
    elapsed = jiffies_to_msecs(now - then);
    pr_info("demo_module: mdelay(100) took %lu ms (expected ~100ms)\n", elapsed);

    /* Greeting loop */
    pr_info("demo_module: Greetings (%d time(s)):\n", demo_count);
    for (i = 0; i < demo_count; i++)
        pr_info("demo_module:   Hello, %s! (greeting %d of %d)\n",
            demo_name, i + 1, demo_count);

    /* Module struct inspection */
    pr_info("demo_module: Module state:     %u (0=LIVE)\n",
        THIS_MODULE->state);
    pr_info("demo_module: Reference count:  %d\n",
        module_refcount(THIS_MODULE));
    pr_info("demo_module: Taints:           0x%lx\n",
        THIS_MODULE->taints);
    if (THIS_MODULE->taints)
        pr_info("demo_module:   (module tainted — see Documentation/admin-guide/tainted-kernels.rst)\n");

    /* Show exported symbol count */
    {
        unsigned int nsyms = 0;
        struct kernel_symbol *ks;
        /* Walk module's exported symbols (requires CONFIG_KALLSYMS) */
        pr_info("demo_module: Symbols exported by this module:\n");
        pr_info("demo_module:   demo_add_numbers       [EXPORT_SYMBOL]\n");
        pr_info("demo_module:   demo_multiply_numbers  [EXPORT_SYMBOL_GPL]\n");
        pr_info("demo_module:   demo_global_counter    [EXPORT_SYMBOL]\n");
    }

    pr_info("========================================\n");
    pr_info("demo_module: Initialization complete.\n");
    pr_info("========================================\n");

    return 0;
}

/* ── Module Exit ── */

static void __exit demo_exit(void)
{
    pr_info("demo_module: Shutting down...\n");
    pr_info("demo_module:   Final counter value: %d\n", demo_global_counter);
    pr_info("demo_module:   Uptime jiffies: %lu\n", jiffies);
    pr_info("demo_module: Goodbye, %s!\n", demo_name);
}

module_init(demo_init);
module_exit(demo_exit);
MODSOURCE

COPY <<'CONSUMER' /src/consumer_module.c
/*
 * consumer_module.c — Demonstrates using EXPORT_SYMBOL from another module.
 *
 * This module depends on demo_module and calls its exported functions.
 * In practice, you'd use Module.symvers or modprobe to resolve dependencies.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Kernel Modules Lab");
MODULE_DESCRIPTION("Consumer of demo_module exported symbols");

/* Declare external symbols (normally resolved via Module.symvers) */
extern int demo_add_numbers(int a, int b);
extern int demo_multiply_numbers(int a, int b);
extern int demo_global_counter;

static int __init consumer_init(void)
{
    pr_info("consumer: Initializing...\n");

    /* Call symbols exported by demo_module */
    pr_info("consumer: Calling demo_add_numbers(100, 200) = %d\n",
        demo_add_numbers(100, 200));
    pr_info("consumer: Calling demo_multiply_numbers(7, 8) = %d\n",
        demo_multiply_numbers(7, 8));
    pr_info("consumer: Reading demo_global_counter = %d\n",
        demo_global_counter);

    /* Modify the exported global */
    demo_global_counter = 42;
    pr_info("consumer: Set demo_global_counter to %d\n", demo_global_counter);

    pr_info("consumer: Initialization complete.\n");
    return 0;
}

static void __exit consumer_exit(void)
{
    pr_info("consumer: Shutting down. Counter = %d\n", demo_global_counter);
}

module_init(consumer_init);
module_exit(consumer_exit);
CONSUMER

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Kernel Modules Lab — Build, Signature & Symbol Export ==="
echo ""
echo "Exploring kernel module lifecycle, module_param, EXPORT_SYMBOL,"
echo "modinfo inspection, and module stacking."
echo ""

echo "── Module Subsystem Overview ──"
echo "Kernel version: $(uname -r)"
echo "Module directory: /lib/modules/$(uname -r)/"
echo "Kernel config: $(zcat /proc/config.gz 2>/dev/null | grep -c CONFIG_MODULES= || echo 'modules enabled')"
echo "Module signing: $(zcat /proc/config.gz 2>/dev/null | grep CONFIG_MODULE_SIG= || echo 'check kernel config')"
echo "Module compression: $(zcat /proc/config.gz 2>/dev/null | grep CONFIG_MODULE_COMPRESS= || echo 'check kernel config')"
echo ""

echo "── Building Demo Module ──"
cd /src
make 2>&1

if [ -f demo_module.ko ]; then
    echo ""
    echo "  Module built: $(ls -lh demo_module.ko)"
    echo ""

    echo "── modinfo: Module Internal Metadata ──"
    modinfo demo_module.ko
    echo ""

    echo "── Module Sections (readelf) ──"
    readelf -S demo_module.ko 2>/dev/null | grep -E '\.text|\.data|\.bss|\.rodata|\.modinfo|\.init\.text|\.exit\.text|\.gnu\.linkonce' || echo "  (readelf not available)"

    echo ""
    echo "── Module Symbols ──"
    nm demo_module.ko 2>/dev/null | grep -E ' [TtDdBb] ' | head -20 || echo "  (nm not available)"

    echo ""
    echo "── Loading Module with Default Parameters ──"
    insmod demo_module.ko 2>&1 && echo "  Module loaded!" || echo "  Loading failed (needs --privileged)"

    if lsmod | grep -q demo_module; then
        echo ""
        echo "  lsmod output:"
        lsmod | grep -E "^Module|demo_module"

        echo ""
        echo "  Module reference count:"
        cat /sys/module/demo_module/refcnt 2>/dev/null || echo "  (not accessible)"

        echo ""
        echo "  Module parameters (sysfs):"
        ls /sys/module/demo_module/parameters/ 2>/dev/null && \
            for p in /sys/module/demo_module/parameters/*; do
                echo "    $(basename $p) = $(cat $p 2>/dev/null || echo '?')"
            done || echo "  (sysfs not accessible)"

        echo ""
        echo "── Module Messages (dmesg) ──"
        dmesg 2>/dev/null | grep "demo_module:" | tail -30 || echo "  (dmesg not accessible)"

        echo ""
        echo "── Reloading with Different Parameters ──"
        rmmod demo_module 2>/dev/null
        insmod demo_module.ko demo_count=3 demo_name="Linux" demo_array=10,20,30,40 2>&1 && \
            echo "  Reloaded with custom parameters!" || echo "  Reload failed"

        dmesg 2>/dev/null | grep "demo_module:" | tail -10 || true

        echo ""
        echo "── /proc/modules Entry ──"
        grep demo_module /proc/modules 2>/dev/null || echo "  (not accessible)"

        echo ""
        echo "── Module Holders and Dependencies ──"
        cat /sys/module/demo_module/holders 2>/dev/null || echo "  (no dependents)"

        echo ""
        echo "── Taint Status ──"
        cat /proc/sys/kernel/tainted 2>/dev/null && echo "  (0 = no taint)" || echo "  (not accessible)"
        echo "  Taint values: P=proprietary, F=force-loaded, O=out-of-tree, E=unsigned"
        echo "  More: cat /proc/sys/kernel/tainted && echo \$((\$?))"

        echo ""
        echo "── Unloading ──"
        rmmod demo_module 2>/dev/null && echo "  Module unloaded." || echo "  Unload failed"
    fi

    echo ""
    echo "── Clean Build Artifacts ──"
    make clean 2>/dev/null
else
    echo ""
    echo "  ERROR: Build failed."
fi
echo ""

echo "── Module Parameter Types ──"
echo "  module_param(name, type, perm)"
echo ""
echo "  Types:  bool, invbool  — boolean (inverted boolean)"
echo "          charp          — char pointer (string)"
echo "          int, long, short, uint, ulong, ushort — integers"
echo "          byte, char     — single bytes"
echo ""
echo "  Permissions: 0 = hidden, 0444 = read-only, 0644 = rw"
echo "               S_IRUGO|S_IWUSR = 0644 equivalent"
echo ""
echo "  Arrays:  module_param_array(name, type, &num, perm)"
echo "  Strings: module_param_string(name, string, len, perm)"
echo ""

echo "── EXPORT_SYMBOL Variants ──"
echo "  EXPORT_SYMBOL(name)          — available to all modules"
echo "  EXPORT_SYMBOL_GPL(name)      — available only to GPL modules"
echo "  EXPORT_SYMBOL_NS(name, ns)   — available in specific namespace"
echo "  EXPORT_SYMBOL_NS_GPL(name, ns) — GPL + namespace restricted"
echo ""

echo "── Module Loading Commands ──"
echo "  insmod <path>          — load a .ko file directly"
echo "  rmmod <name>           — unload a module by name"
echo "  modprobe <name>        — load with dependency resolution"
echo "  modprobe -r <name>     — unload with dependency resolution"
echo "  modinfo <name|path>    — display module metadata"
echo "  lsmod                  — list currently loaded modules"
echo "  depmod -a              — rebuild module dependency map"
echo ""

echo "── Module Signing (if CONFIG_MODULE_SIG=y) ──"
echo "  Key location:  $(cat /proc/sys/kernel/modules_disabled 2>/dev/null && echo 'key at certs/signing_key.pem' || echo 'signing may be disabled')"
echo "  Enforced:      $(cat /sys/module/kernel/parameters/module_sig_enforce 2>/dev/null || echo 'unknown')"
echo ""
echo "  Sign a module:  scripts/sign-file sha256 certs/signing_key.pem certs/signing_key.x509 demo_module.ko"
echo "  Verify:         modinfo -F sig_id demo_module.ko"
echo "  Strip sig:      strip --strip-debug demo_module.ko"
echo ""

echo "── Module Layout on Disk ──"
echo "  /lib/modules/\$(uname -r)/"
echo "  ├── kernel/"
echo "  │   ├── drivers/    (block, char, net, usb, ...)"
echo "  │   ├── fs/          (ext4, btrfs, nfs, ...)"
echo "  │   ├── net/         (tcp, ipv6, ...)"
echo "  │   └── ..."
echo "  ├── modules.alias    (device ID → module mapping)"
echo "  ├── modules.dep      (dependency graph)"
echo "  ├── modules.symbols  (exported symbol → module mapping)"
echo "  └── modules.builtin  (built-in (non-modular) drivers)"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Load module with different parameters: insmod demo_module.ko demo_count=5 demo_name='Student'"
echo "  2. Check modinfo for vermagic mismatch issues"
echo "  3. Use strace to see the init_module syscall: strace insmod demo_module.ko"
echo "  4. Explore /sys/module/<name>/ for runtime module info"
echo "  5. Force load (taint kernel): insmod --force demo_module.ko (if vermagic mismatch)"
echo "  6. Build consumer_module (needs Module.symvers from demo_module)"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /src
ENTRYPOINT ["/entrypoint.sh"]

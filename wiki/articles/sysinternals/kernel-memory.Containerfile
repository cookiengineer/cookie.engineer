# Kernel Memory Lab - kmalloc, vmalloc, alloc_pages, slab/buddy exploration
# Build:  podman build -f kernel-memory.Containerfile -t kernel-memory-lab .
# Run:    podman run -it --rm --privileged kernel-memory-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    linux-headers \
    base-devel \
    kmod \
    procps-ng \
    bc \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /src

COPY <<'MAKEFILE' /src/Makefile
obj-m += kernel_memory_demo.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
MAKEFILE

COPY <<'KMSOURCE' /src/kernel_memory_demo.c
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/slab.h>
#include <linux/vmalloc.h>
#include <linux/mm.h>
#include <linux/gfp.h>
#include <linux/version.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Kernel Memory Lab");
MODULE_DESCRIPTION("Demonstrates kmalloc, vmalloc, and alloc_pages");

#define KALLOC_TESTS 5
#define VMALLOC_TESTS 3

static int demo_stress = 0;
module_param(demo_stress, int, 0644);
MODULE_PARM_DESC(demo_stress, "Run stress allocation test (0=off, 1=on)");

static void *k_allocs[KALLOC_TESTS];
static void *v_allocs[VMALLOC_TESTS];

static int __init kmem_demo_init(void)
{
    int i;

    pr_info("=== Kernel Memory Allocator Demo ===\n");

    /* ── kmalloc() — physically contiguous, size limited ── */
    pr_info("── kmalloc() allocations ──\n");
    for (i = 0; i < KALLOC_TESTS; i++) {
        size_t sz = (i + 1) * 1024; /* 1K, 2K, 4K, 8K, 16K */
        k_allocs[i] = kmalloc(sz, GFP_KERNEL);
        if (k_allocs[i])
            pr_info("  kmalloc(%4zu) = %px (virt) — %s\n",
                sz, k_allocs[i],
                virt_addr_valid(k_allocs[i]) ? "direct-mapped" : "highmem");
        else
            pr_info("  kmalloc(%4zu) FAILED\n", sz);
    }

    /* ── vmalloc() — virtually contiguous, may be physically discontiguous ── */
    pr_info("── vmalloc() allocations ──\n");
    for (i = 0; i < VMALLOC_TESTS; i++) {
        size_t sz = (1 << 18) * (i + 1); /* 256K, 512K, 768K */
        v_allocs[i] = vmalloc(sz);
        if (v_allocs[i])
            pr_info("  vmalloc(%6zu) = %px (vmap area)\n", sz, v_allocs[i]);
        else
            pr_info("  vmalloc(%6zu) FAILED\n", sz);
    }

    /* ── alloc_pages() — page-level allocation ── */
    pr_info("── alloc_pages() — order 0..3 ──\n");
    for (i = 0; i <= 3; i++) {
        int n_pages = (1 << i);
        struct page *p = alloc_pages(GFP_KERNEL, i);
        if (p)
            pr_info("  alloc_pages(order=%d) = %px → %d page(s) (0x%lx bytes)\n",
                i, p, n_pages, (unsigned long)PAGE_SIZE * n_pages);
        else
            pr_info("  alloc_pages(order=%d) FAILED\n", i);
        if (p) __free_pages(p, i);
    }

    /* ── get_free_pages() — convenience wrapper ── */
    {
        unsigned long addr = __get_free_pages(GFP_KERNEL, 2); /* 4 pages */
        if (addr)
            pr_info("  __get_free_pages(order=2) = 0x%lx (4 pages = 16K)\n", addr);
        else
            pr_info("  __get_free_pages(order=2) FAILED\n");
        if (addr) free_pages(addr, 2);
    }

    /* ── GFP flags demonstration ── */
    pr_info("── GFP flags reference ──\n");
    pr_info("  GFP_KERNEL     = 0x%x (normal kernel allocation, may sleep)\n", GFP_KERNEL);
    pr_info("  GFP_ATOMIC     = 0x%x (atomic, will not sleep)\n", GFP_ATOMIC);
    pr_info("  GFP_DMA        = 0x%x (DMA-capable zone)\n", GFP_DMA);
    pr_info("  GFP_HIGHUSER   = 0x%x (user pages)\n", GFP_HIGHUSER);
    pr_info("  __GFP_ZERO     = 0x%x (zero the allocation)\n", __GFP_ZERO);
    pr_info("  __GFP_NOWARN   = 0x%x (suppress failure warning)\n", __GFP_NOWARN);

    /* ── Stress test (optional) ── */
    if (demo_stress) {
        pr_info("── Stress allocation test ──\n");
        for (i = 0; i < 100; i++) {
            void *p = kmalloc(4096, GFP_KERNEL);
            if (!p) {
                pr_info("  kmalloc failed at iteration %d\n", i);
                break;
            }
            /* don't free — OOM after enough iterations */
        }
        pr_info("  Stress test complete (memory may be low now)\n");
    }

    return 0;
}

static void __exit kmem_demo_exit(void)
{
    int i;

    pr_info("=== Kernel Memory Demo Exit ===\n");
    for (i = 0; i < KALLOC_TESTS; i++)
        kfree(k_allocs[i]);
    for (i = 0; i < VMALLOC_TESTS; i++)
        vfree(v_allocs[i]);
    pr_info("All allocations freed.\n");
}

module_init(kmem_demo_init);
module_exit(kmem_demo_exit);
KMSOURCE

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Kernel Memory Allocator Lab ==="
echo ""
echo "Exploring kmalloc, vmalloc, alloc_pages, slab, and buddy allocators."
echo ""

echo "── Zone Information ──"
cat /proc/buddyinfo 2>/dev/null || echo "  buddyinfo not accessible"
echo ""
echo "This shows free page counts by order (2^order pages) per zone."
echo "  DMA / DMA32 / Normal zones each have their own buddy lists."
echo ""

echo "── Node and Zone Summary ──"
cat /proc/zoneinfo 2>/dev/null | grep -E "^Node|^  (per|pages|managed|spanned|present)" | head -20 || echo "  zoneinfo not accessible"
echo ""

echo "── Slab Cache Overview ──"
echo "Top 15 slab caches by size:"
if [ -f /proc/slabinfo ]; then
    head -1 /proc/slabinfo
    tail -n +2 /proc/slabinfo | sort -k3 -n -r | head -15
    echo ""
    echo "Key slabs:"
    echo "  kmalloc-*    = general-purpose kernel allocator caches"
    echo "  dentry       = directory entry cache (VFS)"
    echo "  inode_cache  = inode cache (VFS)"
    echo "  buffer_head  = block device I/O buffers"
    echo "  vm_area_struct = virtual memory areas"
    echo "  task_struct  = process descriptors"
else
    echo "  /proc/slabinfo not accessible (needs sudo or kernel.slabinfo.legacy=y)"
fi
echo ""

echo "── Active Slab Caches Count ──"
if [ -f /proc/slabinfo ]; then
    SLABS=$(tail -n +2 /proc/slabinfo | wc -l)
    echo "  Total active slabs: $SLABS"
fi
echo ""

echo "── Page Allocator Stats ──"
grep -E "^nr_free_pages|^nr_alloc_batch|^pgalloc_|^pgfree|^pgsteal_" /proc/vmstat 2>/dev/null | head -15 || echo "  vmstat not accessible"
echo ""

echo "── Kernel Memory Usage ──"
echo "Kernel stack: $(grep KernelStack /proc/meminfo 2>/dev/null | awk '{print $2, $3}' || echo 'unavailable')"
echo "Slab:         $(grep "^Slab:" /proc/meminfo 2>/dev/null | awk '{print $2, $3}' || echo 'unavailable')"
echo "SReclaimable: $(grep "^SReclaimable:" /proc/meminfo 2>/dev/null | awk '{print $2, $3}' || echo 'unavailable')"
echo "SUnreclaim:   $(grep "^SUnreclaim:" /proc/meminfo 2>/dev/null | awk '{print $2, $3}' || echo 'unavailable')"
echo "VmallocTotal: $(grep "^VmallocTotal:" /proc/meminfo 2>/dev/null | awk '{print $2, $3}' || echo 'unavailable')"
echo "VmallocUsed:  $(grep "^VmallocUsed:" /proc/meminfo 2>/dev/null | awk '{print $2, $3}' || echo 'unavailable')"
echo ""

echo "── Building Kernel Memory Demo Module ──"
echo "Working directory: /src"
cd /src
make 2>&1 || echo "  WARNING: Build failed (kernel headers mismatch?)"

if [ -f /src/kernel_memory_demo.ko ]; then
    echo ""
    echo "  Module built: $(ls -lh /src/kernel_memory_demo.ko)"
    echo ""
    echo "── Module Info ──"
    modinfo /src/kernel_memory_demo.ko 2>/dev/null | grep -v "^filename:" | grep -v "^vermagic:" || true
    echo ""
    echo "── Loading Module ──"
    insmod /src/kernel_memory_demo.ko 2>&1 || echo "  Loading failed (may need sudo / --privileged)"
    echo ""
    echo "── Module Messages from dmesg ──"
    dmesg 2>/dev/null | tail -30 | grep "kernel_memory_demo" || echo "  (dmesg not accessible or module not loaded)"
    echo ""
    echo "── Unloading Module ──"
    rmmod kernel_memory_demo 2>/dev/null || echo "  (module may not be loaded)"
else
    echo ""
    echo "  Module could not be built. Check kernel headers:"
    echo "  Kernel: $(uname -r)"
    echo "  Headers: $(ls /lib/modules/$(uname -r)/build/include/linux/version.h 2>/dev/null || echo 'NOT FOUND')"
fi
echo ""

echo "── Buddy Allocator Anatomy ──"
echo "The buddy allocator manages pages in power-of-2 groups."
echo "Each 'order' represents 2^order contiguous pages."
echo ""
echo "  Order 0 = 1 page  (4 KB on x86_64)"
echo "  Order 1 = 2 pages (8 KB)"
echo "  Order 2 = 4 pages (16 KB)"
echo "  Order 3 = 8 pages (32 KB)"
echo "  ..."
echo "  Order 10 = 1024 pages (4 MB)"
echo ""
echo "The buddyinfo file shows free blocks per order per zone."
echo ""

echo "── Slab Allocator Architecture ──"
echo "  kmalloc() → slab cache (kmalloc-NNNN) → page allocator if needed"
echo ""
echo "  The slab allocator sits on top of the buddy allocator."
echo "  It manages objects of fixed sizes (8, 16, 32, 64, 96, 128, 192, 256, 512, 1024, 2048, 4096, 8192)."
echo "  Each cache has full / partial / empty slab lists."
echo ""

echo "── Memory Allocation Decision Tree ──"
echo "  Need < 8 KB, physically contiguous?  → kmalloc()"
echo "  Need > 8 KB, virtually contiguous?   → vmalloc()"
echo "  Need multiple pages?                  → alloc_pages() / __get_free_pages()"
echo "  Need DMA-capable memory?             → kmalloc(..., GFP_DMA)"
echo "  Can't sleep?                          → kmalloc(..., GFP_ATOMIC)"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Reload the module with stress test: insmod kernel_memory_demo.ko demo_stress=1"
echo "  2. Watch slab caches during test: watch -n1 'head -20 /proc/slabinfo'"
echo "  3. Observe buddy allocation: cat /proc/buddyinfo before/after module load"
echo "  4. Trigger OOM: write a small program that malloc()s repeatedly"
echo "  5. Explore vmstat counters: grep alloc /proc/vmstat"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /src
ENTRYPOINT ["/entrypoint.sh"]

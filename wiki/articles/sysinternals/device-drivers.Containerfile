# Device Drivers Lab - Character driver build environment with echo driver
# Build:  podman build -f sysinternals/device-drivers.Containerfile -t device-drivers-lab .
# Run:    podman run -it --rm --privileged device-drivers-lab
#
# Purpose: Provides kernel headers and build tools, then compiles, loads, exercises, and
# unloads a minimal echo character driver (open/read/write/release). The lab also prints the
# file_operations contract, device registration functions, and major device numbers.
#
# Requires --privileged to load kernel modules inside the container.

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    linux-headers \
    base-devel \
    kmod \
    procps-ng \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /src

COPY <<'MAKEFILE' /src/Makefile
obj-m += echo_driver.o

KDIR := /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)

default:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
MAKEFILE

COPY <<'ECHODRIVER' /src/echo_driver.c
/*
 * echo_driver.c — A minimal character device driver.
 *
 * Demonstrates: open, read, write, release file_operations.
 * The device stores a single buffer and returns it on read.
 * Writing to the device replaces the buffer contents.
 *
 * This is the "Hello World" of Linux device drivers.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/fs.h>
#include <linux/device.h>
#include <linux/cdev.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/version.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Device Drivers Lab");
MODULE_DESCRIPTION("Minimal echo character device driver");

#define DEVICE_NAME "echo"
#define CLASS_NAME  "echo_class"
#define BUFFER_SIZE  4096

static int    major_number;
static struct class    *echo_class  = NULL;
static struct device   *echo_device = NULL;
static char   *echo_buffer;
static size_t  echo_buffer_len;
static struct cdev echo_cdev;

/*
 * open() — Called when a process opens /dev/echo.
 * Returns 0 on success, negative errno on error.
 * This is where you would initialize per-open data.
 */
static int echo_open(struct inode *inodep, struct file *filep)
{
    pr_info("echo: open() called — device opened\n");
    pr_info("echo:   i_rdev = %d:%d\n", MAJOR(inodep->i_rdev), MINOR(inodep->i_rdev));
    pr_info("echo:   f_flags = 0x%x\n", filep->f_flags);
    pr_info("echo:   f_mode  = 0x%x (FMODE_READ=%d FMODE_WRITE=%d)\n",
        filep->f_mode,
        !!(filep->f_mode & FMODE_READ),
        !!(filep->f_mode & FMODE_WRITE));

    return 0;
}

/*
 * read() — Copy data from kernel buffer to userspace.
 * Returns number of bytes read, 0 for EOF, negative for error.
 */
static ssize_t echo_read(struct file *filep, char __user *buffer,
                         size_t len, loff_t *offset)
{
    size_t bytes_to_copy;
    int ret;

    pr_info("echo: read() called — len=%zu offset=%lld\n", len, *offset);

    /* Return 0 (EOF) if we've read everything */
    if (*offset >= echo_buffer_len)
        return 0;

    bytes_to_copy = min(len, echo_buffer_len - (size_t)*offset);

    ret = copy_to_user(buffer, echo_buffer + *offset, bytes_to_copy);
    if (ret) {
        pr_err("echo: copy_to_user failed — %d bytes not copied\n", ret);
        return -EFAULT;
    }

    pr_info("echo: read() — copied %zu bytes to userspace\n", bytes_to_copy);

    *offset += bytes_to_copy;
    return bytes_to_copy;
}

/*
 * write() — Copy data from userspace to kernel buffer.
 * Returns number of bytes written, negative for error.
 */
static ssize_t echo_write(struct file *filep, const char __user *buffer,
                          size_t len, loff_t *offset)
{
    size_t bytes_to_copy;

    pr_info("echo: write() called — len=%zu\n", len);

    bytes_to_copy = min(len, (size_t)(BUFFER_SIZE - 1));

    if (copy_from_user(echo_buffer, buffer, bytes_to_copy))
        return -EFAULT;

    echo_buffer[bytes_to_copy] = '\0';
    echo_buffer_len = bytes_to_copy;

    pr_info("echo: write() — stored %zu bytes: '%.20s%s'\n",
        bytes_to_copy, echo_buffer,
        bytes_to_copy > 20 ? "..." : "");

    return bytes_to_copy;
}

/*
 * release() — Called when the last file descriptor is closed.
 * Equivalent to close() in userspace.
 */
static int echo_release(struct inode *inodep, struct file *filep)
{
    pr_info("echo: release() called — device closed\n");
    return 0;
}

/* ── file_operations structure ── */
static struct file_operations fops = {
    .open    = echo_open,
    .read    = echo_read,
    .write   = echo_write,
    .release = echo_release,
    .owner   = THIS_MODULE,
};

/* ── Module init ── */
static int __init echo_init(void)
{
    pr_info("echo: ========================================\n");
    pr_info("echo: Initializing Echo Character Driver\n");
    pr_info("echo: ========================================\n");

    /* 1. Allocate a major number dynamically */
    major_number = register_chrdev(0, DEVICE_NAME, &fops);
    if (major_number < 0) {
        pr_err("echo: Failed to register character device\n");
        return major_number;
    }
    pr_info("echo: Registered with major number %d\n", major_number);

    /* 2. Create device class (appears in /sys/class/) */
#if LINUX_VERSION_CODE >= KERNEL_VERSION(6, 4, 0)
    echo_class = class_create(CLASS_NAME);
#else
    echo_class = class_create(THIS_MODULE, CLASS_NAME);
#endif
    if (IS_ERR(echo_class)) {
        unregister_chrdev(major_number, DEVICE_NAME);
        pr_err("echo: Failed to create class\n");
        return PTR_ERR(echo_class);
    }
    pr_info("echo: Class '%s' created in /sys/class/\n", CLASS_NAME);

    /* 3. Create device node */
    echo_device = device_create(echo_class, NULL,
                               MKDEV(major_number, 0), NULL, DEVICE_NAME);
    if (IS_ERR(echo_device)) {
        class_destroy(echo_class);
        unregister_chrdev(major_number, DEVICE_NAME);
        pr_err("echo: Failed to create device\n");
        return PTR_ERR(echo_device);
    }
    pr_info("echo: Device '/dev/%s' created\n", DEVICE_NAME);

    /* 4. Allocate kernel buffer */
    echo_buffer = kmalloc(BUFFER_SIZE, GFP_KERNEL);
    if (!echo_buffer) {
        device_destroy(echo_class, MKDEV(major_number, 0));
        class_destroy(echo_class);
        unregister_chrdev(major_number, DEVICE_NAME);
        return -ENOMEM;
    }
    memset(echo_buffer, 0, BUFFER_SIZE);
    echo_buffer_len = 0;
    pr_info("echo: Buffer allocated (%d bytes)\n", BUFFER_SIZE);

    pr_info("echo: ========================================\n");
    pr_info("echo: Driver initialized successfully!\n");
    pr_info("echo: Try: echo 'hello' > /dev/%s\n", DEVICE_NAME);
    pr_info("echo: Try: cat /dev/%s\n", DEVICE_NAME);
    pr_info("echo: ========================================\n");

    return 0;
}

/* ── Module exit ── */
static void __exit echo_exit(void)
{
    pr_info("echo: Shutting down...\n");

    kfree(echo_buffer);
    device_destroy(echo_class, MKDEV(major_number, 0));
    class_destroy(echo_class);
    unregister_chrdev(major_number, DEVICE_NAME);

    pr_info("echo: Driver unloaded. Goodbye!\n");
}

module_init(echo_init);
module_exit(echo_exit);
ECHODRIVER

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Device Drivers Lab — Character Driver Development ==="
echo ""
echo "This lab demonstrates the Linux device driver model with a"
echo "minimal character device driver (open/read/write/release)."
echo ""

echo "── Current Kernel Version ──"
echo "  $(uname -r)"
echo ""

echo "── Device Driver Architecture ──"
echo "  Userspace:  open('/dev/echo') → read() / write() → close()"
echo "  ───────────────────── syscall boundary ─────────────────────"
echo "  VFS:        struct file_operations { .open, .read, .write, .release }"
echo "  Driver:     echo_open() → echo_read() / echo_write() → echo_release()"
echo "  ───────────────────── kernel internal ─────────────────────"
echo "  Hardware:   (none for this virtual driver)"
echo ""

echo "── Building the Echo Driver ──"
cd /src
make 2>&1

if [ -f echo_driver.ko ]; then
    echo ""
    echo "  Module built: $(ls -lh echo_driver.ko)"
    echo ""
    
    echo "── Module Information (modinfo) ──"
    modinfo echo_driver.ko
    echo ""

    echo "── Loading the Echo Driver ──"
    insmod echo_driver.ko 2>&1 && echo "  Module loaded!" || echo "  Loading failed (needs --privileged)"

    if lsmod | grep -q echo_driver; then
        echo ""
        echo "── Verifying /dev/echo ──"
        ls -la /dev/echo 2>/dev/null && echo "  Device node exists!" || echo "  Device node not found"

        echo ""
        echo "── Testing the Echo Driver ──"
        echo "  Writing: echo 'Hello, kernel!' > /dev/echo"
        echo 'Hello, kernel!' > /dev/echo 2>/dev/null && echo "  Write succeeded!" || echo "  Write failed"

        echo ""
        echo "  Reading: cat /dev/echo"
        cat /dev/echo 2>/dev/null && echo "" && echo "  Read succeeded!" || echo "  Read failed"

        echo ""
        echo "── Driver Messages (dmesg) ──"
        dmesg 2>/dev/null | grep "echo:" | tail -20 || echo "  (dmesg not accessible)"

        echo ""
        echo "── Sysfs Entries ──"
        if [ -d /sys/class/echo_class ]; then
            echo "  Class: /sys/class/echo_class/"
            ls /sys/class/echo_class/echo/
        else
            echo "  /sys/class/echo_class not found"
        fi

        echo ""
        echo "── Unloading Driver ──"
        rmmod echo_driver 2>/dev/null && echo "  Driver unloaded!" || echo "  Unload failed"

        echo ""
        echo "── Clean Up ──"
        make clean
    fi
else
    echo ""
    echo "  ERROR: Module build failed. Check kernel headers:"
    echo "  $(ls /lib/modules/$(uname -r)/build/ 2>/dev/null | head -5)"
fi
echo ""

echo "── file_operations Reference ──"
echo "  struct file_operations {"
echo "      .open      = called on open(2)"
echo "      .read      = called on read(2) — copy_to_user()"
echo "      .write     = called on write(2) — copy_from_user()"
echo "      .release   = called on close(2)"
echo "      .llseek    = called on lseek(2)"
echo "      .unlocked_ioctl = called on ioctl(2)"
echo "      .mmap      = called on mmap(2)"
echo "      .poll      = called on poll(2) / select(2)"
echo "      .fsync     = called on fsync(2)"
echo "  };"
echo ""

echo "── Device Registration Functions ──"
echo "  register_chrdev(major, name, &fops)   — register with static/dynamic major"
echo "  alloc_chrdev_region(&dev, baseminor, count, name) — dynamic allocation"
echo "  cdev_init(&cdev, &fops)               — initialize cdev structure"
echo "  cdev_add(&cdev, dev, count)           — add cdev to system"
echo "  class_create(owner, name)             — create sysfs class"
echo "  device_create(class, parent, devt, drvdata, name) — create device node"
echo ""

echo "── Major Device Numbers Reference ──"
echo "  Character:    1=mem  4=tty*  5=tty  10=misc  13=input"
echo "  Block:        1=ram  3=hd   8=sd   9=md    11=sr  259=blkext"
echo "  Full list:    cat /proc/devices"
echo ""

echo "── User-Kernel Data Transfer ──"
echo "  copy_to_user(to, from, n)     — kernel → user (returns bytes NOT copied)"
echo "  copy_from_user(to, from, n)   — user → kernel (returns bytes NOT copied)"
echo "  get_user(x, ptr)              — reads a single value"
echo "  put_user(x, ptr)              — writes a single value"
echo "  access_ok(type, addr, size)   — verify user pointer validity"
echo ""

echo "── Current Devices ──"
cat /proc/devices 2>/dev/null | head -30 || echo "  (not accessible)"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Extend the echo driver with an ioctl that returns a counter"
echo "  2. Add a procfs entry (/proc/echo) that shows the current buffer"
echo "  3. Implement a blocking read (wait until data is available)"
echo "  4. Add a sysfs attribute to show buffer size"
echo "  5. Port the driver to use cdev_init/cdev_add instead of register_chrdev"
echo "  6. Try: echo 'new content' > /dev/echo && cat /dev/echo"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /src
ENTRYPOINT ["/entrypoint.sh"]

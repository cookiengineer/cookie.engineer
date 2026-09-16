# Rootkits Lab - detection tooling and cross-view checks
# Purpose: Educational rootkit detection lab. Intentionally vulnerable
#          environment; never expose it to a real network.
# Build:  podman build -f sysinternals/rootkits.Containerfile -t rootkits-lab .
# Run:    podman run -it --rm --privileged rootkits-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
    base-devel \
    linux-headers \
    git \
    python \
    python-pip \
    rkhunter \
    chkrootkit \
    unhide \
    bpftrace \
    bcc-tools \
    strace \
    busybox \
    procps-ng \
    net-tools \
    iproute2 \
    && pacman -Scc --noconfirm

# Initialize rkhunter database
RUN rkhunter --propupd --nocolors 2>&1 || true

# Educational kernel module showing how rootkits hook system calls
COPY <<'HEREDOC' /tmp/edu_rootkit.c
// Educational rootkit module — demonstrates syscall hooking concepts
// WARNING: This is for educational understanding only
// On modern kernels, sys_call_table is in .rodata and not directly modifiable

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/sched.h>
#include <linux/sched/signal.h>
#include <linux/list.h>
#include <linux/slab.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/version.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Educational");
MODULE_DESCRIPTION("Educational rootkit demonstration — process/connection listing");

static struct proc_dir_entry *proc_entry;

// List all processes by walking the kernel task list directly
static int edu_show_processes(struct seq_file *m, void *v)
{
    struct task_struct *task;
    int count = 0;

    seq_printf(m, "%-8s %-20s %-6s %s\n",
               "PID", "COMM", "STATE", "PARENT");

    rcu_read_lock();
    for_each_process(task) {
        seq_printf(m, "%-8d %-20s %-6ld %d\n",
                   task->pid, task->comm,
                   task->__state, task->parent ? task->parent->pid : 0);
        count++;
    }
    rcu_read_unlock();

    seq_printf(m, "\nTotal processes: %d\n", count);
    return 0;
}

static int edu_open(struct inode *inode, struct file *file)
{
    return single_open(file, edu_show_processes, NULL);
}

static const struct proc_ops edu_proc_ops = {
    .proc_open    = edu_open,
    .proc_read    = seq_read,
    .proc_lseek   = seq_lseek,
    .proc_release = single_release,
};

static int __init edu_rootkit_init(void)
{
    pr_info("[edu_rootkit] Module loaded — educational demonstration\n");
    pr_info("[edu_rootkit] On production kernels, sys_call_table is in .rodata\n");
    pr_info("[edu_rootkit] /proc/kallsyms shows: R sys_call_table (Read-only)\n");

    proc_entry = proc_create("edu_rootkit_tasks", 0444, NULL, &edu_proc_ops);
    if (!proc_entry)
        pr_err("[edu_rootkit] Failed to create /proc/edu_rootkit_tasks\n");
    else
        pr_info("[edu_rootkit] Created /proc/edu_rootkit_tasks — direct task_list walk\n");

    return 0;
}

static void __exit edu_rootkit_exit(void)
{
    if (proc_entry)
        proc_remove(proc_entry);
    pr_info("[edu_rootkit] Module unloaded\n");
}

module_init(edu_rootkit_init);
module_exit(edu_rootkit_exit);
HEREDOC

# Detection scripts
COPY <<'HEREDOC' /usr/local/bin/cross-view-detect.sh
#!/bin/bash
# Cross-view rootkit detection script
# Compares /proc listing with alternative process discovery methods

echo "=== Cross-View Process Detection ==="
echo

# Method 1: /proc directory listing
echo "[1] Scanning /proc for PID directories..."
ls /proc | grep -E '^[0-9]+$' | sort -n > /tmp/proc_pids

# Method 2: kill(0) brute force walk
echo "[2] Walking PIDs via kill(0) signal test..."
for i in $(seq 1 65536); do
    kill -0 $i 2>/dev/null && echo $i
done > /tmp/signal_pids

# Method 3: sched_debug (requires root)
echo "[3] Checking scheduler runqueues (sched_debug)..."
if [ -r /proc/sched_debug ]; then
    grep -oP 'pid\s+\K\d+' /proc/sched_debug | sort -n | uniq > /tmp/sched_pids 2>/dev/null
    echo "    Sched PIDs found: $(wc -l < /tmp/sched_pids)"
else
    echo "    /proc/sched_debug not readable (run as root)"
    touch /tmp/sched_pids
fi

# Compare
echo
echo "=== Results ==="
echo "PIDs in /proc:         $(wc -l < /tmp/proc_pids)"
echo "PIDs via kill(0):      $(wc -l < /tmp/signal_pids)"
echo "PIDs in sched_debug:   $(wc -l < /tmp/sched_pids)"
echo

# Find PIDs that respond to kill but aren't in /proc
echo "=== PIDs hidden from /proc ==="
comm -13 /tmp/proc_pids /tmp/signal_pids | while read pid; do
    echo "  HIDDEN PID: $pid (kill(0) succeeds but not in /proc)"
done

# Find PIDs in sched_debug but not in /proc
comm -13 /tmp/proc_pids /tmp/sched_pids | while read pid; do
    echo "  SCHED-HIDDEN PID: $pid (on runqueue but not in /proc)"
done

echo
echo "=== Module Detection ==="
echo "[1] Modules in /proc/modules:"
cut -d' ' -f1 /proc/modules | sort > /tmp/proc_mods

echo "[2] Modules via kallsyms:"
grep -oP '\[([a-zA-Z0-9_]+)\]$' /proc/kallsyms 2>/dev/null | \
    tr -d '[]' | sort -u > /tmp/kallsyms_mods

echo "[3] Modules only in kallsyms (hidden from /proc/modules):"
comm -13 /tmp/proc_mods /tmp/kallsyms_mods

echo
echo "=== LD_PRELOAD Detection ==="
if [ -f /etc/ld.so.preload ]; then
    echo "WARNING: /etc/ld.so.preload exists:"
    cat /etc/ld.so.preload
else
    echo "/etc/ld.so.preload: clean (no entry)"
fi

echo
echo "=== BPF Program Inspection ==="
bpftool prog list 2>/dev/null || echo "  bpftool not available"

# Cleanup
rm -f /tmp/proc_pids /tmp/signal_pids /tmp/sched_pids \
      /tmp/proc_mods /tmp/kallsyms_mods

echo
echo "Detection complete."
HEREDOC

RUN chmod +x /usr/local/bin/cross-view-detect.sh

# Script to demonstrate the educational module concepts
COPY <<'HEREDOC' /usr/local/bin/edu-rootkit-demo.sh
#!/bin/bash
echo "=== Educational Rootkit Concepts Demo ==="
echo

echo "1. sys_call_table status:"
grep sys_call_table /proc/kallsyms 2>/dev/null | head -5
echo "   Note: 'R' prefix = Read-only (.rodata section)"
echo

echo "2. Kernel hardening checks:"
echo "   modules_disabled: $(cat /proc/sys/kernel/modules_disabled)"
echo "   lockdown: $(cat /sys/kernel/security/lockdown 2>/dev/null || echo 'not available')"
echo "   unprivileged_bpf: $(cat /proc/sys/kernel/unprivileged_bpf_disabled)"
echo

echo "3. Running cross-view detection:"
/usr/local/bin/cross-view-detect.sh
echo

echo "4. Running rkhunter:"
rkhunter --check --skip-keypress --nocolors 2>&1 | tail -30
echo

echo "5. Running chkrootkit:"
chkrootkit 2>&1 | grep -v 'not infected\|nothing found\|INFECTED'
echo

echo "=== Demo Complete ==="
HEREDOC

RUN chmod +x /usr/local/bin/edu-rootkit-demo.sh

ENTRYPOINT ["/usr/local/bin/edu-rootkit-demo.sh"]

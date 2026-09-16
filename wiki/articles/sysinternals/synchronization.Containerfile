# synchronization.Containerfile
# Purpose: Build and exercise kernel synchronization primitives (spinlocks, mutexes,
#          RCU, seqlocks, atomics) and inspect lockdep/lock_stat.
# Build:   podman build -t sync-lab -f synchronization.Containerfile .
# Run:     podman run --rm --privileged -v /lib/modules:/lib/modules sync-lab
# Notes:   Inserting the module requires matching host kernel headers. The container
#          runs privileged because module load and debugfs/lock_stat need it.

FROM docker.io/archlinux:latest

RUN pacman -Sy --noconfirm linux-headers base-devel perf bpftrace strace

COPY <<'HEREDOC' /kernel-module/Makefile
obj-m += sync_lab.o

all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
HEREDOC

COPY <<'HEREDOC' /kernel-module/sync_lab.c
/*
 * sync_lab.c — Kernel synchronization lab module
 *
 * Demonstrates: spinlocks, mutexes, RCU, seqlocks, atomic ops, lockdep.
 * Build and insert to observe /proc/lock_stat and /proc/lockdep_stats.
 */

#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/init.h>
#include <linux/spinlock.h>
#include <linux/mutex.h>
#include <linux/rwlock.h>
#include <linux/semaphore.h>
#include <linux/kthread.h>
#include <linux/delay.h>
#include <linux/rcupdate.h>
#include <linux/slab.h>
#include <linux/completion.h>
#include <linux/seqlock.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>

MODULE_LICENSE("GPL");
MODULE_AUTHOR("sync_lab");
MODULE_DESCRIPTION("Synchronization primitives lab");

/* ─── Data structures with different locks ─── */

static DEFINE_SPINLOCK(lab_spinlock);
static int spinlock_data;

static DEFINE_MUTEX(lab_mutex);
static int mutex_data;

static DEFINE_RWLOCK(lab_rwlock);
static int rwlock_data;

static DEFINE_SEMAPHORE(lab_semaphore, 2);  /* counting, max 2 concurrent */

static DEFINE_SEQLOCK(lab_seqlock);
static unsigned long seqlock_data;

/* RCU-protected linked list */
struct rcu_node {
    int value;
    struct rcu_head rcu;
    struct list_head list;
};
static LIST_HEAD(rcu_list);
static DEFINE_SPINLOCK(rcu_list_lock);

static atomic_t atomic_counter = ATOMIC_INIT(0);

/* Thread functions */
static struct task_struct *threads[4];

static int spinlock_thread(void *data) {
    while (!kthread_should_stop()) {
        spin_lock(&lab_spinlock);
        spinlock_data++;
        if (spinlock_data > 1000000)
            spinlock_data = 0;
        spin_unlock(&lab_spinlock);
        schedule_timeout_interruptible(msecs_to_jiffies(1));
    }
    return 0;
}

static int mutex_thread(void *data) {
    while (!kthread_should_stop()) {
        mutex_lock(&lab_mutex);
        mutex_data += 2;
        msleep(5);
        mutex_unlock(&lab_mutex);
        schedule_timeout_interruptible(msecs_to_jiffies(1));
    }
    return 0;
}

static int reader_thread(void *data) {
    unsigned long seq;
    unsigned long val;

    while (!kthread_should_stop()) {
        /* RW lock reader */
        read_lock(&lab_rwlock);
        val = rwlock_data;
        read_unlock(&lab_rwlock);

        /* Seqlock reader (lock-free) */
        do {
            seq = read_seqbegin(&lab_seqlock);
            val = seqlock_data;
        } while (read_seqretry(&lab_seqlock, seq));

        /* RCU reader */
        rcu_read_lock();
        if (!list_empty(&rcu_list)) {
            struct rcu_node *node = list_first_or_null_rcu(&rcu_list,
                struct rcu_node, list);
            if (node)
                val += node->value;
        }
        rcu_read_unlock();

        schedule_timeout_interruptible(msecs_to_jiffies(5));
    }
    return 0;
}

static int writer_thread(void *data) {
    struct rcu_node *old, *new;
    int count = 0;

    while (!kthread_should_stop()) {
        /* RW lock writer */
        spin_lock(&lab_rwlock);
        rwlock_data = count;
        spin_unlock(&lab_rwlock);

        /* Seqlock writer */
        write_seqlock(&lab_seqlock);
        seqlock_data = count * 7 + 13;
        write_sequnlock(&lab_seqlock);

        /* RCU update (add new node, remove old if > 10 items) */
        new = kmalloc(sizeof(*new), GFP_KERNEL);
        if (new) {
            new->value = count;
            spin_lock(&rcu_list_lock);
            list_add_tail_rcu(&new->list, &rcu_list);
            spin_unlock(&rcu_list_lock);

            /* Trim if too many */
            spin_lock(&rcu_list_lock);
            if (!list_empty(&rcu_list)) {
                old = list_first_entry(&rcu_list, struct rcu_node, list);
                list_del_rcu(&old->list);
                synchronize_rcu();
                kfree(old);
            }
            spin_unlock(&rcu_list_lock);
        }

        count++;
        msleep(100);
    }
    return 0;
}

/* /proc/sync_lab entry */
static int sync_lab_show(struct seq_file *m, void *v) {
    seq_printf(m, "=== Synchronization Lab State ===\n");
    seq_printf(m, "spinlock_data: %d\n", spinlock_data);
    seq_printf(m, "mutex_data:    %d\n", mutex_data);
    seq_printf(m, "rwlock_data:   %d\n", rwlock_data);
    seq_printf(m, "atomic_ctr:    %d\n", atomic_read(&atomic_counter));
    seq_printf(m, "seqlock_data:  %lu\n", seqlock_data);
    return 0;
}

static int sync_lab_open(struct inode *inode, struct file *file) {
    return single_open(file, sync_lab_show, NULL);
}

static const struct proc_ops sync_lab_fops = {
    .proc_open    = sync_lab_open,
    .proc_read    = seq_read,
    .proc_lseek   = seq_lseek,
    .proc_release = single_release,
};

static int __init sync_lab_init(void) {
    pr_info("sync_lab: loading synchronization lab module\n");

    proc_create("sync_lab", 0444, NULL, &sync_lab_fops);

    threads[0] = kthread_run(spinlock_thread, NULL, "sync_spinlock");
    threads[1] = kthread_run(mutex_thread, NULL, "sync_mutex");
    threads[2] = kthread_run(reader_thread, NULL, "sync_reader");
    threads[3] = kthread_run(writer_thread, NULL, "sync_writer");

    if (IS_ERR(threads[0]) || IS_ERR(threads[1]) ||
        IS_ERR(threads[2]) || IS_ERR(threads[3])) {
        pr_err("sync_lab: failed to start threads\n");
        return -ENOMEM;
    }

    pr_info("sync_lab: threads started. Check /proc/sync_lab, /proc/lock_stat\n");
    return 0;
}

static void __exit sync_lab_exit(void) {
    int i;
    struct rcu_node *node, *tmp;

    for (i = 0; i < 4; i++)
        if (threads[i])
            kthread_stop(threads[i]);

    remove_proc_entry("sync_lab", NULL);

    /* Cleanup RCU list */
    spin_lock(&rcu_list_lock);
    list_for_each_entry_safe(node, tmp, &rcu_list, list) {
        list_del(&node->list);
        kfree(node);
    }
    spin_unlock(&rcu_list_lock);

    pr_info("sync_lab: module unloaded\n");
}

module_init(sync_lab_init);
module_exit(sync_lab_exit);
HEREDOC

COPY <<'HEREDOC' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Synchronization Lab ==="
echo ""

echo "[1] Kernel headers check:"
ls /lib/modules/$(uname -r)/build/Makefile > /dev/null 2>&1 && \
  echo "    OK: headers at /lib/modules/$(uname -r)/build" || \
  echo "    WARN: kernel headers not found (container may lack them)"

echo "[2] Building kernel module..."
cd /kernel-module && make 2>&1 || {
    echo "    WARN: build failed (expected in container without host headers)"
    echo "    To compile on host, run:"
    echo "      cd /kernel-module && make"
    echo "      sudo insmod sync_lab.ko"
    echo ""
    echo "    Then observe:"
    echo "      cat /proc/lock_stat | head -20"
    echo "      cat /proc/lockdep_stats"
    echo "      cat /proc/sync_lab"
}

echo ""
echo "[3] Preemption model:"
zcat /proc/config.gz 2>/dev/null | grep PREEMPT || grep PREEMPT /boot/config-$(uname -r) 2>/dev/null || echo "    (not available)"

echo ""
echo "[4] Locking features enabled:"
zcat /proc/config.gz 2>/dev/null | grep -E 'QUEUED_SPINLOCKS|LOCKDEP|LOCK_STAT|RCU|RT_MUTEXES|MUTEX_SPIN_ON_OWNER' || \
  grep -E 'QUEUED_SPINLOCKS|LOCKDEP|LOCK_STAT|RCU|RT_MUTEXES|MUTEX_SPIN_ON_OWNER' /boot/config-$(uname -r) 2>/dev/null || \
  echo "    (config not accessible)"

echo ""
echo "[5] Current lock statistics (if available):"
sudo cat /proc/lock_stat 2>/dev/null | head -15 || echo "    /proc/lock_stat not available (CONFIG_LOCK_STAT=n?)"

echo ""
echo "[6] Lockdep stats (if available):"
sudo cat /proc/lockdep_stats 2>/dev/null || echo "    /proc/lockdep_stats not available (CONFIG_LOCKDEP=n?)"

echo ""
echo "[7] RCU implementation details:"
cat /sys/kernel/debug/rcu/rcu_sched/rcugp 2>/dev/null | head -5 || echo "    (debugfs not mounted or RCU data not available)"

echo ""
echo "[8] User-space lock contention test:"
cat > /tmp/pi_test.c << 'PIEOF'
#define _GNU_SOURCE
#include <pthread.h>
#include <stdio.h>
int main() {
    pthread_mutex_t lock;
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_setprotocol(&attr, PTHREAD_PRIO_INHERIT);
    pthread_mutex_init(&lock, &attr);
    printf("    PI mutex initialized successfully\n");
    pthread_mutex_destroy(&lock);
    return 0;
}
PIEOF
gcc -pthread -o /tmp/pi_test /tmp/pi_test.c && /tmp/pi_test

echo ""
echo "[9] Atomic operations test (inline asm x86-64):"
cat > /tmp/atomic_test.c << 'ATEOF'
#include <stdio.h>
#include <stdatomic.h>
int main() {
    atomic_int counter = 0;
    printf("    atomic_int size: %zu bytes\n", sizeof(counter));
    atomic_fetch_add(&counter, 42);
    printf("    after atomic_fetch_add(42): %d\n", atomic_load(&counter));
    printf("    cmpxchg (expect %d): %s\n", counter,
           atomic_compare_exchange_strong(&counter, &(int){42}, &(int){99})
           ? "swapped → 99" : "unchanged");
    printf("    final value: %d\n", atomic_load(&counter));
    return 0;
}
ATEOF
gcc -O2 -o /tmp/atomic_test /tmp/atomic_test.c && /tmp/atomic_test

echo ""
echo "=== Lab complete ==="
echo ""
echo "To run the kernel module on your host:"
echo "  cd /kernel-module/code && make && sudo insmod sync_lab.ko"
echo "  sudo cat /proc/sync_lab"
echo "  sudo cat /proc/lock_stat | head -30"
echo "  sudo rmmod sync_lab"
HEREDOC

RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

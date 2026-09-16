# Context Switching Lab - CPU, FPU and scheduler accounting
# Build:  podman build -f sysinternals/context-switching.Containerfile -t ctx-switch .
# Run:    podman run --rm ctx-switch
#
# Purpose: Compiles a multithreaded CPU/FPU workload and samples it with perf stat, then
# prints the voluntary versus involuntary context switch counters, the system-wide rate from
# vmstat, and the XSAVE/PCID features reported by the CPU.

FROM docker.io/archlinux:latest

RUN pacman -Sy --noconfirm perf strace stress curl hwloc

COPY <<'HEREDOC' /workload.c
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <pthread.h>
#include <sched.h>
#include <string.h>
#include <time.h>

#define WORKERS 4
#define ITERATIONS 1000000

volatile int running = 1;

void *cpu_burner(void *arg) {
    int id = (int)(long)arg;
    volatile double x = 0.0;
    long iters = 0;
    while (running) {
        for (int i = 0; i < 10000; i++)
            x += i * 0.001 * (id + 1);
        iters++;
        if (iters % 10000 == 0)
            sched_yield();  /* trigger voluntary context switches */
        else
            usleep(0);      /* brief yield to speculatively trigger preemption */
    }
    return NULL;
}

void *fpu_burner(void *arg) {
    /* Heavy FPU/SSE workload that forces XSAVE/XRSTOR */
    volatile double results[16] __attribute__((aligned(64)));
    while (running) {
        for (int i = 0; i < 16; i++) {
            for (int j = 0; j < 10000; j++) {
                results[i] = results[i] * 1.000001 + (double)(i * j) * 0.000001;
            }
        }
        usleep(0);
    }
    return NULL;
}

int main() {
    pthread_t threads[WORKERS + 2];
    cpu_set_t cpus;

    printf("[+] CPU: %d cores, %ld KB cache\n",
           sysconf(_SC_NPROCESSORS_ONLN),
           sysconf(_SC_LEVEL1_DCACHE_SIZE) / 1024);

    /* Pin threads to specific CPUs to observe per-CPU ctx switches */
    for (int i = 0; i < WORKERS; i++) {
        CPU_ZERO(&cpus);
        CPU_SET(i % sysconf(_SC_NPROCESSORS_ONLN), &cpus);
        pthread_create(&threads[i], NULL, cpu_burner, (void *)(long)i);
        pthread_setaffinity_np(threads[i], sizeof(cpus), &cpus);
    }

    /* FPU-heavy thread */
    pthread_create(&threads[WORKERS], NULL, fpu_burner, NULL);
    pthread_create(&threads[WORKERS+1], NULL, fpu_burner, NULL);

    printf("[+] Running workload (Ctrl+C to stop)\n");
    printf("[+] Monitor with: perf stat -e context-switches,cpu-migrations ");
    printf("-p %d -- sleep 5\n", getpid());
    printf("[+] Or: watch -n1 'cat /proc/%d/status | grep ctxt'\n", getpid());
    fflush(stdout);

    sleep(600);
    running = 0;

    for (int i = 0; i < WORKERS + 2; i++)
        pthread_join(threads[i], NULL);

    return 0;
}
HEREDOC

COPY <<'HEREDOC' /entrypoint.sh
#!/bin/bash
set -e

echo "=== Context Switching Lab ==="
echo ""

echo "[1] Build workload generator..."
gcc -pthread -O2 -o /workload /workload.c -lm

echo "[2] CPU topology:"
lstopo-no-graphics --no-io 2>/dev/null || lstopo --no-io 2>/dev/null || echo "(lstopo not available)"

echo ""
echo "[3] Current context switch counters:"
cat /proc/stat | grep ctxt

echo ""
echo "[4] Running workload in background..."
/workload &
PID=$!
sleep 2

echo ""
echo "[5] Workload PID: $PID"
echo ""
echo "    Voluntary vs involuntary switches:"
cat /proc/$PID/status | grep ctxt

echo ""
echo "[6] Measuring context switch rate with perf (5 second sample)..."
perf stat -e context-switches,cpu-migrations,page-faults \
    -e cycles,instructions,L1-dcache-load-misses,LLC-load-misses \
    -e dTLB-load-misses,dTLB-store-misses \
    -p $PID -- sleep 5 2>&1 || echo "(perf not available or no permission)"

echo ""
echo "[7] Final switch counts:"
cat /proc/$PID/status | grep ctxt

echo ""
echo "[8] System-wide context switch rate (vmstat):"
vmstat 1 3

echo ""
echo "[9] TLB / Meltdown status:"
cat /sys/devices/system/cpu/vulnerabilities/meltdown 2>/dev/null || echo "(not available)"
grep pcid /proc/cpuinfo > /dev/null && echo "PCID: supported" || echo "PCID: not supported"

echo ""
echo "[10] XSAVE features:"
grep -E '^flags' /proc/cpuinfo | head -1 | tr ' ' '\n' | grep -E 'xsave|avx|fpu|xmm|ymm|zmm' | sort

echo ""
echo "=== Lab complete ==="
kill $PID 2>/dev/null || true
wait $PID 2>/dev/null || true
HEREDOC

RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

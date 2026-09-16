# ebpf.Containerfile - BPF development environment with a syscall counter
# Purpose: Build, load, and inspect a BPF program with clang, libbpf, and bpftool.
# Build:  podman build -f sysinternals/ebpf.Containerfile -t ebpf-lab .
# Run:    podman run -it --rm --privileged ebpf-lab

FROM docker.io/archlinux:latest

RUN pacman -Syu --noconfirm && pacman -S --noconfirm \
    clang \
    llvm \
    libbpf \
    bpftool \
    linux-headers \
    base-devel \
    python \
    make \
    && pacman -Scc --noconfirm \
    && rm -rf /var/cache/pacman/pkg/*

RUN mkdir -p /bpf/src

COPY <<'BPF_SOURCE' /bpf/src/syscall_counter.bpf.c
// SPDX-License-Identifier: GPL-2.0
// syscall_counter.bpf.c — BPF program that counts syscalls per process.

#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 10240);
    __type(key, __u32);
    __type(value, __u64);
} syscall_count_map SEC(".maps");

SEC("tracepoint/raw_syscalls/sys_enter")
int count_syscalls(void *ctx)
{
    __u32 pid = bpf_get_current_pid_tgid() >> 32;
    __u64 *count, new_count;

    count = bpf_map_lookup_elem(&syscall_count_map, &pid);
    if (count) {
        new_count = *count + 1;
        bpf_map_update_elem(&syscall_count_map, &pid, &new_count, BPF_ANY);
    } else {
        new_count = 1;
        bpf_map_update_elem(&syscall_count_map, &pid, &new_count, BPF_ANY);
    }
    return 0;
}

char LICENSE[] SEC("license") = "GPL";
BPF_SOURCE

COPY <<'LOADER' /bpf/src/syscall_loader.c
// SPDX-License-Identifier: GPL-2.0
// syscall_loader.c — Userspace loader for the BPF syscall counter.

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>

static volatile sig_atomic_t running = 1;

static void sig_handler(int sig) { running = 0; }

int main(int argc, char **argv) {
    struct bpf_object *obj = NULL;
    struct bpf_program *prog;
    struct bpf_link *link = NULL;
    int map_fd, err, interval = 1;

    if (argc > 1) interval = atoi(argv[1]);

    obj = bpf_object__open_file("syscall_counter.bpf.o", NULL);
    if (libbpf_get_error(obj)) {
        fprintf(stderr, "ERROR: opening BPF object\n");
        return 1;
    }

    err = bpf_object__load(obj);
    if (err) {
        fprintf(stderr, "ERROR: loading BPF object\n");
        return 1;
    }

    bpf_object__for_each_program(prog, obj) {
        const char *name = bpf_program__name(prog);
        printf("BPF program: %s\n", name);
        link = bpf_program__attach(prog);
        if (libbpf_get_error(link)) {
            fprintf(stderr, "ERROR: attaching %s\n", name);
            link = NULL;
            continue;
        }
        printf("  Attached.\n");
    }

    if (!link) {
        fprintf(stderr, "No programs were attached.\n");
        return 1;
    }

    map_fd = bpf_object__find_map_fd_by_name(obj, "syscall_count_map");
    if (map_fd < 0) {
        fprintf(stderr, "ERROR: finding map\n");
        return 1;
    }

    printf("\n=== Syscall Counter Running ===\n");
    printf("Polling BPF map every %d second(s). Ctrl+C to stop.\n\n", interval);

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    while (running) {
        __u32 key = 0, next_key;
        __u64 value;

        printf("\033[2J\033[H");
        printf("=== Top Syscall-Counting Processes ===\n");
        printf("%-10s %-16s %s\n", "PID", "COUNT", "COMMAND");
        printf("-----------------------------------------\n");

        while (bpf_map_get_next_key(map_fd, &key, &next_key) == 0) {
            if (bpf_map_lookup_elem(map_fd, &next_key, &value) == 0) {
                char comm[256] = "?";
                char path[64];
                snprintf(path, sizeof(path), "/proc/%u/comm", next_key);
                FILE *f = fopen(path, "r");
                if (f) {
                    if (fgets(comm, sizeof(comm), f))
                        comm[strcspn(comm, "\n")] = 0;
                    fclose(f);
                }
                printf("%-10u %-16lu %s\n", next_key, value, comm);
            }
            key = next_key;
        }

        fflush(stdout);
        sleep(interval);
    }

    printf("\nCleaning up...\n");
    bpf_link__destroy(link);
    bpf_object__close(obj);
    printf("Done.\n");
    return 0;
}
LOADER

COPY <<'MAKEFILE' /bpf/src/Makefile
CLANG   ?= clang
LLC     ?= llc
CC      ?= gcc
CFLAGS  := -O2 -Wall
BPF_CFLAGS := -O2 -g -target bpf -D__TARGET_ARCH_x86

LIBBPF_DIR  := /usr/lib64
INCLUDES    := -I/usr/include

all: syscall_counter.bpf.o syscall_loader

syscall_counter.bpf.o: syscall_counter.bpf.c
	$(CLANG) $(BPF_CFLAGS) $(INCLUDES) -c $< -o $@

syscall_loader: syscall_loader.c
	$(CC) $(CFLAGS) $(INCLUDES) $< -L$(LIBBPF_DIR) -lbpf -lelf -lz -o $@

clean:
	rm -f syscall_counter.bpf.o syscall_loader
MAKEFILE

COPY <<'ENTRY' /entrypoint.sh
#!/bin/bash
set -e

echo "=== eBPF Development Lab — BPF Programs & Maps ==="
echo ""
echo "This lab provides a complete eBPF development environment."
echo "Build, load, and inspect BPF programs with bpftool."
echo ""

echo "── eBPF Architecture ──"
echo ""
echo "  Userspace                   Kernel"
echo "  ─────────                   ──────"
echo "  BPF C source                BPF Verifier"
echo "       │                          │"
echo "  clang -target bpf               ▼"
echo "       │                     Bytecode OK?"
echo "       ▼                          │"
echo "  BPF .o (ELF)                    ▼"
echo "       │                     JIT Compiler"
echo "  libbpf: load/attach             │"
echo "       │                          ▼"
echo "       └─────────► BPF Maps ◄──── Native Code"
echo "                     ▲"
echo "              Userspace can read"
echo ""

echo "── Environment Check ──"
echo "  clang:   $(which clang 2>/dev/null || echo 'NOT FOUND')"
echo "  llc:     $(which llc 2>/dev/null || echo 'NOT FOUND')"
echo "  bpftool: $(which bpftool 2>/dev/null || echo 'NOT FOUND')"
echo "  libbpf:  $(find /usr -name 'libbpf.so*' 2>/dev/null | head -1 || echo 'check /usr/lib64/')"
echo ""

echo "── BPF Map Types Reference ──"
echo "  BPF_MAP_TYPE_HASH          — generic hash table"
echo "  BPF_MAP_TYPE_ARRAY         — fixed-size array"
echo "  BPF_MAP_TYPE_PERCPU_HASH   — per-CPU hash"
echo "  BPF_MAP_TYPE_PERCPU_ARRAY  — per-CPU array"
echo "  BPF_MAP_TYPE_RINGBUF       — ring buffer (replaces perfbuf)"
echo "  BPF_MAP_TYPE_STACK_TRACE   — stack traces"
echo "  BPF_MAP_TYPE_LPM_TRIE      — longest prefix match"
echo "  BPF_MAP_TYPE_BLOOM_FILTER  — bloom filter"
echo "  BPF_MAP_TYPE_LRU_HASH      — LRU eviction hash"
echo "  BPF_MAP_TYPE_QUEUE         — FIFO queue"
echo "  BPF_MAP_TYPE_STACK         — LIFO stack"
echo ""

echo "── BPF Helper Functions Reference ──"
echo "  bpf_map_lookup_elem()     — read map entry"
echo "  bpf_map_update_elem()     — write map entry"
echo "  bpf_map_delete_elem()     — remove map entry"
echo "  bpf_map_push_elem()       — push to queue/stack"
echo "  bpf_map_pop_elem()        — pop from queue/stack"
echo "  bpf_get_current_pid_tgid() — get PID/TGID"
echo "  bpf_get_current_comm()    — get task name"
echo "  bpf_ktime_get_ns()        — monotonic clock (ns)"
echo "  bpf_trace_printk()        — debug print to trace_pipe"
echo "  bpf_get_stackid()         — capture stack trace"
echo "  bpf_probe_read()          — safe kernel memory read"
echo "  bpf_perf_event_output()   — write to ring buffer"
echo ""

echo "── Building BPF Program ──"
cd /bpf/src
make 2>&1

if [ -f syscall_counter.bpf.o ]; then
    echo ""
    echo "  BPF object: $(ls -lh syscall_counter.bpf.o)"
    echo ""

    echo "── BPF Object Analysis (llvm-objdump) ──"
    llvm-objdump -S syscall_counter.bpf.o 2>/dev/null | head -40 || \
        objdump -S syscall_counter.bpf.o 2>/dev/null | head -40 || \
        echo "  (objdump not available)"
    echo ""

    echo "── Loading BPF Program ──"
    bpftool prog load syscall_counter.bpf.o /sys/fs/bpf/syscall_counter \
        type tracepoint 2>&1 || echo "  (loading failed — needs bpftool / --privileged)"
    echo ""

    echo "── Inspecting with bpftool ──"
    bpftool prog list 2>/dev/null | head -20 || echo "  (bpftool not available)"
    echo ""

    echo "── Inspecting BPF Maps ──"
    bpftool map list 2>/dev/null | head -20 || echo "  (no maps visible)"
    echo ""

    if [ -x syscall_loader ]; then
        echo "── Running BPF Loader ──"
        echo "  ./syscall_loader 2"
        echo "  (This will attach the tracepoint and display live syscall counts)"
    fi
else
    echo "  Build failed. Check that clang + libbpf are installed."
fi
echo ""

echo "── bpftool Common Commands ──"
echo "  bpftool prog list                    — list loaded BPF programs"
echo "  bpftool prog show id <ID>            — details of a specific program"
echo "  bpftool prog dump xlated id <ID>     — dump translated instructions"
echo "  bpftool prog dump jited  id <ID>     — dump JIT-compiled code"
echo "  bpftool map list                     — list all BPF maps"
echo "  bpftool map dump id <ID>             — dump map contents"
echo "  bpftool map lookup id <ID> key <hex> — lookup specific key"
echo "  bpftool map pin  id <ID> <path>      — pin map to BPF filesystem"
echo "  bpftool prog pin  id <ID> <path>     — pin program to BPF filesystem"
echo "  bpftool cgroup list                  — list cgroup-attached programs"
echo "  bpftool net list                     — list network-attached programs"
echo "  bpftool gen skeleton <file>.bpf.o    — generate BPF skeleton header"
echo "  bpftool btf dump id <ID>             — dump BTF type info"
echo ""

echo "── BPF Program Types ──"
echo "  BPF_PROG_TYPE_SOCKET_FILTER  — socket filtering"
echo "  BPF_PROG_TYPE_KPROBE          — kernel function probing"
echo "  BPF_PROG_TYPE_TRACEPOINT      — static tracepoints"
echo "  BPF_PROG_TYPE_XDP             — eXpress Data Path"
echo "  BPF_PROG_TYPE_PERF_EVENT      — perf event sampling"
echo "  BPF_PROG_TYPE_CGROUP_SKB      — cgroup packet filtering"
echo "  BPF_PROG_TYPE_CGROUP_SOCK     — cgroup socket control"
echo "  BPF_PROG_TYPE_LWT_IN          — lightweight tunnel input"
echo "  BPF_PROG_TYPE_TRACING         — BTF-based tracing (fentry/fexit)"
echo "  BPF_PROG_TYPE_STRUCT_OPS      — kernel struct ops replacement"
echo "  BPF_PROG_TYPE_SYSCALL         — syscall programs"
echo ""

echo "── BPF Attach Types ──"
echo "  tracepoint, kprobe, kretprobe, uprobe, uretprobe"
echo "  fentry, fexit (BTF-based, lower overhead)"
echo "  cgroup_inet_ingress, cgroup_inet_egress"
echo "  xdp (driver / generic / offload mode)"
echo ""

echo "── Writing a BPF Program (Cheat Sheet) ──"
echo ""
echo "  1. Define maps:"
echo "     struct { __uint(type, BPF_MAP_TYPE_HASH); ... } name SEC(\".maps\");"
echo ""
echo "  2. Write probe function:"
echo "     SEC(\"tracepoint/category/event\")"
echo "     int my_probe(void *ctx) { ... return 0; }"
echo ""
echo "  3. Add license:"
echo "     char LICENSE[] SEC(\"license\") = \"GPL\";"
echo ""
echo "  4. Compile:"
echo "     clang -O2 -g -target bpf -c prog.bpf.c -o prog.bpf.o"
echo ""
echo "  5. Load and attach (userspace):"
echo "     bpf_object__open_file() → bpf_object__load() → bpf_program__attach()"
echo ""

echo "=== Lab Complete ==="
echo ""
echo "Exercises:"
echo "  1. Build and load the syscall counter: make && bpftool prog load ..."
echo "  2. Run the loader: ./syscall_loader 2"
echo "  3. While the loader runs, generate activity: ls /; find /etc -name '*.conf'"
echo "  4. Use bpftool to inspect the running program"
echo "  5. Modify the BPF program to count specific syscalls by ID"
echo "  6. Add a ring buffer map for event streaming"
echo "  7. Generate a BPF skeleton: bpftool gen skeleton syscall_counter.bpf.o"
echo ""

exec bash
ENTRY

RUN chmod +x /entrypoint.sh
WORKDIR /bpf/src
ENTRYPOINT ["/entrypoint.sh"]

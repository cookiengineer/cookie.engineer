
section .text
    global _start

_start:
    ; set two registers for demonstration
    mov rax, 13
    mov rdx, 37

    ; rax stored at address 0 * 8
    ; increment rsp address to where the value of 13 is
    push rax

    ; rdx stored at address 1 * 8
    ; increment rsp address to where the value of 37 is
    push rdx

    ; set rax to the value of [rsp + 8], which is 13
    mov rax, [rsp + 8]

    cmp rax, 13
    je .success
    jmp .failure

.success:
    mov rax, 60
    mov rdi, 0
    syscall

.failure:
    mov rax, 60
    mov rdi, 1
    syscall

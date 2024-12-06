section .data
    ; Define our numbers
    num1: equ 13
    num2: equ 37

    ; Define our messages
    msg1: db "Sum is correct!"
    msg2: db "Sum is incorrect!"

section .text
    global _start

_start:

    mov rax, num1
    mov rbx, num2
    add rax, rbx  ; add(rax, rbx) stores the result in rax

    cmp rax, 50
    je .print_correct
    jmp .print_incorrect

.print_correct:

    mov rax, 1
    mov rdi, 1
    mov rsi, msg1
    mov rdx, 15
    syscall
    jmp .exit_correct

.print_incorrect:

    mov rax, 1
    mov rdi, 1
    mov rsi, msg2
    mov rdx, 17
    syscall
    jmp .exit_incorrect

.exit_correct:
    mov rax, 60
    mov rdi, 0
    syscall

.exit_incorrect:
    mov rax, 60
    mov rdi, 1
    syscall

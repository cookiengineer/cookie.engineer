section .bss
    buffer resb 20 ; reserve 64 bytes

section .text
    global _start

_start:
    push rbp     ; preserve base pointer
    mov rbp, rsp ; set the new base pointer

    ; stack contains the last 2 arguments
    push 8 ; push 8th argument to stack
    push 7 ; push 7th argument to stack

    ; registers contain the first 6 arguments
    mov rdi, 1
    mov rsi, 2
    mov rdx, 3
    mov rcx, 4
    mov r8, 5
    mov r9, 6

    call .makesum
    add rsp, 16 ; clean up the two arguments on the stack

    ; rax = input
    ; convert rax to string, rsi = buffer, rdx = length
    call .sprintf

    ; print to stdout
    mov rax, 1
    mov rdi, 1
    mov rsi, buffer
    mov rdx, 64
    syscall

    ; exit with code 0
    call .exit

.exit:
    mov rax, 60
    mov rdi, 0
    syscall

.sprintf:
    mov rcx, 0
    mov rsi, buffer + 19 ; point to end of buffer
    mov rbx, 10

    test rax, rax
    jnz .divide_by_10_loop

    ; rax == 0 case
    dec rsi
    mov byte [rsi], '0'
    mov rdx, 1
    ret

.divide_by_10_loop:
    xor rdx, rdx
    div rbx

    add dl, '0'
    dec rsi
    mov [rsi], dl

    inc rcx
    test rax, rax
    jnz .divide_by_10_loop

    mov rdx, rcx
    ret

.makesum:
    push rbp     ; preserve base pointer
    mov rbp, rsp ; set the new base pointer

    mov rax, rdi ; arg1
    add rax, rsi ; + arg2
    add rax, rdx ; + arg3
    add rax, rcx ; + arg4
    add rax, r8  ; + arg5
    add rax, r9  ; + arg6

    ; stack layout at function entry:
    ; [rsp] -> return address
    ; [rsp+8] -> 7th argument
    ; [rsp+16] -> 8th argument

    mov rbx, [rbp + 16] ; arg7
    add rax, rbx

    mov rbx, [rbp + 24] ; arg8
    add rax, rbx

    ; leave function and return
    ; rax contains sum
    pop rbp
    ret

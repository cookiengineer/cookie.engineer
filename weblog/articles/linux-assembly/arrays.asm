section .data
    numbers: dq 13, 37, 50, 24, 481
    numbers_len: equ 5

    label_sum: db "Sum: "
    newline:   db 0x0a

section .bss
    buffer resb 20

section .text
    global _start

_start:
    xor rax, rax ; sum = 0
    xor rcx, rcx ; index = 0

.sum_loop:
    add rax, [numbers + rcx * 8]
    inc rcx
    cmp rcx, numbers_len
    jl .sum_loop

    mov rsi, label_sum
    mov rdx, 5
    call .write
    call .print_number
    call .print_newline
    call .exit

.write:
    push rax       ; preserve the caller's rax (syscall clobbers it)
    mov rax, 1
    mov rdi, 1
    syscall
    pop rax
    ret

.print_newline:
    mov rsi, newline
    mov rdx, 1
    call .write
    ret

.print_number:
    ; rax contains the unsigned number to print
    mov rcx, 0
    mov rsi, buffer + 19 ; point to the end of the buffer
    mov rbx, 10

    test rax, rax
    jnz .convert_loop

    ; handle the zero case
    dec rsi
    mov byte [rsi], '0'
    mov rcx, 1
    jmp .print_number_done

.convert_loop:
    xor rdx, rdx
    div rbx

    add dl, '0'
    dec rsi
    mov [rsi], dl

    inc rcx
    test rax, rax
    jnz .convert_loop

.print_number_done:
    mov rdx, rcx
    call .write
    ret

.exit:
    mov rax, 60
    mov rdi, 0
    syscall

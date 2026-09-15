section .data
    num1: equ 13
    num2: equ 37

    label_sum:  db "Sum:      "
    label_diff: db "Diff:     "
    label_prod: db "Product:  "
    label_quot: db "Quotient: "
    label_rem:  db "Remainder:"
    newline:    db 0x0a

section .bss
    buffer resb 20

section .text
    global _start

_start:
    ; sum = num1 + num2 = 50
    mov rax, num1
    add rax, num2
    mov rsi, label_sum
    mov rdx, 10
    call .write
    call .print_number
    call .print_newline

    ; difference = num2 - num1 = 24
    mov rax, num2
    sub rax, num1
    mov rsi, label_diff
    mov rdx, 10
    call .write
    call .print_number
    call .print_newline

    ; product = num1 * num2 = 481
    mov rax, num1
    mov rbx, num2
    mul rbx
    mov rsi, label_prod
    mov rdx, 10
    call .write
    call .print_number
    call .print_newline

    ; quotient = num2 / num1 = 2
    mov rax, num2
    xor rdx, rdx
    mov rbx, num1
    div rbx
    push rdx           ; save the remainder (rdx is clobbered by print_number)
    mov rsi, label_quot
    mov rdx, 10
    call .write
    call .print_number
    call .print_newline

    ; remainder = num2 % num1 = 11
    pop rax             ; restore the remainder
    mov rsi, label_rem
    mov rdx, 10
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

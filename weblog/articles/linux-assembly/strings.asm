section .data
    source: db "Hello, World!", 0
    source_len: equ $ - source ; 14 bytes (13 characters + null terminator)

    label_len:  db "Length: "
    label_copy: db "Copy:   "
    newline:    db 0x0a

section .bss
    dest resb 32
    buffer resb 20

section .text
    global _start

_start:
    ; strlen via repne scasb
    xor al, al       ; search for the null byte
    mov rdi, source  ; start scanning at source
    mov rcx, -1      ; scan "forever" (until a match is found)
    cld              ; clear direction flag (scan forward)
    repne scasb      ; decrement rcx and compare [rdi] with al

    ; rdi now points one byte past the null terminator
    mov rax, rdi
    sub rax, source
    dec rax          ; rax = length = 13

    mov rsi, label_len
    mov rdx, 8
    call .write
    call .print_number
    call .print_newline

    ; memcpy source -> dest via rep movsb
    mov rsi, source  ; source pointer
    mov rdi, dest    ; destination pointer
    mov rcx, source_len
    cld              ; copy forward
    rep movsb        ; copy rcx bytes from [rsi] to [rdi]

    mov rsi, label_copy
    mov rdx, 8
    call .write
    mov rsi, dest
    mov rdx, source_len - 1
    call .write
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

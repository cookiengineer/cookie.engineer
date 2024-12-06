section .data
	msg db "Hello, World!"

section .text
	global _start

_start:
	mov rax, 1    ; syscall 1 "ksys_write(rdi, rsi, rdx)"
	mov rdi, 1    ; int 1 for standard output
	mov rsi, msg  ; pointer to message
	mov rdx, 13   ; length of message
	syscall       ; execute syscall stored in rax

	mov rax, 60   ; syscall 60 for "exit(rdi)"
	mov rdi, 0    ; int 0 for exit code
	syscall       ; execute syscall stored in rax

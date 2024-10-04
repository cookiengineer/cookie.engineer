===
- date: 2024-10-01
- name: Linux Assembly Part 1
- tags: linux, assembly
- type: software, research
- crux: Learn assembly for Linux syscalls
===


This is my attempt at writing down my personal notes in the form of a tutorial
on Linux binary exploitation and how syscalls work behind the scenes by learning
how to write code in assembler.

I chose to use `nasm` here for the sake of explaining how assembly works behind
the scenes, and my goal is to move to `go` as a high level programming language
to write/port that binary exploitation code.

This way the reader or an older me can take a look at this article and use it as
a somewhat how-to guide to figure things out again in case I or you forget them.


## Requirements and Tools

- Install `nasm` assembler
- Install `go` toolchain

```bash
sudo pacman -S go nasm;
```


## Hello World in C

In order to understand how a program is structured in `asm` we first need to
understand how a typical program looks like when we write it in `C`.

The best example is a simple program that outputs `Hello World` and uses `printf()`
behind the scenes.

```c
#include <stdio.h>

int main() {
	printf("Hello, world!");
	return 0;
}
```


## Anatomy of NASM assembly

An assembly program usually tries to reflect the `binary` formats it is targeting.
In this case, we target `ELF` as a format, which is divided in two different sections:

- `.data` section that contains `variables`, `constants` and `strings`
- `.text` section that contains defined `methods` and rest of the actual program

The syntax of a NASM assembly line looks like this, where statements inside a square
bracket are optional:

`[label:] instruction [operands] [; comment]`


## Syscall Values

The syscall table for the upstream Linux is available in the [syscall_64.tbl](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl)
file for the `amd64` architecture. The [syscall_32.tbl](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_32.tbl)
contains the syscall numbers for the `i386` architecture.

- syscall `1` calls `ksys_write(rdi, rsi, rdx)`
- syscall `60` calls `exit(rdi)`

## Registers

For now, we stick to the basics and the registers we need to do to call the `ksys_write()` method
with our given parameters. Before we know which registers to use, we need to understand how the
functions are defined in the `C ABI` of the kernel.

The anatomy of the `ksys_write()` function method looks like this and is defined in the
[fs/read_write.c](https://github.com/torvalds/linux/blob/master/fs/read_write.c) file:

```c
// From linux/fs/read_write.c
SYSCALL_DEFINE3(write, unsigned int, fd, const char __user *, buf, size_t, count)
{
	return ksys_write(fd, buf, count);
}

// which is equivalent to
size_t ksys_write(unsigned int fd, const char *buffer, size_t length);
```

This means that we need the following registers to execute the `syscall`:

- `rax` is the temporary register that has to contain the `syscall number`.
- `rdi` is the 1st function argument, representing `unsigned int fd`.
- `rsi` is the 2nd function argument, representing the pointer to `const char *buffer`.
- `rdx` is the 3rd function argument, representing the message `size_t length`.

The `unsigned int fd` parameter can have the following values:

- `0` for `stdin` or standard input
- `1` for `stdout` or standard output
- `2` for `stderr` or standard error

Remember this from bash? You can redirect those standard input, output, and error messages
by using e.g. something like `program 2> /dev/null` to ignore them. `0`, `1`, and `2`
represent the same thing here as in our assembly program.


## Hello World in NASM

```asm
section .data
	msg db "Hello, World!"

section .text
	global _start

_start:
	mov rax, 1;   syscall 1 "ksys_write(rdi, rsi, rdx)"
	mov rdi, 1;   int 1 for standard output
	mov rsi, msg; pointer to message
	mov rdx, 13;  length of message
	syscall;      execute syscall stored in rax

	mov rax, 60;  syscall 60 for "exit(rdi)"
	mov rdi, 0;   int 0 for exit code
	syscall;      execute syscall stored in rax
```

If we compile and run our program, we can see the `Hello, World!` message:

```bash
nasm -f elf64 -o hello.o hello.asm;
ld -o hello.bin hello.o;

chmod +x hello.bin;
./hello.bin;
```

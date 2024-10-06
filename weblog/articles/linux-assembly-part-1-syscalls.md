===
- date: 2024-10-01
- name: Linux Assembly Part 1: Syscalls
- tags: linux, assembly
- type: software, research
- crux: Learn Linux assembly to execute syscalls.
===


This is my attempt at writing down my personal notes in the form of a tutorial.
The tutorial for now wants to go deeper into the topics of binary exploitation
techniques, and also describe how EDR evasion techniques work behind the scenes.

Most of these topics, however, require a fundemental understanding of assembly
and shellcoding. That is why we are going to learn about assembly first, before
we can continue to new realms of malware development techniques.

I chose to use `nasm` as an assembler here for the sake of ease of use, and my
my goal is to move towards `go` as a high level programming language to write
and backport binary exploitation code, so that you can learn why most APTs have
moved towards `go` and `c#` as a programming language.

This way you or an older fool like me can take a look at this article and use it
as a reference guide on how to relearn things again in case I forget about them.


## Requirements and Tools

- Install the `gcc` compiler toolchain
- Install the `go` compiler toolchain
- Install the `nasm` assembler

```bash
sudo pacman -S gcc go nasm;
```


## Hello World in C

In order to understand how a program is structured in `asm` we first need to
understand how a typical program looks like when we write it in `C`.

The best example is a simple program that outputs `Hello World` and uses `printf()`
behind the scenes.

```c
#include <stdio.h>

int main() {
	printf("Hello, World!");
	return 0;
}
```

If we compile the program with `gcc` and execute it, it will print out our `Hello, World!`
message:

```bash
gcc -o main.bin main.c;

chmod +x ./main.bin;
./main.bin;
```


## Binary Formats

In order to understand how we can get from high-level programming language code
like `C` to our low-level programming language `asm`, we need to first understand
what binary formats are.

What's important is that there are different sections inside each program, and they
vary depending on the targeted binary format and whether or not they are a shared
library that contains reusable functions for other programs.

The most common binary formats are:

- `COFF` the common object file format for Unices (but meanwhile is used in malware for sideloading)
- `ELF` the executable and linkable format for GNU/Linux
- `Mach-O` the mach object format for Darwin, MacOS and MacOSX
- `MZ` the format for MS-DOS, which meanwhile is somewhat migrated to `PE`
- `PE` the portable executable format for Windows
- `PE32+` the ironically 64bit-targeting portable executable format for Windows
- `PRG` the format for the C64 (yeah I'm _that_ old)

The `PE` format is a little different here because Microsoft tried to reuse the same `PE` format
for compatibility reasons over the years, which means that newer programs usually have to
contain a special header to let the kernel and the users know that it cannot be run in `MS-DOS`
mode or inside the `cmd.exe` environment directly. We're going to learn about the quirks of
`PE` later in this article series.

Wikipedia has a really nice [Comparison of Executable File Formats](https://en.wikipedia.org/wiki/Comparison_of_executable_file_formats)
article that I recommend you to check out.


## Anatomy of an ELF Program

An assembly program usually tries to reflect the `binary` formats it is targeting.
In our case, we target `ELF` as a format, which is divided in a couple of different
sections. We don't need to know about all the special sections for now, but these
are the most important ones that you will find in most `ELF` binaries:

- The program header table contains meta information about our program.
- `.text` section that contains defined `methods` and the references to them inside our program.
- `.rodata` section that contains `read-only` binary data that cannot be changed.
- `.data` section that contains `constants`, `strings` and changeable `variables`.
- `.shstrtab` section that represents the section header table (that is the index of everything)

You can read more about the `ELF` binary format in the official [ELF Specification Document](https://refspecs.linuxfoundation.org/elf/elf.pdf).


## Syscall Values

The syscall table for the upstream Linux is available in the [syscall_64.tbl](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl)
file for the `amd64` architecture. The [syscall_32.tbl](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_32.tbl)
contains the syscall numbers for the `i386` architecture.

- syscall `1` calls `ksys_write(rdi, rsi, rdx)`
- syscall `60` calls `exit(rdi)`


## Registers

Registers are small storages inside the CPU that can be processed. They typically contain unsigned integers
or references (pointers) to larger data. For example, if a string exceeds the size of a register, it usually
is split up onto multiple registers with multiple `mov` instructions.

Registers are a little more complicated than this, there's general purpose registers and special registers
that can only be used for specific instructions or a specific functionality that the CPU provides.

But for now, we stick to the basics and only the registers we need to know about to call the `ksys_write()`
method with our given parameters. Before we know which registers to use, we need to understand how the
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
size_t ksys_write(unsigned int fd, const char *message, size_t message_length);
```

This means that we need the following registers to execute the `syscall`:

- `rax` is the temporary register that has to contain the `syscall number`.
- `rdi` is the 1st function argument, representing `unsigned int fd`.
- `rsi` is the 2nd function argument, representing the pointer to `const char *message`.
- `rdx` is the 3rd function argument, representing the message `size_t message_length`.

The `unsigned int fd` parameter can have the following values:

- `0` for `stdin` or standard input
- `1` for `stdout` or standard output
- `2` for `stderr` or standard error

Remember these values from bash?

You can redirect a processes standard input, output, and error messages if you redirect
them using something like `program 1> out.txt 2> err.txt`. The file descriptor values
`0`, `1`, and `2` represent the same thing here as in our assembly program.


## Hello World in NASM

The syntax of a NASM assembly line looks similar to this, where statements inside a square
bracket are optional:

```syntax
[label:] instruction [operands] [; comment]
```

Our Hello World program is pretty straight forward and doesn't need many registers to work with.
For now, our targeted binary format `ELF` needs only two different `sections`.

We apply the previously learned knowledge and write our assembly program:

```asm
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
```

If we compile and run our program, we can see the `Hello, World!` message:

```bash
nasm -f elf64 -o hello.o hello.asm;
ld -o hello.bin hello.o;

chmod +x hello.bin;
./hello.bin;
```


## Hello World in Go with Syscalls

Now that we know how to do syscalls in `C` and in `asm`, we can come full cycle
by using our high-level `syscall` package in `go`.

```go
package main

import "syscall"

// this is somewhat similar to the data section before
var msg []byte = []byte("Hello, World!")

func main() {
	syscall.Write(1, msg)
	syscall.Exit(0)
}
```

It's important that we only use the `syscall` package for now, so that we can read
the generated assembler code.

```bash
go build -gcflags=-S hello.go;
```

If we compile the binary with the above command, it will print out the generated
go assembly code. It is different from our x86 / amd64 assembly code, because it
uses a different plan9-alike format, but you should be able to understand in principle
what happens now.

For example, the output of the `syscall.Write(1, msg)` line should look similar to this:

```bash
(...)
0x000e 00014 (/tmp/test/main.go:9)	MOVQ	main.msg(SB), BX
0x0015 00021 (/tmp/test/main.go:9)	MOVQ	main.msg+8(SB), CX
0x001c 00028 (/tmp/test/main.go:9)	MOVQ	main.msg+16(SB), DI
0x0023 00035 (<unknown line number>)	NOP
0x0023 00035 (/usr/lib/go/src/syscall/syscall_unix.go:211)	MOVL	$1, AX
0x0028 00040 (/usr/lib/go/src/syscall/syscall_unix.go:211)	PCDATA	$1, $0
0x0028 00040 (/usr/lib/go/src/syscall/syscall_unix.go:211)	CALL	syscall.write(SB)
```


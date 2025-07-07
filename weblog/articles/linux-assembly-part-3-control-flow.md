===
- date: 2024-10-15
- name: Linux Assembly Part 3: Control Flow
- tags: linux, assembly
- type: software, research
- crux: Learn Linux assembly to do function calls.
===

Previous article in this series: [Linux Assembly Part 2 about Declaring Data](/weblog/articles/linux-assembly-part-2-declaring-data.html)

This is the third article in the `Linux Assembly` series. This time, we will focus on how to
do the control flow of our program that we've learned about in the previous article.


## Control Flow

Programming languages usually have the ability to use conditions to create code branches via `if/else`
or `switch/case` or `goto` statements. This is no different in assembly. The most common way you'll
see in programs is the `cmp` (comparison) instruction.

The `cmp` instruction compares 2 values, doesn't affect them, and doesn't execute anything that's
dependent on the result of that comparison. There is however a conditional jump instruction following
it, which allows to jump to different addresses or symbols. Public methods of your program are usually
in the symbol hash table so that you can debug a program more easily. What a symbol hash table is, is
not important now and we'll learn about that later in this article series.

For now, we'll take a look at this simple (partial) program code written in a `C` like language and
compare it with the equivalent `nasm` assembly code.

```cpp
main() {

    if (rax != 1337) {
        exit();
    } else {
        do_something_else();
    }

}
```

```asm
section .text
    global _start

_start:
    cmp rax, 1337
    jne .exit
    jmp .do_something_else

.do_something_else:
    ; do something else in here

.exit:
    mov rax, 60
    mov rdi, 0
    syscall
```

As we can see, there's different types of jump instructions in assembly. In the above example, the `jne`
(jump not equal) instruction is executed once the preceeding `cmp` (comparison) instruction fails.

The unconditional jumps are `jmp` instructions, which in our case reflect the `else` branch of the program.
A typical program has hundreds of these `jmp` instructions, and typically every helper method or function
down the line that's included or imported from a library is another `jmp` in the program's control flow.


## Jump Instructions

As we already know, there's different types of jump instructions available in `nasm` assembly. Here's a list
of those instructions and their meaning/behavior explained.

| Instruction | Description                                                                        |
|:------------|:-----------------------------------------------------------------------------------|
| JMP         | jump to label or register                                                          |
| JE          | jump if equal                                                                      |
| JNE         | jump if not equal                                                                  |
| JZ          | jump if zero                                                                       |
| JNZ         | jump if not zero                                                                   |
| JL          | jump if first operand is lower than second operand                                 |
| JLE         | jump if first operand is lower than or equal to second operand                     |
| JG          | jump if first operand is greater than second operand                               |
| JGE         | jump if first operand is greater than or equal to second operand                   |
| JA          | jump if unsigned first operand is greater than unsigned second operand             |
| JAE         | jump if unsigned first operand is greater than or equal to unsigned second operand |
|:------------|:-----------------------------------------------------------------------------------|


## Calculator Program

Now we know everything to be able to understand what the following program in `nasm` assembly is doing.

```asm
global _start

section .data
    ; Define our numbers
    num1: equ 13
    num2: equ 37

    ; Define our messages
    msg1: db "Sum is correct!"
    msg2: db "Sum is incorrect!"

section .text

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
```

The calculator program can also be downloaded [here](/weblog/articles/linux-assembly/calculator.asm).
If we compile and run our program, we can see the `Sum is correct!` message:

```bash
nasm -f elf64 -o calculator.o calculator.asm;
ld -o calculator.bin calculator.o;
chmod +x calculator.bin;

./calculator.bin;
```


## Stacks

The stack is a special region in memory, which operates on the principle of Last In, First Out.
This means that the frame in the stack that was added to the queue last will be processed first.

You can visualize this as a physical stack of todos where each new frame will be added on top of
the stack, and the processor will take one todo each time from the top of the stack, process it,
and write down the results of it. When the bottom of the stack and the last todo is reached, the
program is finished.

In order to `push` things to the stack or `pop` things off the stack, we need to use our general
purpose registers that we learned about in [Linux Assembly Part 1 about Syscalls](/weblog/articles/linux-assembly-part-1-syscalls.html).

The 16 general purpose registers are: `RAX`, `RBX`, `RCX`, `RDX`, `RDI`, `RSI`, `RBP`, `RSP` and `R8-R15`.
These registers can store small amounts of data and can be accessed by all functions, as they are global
registers.

```asm
global _start

section .text

_start:
    mov rax, 1
    call .increment_rax
    cmp rax, 2
    jne exit
    ; Do something

.increment_rax:
    inc rax
    ret
```

When we call a function, the return address is copied onto the stack and after the end of a function
execution, then the address is copied in the `RIP` register and the program continues its execution
from the point where it called the function from.

If we remember the `syscall` function signature from the first article, we'll also remember that almost
if not all syscalls using the same registers as their first arguments. The first six arguments of all
functions are passed via registers. If your function has more arguments, they will be passed as stack
pointers.

```c
int a_function(int rdi, int rsi, int rdx, int rcx, int r8, int r9 /*, stack pointers ... */) {
    return (rdi + rsi - rdx + rcx - r8 + r9); // well, or something like that
}
```


## Stack Frames and Stack Pointers

Remember the `rbp` and `rsp` registers from the second article in the series? They are special registers
that are needed to interact with the stack and its frame offsets.

- `rip` is the Instruction Pointer and it points to the next instruction the CPU is going to execute
- `rbp` is the Base Pointer and it points to the start of the current frame's position
- `rsp` is the Stack Pointer and it points to the end of the current frame's position

Now we also know that the stack consists of so-called stack frames. Each stack frames is limited in its
size to `16 bytes` and the address values of `rsp + 8` are always multiple of `16`. The 128 bytes area
beyond the location pointed to by the `rsp` pointer is a reserved memory zone and is also called the `red zone`,
in it you can store temporary memory that is not persisted across function calls.

The registers `rbp`, `rbx` and `r12` to `r15` belong to the calling function, and the called function
is required to preserve their values. A called function must preserve these registers' values for its
caller. The remaining registers belong to the called function. If a calling function wants to preserve
such a register value across a function call, it must save the value in its local stack frame.

The `rip` instruction pointer contains the next instruction that the CPU is going to execute. When the
CPU is at the `call` instruction to call a function, it pushes the address of the next instruction to
run after the current function call to the stack.

The structure of a Stack Frame with a Base Pointer looks like this:

| Position         | Contents                      |
|-----------------:|:-----------------------------:|
|       8 + `%rbp` | return address                |
|       0 + `%rbp` | previous `%rbp` value         |
|      -8 + `%rbp` | variable size byte `n`        |
|                  | (...)                         |
|       0 + `%rsp` | variable size byte `0`        |
|-----------------:|:-----------------------------:|
|    -128 + `%rsp` | (temporary) red zone          |

Additionally, there are two different instructions to interact with the stack:

- `push <argument>` stores the argument in the stack and increments the `rsp` stack pointer afterwards
- `pop <argument>` stores the data in the stack to the argument from a location pointed to by the stack pointer

The important thing to remember is that the `push` instruction will increment the `rsp` pointer _after_
the value was stored, which means that `rsp - 8` will be the equivalent position of `rbp` when the
`push` instruction is called.


## Stack Program

The following example will explain how stack frames are allocated and when the `registers` are updated.

```asm
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
```

Because the `rsp` address is incremented after the value is allocated to the stack, the program will
have the following values in the stack of the program before it exits:

| Start     |  End  | Contents | Frame |
|----------:|------:|:--------:|:------|
| 8 + `rsp` | `rsp` | 13       | 1     |
|     `rsp` | `rbp` | 37       | 2     |
|----------:|------:|:--------:|:------|


The stack example program can also be downloaded [here](/weblog/articles/linux-assembly/stack.asm).
If we compile and run our program, it will exit with the `exit code 0`.

```bash
nasm -f elf64 -o stack.o stack.asm;
ld -o stack.bin stack.o;
chmod +x stack.bin;

./stack.bin;
echo $?; # output: 0
```


## Function Calls

Function calls in `nasm` assembly code always use the same generic registers to use access and
manipulate declared data.

Let's take a look at a typical `C` program and translate it to `nasm` to understand the limitations
of the generic registers and when or where we need to push data to the stack to be able to use it.

```cpp
#include <stdio.h>

int makesum(int arg1, int arg2, int arg3, int arg4, int arg5, int arg6, int arg7, int arg8) {
    return arg1 + arg2 + arg3 + arg4 + arg5 + arg6 + arg7 + arg8;
}

int main() {
    int result = makesum(1, 2, 3, 4, 5, 6, 7, 8);
    char buffer[20];

    // convert integer to string
    sprintf(buffer, "%d", result);

    // print to stdout
    printf("%s", buffer);

    // exit with code 0
    return 0;
}
```

Our example program has a bunch of functionality that makes it a little more complicated:

- The variable `buffer` is initialized but not set, and therefore must be part of `.bss` and not `.data`
- We need to implement `sprintf()` to convert our result to a string
- We need to implement a conversion loop that can divide by 10

```asm
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
```

The Makesum program can also be downloaded from [here](/weblog/articles/linux-assembly/makesum.asm).
If we compile and run our program, we can see the `36` message:

```bash
nasm -f elf64 -o makesum.o makesum.asm;
ld -o makesum.bin makesum.o;

chmod +x makesum.bin;
./makesum.bin;
```


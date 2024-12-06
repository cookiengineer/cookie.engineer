===
- date: 2024-10-15
- name: Linux Assembly Part 3: Control Flow
- tags: linux, assembly
- type: software, research
- crux: Learn Linux assembly to do function calls.
===

Previous article in this series: [Linux Assembly Part 2 about Declaring Data](/weblog/articles/linux-assembly-part-2-declaring-data.html)

This is the third article in the `Linux Assembly` series. This time, we will focus on how to
do arithmetic operations on the data types that we've learned about in the previous article.


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


## Static Calculator Program

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


## Call Stacks

The stack is a special region in memory, which operates on the principle of Last In, First Out.
This means that the entry in the stack that was added to the queue last will be processed first.

You can visualize this as a physical stack of todos where each new call entry will be added on top
of the stack, and the processor will take one todo each time from the top of the stack, process it,
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


## Stack Pointers

TODO: Explain Stack Pointers, how they change, and how they work


## Function Calls

TODO: Explain `call` in detail, and `EIP` and returns


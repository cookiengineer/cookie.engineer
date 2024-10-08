===
- date: 2024-10-02
- name: Linux Assembly Part 2: Declaring Data
- tags: linux, assembly
- type: software, research
- crux: Learn Linux assembly to do declare data and reserve memory.
===


Previous article in this series: [Linux Assembly Part 1 about Syscalls](/weblog/linux-assembly-part-1-syscalls.html)

This is the second article in the `Linux Assembly` series. This time, we will focus on how
to represent different data types in `asm` and how to do arithmetic operations with them.


## Registers

Remember the registers we used last time?

Now we need to learn a bit more about them. There are various registers available for
different purposes. See the table below to find out how they are named, and whether or
not they're persistent if you make a `call`.

| Description                  | 64 bit    | 32 bit      | 16 bit      | 8 bit       | Persistent? |
|:-----------------------------|-----------|-------------|-------------|-------------|-------------|
| Accumulator                  | RAX       | EAX         | AX          | AL          | No          |
| Base                         | RBX       | EBX         | BX          | BL          | Yes         |
| Counter / 4th Argument       | RCX       | ECX         | CX          | CL          | No          |
| Data / 3rd Argument          | RDX       | EDX         | DX          | DL          | No          |
| Stack Pointer                | RSP       | ESP         | SP          | SPL         | Yes         |
| Base Pointer / Frame Pointer | RBP       | EBP         | BP          | BPL         | Yes         |
| 1st Argument                 | RDI       | EDI         | DI          | DIL         | No          |
| 2nd Argument                 | RSI       | ESI         | SI          | SIL         | No          |
| 5th Argument                 | R8        | R8D         | R8W         | R8B         | No          |
| 6th Argument                 | R9        | R9D         | R9W         | R9B         | No          |
| Temporary                    | R10 - R11 | R10D - R11D | R10W - R11W | R10B - R11B | No          |
| Callee-Saved Registers       | R12 - R15 | R12D - R15D | R12W - R15W | R12B - R15W | Yes         |
|:-----------------------------|-----------|-------------|-------------|-------------|-------------|


## Data Types

Remember the `.data` section in which we declared our `Hello, World!` message from the previous article?

```asm
section .data
	msg db "Hello, World!"

section .text
	global _start

_start:
	; (...)
```

In the `NASM` language you can also declare other data types, which we are going to learn about
now. Behind the scenes, everything is a `byte` or a `word` due to how `x86` as an instruction
set is designed.

### Bytes and Words

The basic data types in `nasm` are:

- `byte` is a byte that is `8 bits` long.
- `word` is `2 bytes` long.
- `doubleword` is `4 bytes` long.
- `quadword` is `8 bytes` long.
- `doublequadword` is `16 bytes` long.

### Unsigned Integers

Unsigned integers or `signed int` are binary numbers that can be represented as a `byte`,
a `word`, a `doubleword`, a `quadword`, or `doublequadword`. The byte length influences
the range of numbers we can represent.

- `unsigned integer` as `byte` can represent the numbers from `0` to `255`.
- `unsigned integer` as `word` can represent the numbers from `0` to `65535`.
- `unsigned integer` as `doubleword` can represent the numbers from `0` to `4294967295`.
- `unsigned integer` as `quadword` can represent the numbers from `0` to `18446744073709552000`.
- `unsigned integer` as `doublequadword` can represent the numbers from `0` to `340282366920938463463374607431768211456`

### Signed Integers

Signed integers or `unsigned int` are binary numbers that can be represented in the same way
as `unsigned int` but they represent different number ranges.

The first bit is set to `1` for `negative` numbers and is set to `0` for `positive` numbers.
This means that the number range doesn't start at `0`, and instead starts at `-(bitlength/2)`
and ends at `+(bitlength/2)-1`.

- `signed integer` as `byte` can represent the numbers from `-128` to `+127`.
- `signed integer` as `word` can represent the numbers from `-32768` to `+32767`.
- `signed integer` as `doubleword` can represent the numbers from `-2^31` to `+2^31-1`.
- `signed integer` as `quadword` can represent the numbers from `-2^63` to `+2^63-1`.
- `signed integer` as `doublequadword` can represent the numbers from `-2^127` to `+2^127-1`.

### Strings

Strings are represented as `double word` chunks behind the scenes, which makes them a little
quirky to work with. That means strings that are larger than a `double word` or `4 bytes` need
to be concatenated together to be used by instructions like `cmp` due to the bit size limitations
of registers.

In order to prevent doing that most of the time, `Kernel` developers decided to offer `syscalls`
that use references (or pointers) to addresses that contain the `strings` for that very reason.

So strings are special case that's important to keep in mind. Usually, userspace libraries try
to abstract away dealing with `string` lengths. A common convention in the `C ABI` world, for
example, is that strings are `NULL` delimited. This means that they have a trailing `0x00` byte
that marks the end of the series of bytes that contain a `string` value.


## NASM Pseudo Instructions

The `NASM` language specifies so-called pseudo instructions. These instructions are not part
of the `x86` (or `x86_64`) instruction set, but allow us to declare data in a much easier manner.

### Declaring Initialized Data

The current pseudo instructions to declare initialized data are:

- `DB` to declare a byte (8 bit)
- `DW` to declare a word (16 bit)
- `DD` to declare a double word (32 bit)
- `DDQ` to declare a double quad word (64 bit)
- `DO` to declare a generic output file (64 bit)
- `DY` and `DZ` to declare `YMM` and `ZMM` registers (See [AVX512](https://en.wikipedia.org/wiki/Advanced_Vector_Extensions))

The limitations of what kind of data you can declare are as follows:

- `DD` can declare a float
- `DQ` can declare a double-precision float
- `DT` can declare a extended-precision float
- `DT` does not accept numeric constants.
- `DDQ` does not accept float constants as operands.
- Any operand size larger than `DD` (double word) does not accept strings as operands.

However, the pseudo instructions are somewhat data type independent, which means that they
can have a different effect depending on what data type you're using to declare the data.

### Declaring Bytes and Words

As the `x86` (and therefore `x86_64`) instruction set is `little-endian`, the above pseudo
instructions also exist to do the conversion from/to endianness for us.

```asm
db 0x12               ; 0x12
db 0x11,0x12,0x13     ; 0x12 0x12 0x13
dd 0x11223344         ; 0x44 0x33 0x22 0x11                     (note the endianness)
dq 0x1122334455667788 ; 0x88 0x77 0x66 0x55 0x44 0x33 0x22 0x11 (note the endianness)
```

### Declaring Floating-Point Numbers

The floating point number precision is a little quirky due to their byte length to represent
the precision after the comma.

```asm
dd 1.234567e20 ; floating-point constant
dq 1.234567e20 ; double-precision float
dt 1.234567e20 ; extended-precision float
```

### Declaring Strings

Both character constants and strings can be declared using single quotation marks around
them. However, behind the scenes, `string` is almost always declared and processed as a
`double word` in many instructions. If you declare a `dw 'string'` that doesn't fill out
all the reserved bytes, a trailing `0x00` byte is added.

```asm
db 'A',0x42  ; 'AB' string in ASCII
dw 'A'       ; 0x41 0x00            (filled with trailing 0x00 byte)
dw 'AB'      ; 0x41 0x42
dw 'ABC'     ; 0x41 0x42 0x43 0x00  (filled with trailing 0x00 byte)
```

You can read more about pseudo instructions in [Chapter 3 of the NASM Documentation](https://www.nasm.us/xdoc/2.11.02/html/nasmdoc3.html).


### Declaring Uninitialized Data

The current pseudo instructions to declare uninitialize data are:

- `RESB` to reserve a byte (8 bit)
- `RESW` to reserve a word (16 bit)
- `RESD` to reserve a double word (32 bit)
- `RESO` to reserve a generic output file (64 bit)
- `RESY` and `RESZ` to declare `YMM` and `ZMM` registers (See [AVX512](https://en.wikipedia.org/wiki/Advanced_Vector_Extensions))

- `RESD` to reserve a float
- `RESQ` to reserve a double-precision float
- `REST` to reserve an extended-precision float

```asm
resb 32     ; reserve 32 bytes
resw  2     ; reserve 2 words
resq 10     ; reserve 10 double-precision floats
resy  2     ; reserve 2 YMM registers
resz  4     ; reserve 4 ZMM registers
```


# HEXLD3 (for ZX80 with RAM expansion/ Minstrel 2)

## Introduction

HEXLD3 is a tool, created by Toni Baker and described in her book "Mastering Machine Code on Your ZX81 (and ZX80)", to help people learn and write Z80 machine code.

HEXLD3 is intended to give you a feel for how people wrote code in the 1980s: it is not very suitable for major projects!

Readers of the book would progressively develop the tool as they read the book (mostly, in Chapter 9) and use it to write some interesting and creative examples of machine code on the ZX81 and ZX80.

There are two different versions of the tool: the ZX81 version (which you would also use if you had upgraded your ZX80 with the updated 8K ROM) is the focus of the book. Those wishing to type in the 4K ROM version need to make adjustments to the code as listed and, when I tried to do this, I found some problems.

In 2011, [Thunor](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwifh9-X38X4AhUMKcAKHYa7AeYQFnoECAIQAQ&url=http%3A%2F%2Fwww.users.waitrose.com%2F~thunor%2Fmmcoyzx81%2Findex.html&usg=AOvVaw2u-jWVQsJL5syJxuSnPI1U) published their attempt to create a 4K ROM version of HEXLD3, following the Toni's guidelines. They noted similar problems to me and proposed fixes. Thunor's notes were incredibly useful and I have built on these. Thunor's 4K ROM version mostly works though I found some minor limitations, which I have attempted to fix.

Most notably, I have moved the HEXLD3 (subject) code into REM statements at the beginning of the BASIC program. This has a number of advantages:
- It means it is ready to run as soon as you load HEXLD3 and is relatively safe from being overwritten.
- It means there is more space for your own machine code (as it stands, you can only save 512 bytes of code and that previously included the HEXLD3 code).

There are a small number of drawbacks, however:
- You must never list Lines 1, 2, 3, or 4 of the program, as they will likely crash the computer. Using `POKE 16403, 10` reduces the risk of this happening.
- When relocating the code into the REM statements, I needed to remove any code that assembled to 0x76, as this is the end-of-line code for 4K BASIC.

Moving forward, I may make some further improvements and extensions to HEXLD3, as follows:

- [x] Add the improved code-listing capability, which is described by Toni Baker as "level 2" disassembly.
- [x] Add breakpoint routine from the ZX Spectrum version of HEXLD3, which Toni developed later on.
- [ ] Port the full disassembler from the ZX Spectrum version of the book.

## Usage

This version of HEXLD3 should work well on a real ZX80 (with a RAM pack), an emulator (I use [EightyOne](https://sourceforge.net/projects/eightyone-sinclair-emulator/)), or the Minstrel 2.

The easiest way to load the program is to use the virtual tape file 'hexld3.o'. This can be used with an emulator such as EightyOne or with a Minstrel 2/ ZX80 fitted with a ZXpand SD-card reader.

If you want to use on real hardware, you might also be able to convert it to a WAV file and load it in via the Ear socket. However, I have not tried to do this (yet).

Full details of how to use the program are provided in Toni's book. In summary, to run the program:

1. Type `LOAD` (emulator/ real audio) or `LOAD "HEXLD3"` (ZXpand).
2. If you have an in-progress project, type `GOTO 500` to reinstate it in memory.
3. Use the following commands to access different functions:
    1. `RUN` or `RUN 50` to list code (`RUN 50` gives "level 2" listing). Use `CONTINUE` to list additional screens of code.
    2. `RUN 100` to write code. Enter a blank line to cease input.
    3. `RUN 200` to insert new code between existing code.
    4. `RUN 300` to delete a block of code.
    5. `RUN 400` to save HEXLD3 and your code (you can rename the file by editing line 420.
    6. `GOTO 500` to restore your code (immediately after loading).
    7. `RUN 700` to see the location and length of your code
    8. `RUN 800` to start a new project.

Have fun!

## Demo -- Life

The tape image [life.o](life.o) contains a ZX80 version of the program Life from Toni's book (see Chapter 12). To use the program, do the following:

1. Open the tape archive file  [life.o](life.o) in your emulator.
2. Type `LOAD` to load the program.
3. Type `GOTO 500` to restore the machine code back into memory.
4. Type `RUN 1000` to run the program. Between each iteration, the program will wait for keyboard input. Simply type Enter to run the next iteration.

The program was assembled to address 0x4A00 in memory. You can see the extent of the program, by typing `RUN 700` or list the program by typing `RUN 50` and setting the start address to (for example) 0x4A00. The listing is produced one screen at a time: enter `CONTINUE` to see subsequent screens.

You will see, from Toni's book, that the program contains two routines and some program data. In this version, the START routines starts at 0x4A08 and the NEXGEN routine starts at 0x4A34.  

## Notes

- The program HEXLD3 is unforgiving and has almost no error checking. Inputs are typically four-digit hex numbers for addresses, or sequences of one or more two-digit hex numbers for data. The validity of inputs is not checked: the code will naively convert your input into numerical data as best as it can.
- The program will stop if the cursor reaches the bottom of the screen. For example, when listing code or entering code. In some cases, `CONTINUE` (typed immediately after the stoppage) will allow you to continue. Alternatively, (for example, when entering code) re-run the correct part of the program and enter the next address at which code is to be inserted.
- The user is responsible for memory management. You need to ensure you do not write code to somewhere you should not (e.g., inside the BASIC workspace) and, if you extend the BASIC program, that it does not grow to overlap with your machine code.
- Unlike for Toni's original version of the program, you do not need type `GOTO 500` when you load the program unless you have pre-existing machine code. Because HEXLD3 is stored in REM statements, it is immediately available for use.
- I have (so far) added two extra routines. You can see the location and extent of your machine code, using `RUN 700`. This should help you to keep track of memory usage. You can start a new project, using `RUN 800` and then entering the start address (e.g., "org" address) for your new code. This will reset HEXLD3 variables, so it can no longer see any preexisting code you have written.
Notes:


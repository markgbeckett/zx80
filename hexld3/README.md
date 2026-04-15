# HEXLD3 and Z80 Disassembler (for ZX80 with RAM expansion/ Minstrel 2)

## Introduction

HEXLD3 is a tool, created by Toni Baker and described in her book "Mastering Machine Code on Your ZX81 (and ZX80)", to help people to learn and to write Z80 machine code.

HEXLD3 is a good way to give you a feel for how people wrote code in the 1980s: it is not very suitable for major projects!

Readers of Toni's book would progressively develop the tool as they read the book (mostly, in Chapter 9) and use it to write some interesting and creative examples of machine code on the ZX81 and ZX80.

Towards the end of the book (in Chapter 16), Toni provides a starting point for writing a compact Z80 disassember, which -- improving on HEXLD3 -- will disassemble machine code back into the assembly language mnemonics, making it much easier to review and find errors in your machine code. Toni does not provide a complete listing, leaving the reader with a challenging exercise.

In her subsequent book, "Mastering Machine Code on Your ZX Spectrum", Toni provides a complete listing of the disassembler. Starting from this, I have back-ported the disassembler to work with the ZX80, and integrated it into the HEXLD3 tool.

## Developing HEXLD3

Toni provided two different versions of the tool: a ZX81 version (which you would also use if you had upgraded your ZX80 with the updated 8K ROM) is the focus of the book. Those wishing to type in a version suitable for the original ZX80 (4K BASIC) ROM needed to make adjustments to the code as listed and, when I tried to do this, I found some problems.

In 2011, [Thunor](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwifh9-X38X4AhUMKcAKHYa7AeYQFnoECAIQAQ&url=http%3A%2F%2Fwww.users.waitrose.com%2F~thunor%2Fmmcoyzx81%2Findex.html&usg=AOvVaw2u-jWVQsJL5syJxuSnPI1U) published their attempt to create a 4K ROM version of HEXLD3, following Toni's guidelines. They noted similar problems to me and proposed fixes. Thunor's notes were incredibly useful and I have built on these. Thunor's 4K ROM version mostly works though I found some minor limitations, which I have attempted to fix.

Most notably, I have moved the HEXLD3 (subject) code into REM statements at the beginning of the BASIC program. This has a number of advantages:
- It is ready to run as soon as you load HEXLD3 and is relatively safe from being overwritten.
- There is more space for your own machine code (the original ZX80 version could only save 512 bytes of code and that previously included the HEXLD3 code).

There are a small number of drawbacks, however:
- You must never list Lines 1, 2, 3, or 4 of the program, as doing so will likely crash the computer. Using `POKE 16403, 10` reduces the risk of this happening.
- When relocating the code into the REM statements, I needed to remove any code that assembled to the opcode 0x76, as this is the end-of-line code for 4K BASIC and will confuse the BASIC interpretter.

Since completing the original port, I have made some further improvements, which hopefully make HEXLD3 more usable:
- I added the improved code-listing capability, which is described by Toni Baker as "level 2" disassembly, in which object code is grouped together by instruction. So, for example `call 0x4800` would be displayed as `CD0048` in the Level 2 disassembly. It may not seem much of an improvement but it makes it almost impossible to lose your place when checking code. 
- I added the breakpoint routine from the ZX Spectrum version of HEXLD3, which Toni developed later on. You use this to help you debug your program: by inserting a call to  the breakpoint routine, you can safely exit your code, displaying the state of the registers, flags, machine stack, and so on.
- I ported the full disassembler from the ZX Spectrum version of the book, though it is too big to be inserted into REM statements and so needs to be loaded separately (as explained below).
- I extended the save-code routine to support programs of more than 512 bytes. As with the original version, it works by copying code into BASIC integer arrays, which can be conveniently saved as part of the program. This does double the memory use (during a save operation, you have two copies of your program in memory) and you need to be careful to locate your object program high enough in memory to not be overwritten by the integer arrays created during the save operation.

## Usage

This version of HEXLD3 should work well on a real ZX80 (with a RAM pack), an emulator (I use [EightyOne](https://sourceforge.net/projects/eightyone-sinclair-emulator/)), or the Minstrel 2.

The easiest way to load the program is to use the virtual tape file 'hexld3.o'. This can be used with an emulator such as EightyOne or with a Minstrel 2/ ZX80 fitted with a ZXpand SD-card reader.

If you want to use on real hardware, you might also be able to convert it to a WAV file and load it in via the Ear socket. However, I have not tried to do this (yet).

Full details of how to use the program are provided in Toni's book (noting I have made some improvements). In summary, to run the program:

1. Type `LOAD` (emulator/ real audio) or `LOAD "HEXLD3"` (ZXpand).
2. If you have an in-progress project, type `GOTO 500` to reinstate it in memory.
3. Use the following commands to access different functions:
    1. `RUN` or `RUN 50` to list code (`RUN 50` gives "level 2" listing). Use `CONTINUE` to list additional screens of code.
    2. `RUN 100` to write code. Enter a blank line to cease input.
    3. `RUN 200` to insert new code between existing code.
    4. `RUN 300` to delete a block of code.
    5. `RUN 400` to save HEXLD3 and your code (if using the ZXpand version, you should choose a filename by editing line 420. 
    6. `GOTO 500` to restore your code (immediately after loading). You must not use `RUN 500` as this will wipe the user variables, which is where your object code is stored during the save operation and where your program is restored from after being loaded.
    7. `RUN 700` to see the location (`BEGIN`)and end (`LIMIT`) of your object  program. This function also lists the end of memory being used by BASIC (`DF_END`). Note that during the save operation, the BASIC program will expand by multiples of 512 bytes, as needed to hold your object program. You should make sure your object code starts high enough in memory that this will not overwrite your code. The BASIC monitor knows nothing about your machine code and will blindly overwrite it, if needed. 
    8. `RUN 800` to start a new project (resetting `BEGIN` and `LIMIT` to the same value, effectively forgetting any previously entered object code).
    9. `RUN 900` to disassemble machine code (having first loaded the disassembler -- see below). Do not use this function unless you have loaded the disassembler or, otherwise, you will crash the computer.

Since HEXLD3 is saved alongside your object code, you may wish to create a short routine at, say, line 1000 to run your program, saving you from the start address and using `USR` each time.

### Loading the Disassembler

Toni's Z80 disassembler is too long for me to insert into REM statements, so I have provided it as a separate binary file that can be loaded into memory at address 7800h. The binary file can only be loaded from a ZXpand SD-card reader, I am afraid. Assuming you have one, and having first loaded the main HEXLD3 program, you should type `LOAD "ZX80DISS.BIN;30720"`. The BASIC code at line 900 assumes the disassembler has been loaded in this way.

If you would like to see the disassembler source code, take a look at [https://github.com/markgbeckett/jupiter_ace/tree/master/z80_disassembler](https://github.com/markgbeckett/jupiter_ace/tree/master/z80_disassembler) or type `RUN 900` and enter `787C` as the starting address (the bytes between 7800h and 787Bh are data, so disassemble to nonsense)!

Have fun!

## Demo -- Life

The tape image [life.o](life.o) contains a ZX80 version of the program Life from Toni's book (see Chapter 12). To use the program, do the following:

1. Open the tape archive file  [life.o](life.o) in your emulator.
2. Type `LOAD` to load the program.
3. Type `GOTO 500` to restore the machine code back into memory.
4. Type `RUN 1000` to run the program. Between each iteration, the program will wait for keyboard input. Simply type Enter to run the next iteration.

The program was assembled to address 0x4A00 in memory. You can see the extent of the program by typing `RUN 700` or list the program by typing `RUN 50` and setting the start address to (for example) 0x4A00. The listing is produced one screen at a time: enter `CONTINUE` to see subsequent screens.

You will see, from Toni's book, that the program contains two routines and some program data. In this version, the START routines starts at 0x4A08 and the NEXGEN routine starts at 0x4A34.  

## Notes

- The program HEXLD3 is unforgiving and has almost no error checking. Inputs are typically four-digit hex numbers for addresses, or sequences of one or more two-digit hex numbers for data. The validity of inputs is not checked: the code will naively convert your input into numerical data as best as it can.
- The program will stop if the cursor reaches the bottom of the screen; for example, when listing code or entering code. In some cases, `CONTINUE` (typed immediately after the stoppage) will allow you to continue. Alternatively, (for example, when entering code) re-run the correct part of the program and enter the next address at which code is to be inserted.
- The user is responsible for memory management. You need to ensure you do not write code to somewhere you should not (e.g., inside the BASIC workspace) and, if you extend the BASIC program, that it does not grow to overlap with your machine code. As noted above, you should also leave sufficient space for the save function to create temporary arrays in the BASIC workspace.
- Unlike for Toni's original version of the program, you do not need type `GOTO 500` when you load the program unless you have pre-existing machine code. Because HEXLD3 is stored in REM statements, it is immediately available for use.
- I have (so far) added two extra routines. You can see the location and extent of your machine code, using `RUN 700`. This should help you to keep track of memory usage. You can start a new project, using `RUN 800` and then enter the start address (that is, the origin or "org" address) for your new code. This will reset HEXLD3 variables, so it can no longer see any preexisting code you have written.

# Building from source

HEXLD3 is mostly written in Z80 machine code, with a BASIC wrapper. For the ZX80 (4K BASIC) version, the machine code is stored in four `REM` statements each containing space for 256 bytes of machine code. The data of these REM statements (where code can be inserted) is as follows::
- Line 1 data 402B--412A (256 bytes)
- Line 2 data 412F-- 422E (256 bytes)
- Line 3 data 4233--4332 (256 bytes)
- Line 4 data 4337--4436 (256 bytes)

The machine code to go into these four REM statements is held in four source files, named "hexld3_line1.asm" and so on. These source files need to be assembled in sequence and the symbols table from assembling each file should be written to a corresponding file named "hexld3_line1_symbols.asm" and so on. A simple Makefile is provided to help you.

Once assembled, you should have four binary files, named "hexld3_line1.bin" and so on. These can be inserted into the body of the corresponding `REM` statement using the memory-load function of an emulator such as [EightyOne](https://sourceforge.net/projects/eightyone-sinclair-emulator/) and specifying the start address as indicated above.

If you make significant changes to the code of HEXLD3, you should check that each binary file is no more than 256 bytes. If necessary, you may need to create additional REM statements at line 5, line 6, ..., and line 9. The first actual BASIC command is at line 10.

A useful way to check the size of your `REM` statement is to define it as:

```REM 01234567890123456789...```

--which should make it easier to check the length. You could also check the memory dump. Each REM statement starts with two bytes indicating the line number (in big-endian format) followed by the code for `REM`, which is 0xFE, followed by the data. Each BASIC line is terminated with code 0x76.

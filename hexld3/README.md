# HEXLD3 (for ZX80 with 4K ROM)

## Introduction

HEXLD3 is a tool, created by Toni Baker, in her book "Mastering Machine Code on Your ZX81 (and ZX80)", to help people learn and write machine code.

Readers of the book would progressively develop the tool as they read the book (mostly, in Chapter 9) and use it to write some interesting and creative examples of machine code on the ZX81 and ZX80.

There are two different versions of the tool: the ZX81 version (which is also suitable for a ZX80 with the updated 8K ROM) is the focus of the book. Those wishing to type in the 4K ROM version need to make adjustments to the code as listed and, when I tried to do this, I found some problems.

In 2011, [Thunor](https://www.google.com/url?sa=t&rct=j&q=&esrc=s&source=web&cd=&cad=rja&uact=8&ved=2ahUKEwifh9-X38X4AhUMKcAKHYa7AeYQFnoECAIQAQ&url=http%3A%2F%2Fwww.users.waitrose.com%2F~thunor%2Fmmcoyzx81%2Findex.html&usg=AOvVaw2u-jWVQsJL5syJxuSnPI1U) published their attempt to create a 4K ROM version of HEXLD3, following the Toni's guidelines. They noted similar problems to me and proposed fixes. Thunor's notes were incredibly useful and I have built on these. Thunor's 4K ROM version mostly works though I found some minor issues, which I have attempted to fix.

Most notably, I have moved the HEXLD3 (subject) code into REM statements at the beginning of the BASIC program. This has a number of advantages:
- It means you it is ready to run as soon as you load HEXLD3.
- It means there is more space for your own machine code (as it stands, you can only save 512 bytes of code and that previously included the HEXLD3 code).

There are a small number of drawbacks, however:
- You must never list Lines 1, 2, or 3 of the program, as they will likely crash the computer.
- When relocating the code into the REM statements, I needed to remove any code that assembled to 0x76, as this is the end-of-line code for 4K BASIC.

Moving forward, I plan to make some further improvements and extensions to HEXLD3, as follows:

- [x] Add the improved code-listing capability, which is described by Toni Baker as "level 2" disassembly.
- [ ] Add features from, later, ZX Spectrum version of HEXLD3 -- including support for adding text and for creating a breakpoint.
- [ ] Port the full disassembler from the ZX Spectrum version of the book.

## Usage

The easiest way to load the program is to use the virtual tape file 'hexld3.o'. This can be used with an emulator such as EightyOne or with a Minstrel 2/ ZX80 fitted with a ZXpand SD-card reader. You might also be able to convert it to a WAV file and load it in via the Ear socket.

To run the program:

1. type LOAD (emulator) or LOAD "HEXLD3" (ZXpand).

2. If you have an in-progress project, type 'GOTO 500' to reinstate it in memory.

3. Use the following commands for different functions:

  a. RUN or RUN 50 to list code.
  b. RUN 100 to write code.
  c. RUN 200 to insert new code between existing code.
  d. RUN 300 to delete a block of code
  e. RUN 400 to save HEXLD3 and your code.
  f. GOTO 500 to restore your code (immediately after loading).
  g. RUN 700 to see the location and length of your code
  h. RUN 800 to start a new project.

Have fun!

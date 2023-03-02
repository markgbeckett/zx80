# Hampson's Plane Game (flicker-free)

This program is a Z80 machine-code implementation of the game Hampson's Plane, originally written by Mike Hampson (in BASIC) in 1982 and later ported to Forth as an example program for [CP Software's Spectrum Forth compiler](https://spectrumcomputing.co.uk/entry/8742/ZX-Spectrum/Spectrum_FORTH). 

It can be run on a ZX80 (with 4K ROM and 16K RAM) or a Minstrel 2. At the moment, to run the program, you need to be able to load a code-block into the computer's memory--for example, using the ZXpand interface. Alternatively, you can run inside an emulator that accepts memory-block loading (e.g., [EightyOne](https://sourceforge.net/projects/eightyone-sinclair-emulator/)).

To use the program:

1. Copy the binary file `hampson.bin` to an SD card.
2. Load the program into memory at address 0x6000 -- for example, using the ZXpand command `LOAD "hampson.bin;24576"`.
3. Enter `RANDOMIZE USR(25369)`

The game is incomplete: at the moment there is no check that the player has solved the grid. Check back regularly for updates.

## Development

I am writing this game to get to grips with flicker-free game writing for the ZX80 and Minstrel 2. Paul Farrow's guide to the [Flicker-free Mechanism](http://www.fruitcake.plus.com/Sinclair/ZX80/FlickerFree/ZX80_DisplayMechanism.htm) is particularly useful for learning to do this, as is the listing of the flicker-free [Breakout](http://www.fruitcake.plus.com/Sinclair/ZX80/FlickerFree/ZX80_Breakout.htm) game, by Macronics.

I have adopted the approach used by Breakout, which splits the game code into a sequence of functional units that can be fitted in the time taken to produce the VSync signal at the beginning of each display frame.

The VSync signal is turned on and off with two I/O statements: `in a,(0xFE)` and `out (0xFE),a`, respectively. Between these two commands, you have 1,360 T states of 'spare' time in which you can execute code (see Paul Farrow's guide for details of the timing).

I have written a simple sequencer which will run a step of the game's pipeline using a lookup tables of addresses of routines.

The game sequence is, as follows:

1. Input skill level
2. Randomise game board (Part 1)
3. Randomise game board (Part 2)
4. Read in column id
5. Read in row id (first digit)
6. Read in row id (second digit)
7. Flip tile
8. Check if solved (jump to 3, if not)
9. Congratulate player (return to 2 on keypress)

The sequencer itself requires 77 T states, leaving 1,287 T states for the functionality of each game step. The game will only move from one step to the next, if a certain condition is met. For example, the game will only move from Step 1 to Step 2, if the user presses a valid key (selecting a skill level between 1 and 9).

There seems to be some flexibility in exactly how long a game step is -- possibly anything within around 10 T states of the target of 1,287 is good enough. If the routine length is too far from the target, the screen will be displayed offset or will flicker.

Initially, I intended to write a separate routine to check if the player had solved the grid -- that is, checking there were no hash characters left on the grid. However, this proved far too time-consuming. I had intended to use the CPIR command to scan through the display file for a hash character. However, to check the whole board would require around 10,000 T states, or around 8 times the time available between frames. Instead I track the number of has characters throughout the game, updating the count ever time a block of tiles is flipped. This work well, though on top of other tasks, a player flipping a tile requires two frames.

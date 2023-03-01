# Hampson's Plane Game (flicker-free)

This program is a machine-code implementation of the game Hampson's Plane, originally written by Mike Hampson (in BASIC). 

It will be able to run on a ZX80 (with 4K ROM and 16K RAM) or a Minstrel 2. At the moment, you can only run inside an emulator that accepts memory-block loading (e.g., EightyOne).

To use the program:

1. Reset the emulator, making sure to select the 4K ROM and 16kb of RAM.
2. Load the compiled version of the program `hampson.bin` into memory, to address 0x6000.
3. Enter `RANDOMIZE USR(25369)`

The game is incomplete. Check back regularly for updates.

## Development

I am writing this game to get to grips with flicker-free game writing for the ZX80 and Minstrel 2. Paul Farrow's guide to the [Flicker-free Mechanism](http://www.fruitcake.plus.com/Sinclair/ZX80/FlickerFree/ZX80_DisplayMechanism.htm) is particularly useful for doing this, as is the listing of the flicker-free [Breakout](http://www.fruitcake.plus.com/Sinclair/ZX80/FlickerFree/ZX80_Breakout.htm) game, by Macronics.

I have adopted the approach used by Breakout, which breaks the game code into a sequence of functional units can be fitted in the time taken to produce the VSync signal at the beginning of each display frame.

The VSync signal is turned on and off with two I/O statements: `in a,(0xFE)` and `out (0xFE),a`, respectively. Between these two commands, you have 1,360 T states of 'spare' time in which you can execute code (see Paul Farrow's guide for details of the timing.

I have written a simple sequencer which will run a step of the game's pipeline using a lookup tables of addresses of routines.

The game sequence is, as follows:

1. Input skill level
2. Randomise game board
3. Read in column id
4. Read in row id (first digit)
5. Read in row id (second digit)
6. Flip tile
7. Check if solved (jump to 3, if not)
8. Congratulate player (return to 2 on keypress)

The sequencer requires 77 T states leaving 1,287 T states for the functionality of each game step. The game will only move from one step to the next, if a certain condition is met. For example, the game will only move from Step 1 to Step 2, if the user types a valid key (selecting a skill level between 1 and 9).

There seems to be some flexibility in exactly how long a game step is -- possibly anything within around 10 T states of the target of 1,287 is good enough. If the routine length is too far from the target, the screen will be offset.

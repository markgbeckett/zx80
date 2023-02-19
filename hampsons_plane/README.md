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

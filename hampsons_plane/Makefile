ASM=z80asm
AFLAGS=-L

hampson: hampson.asm Makefile hampson_gameboard.asm ../zx80_chars.asm
	$(ASM) $(AFLAGS) -o hampson.bin hampson.asm

clean:
	erase *.bin

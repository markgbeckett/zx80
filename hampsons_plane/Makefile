ASM=z80asm
AFLAGS=-L

hampson: hampson.asm Makefile ../utilities/zx80_chars.asm
	$(ASM) $(AFLAGS) -o hampson.bin hampson.asm

clean:
	erase *.bin

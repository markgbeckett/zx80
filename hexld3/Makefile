ASM = z80asm
AFLAGS = -L

ifeq ($(OS),Windows_NT)
	ERASE = erase
	else
	ERASE = rm
endif

all:
	$(ASM) $(AFLAGS) -o hexld3_line1.bin hexld3_line1.asm > hexld3_line1_symbols.asm 2>&1
	$(ASM) $(AFLAGS) -o hexld3_line2.bin hexld3_line2.asm > hexld3_line2_symbols.asm 2>&1
	$(ASM) $(AFLAGS) -o hexld3_line3.bin hexld3_line3.asm > hexld3_line3_symbols.asm 2>&1
	$(ASM) $(AFLAGS) -o hexld3_line4.bin hexld3_line4.asm > hexld3_line4_symbols.asm 2>&1

clean:
	$(ERASE) $(OBJS)

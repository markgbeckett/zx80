include "hexld3_line3_symbols.asm"

	org 0x4338

UADDR:	ld bc, 0x0000

PRADDR:	ld hl,(ADDRESS)

PRHL:	ld a,h
	call HPRINT

	ld a,l
	call HPRINT

	xor a
	call APRINT

	ret
	
BREAKPT:
	push iy
	push ix

	ex af, af'
	push af
	ex af,af'
	exx
	push bc
	push de
	push hl
	exx

	call REGS

	ld a, 0x75
	inc a
	call APRINT

	pop hl
	pop de
	pop bc
	pop af

	call REGS

	ld a, 0x75
	inc a
	call APRINT

	pop hl
	call PRHL

	pop hl
	call PRHL

	pop hl
	dec hl
	dec hl
	dec hl
	call PRHL

	call ICHECK

	ld a, 41

	jr z, BCI
	inc a

BCI:	call APRINT

	jp DONE

	
	

include "hexld3_line1_symbols.asm"	

	org 0x412F

WRITE:	ld hl,(VARS)
	push hl
	ld b,0xFF
ANOTHER:
	inc hl
	ld a,(hl)
	inc b
	dec a
	jr nz,ANOTHER
	pop hl
	sra b

	jp z, DONE

	ld de, (ADDRESS)
NEXTBYTE:
	inc hl
	ld a,(hl)
	add a,a
	add a,a
	add a,a
	add a,a
	inc hl
	add a,(hl)
	add a,0x24
	ld (de),a
	inc de
	ld (ADDRESS),de
	push hl
	ld hl,(LIMIT)
	sbc hl,de
	pop hl
	jr nc, CHECK_WR
	ld (LIMIT),de
CHECK_WR:
	djnz NEXTBYTE
	ret
	
	;;  Compute size of array required to hold machine code
ARRAY:	ld hl, (LIMIT)
	ld de, (BEGIN)
	and a
	sbc hl,de		; hl = LIMIT - BEGIN

	ld (ADD2),hl		; Store for later use

	sra h			; Divide by two, as two bytes per
	rr l			; array element

	ret			; HL returned as output of USR()

STORE:	ld hl,(VARS)
	ld de, 0x0002
	add hl,de
	ex de,hl
	ld hl,(BEGIN)
	ld bc,(ADD2)
	ldir
	ret

RETRIEVE:
	ld hl,(VARS)
	inc hl
	inc hl
	ld de,(BEGIN)
	ld bc,(ADD2)
	ldir
	ret

INSERT:
	ld hl,(VARS)
	push hl
	ld bc, 0xFFFF
MORE:	inc hl
	ld a,(hl)
	inc bc
	dec a
	jr nz, MORE
	pop hl

COPYUP: sra b
	rr c
	jr nz, NOTEMPTY
	rst 0x08
	db 0x08

NOTEMPTY:
	push bc
	ld hl,(LIMIT)
	ld de,(ADDRESS)
	and a
	sbc hl,de
	inc hl
	ld b,h
	ld c,l
	pop hl
	ld de,(LIMIT)
	add hl,de
	ld (LIMIT),hl
	ex de,hl
	lddr
	call WRITE
	ret
	
DELETE:	ld hl,(LIMIT)
	ld de,(ADD2)
	push de
	and a
	sbc hl,de
	ld b,h
	ld c,l
	pop hl
	inc hl
	ld de,(ADDRESS)
	ldir
	dec de
	ld (LIMIT),de
	rst 0x08
	db 0x08

SHPRINT:
	push af
	
	xor a
	call APRINT

	pop af
	call HPRINT

	ret
	
REGS:	push af
	call HPRINT
	
	ld a,b
	call SHPRINT

	ld a,c
	call HPRINT

	ld a,d
	call SHPRINT

	ld a,e
	call HPRINT

	ld a,h
	call SHPRINT

	ld a,l
	call HPRINT

	xor a
	call APRINT
	
	pop af

	ld a, 56
	call m, APRINT

	ld a, 63
	call z, APRINT

	ld a, 53
	call pe, APRINT

	ld a, 40
	call c, APRINT

	ret
	

	;; 4K ROM routines
PRPOS:	equ 0x06E0		
PRINT:	equ 0x0720
VARS:	equ 0x4008

	;; Main program
	org 0x4a00
	
BEGIN:	dw $
ADDRESS:
	dw BEGIN
ADD2:	dw 0x0000
LIMIT:	dw END

	;; Print character in A register to screen
APRINT:	push hl			; Save HL
	push af

	call PRPOS		; Initialise printing (corrupts HL, BC', and DE')
	pop af
	
	call PRINT		; Print it
	exx
	
	pop hl			; Restore HL

	ret

HPRINT:	push af 		; Store A for later use
	and 0xF0		; Isolate first digitset
	rra			; Move into lower nibble
	rra
	rra
	rra
	add a, 0x1c		; Convert to printable character
	call APRINT		; Print it
	
	pop af			; Restore A
	and 0x0F		; Isolate second digit
	add a, 0x1c		; Convert to printable character
	call APRINT		; Print it

	ret
	
HLIST:	ld hl,(LIMIT) 		; Copy LIMIT value to ADD2
	ld (ADD2),hl

	ld d,h			; DE = (LIMIT)
	ld e,l

	ld hl, (ADDRESS)	; Retrieve address from which to list
	ld b, 0x14		; Will list 20 bytes per use

NXTAD:	and a			; Check that ADDRESS is less than LIMIT
	sbc hl,de
	add hl,de
	jr nc, DONE		; If not, then exit

	ld a,h			; Print ADDRESS
	call HPRINT
	ld a,l
	call HPRINT

	xor a			; Print space
	call APRINT

	ld a,(hl)		; Print contents of ADDRESS
	call HPRINT

	bit 6,(hl)		; Check if contents is printable character
	jr nz, NOPRINT		; If not, skip forward

	xor a			; Print space
	call APRINT

	ld a,(hl)		; Print character code
	call APRINT

NOPRINT:
	ld a, 0x76		; Print newline
	call APRINT

	inc hl			; Advance to next address
	ld (ADDRESS),hl		; and save it

	djnz NXTAD		; Repeat, unless done

DONE:
	rst 0x08		; Return to BASIC
	db 0x00

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

	jr z, DONE

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
	
END:	

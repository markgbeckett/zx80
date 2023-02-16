DISP_2:	equ 0x01AD		; ROM screen display routine
DFILE:	equ 0x400C
DF_EA:	equ 0x400E
DF_END:	equ 0x4010
FRAME:	equ 0x401E
	
_HALT:	equ 0x76

	include "..\zx80_chars.asm"

	org 0x6000

DISPLAY:
	include "hampson_gameboard.asm"
	
	;; Main game loop
START:	
	ld hl, DISPLAY
	ld (DFILE), hl
	ld hl, DISPLAY+0x21*0x17+01
	ld (DF_EA), hl
	ld hl, DISPLAY+0x21*0x18+01
	ld (DF_END),hl

	ld hl,0x0000

MAIN_LOOP:
	ld (iy+0x23),0x38	; 56 scan lines above display area
	
	pop hl
	inc l
	push hl
	
	in a, (0xFE)		; Turn on vertical sync generator

	;; Game code (max of 1360 T states)
	ld b,0x68		; (7)

WAIT:	djnz WAIT		; (13/8)

	;; Generate display
	
	out (0xFE),a		; Turn off vertical sync generation

	ld a, 0xEC
	ld b, 0x19

	ld hl, DISPLAY+0x8000

	call DISP_2		; Produce top border and main area

	;; Generate bottom border
	ld a, 0xF0
	inc b
	dec hl

	dec (iy+23)
	call DISP_2

	jr MAIN_LOOP		; (12)

	;;
	;; Simple Random Number Generator
	;;
	;; On entry:
	;;      
	;; On exit:
	;; 	a  - random number
	;;	de - corrupted
	;; 	hl - corrupted
RAND:	ld hl,(SEED)

	ld a,r
	ld d,a
	ld e,(HL)
	add hl,de
	add a,l
	xor h
	
	ld (SEED),hl

	ret

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
	;; T = 1287 + WAIT

	;; Pick row number - 0...15
	call RAND		; (17+81)
	and 0x0F		; (7)
	ld b,a			; (4)

	;; Pick column number - 0 -- 25
	call RAND		; (17+81)

	;; Divide by 10 (takes 89 T states)
	ld d,0			; (7)
	ld e,a			; (4)
	ld h,d			; (4)
	ld l,e			; (4)
	add hl,hl		; (11)
	add hl,de		; (11)
	add hl,hl		; (11)
	add hl,hl		; (11)
	add hl,de		; (11)
	add hl,hl		; (11)
	ld c,h			; (4)
	
	call FLIP9		; (17 + 974)
	
	;; T = 4 + 7 + 8 + 13*(N-1)
	nop
	ld b,0x05		; (7)
LOOP:	djnz LOOP		;
	
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
	;;
	;; Timing: 81 T-states
RAND:	ld hl,(SEED)		; (16)

	ld a,r			; (9)
	ld d,a			; (4)
	ld e,(HL)		; (7)
	add hl,de		; (11)
	add a,l			; (4)
	xor h			; (4)
	
	ld (SEED),hl		; (16)

	ret			; (10)

SEED:	dw 0x0000

	;;
	;; Flip a 3x3 block of tiles
	;;
	;; On entry:
	;;      b  - row number (0...15)
	;;      c  - column number (0...25)
	;; On exit:
	;; 	a  - corrupted
	;;      be - corrupted
	;;	de - corrupted
	;; 	hl - corrupted
	;;
	;; Timing:
	;; T states = 974
FLIP9:	ld hl,DISPLAY+3		; (10) Top, lefthand cormer of gameboard
	ld de, 0x0021		; (10) Length of a screen row

	ld a,16			; (7)
	sub b			; (8) a = 1...16

	;; Step down to correct row
	;; T = 4 + 19 + (B-1)x24 = 23 ... 383
	inc b			; (4) Row 1...16
NROW:	add hl,de		; (11)
	djnz NROW		; (13/8)

	;; Dummy routine to balance timing
	;; T = 4 + 19 + (A-1)x24 = 23...383
	ld b,a			; (4)
DROW:	and a			; (4)
	and 0xFF		; (7)
	djnz DROW		; (13/8)
	
	;; Remainder of routine = 533 T-states, inc. RET
	;; Step along row
	add hl,bc		; (11) B is zero thanks to previous loop

	ld c,3			; (7) Three rows in block
	
	;; T = 170*2+165 = 505
COL3:	ld b,3			; (7)

	push hl			; (11)

	;; T = 40x2+35 = 115
ROW3:	ld a,(hl)		; (7) Invert three tiles on current row
	xor _ASTERISK		; (7)
	ld (hl),a		; (7)
	inc hl			; (6)
	djnz ROW3		; (13/8)

	pop hl			; (10)

	add hl,de		; (11) Next row

	dec c			; (4)
	jr nz, COL3		; (12/7)

	ret			; (10)

DISP_2:	equ 0x01AD		; ROM screen display routine
KTABLE:	equ 0x6B00		; Keyboard lookup in ROM
DFILE:	equ 0x400C		; System variable holding display address
DF_EA:	equ 0x400E		; System variable holding input line address
DF_END:	equ 0x4010		; System variable holding end of display
FRAME:	equ 0x401E		; System variable holding clock
	
_HALT:	equ 0x76		; End-of-line character for display buffer

	include "..\zx80_chars.asm"

	org 0x6000

DISPLAY:
	;; Locate display memory at start of game
	include "hampson_gameboard.asm"
	
	;; Main game loop
START:
	;; Point ROM to display info
	ld hl, DISPLAY
	ld (DFILE), hl
	ld hl, DISPLAY+0x21*0x17+01
	ld (DF_EA), hl
	ld hl, DISPLAY+0x21*0x18+01
	ld (DF_END),hl

	;; Set random-number seed based on FRAME
	ld hl,(FRAME)
	ld (SEED),hl
	
	ld hl,500		; Test value for randomisation of board
	ld (ROW),hl

	;; Initialise game cycle
	ld hl,0x0000
	push hl
	
MAIN_LOOP:
	ld (iy+0x23),0x38	; 56 scan lines above display area

	;; Retrieve game state
	pop hl 			; (10)
	push hl			; (11)
	
	in a, (0xFE)		; Turn on vertical sync generator

	;; Game code (max of 1360 T states)
V_ON:
	;; Jump to correct routine (77 T states + routine cost)	
	add hl,hl		; (11) Multiple by 2
	ld de, JUMP_TABLE	; (10)
	add hl,de		; (11) Point to correct routine

	ld e,(hl)		; (7)
	inc hl			; (6)
	ld d,(hl)		; (7)
	ex de,hl		; (4)
	call JUMP_TO_IT		; (17 + 4 + routine cost)
	
	;; Generate display
V_OFF:	out (0xFE),a		; Turn off vertical sync generation

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
	;; Effectively JP DE
	;;
JUMP_TO_IT:
	jp (hl)			; (4)

JUMP_TABLE:
	dw FLIP_TILE		; 1240 T states
	dw GETNUM		; 1240 T states

ROW:	dw 0x0000
	
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
	;; Generate game board (1-iter)
	;; 
	;; T = 1277 (aiming for 1,283 T states)
FLIP_TILE:
	;; Check if done
	ld hl,(ROW)	       ; (16) Retrieve counter
	dec hl		       ; (6)
	ld (ROW),hl	       ; (16)

	ld a,h			; (4)
	or l			; (4)
	jr z, FLIP_DONE		; (12/7)
	
	;; Pick row number - 0...15 (82 T-states)
	ld hl,(SEED)		; (16)
	ld a,r			; (9)
	ld d,a			; (4)
	ld e,(HL)		; (7)
	add hl,de		; (11)
	add a,l			; (4)
	xor h			; (4)
	ld (SEED),hl		; (16)
	and 0x0F		; (7)
	ld b,a			; (4)

	;; Pick column number - 0 -- 25 (71 T-states)
	ld hl,(SEED)		; (16)
	ld a,r			; (9)
	ld d,a			; (4)
	ld e,(HL)		; (7)
	add hl,de		; (11)
	add a,l			; (4)
	xor h			; (4)
	ld (SEED),hl		; (16)

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
	
	call FLIP9		; (17 + 965)
	
	ret			; (7)

FLIP_DONE:			; 55 + WAIT
	pop de			; (10) Return address for routine
	pop hl			; (10) Sequence counter
	inc hl			; (6) Next step
	push hl			; (11) Store sequence counter
	push de			; (11) and return address

	;; Dummy wait (T = 7 + 8 + (N-1)*13)
	ld b, 0x59
FLIP_W:	djnz FLIP_W

	nop			; (4)
	nop			; (4)
	
	ret			; (10)

GETNUM:
	;; Aiming for 1287 T-states
	;; 
	;; 296...298 T-states
	call READNUM		; (17+251...253)
	ld a, _0		; (7)
	add a,d			; (4)
	ld hl, DISPLAY+33*20+2	; (10)
	ld (hl),a		; (7)

;; Dummy wait (T = 7 + 8 + (N-1)*13)
	ld b, 0x4B
GLOOP:	djnz GLOOP
	
	ret			; (10)
	
	;;
	;; Dummy sequence step which waits for suitable time
	;;

	;; Dummy wait (T = 7 + 8 + (N-1)*13)
IDLE:	ld b, 0x61		; (7)
IDLE_W:	djnz IDLE_W		; (13/8)

	nop 			; (4)
	nop			; (4)
	
	ret			; (10)
	
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
	;; T states = 965
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
	
	;; Remainder of routine = 524 T-states, inc. RET
	;; Step along row
	add hl,bc		; (11) B is zero thanks to previous loop

	ld c,3			; (7) Three rows in block
	
	;; T = 167*2+162 = 496
COL3:	ld b,3			; (7)

	;; T = 40x2+35 = 115
ROW3:	ld a,(hl)		; (7) Invert three tiles on current row
	xor _ASTERISK		; (7)
	ld (hl),a		; (7)
	inc hl			; (6)
	djnz ROW3		; (13/8)

	;; Return to start of row
	dec hl			; (6)
	dec hl			; (6)
	dec hl			; (6)
	
	add hl,de		; (11) Next row

	dec c			; (4)
	jr nz, COL3		; (12/7)

	ret			; (10)
END:	

	;;
	;; Read number
	;;
	;; 251 ... 253 T-states
READNUM:	
	ld d, 0xFF		; (7)
	ld bc, 0xF7FE		; (10)
	in a,(c)		; (12)

	cp 0x7E			; (7)
	jr nz, NO_1		; (12/7)
	ld d, 0x01		; (7)
NO_1:	cp 0x7D			; (7)
	jr nz, NO_2		; (12/7)
	ld d, 0x02		; (7)
NO_2:	cp 0x7B			; (7)
	jr nz, NO_3		; (12/7)
	ld d, 0x03		; (7)
NO_3:	cp 0x77			; (7)
	jr nz, NO_4		; (12/7)
	ld d, 0x04		; (7)
NO_4:	cp 0x6F			; (7)
	jr nz, NO_5		; (12/7)
	ld d, 0x05		; (7)

NO_5:	ld bc, 0xEFFE		; (10)
	in a,(c)		; (12)

	cp 0x7E			; (7)
	jr nz, NO_0		; (12/7)
	ld d, 0x00		; (7)
NO_0:	cp 0x7D			; (7)
	jr nz, NO_9		; (12/7)
	ld d, 0x09		; (7)
NO_9:	cp 0x7B			; (7)
	jr nz, NO_8		; (12/7)
	ld d, 0x08		; (7)
NO_8:	cp 0x77			; (7)
	jr nz, NO_7		; (12/7)
	ld d, 0x07		; (7)
NO_7:	cp 0x6F			; (7)
	jr nz, NO_6		; (12/7)
	ld d, 0x06		; (7)

NO_6:	ret			; (10)
	

;; 	;;
;; 	;; Read keyboard
;; 	;; 
;; KSCAN:	ld hl, 0xFFFF
;; 	ld bc, 0xFEFE
;; 	in a,(c)
;; 	or 0x01
	
;; KLOOP:	or 0xE0
;; 	ld d,a
;; 	cpl
;; 	cp 0x01
;; 	sbc a,a
;; 	or b
;; 	and l
;; 	ld l,a
;; 	ld a,h
;; 	and d
;; 	ld h,a
;; 	rlc b
;; 	in a,(c)
;; 	jr c, KLOOP
;; 	rra
;; 	rl h

;; 	ret

;; FINDCHR:
;; 	ld d,0x00
;; 	sra b
;; 	sbc a,a
;; 	or 0x26
;; 	sub l
;; FLOOP:	add a,l
;; 	scf
;; 	rr c
;; 	jr c, FLOOP

;; 	inc c
;; 	ret nz

;; 	ld c,b
;; 	dec l
;; 	ld l,01

;; 	jr nz, FLOOP
;; 	ld hl, KTABLE

;; 	ld e,a
;; 	add hl,de

;; 	ret

;; 	;;
;; 	;; Read key from keyboard
;; 	;; 
;; GETKEY:	call KSCAN
;; 	ld b,h
;; 	ld c,l
;; 	ld d,c
;; 	inc d
;; 	ld a, 0x00		; Avoid changing flags
;; 	jr z, NOCHR
;; 	call FINDCHR
;; 	ld a,(hl)
	
;; NOCHR:	ret

;; TEST:	call GETKEY
;; 	jr TEST

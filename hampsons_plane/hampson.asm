	;; Port of Mike Hampson's tile flipping game, Hampson's Plane, to
	;; the ZX80 (4K ROM), written so as to be flicker-free using a
	;; similar technique to Breakout
	;; (http://www.fruitcake.plus.com/Sinclair/ZX80/FlickerFree/ZX80_Breakout.htm)
	;;
	;; Ported by George Beckett, 2023.

	;; Useful 4K ROM routines/ addresses/ system variables
DISP_2:	equ 0x01AD		; ROM screen display routine
KTABLE:	equ 0x006B		; Keyboard lookup in ROM
DFILE:	equ 0x400C		; System variable holding display address
DF_EA:	equ 0x400E		; System variable holding input line address
DF_END:	equ 0x4010		; System variable holding end of display
FRAME:	equ 0x401E		; System variable holding clock


	include "..\zx80_chars.asm"

	org 0x6000
DISPLAY:
	;; Locate display memory at start of game code
	include "hampson_gameboard.asm"
	
	;; Entry point from BASIC
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
	
	;; Initialise game cycle
	ld hl,0x0000
	push hl
	
MAIN_LOOP:
	;; Set scan-line count for upper board, ready for use of ROM routine
	ld (iy+0x23),0x38	; 56 scan lines above display area

	;; Retrieve game state
	pop hl 			; (10)
	push hl			; (11)
	
V_ON:	in a, (0xFE)		; Turn on vertical sync generator

	;; 
	;; Game code (max of 1360 T states between V_ON and V_OFF)
	;;
	
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
	;; Effectively `call HL`
	;;
JUMP_TO_IT:
	jp (hl)			; (4)

JUMP_TABLE:
	dw NEW_GAME		; 1244 T states
	dw FLIP_TILE		; 1287 T states
	dw REQ_COORD		; 1283 T states
	dw GET_COL		; 1283--1287 T states
	dw WAIT_NO_KEY		;
	dw GET_ROW_1		;
	dw WAIT_NO_KEY		;
	dw GET_ROW_0		;
	dw FLIP_IT		;
	dw IDLE			; 1240 T states

COORD:	dw 0x0000
	
	;; ----------------------------------------------------------------
	;; Start new game
	;; ----------------------------------------------------------------
	;; Usually 1,287 T states (aim for 1,283)
NEW_GAME:
	;; 613 T states
	;; Print message asking user to choose difficult level
	ld hl, SKILL_MSG	; (10)
	ld bc, 0x001D		; (10)
	ld de, DISPLAY+21*33+1	; (10)
	ldir			; ( = 21*27+16)


	;; Read number from keyboard (268...270 T states)
	call READNUM		; (17+251...253)

	;; Check value read is within range 1...9
	;; 32/23/37 T-states (balanced by NO_NUM)
	ld a,d			; (4)
	cp 0x01			; (7)
	jr c, NO_NUM		; (12/7)
	cp 0x0A			; (7)
	jr nc, NO_NUM_2		; (12/7)

	;; Print input and work out how many iterations of
	;; randomisation to do
	
	;; 350 T-states + return
	ld b,a			; (4)
	add a,_0 		; (7)
	ld (DISPLAY+21*33+27),a ; (13)
	ld a,b			; (4)

	;; Reset counter and set increment
	ld hl, 0x0000		; (10)
	ld de, 40		; (10)

	;; 19 + (N-1)*24 = 19 ... 211
N_ADD:	add hl,de		; (11)
	djnz N_ADD		; (13/8)

	;; Store iteration count for new step (use COORD to avoid
	;; wasting memory)
	ld (COORD),hl		; (16)

	;; Idle loop to ensure consisten runtime
	ld b,a			; (4)
	ld a,0x0a		; (7)
	sub b			; (4)
	ld b,a			; (4)

	;; 19 + (N-1)*24 = 19 ... 139
N_DUMMY:
	add hl,de		; (11)
	djnz N_DUMMY		; (13/8)

	;; Advance to next game step (48 T-states)
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)
	
	ret 			; (10)

	;; If invalid entry, idle to complete the game iteration
	;; and return for another input
NO_NUM:	add a,0x00		; (7)
	add a,0x00		; (7)

	;; 344 T-states (aim for 345 T-states) + ret
	;; 
NO_NUM_2:
	nop			; (4)
	ld b,0x1A		; (7)
NN_LOOP:
	djnz NN_LOOP		; (13/8)

	ret			; (10)
	
SKILL_MSG:
	db _SPACE, _C, _H, _O, _O, _S, _E, _SPACE
	db _S, _K, _I, _L, _L, _SPACE, _L, _E
	db _V, _E, _L, _SPACE, _LEFTPARENTH, _1, _MINUS, _9
	db _RIGHTPARENTH, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE

	;; ----------------------------------------------------------------
	;; Generate game board (1-iter)
	;; ----------------------------------------------------------------
	;; T = 1277 (aiming for 1,283 T states)
FLIP_TILE:
	;; Check if done
	ld hl,(COORD)	       ; (16) Retrieve counter
	dec hl		       ; (6)
	ld (COORD),hl	       ; (16)

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

	call COL2ADDR
	call FLIP9		; (17 + 1257)
	
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

	;; ----------------------------------------------------------------
	;; Dummy sequence step which waits for suitable time
	;; ----------------------------------------------------------------
	;; Dummy wait (T = 7 + 8 + (N-1)*13)
IDLE:	ld b, 0x61		; (7)
IDLE_W:	djnz IDLE_W		; (13/8)

	nop 			; (4)
	nop			; (4)
	
	ret			; (10)
	
	;; ----------------------------------------------------------------
	;; Request coordinate
	;; ----------------------------------------------------------------
REQ_COORD:	
	;; 613 T states
	ld hl, COORD_MSG	; (10)
	ld bc, 0x001E		; (10)
	ld de, DISPLAY+21*33+1	; (10)
	ldir			; ( = 21*27+16)

	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)
	
	ld b, 0x2C		; (7)
RLOOP:	djnz RLOOP		; (13/8)
	
	ret			; (10)

COORD_MSG:
	db _SPACE, _E, _N, _T, _E, _R, _SPACE, _M
	db _O, _V, _E, _S, _SPACE, _LEFTPARENTH, _C, _O
	db _L, _SPACE, _F, _I, _R, _S, _T, _RIGHTPARENTH
	db _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE



	;; ----------------------------------------------------------------
	;; Wait for no key
	;; ----------------------------------------------------------------
WAIT_NO_KEY:
	call KSCAN		; (712 + 17)

	;; Check if HL = 0xFFFF, which indicates no key pressed
	inc hl			; (6) HL = 0 ?
	ld a,h			; (4)
	or l			; (4)

	jr nz, WK_PRESSED 	; (12/7)

	;;  No key pressed, so advance to next game step
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Wait 1,283 - 798 - 10 = 475
	ld b, 0x24
W_DUMMY:
	;; 
	djnz W_DUMMY

	ret

WK_PRESSED:
	ld b,0x29
WK_LOOP:	
	djnz WK_LOOP
	
	ret			; (10)
	
	;; ----------------------------------------------------------------
	;; Get first digit of row coordinate (0 or 1)
	;;
	;; If 1 is pressed, 88 + GR_DONE
	;; If 0 is pressed, 126 + GR_DONE
	;; If no suitable key, 92 + GW_NO_0
	;; ----------------------------------------------------------------
GET_ROW_1:
	;; 29 T-states
	ld bc, 0xF7FE		; (10)
	in a,(c)		; (12)
	cp 0x7E			; (7)

	jr nz, GW_NO_1		; (12/7)
	ld a,0x0a		; (7)
	ld (COORD+1), a		; (13)
	ld a,_1			; (7)
	ld (DISPLAY+21*33+27),a	; (13)

	;; Dummy of 38 T states
	ld b, 0x02
GW_LOOP_0:
	djnz GW_LOOP_0

	jr GR_DONE		; (12)
	
GW_NO_1:
	ld bc, 0xEFFE		; (10)
	in a,(c)		; (12)

	cp 0x7E			; (7)
	jr nz, GW_NO_0		; (12/7)
	
	xor a			; (4)
	ld (COORD+1),a		; (13)
	ld a,_0			; (7)
	ld (DISPLAY+21*33+27),a	; (13)

	jr GR_DONE		; (12)
	
	;; 1181 T states to wait
GW_NO_0:
	ld b,0x5C
GW_LOOP:
	djnz GW_LOOP

	ret

GR_DONE: 			; Need 1177 T-states
	;; Advance game sequence
	pop de 			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	ld b,0x55
GW_LOOP_2:
	djnz GW_LOOP_2
	
	ret			; (10)
	

	;; ----------------------------------------------------------------
	;; Read second coordinate of row id
	;; ----------------------------------------------------------------
GET_ROW_0:
	;; 268...270 T states
	call READNUM		; (17+251...253)

	ld a,d			; (4) Check if number key pressed
	inc a			; (4) Will be non-zero if so

	jr z, G0_NO_KEY 	; (12/7)

	;; Update saved coordinate
	ld a,(COORD+1)		; (13) Restore value
	add a,d			; (4)
	ld (COORD+1),a		; (13)

	;; Print keypress
	ld a,d			; (4)
	add a, _0		; (7)
	ld (DISPLAY+21*33+28),a	; (13)

	;; Advance to next game step
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Need 1283-380 T states

	ld b,0x46
G0_LOOP:
	djnz G0_LOOP

	ret
	
G0_NO_KEY:
	ld b, 0x4B
G0_LOOP_2:
	djnz G0_LOOP_2
	
	ret			; (10)
	
	;; ----------------------------------------------------------------
	;; Read letter
	;; ----------------------------------------------------------------
	;; 763 + ??? T-states (aim for 1,283 T states)
GET_COL:
	;; 589--591 T-states
	ld d, 0xFF		; (7)
	
	ld bc, 0xFBFE		; (10)
	in a,(c)		; (12)

	cp 0x7E			; (7)
	jr nz, NO_Q		; (12/7)
	ld d, _Q		; (7)
NO_Q:	cp 0x7D			; (7)
	jr nz, NO_W		; (12/7)
	ld d, _W		; (7)
NO_W:	cp 0x7B			; (7)
	jr nz, NO_E		; (12/7)
	ld d, _E		; (7)
NO_E:	cp 0x77			; (7)
	jr nz, NO_R		; (12/7)
	ld d, _R		; (7)
NO_R:	cp 0x6F			; (7)
	jr nz, NO_T		; (12/7)
	ld d, _T		; (7)

NO_T:	ld bc, 0xDFFE		; (10)
	in a,(c)		; (12)

	cp 0x7E			; (7)
	jr nz, NO_P		; (12/7)
	ld d, _P		; (7)
NO_P:	cp 0x7D			; (7)
	jr nz, NO_O		; (12/7)
	ld d, _O		; (7)
NO_O:	cp 0x7B			; (7)
	jr nz, NO_I		; (12/7)
	ld d, _I		; (7)
NO_I:	cp 0x77			; (7)
	jr nz, NO_U		; (12/7)
	ld d, _U		; (7)
NO_U:	cp 0x6F			; (7)
	jr nz, NO_Y		; (12/7)
	ld d, _Y		; (7)

NO_Y:	ld bc, 0xFDFE		; (10)
	in a,(c)		; (12)

	cp 0x7E			; (7)
	jr nz, NO_A		; (12/7)
	ld d, _A		; (7)
NO_A:	cp 0x7D			; (7)
	jr nz, NO_S		; (12/7)
	ld d, _S		; (7)
NO_S:	cp 0x7B			; (7)
	jr nz, NO_D		; (12/7)
	ld d, _D		; (7)
NO_D:	cp 0x77			; (7)
	jr nz, NO_F		; (12/7)
	ld d, _F		; (7)
NO_F:	cp 0x6F			; (7)
	jr nz, NO_G		; (12/7)
	ld d, _G		; (7)

NO_G:	ld bc, 0xBFFE		; (10)
	in a,(c)		; (12)

	cp 0x7E			; (7)
	jr nz, NO_ENT		; (12/7)
	ld d, 0xFF		; (7)
NO_ENT:	cp 0x7D			; (7)
	jr nz, NO_L		; (12/7)
	ld d, _L		; (7)
NO_L:	cp 0x7B			; (7)
	jr nz, NO_K		; (12/7)
	ld d, _K		; (7)
NO_K:	cp 0x77			; (7)
	jr nz, NO_J		; (12/7)
	ld d, _J		; (7)
NO_J:	cp 0x6F			; (7)
	jr nz, NO_H		; (12/7)
	ld d, _H		; (7)

NO_H:	ld bc, 0xFEFE		; (10)
	in a,(c)		; (12)

	cp 0x7E			; (7)
	jr nz, NO_SH		; (12/7)
	ld d, 0xFF			; (7)
NO_SH:	cp 0x7D			; (7)
	jr nz, NO_Z		; (12/7)
	ld d, _Z		; (7)
NO_Z:	cp 0x7B			; (7)
	jr nz, NO_X		; (12/7)
	ld d, _X		; (7)
NO_X:	cp 0x77			; (7)
	jr nz, NO_C		; (12/7)
	ld d, _C		; (7)
NO_C:	cp 0x6F			; (7)
	jr nz, NO_V		; (12/7)
	ld d, _V		; (7)

NO_V:	ld bc, 0x7FFE		; (10)
	in a,(c)		; (12)

	cp 0x7E			; (7)
	jr nz, NO_SP		; (12/7)
	ld d, 0xFF			; (7)
NO_SP:	cp 0x7D			; (7)
	jr nz, NO_DOT		; (12/7)
	ld d, 0xFF		; (7)
NO_DOT:	cp 0x7B			; (7)
	jr nz, NO_M		; (12/7)
	ld d, _M		; (7)
NO_M:	cp 0x77			; (7)
	jr nz, NO_N		; (12/7)
	ld d, _N		; (7)
NO_N:	cp 0x6F			; (7)
	jr nz, NO_B		; (12/7)
	ld d, _B		; (7)

NO_B:	ld hl, DISPLAY+33*21+26	; (10)
	ld a,d			; (4)
	cp 0xFF			; (7)
	jr z, NO_KEY_PRESSED	; (12/7)
	ld (hl),a		; (7)

	sub a, _9		; (7)
	ld (COORD),a		; (13)
	
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	jr KEY_PRESSED		; (7)
	
NO_KEY_PRESSED:	
	ld b, 0x06		; (7)
KLOOP1:	djnz KLOOP1		; (13/8)

KEY_PRESSED:	
	;; 7 + 8 +(N-1)*13
	ld b, 0x23		; (7)
KLOOP2:	djnz KLOOP2		; (13/8)
	
	ret			; (10)
	
	;;
	;; Flip it
	;;
FLIP_IT:
	ld hl,COORD		; (10)
	ld c,(hl)		; (7)
	dec c			; (4)
	inc hl			; (6)
	ld b,(hl)		; (7)
	dec b			; (4)

	call COL2ADDR		; (17 + )
	call FLIP9		; (17+1266)

	pop de			; (10)
	pop hl			; (10)
	dec hl			; (6)
	dec hl			; (6)
	dec hl			; (6)
	dec hl			; (6)
	dec hl			; (6)
	dec hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Pause 1283 - 1151
	ld b,0x0B
FI_LOOP:
	djnz FI_LOOP
	
	ret			; (10)

	;; ----------------------------------------------------------------
	;; Convert grid coordinate into screen address
	;; ----------------------------------------------------------------
	;; On entry:
	;;     b - row number (0...15)
	;;     c - column number (0...25)
	;; On exit:
	;;     hl - screen address of cell at (b-1,c-1) -- that is top-left
	;;          of 3x3 tile block
	;;     bc,de,af - corrupted
	;; Timing:
	;; ----------------------------------------------------------------
COL2ADDR:	
	ld hl,DISPLAY+3		; (10) Top, lefthand cormer of gameboard
	ld de, 0x0021		; (10) Length of a screen row

	;; Work out idle-time adjustment to make address calc fixed time
	ld a,16			; (7)
	sub b			; (8) a = 1...16

	;; Step down to correct row
	;; T = 4 + 19 + (B-1)x24 = 23 ... 383
	inc b			; (4) Row 1...16
CA_NROW:
	add hl,de		; (11)
	djnz CA_NROW		; (13/8)

	;; Dummy routine to balance timing
	;; T = 4 + 19 + (A-1)x24 = 23...383
	ld b,a			; (4)
CA_DROW:
	and a			; (4) Need 11 T states of nothing
	and 0xFF		; (7)
	djnz CA_DROW		; (13/8)
	
	;; Step along row
	add hl,bc		; (11) B is zero thanks to previous loop

	ret


	;; ----------------------------------------------------------------
	;; Flip a 3x3 block of tiles
	;; ----------------------------------------------------------------
	;; On entry:
	;;      hl - address, in display, of top-left corner of block
	;;      ix - number of '#' in puzzle
	;; 
	;; On exit:
	;;      ix - number of '#' in puzzle 
	;; 	a  - corrupted
	;;      be - corrupted
	;;	de - corrupted
	;; 	hl - corrupted
	;;
	;; Timing:
	;; T states = 1266
	;; ----------------------------------------------------------------
	
FLIP9:	;;  Flip tiles row by row
	ld de,0x1E		; (7) Offset from end of one row of 3
	                        ;     to start of next
	ld c,3			; (7) Three rows in block
	
	;; T = 255*2+250 = 760
	;; Invert three tiles on current row
COL3:	ld b,3			; (7)

	;; T = 76x2+69 = 221
ROW3:	ld a,(hl)		; (7)
	xor _ASTERISK		; (7)
	ld (hl),a		; (7)
	inc hl			; (6) Next column

	;; Update counter (36 T states)
	cp _ASTERISK+0x80	; (7) Check if hash
	jr nz, NO_INC		; (12/7)
	inc ix			; (10) 
	jr CONT			; (12)
NO_INC:	dec ix			; (10) If not hash, then was hash
	and 0xFF		; (7) Dummy argument to add 7 T states
	
CONT:	djnz ROW3		; (13/8)

	;; Return to start of row
	add hl,de		; (11) Next row

	dec c			; (4)
	jr nz, COL3		; (12/7)

	ret			; (10)

	;; ----------------------------------------------------------------
	;; Read number
	;; ----------------------------------------------------------------
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
	

	;; ----------------------------------------------------------------
	;; Read keyboard
	;; ----------------------------------------------------------------
	;; 39 + 651 + 22 = 712 T states
KSCAN:	ld hl, 0xFFFF		; (10)
	ld bc, 0xFEFE		; (10)
	in a,(c)		; (12)
	or 0x01			; (7) Ignore shift

	;; 82*7 + 77 T-states
KLOOP:	or 0xE0			; (7) Only interested in low five bits
	ld d,a			; (4)
	cpl			; (4)
	cp 0x01			; (7)
	sbc a,a			; (4)
	or b			; (4)
	and l			; (4)
	ld l,a			; (4)
	ld a,h			; (4)
	and d			; (4)
	ld h,a			; (4)
LABEL:	rlc b			; (8)
	in a,(c)		; (12)
	jr c, KLOOP		; (12/7)

	rra			; (4)
	rl h			; (8)

	ret			; (10)
	
	;;
	;; Translate key coordinate into character
	;;
	;; On entry:
	;; B - column id from KSCAN
	;; C - row id from KSCAN
	;;
	;; On exit:
	;; A - character of key pressed (or SPACE)
	;; bc, de, hl - corrupted
FINDCHR:
	;; Compute offset for lookup based on whether Shift was pressed
	;; (indicated by bit 0 of B being reset).
 	sra b			; (8) Move shift into carry
 	sbc a,a			; (4) If shifted, A=0x00, else A=0xFF
 	or 0x26			; (7) If shifted, A=0x26, else A=0xFF (-1)

	ld l,5			; (7) Set step size for row search to 5,
	                        ; as there are 5 characters per row
 	sub l			; (4) Initial correction to make loop work

	;; This loop is a search which is used twice. On first pass, it is 
	;; used to identify offset to row data, and then, on second pass,
	;; to add offset to column data. The current offset is kep in A
	;; (which was set based on Shift status, above)
FLOOP:	add a,l			; (4) Advance offset pointer (by 5 or 1)
 	scf			; (4) Ensure left-most bit will be one
	rr c			; (8) Move next search bit int carry flag
	                        ; It will be zero (i.e., NC) if key pressed
	jr c, FLOOP		; (12/7) Carry set implies no key, so continue

	;; At this point, C will be 0xFF, if only one row/ column had key press
	inc c			; (4) C should be 0x00, if only key pressed
	jr nz, F2KEYS		; (12/7) Exit if not

	ld c,b			; (4) Move column id into c for second search
	dec l			; (4) If second search done, L will be zero
	ld l,01			; (7) If not, then step imcrement is 1 
	                        ;     per column for second search
	
	jr nz, FLOOP		; (12/7) Repeat, if second loop

	;; Otherwise compute address in table
	ld hl, KTABLE		; (10)
 	ld d,0x00		; (7)
	ld e,a			; (4)
	add hl,de		; (11)

	ld a, (hl)		; (7)
	
	ret			; (10)

	;; If more than one key is pressed (not including Shift) then ignore.
F2KEYS:	ld a,_SPACE		; (4) Load space char
	
	ret	  		; (10)
	
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

	
;; 	; now decode the value (in BC)
;; FIND_KEY
;;         SRA     B               ; sets carry if unshifted (bit 7 remains set)
;;         SBC     A,A             ; $FF unshifted, else $00
;;         OR      $26             ; $FF unshifted, else $26
;;         LD      L,$05           ; there are five keys in each row.
;;         SUB     L               ; set the starting point

;; ;; KEY-LINE
;; L032B:  ADD     A,L             ; add value 5 (or 1)
;;         SCF                     ; carry will go to bit 7
;;         RR      C               ; test C (which has 1 unset bit identifying row)
;;         JR      C,L032B         ; back if carry to KEY-LINE

;; ; if only one key pressed C should now be $FF.

;;         INC     C               ; test for $FF
;;         JR      NZ,L02F7        ; back if multiple keys to ED-COPY

;; ; the high byte of the key value identifies the column - again only one bit is
;; ; now reset.

;;         LD      C,B             ; transfer to B
;;         DEC     L               ; test if this is first time through
;;         LD      L,$01           ; reduce increment from five to one.
;;         JR      NZ,L032B        ; back if L was five to KEY-LINE

;; ; The accumulator now holds a key value 1-78 decimal.

;;         LD      HL,L006C - 1    ; location before the MAIN-KEYS table ($006B)
;;                                 ; the index value is 1 - 78.

;;         LD      E,A             ; code to E  (D is zero from keyboard)
;;         ADD     HL,DE           ; index into the table.
;;         LD      A,(HL)          ; pick up the letter/number/.

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




END:	

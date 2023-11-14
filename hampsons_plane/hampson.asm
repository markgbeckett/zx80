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


	include "..\utilities\zx80_chars.asm"

	org 0x4000		; Start of RAM on ZX80

SYSVAR:	
	db 0x00			; ERRNO
	db 0x04			; FLAGS
	dw 0xFFFF		; Current statement
	dw E_LINE		; Insertion point in E_LINE
	dw 0x006E		; Current line
	dw VARS
	dw E_LINE		; Start of edit line
	dw D_FILE		; Start of D_FILE
	dw D_FILE+0x21*0x17+01	; DF_EA
	dw END			; DF_END
	db 0x02			; Number of lines in lower screen
	dw 0x0064		; First line on screen
	dw 0x0000
	dw 0x0000
	db 0x00
	dw 0x079C		; Next item in syntax table
	dw 0x0000		; SEED (random-number gen.)
	dw 0x0000		; FRAMES
	dw 0x0000
	dw 0x3800		; Last value
	db 0x21			; Next char posn
	db 0x17			; Next row
	dw 0xFFFF		; Next char

RAMBOT:
LINE10:	db 0x00, 0x0A, _REM, _A ; 10 REM 

	;; Entry point from BASIC
START:
	;; Point system variables to display info, so ROM
	;; display-write routines work

	ld hl, D_FILE
	ld (DFILE), hl
	ld hl, D_FILE+0x21*0x17+01
	ld (DF_EA), hl
	ld hl, D_FILE+0x21*0x18+01
	ld (DF_END),hl

	;; Set random-number seed based on FRAME
	ld hl,(FRAME)
	ld (SEED),hl

	;; Initial display
	call PRINT_GRID
	
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
	;; Game code (max of 1,360 T states between V_ON and V_OFF)
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

	ld hl, D_FILE+0x8000

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

	;; Game sequence
JUMP_TABLE:
	dw NEW_GAME		;
	dw FLIP_TILE_1		;
	dw FLIP_TILE_2		;
	dw PRESS_C		;
	dw STOP_NO_KEY
	dw REQ_COORD		;
	dw GET_COL		;
	dw WAIT_NO_KEY		;
	dw GET_ROW_1		;
	dw WAIT_NO_KEY		;
	dw GET_ROW_0		;
	dw FLIP_IT_1		;
	dw FLIP_IT_2		;
	dw CHECK_SOLVED		;
	dw PRINT_TIME		;
	dw WAIT_NO_KEY		;
	dw RESTART_GAME		;
	dw IDLE			; 1240 T states

	;; Game variables
COORD:	dw 0x0000		; User-specified coordinate (or temp.
	                        ; store for address during grid init)
COUNT:	dw 0x000		; Counter for randomising initial grid
CLOCK:	ds 03			; 24-bit clock for game
MODE:	db 0x01			; ZX81 / 4D
	
LINE20:	db 0x76, 0x00, 0x14, _REM	; 20 REM 

	;; ----------------------------------------------------------------
	;; Start new game
	;; ----------------------------------------------------------------
	;; Usually 1,287 T states (aim for 1,283)
NEW_GAME:
	;; Print message asking user to choose difficult level (613)
	ld hl, SKILL_MSG	; (10)
PROF:	ld bc, 0x001C		; (10)
	ld de, D_FILE+21*33+1	; (10)
	ldir			; ( = 27*21+16)

	;; Read number from keyboard (238...240 T states)
	call READNUM		; (17+221...223)

	;; Time padding (15)
	ld b,1			; (7)
NG_LOOP:
	djnz NG_LOOP		; (13/8)
	
	;; Check value read is within range 1...9
	;; 32/23/37 T-states (balanced by NO_NUM)
	ld a,d			; (4)
	cp 0x01			; (7)
	jr c, NG_NO_NUM		; (12/7)
	cp 0x0A			; (7)
	jr nc, NG_NO_NUM_2	; (12/7)

	;; Print input and work out how many iterations of
	;; randomisation to do (28)
	ld b,a			; (4)
	add a,_0 		; (7)
	ld (D_FILE+21*33+27),a ; (13)
	ld a,b			; (4)

	;; Reset counter and set increment (20)
	ld hl, 0x0000		; (10)
	ld de, 0x40		; (10)

	;; 19 + (N-1)*24 = 19 ... 211
NG_ADD:	add hl,de		; (11)
	djnz NG_ADD		; (13/8)

	;; Store iteration count for new step (use COORD to avoid
	;; wasting memory)
	ld (COUNT),hl		; (16)

	;; Idle loop to ensure consistent runtime (19)
	ld b,a			; (4)
	ld a,0x0a		; (7)
	sub b			; (4)
	ld b,a			; (4)

	;; 19 + (N-1)*24 = 19 ... 211
NG_DUMMY:
	add hl,de		; (11)
	djnz NG_DUMMY		; (13/8)

	;; Advance to next game step (48 T-states)
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)
	
	ret 			; (10)

	;; If invalid entry, idle to complete the game iteration
	;; and return for another input
NG_NO_NUM:
	add a,0x00		; (7)
	add a,0x00		; (7)
	;; 920 so far

	;; (15 + 26*13 = 353)
NG_NO_NUM_2:
	ld b,0x1B		; (7)
NG_NN_LOOP:
	djnz NG_NN_LOOP		; (13/8)

	ret			; (10)
	
SKILL_MSG:			; Ask player to choose difficulty level
	db _SPACE, _C, _H, _O, _O, _S, _E, _SPACE
	db _S, _K, _I, _L, _L, _SPACE, _L, _E
	db _V, _E, _L, _SPACE, _LEFTPARENTH, _1, _MINUS, _9
	db _RIGHTPARENTH, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE

	;; ----------------------------------------------------------------
	;; Generate game board (1-iter), Part 1
	;; ----------------------------------------------------------------
	;; T = 1,283 (aiming for 1,283 T states)

FLIP_TILE_1:
	;; Wait (7 + 8 + 28*13 = 379) to fill time
	ld b,0x1D		; (7)
F1_LOOP:
	djnz F1_LOOP		; (13/8)
	
	;; Decrement counter for initial randomisation of grid
	ld hl,(COUNT)	       ; (16) Retrieve counter
	dec hl		       ; (6)
	ld (COUNT),hl	       ; (16)

	;; Check if done
	ld a,h			; (4)
	or l			; (4)
	jr z, F1_DONE		; (12/7)
	
	;; Pick row number - 0...15 (82 T-states)
	call RAND 		; (17 + 81)
	and 0x0F		; (7) Reduce to 0...15
	ld b,a			; (4) Store in B

	;; Pick column number - 0 -- 25 (98 + 89 = 187 T states)
	call RAND		; (17 + 81)
	
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

	;; Translate coordinate into address and save it
	call COL2ADDR		; (17+458)
	ld (COORD),hl		; (16) Store address

	;; Advanced to second stage of tile-flip
	pop de			; (10) Return address for routine
	pop hl			; (10) Sequence counter
	inc hl			; (6) Next step
	push hl			; (11) Store sequence counter
	push de			; (11) and return address

	ret			; (10)

	;; Game board is generated, so reset clock, advance game
	;; pointer, and wait until end of V. Sync period
F1_DONE:
	;; Reset timer
	call RESET_CLOCK	; (70)

	;; Advance game counter
	pop de			; (10) Return address for routine
	pop hl			; (10) Sequence counter
	inc hl			; (6) Next step
	inc hl 			; (6)
	push hl			; (11) Store sequence counter
	push de			; (11) and return address

	;; Dummy wait (7 + 8 + 59*13 = 782)
	ld b, 0x37
F1_WAIT:
	djnz F1_WAIT

	ret			; (10)

LINE30:	db 0x76, 0x00, 0x1E, _REM	; 30 REM 

	;; ----------------------------------------------------------------
	;; Generate game board (1-iter), Part 2
	;; ----------------------------------------------------------------
	;; T = 1,284 (aiming for 1,283 T states)
FLIP_TILE_2:
	;; Retrieve address from temp store
	ld hl,(COORD)		; (16)

	;; At this point, HL contains address of block to flip
	call FLIP9		; (17 + 784)

	;; Update game-step counter to point to tile-flip, part 1
	pop de			; (10)
	pop hl			; (10)
	dec hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Dummy loop to synchnronise timing
	;; T = 7 + 8 + 29*13 + 4 = 396
	ld b,0x1E			; (7)
F2_LOOP:
	djnz F2_LOOP		; (13/8)
	nop 			; (4)
	
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
	;; Get user to press 'C' to start, which also allows us to check
	;; which keyboard they are using (ZX80 or Minstrel 4D)
	;;	
	;; T = 1,288 - no key, 1,281 - ZX80 'C', 1,283 - Ace 'C' (aiming
	;; for 1,283 T states)
	;; ----------------------------------------------------------------
PRESS_C:	
	;; Copy message to row 21 of display (655)
	ld hl, START_MSG	; (10)
	ld bc, 0x001E		; (10)
	ld de, D_FILE+21*33+1	; (10)
	ldir			; ( = 21*29+16)

	;; Read bottom-left half-row (22)
	ld bc, 0xFEFE		; (10)
	in a,(c)		; (12)

	;; Check if bit 3 (ZX80 'C') is reset (28/39/34 - ZX80/ Ace/ None)
	rra			; (4)
	rra			; (4)
	rra			; (4)
	rra			; (4)
	jr nc, ZX80C 		; (12/7)

	;; Check if bit 4 (Minstrel 4D 'C') is reset
	rra			; (4)
	jr nc, ACEC		; (12/7)

	;; No key pressed, so repeat (T=711, at this point)
	ld b,0x2C		; (7)
C_IDLE:	djnz C_IDLE		; (13/8)

	ret			; (10)

ZX80C:	xor a			; (4)
	ld (MODE),a		; (13)

	;; 346 T-states
	ld b,0x28
CLOOP2:	djnz CLOOP2

	jr CNEXT		; (12)

ACEC:	ld a,0x01		; (7)
	ld (MODE),a		; (13)

	;; Wait (463)
	ld b,0x26		; (7)
CLOOP3:	djnz CLOOP3		; (13/8)
	
	;; Update game-step counter to point to request coordinate (48)
CNEXT:	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	ret			; (10)

START_MSG:
	db _SPACE, _P, _R, _E, _S, _S, _SPACE, _APOSTROPHE
	db _C, _APOSTROPHE, _SPACE, _T,  _O, _SPACE, _S, _T
	db _A, _R, _T, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE
	db _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE


LINE35:	db 0x76, 0x00, 0x23, _REM	; 30 REM 

	
	;; ----------------------------------------------------------------
	;; Wait for all keys to be released
	;;
	;; Timing:
	;;     1,272--1,274 (aiming for 1,278 T-states)
	;; ----------------------------------------------------------------
STOP_NO_KEY:
	;; Check for key-press
	call KSCAN		; (729)

	;; Check if HL = 0xFFFF, which indicates no key pressed (33/35)
	inc hl			; (6) HL = 0 ?
	ld a,h			; (4)
	or l			; (4)

	ld b,0x27		; (7) Default wait time (used at end of
	                        ;     routine
	jr nz, SK_DUMMY 	; (12/7)
	ld b,0x23		; (7) Reduce wait time
	
	;;  No key pressed, so advance to next game step (48)
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Wait until end of V. Sync
SK_DUMMY:
	djnz SK_DUMMY		; (13/8)

	ret			; (10)
	
	;; ----------------------------------------------------------------
	;; Print message to request coordinate
	;;
	;; Timing:
	;;     1,278 T-states
	;; ----------------------------------------------------------------
REQ_COORD:	
	;; Copy message to row 21 of display (655)
	ld hl, COORD_MSG	; (10)
	ld bc, 0x001E		; (10)
	ld de, D_FILE+21*33+1	; (10)
	ldir			; ( = 21*29+16)

	;; Update game-sequence counter (48)
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	ld de, D_FILE+20*33+24	; (10)
	call PRINT_CLOCK	; (426)
	
	;; Pad routine to fill V. Sync period (175)
	ld b, 0x0D		; (7)
RC_LOOP:
	djnz RC_LOOP		; (13/8)
	
	ret			; (10)

COORD_MSG:			; Request next move
	db _SPACE, _E, _N, _T, _E, _R, _SPACE, _M
	db _O, _V, _E, _SPACE, _LEFTPARENTH, _C, _O, _L
	db _SPACE, _F, _I, _R, _S, _T, _RIGHTPARENTH, _SPACE
	db _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE


LINE40:	db 0x76, 0x00, 0x28, _REM	; 40 REM 


	;; ----------------------------------------------------------------
	;; Read column reference
	;; 
	;; On entry:
	;;
	;; On exit:
	;;     d - Column specified (or 0xFF, if no key pressed)
	;;     af, c, de, hl - corrupted
	;; 
	;; Timing (aim for 1,283 T states):
	;;     1,277 (no key)
	;;     1,283 (key)
	;; ----------------------------------------------------------------
GET_COL:
	;; Advance timer
	call INC_CLOCK		; (124)
	
	;; Scan keyboard using brute force check for each key
	;; to ensure consistent timing

	;; Row 1 left (109...111 T states)
	ld d, 0xFF		; (7)
	ld bc, 0xFBFE		; (10)
	in a,(c)		; (12)
	rra			; (4)
	jr c, NO_Q		; (12/7)
	ld d, _Q		; (7)
NO_Q:	rra			; (4)
	jr c, NO_W		; (12/7)
	ld d, _W		; (7)
NO_W:	rra			; (4)
	jr c, NO_E		; (12/7)
	ld d, _E		; (7)
NO_E:	rra			; (4)
	jr c, NO_R		; (12/7)
	ld d, _R		; (7)
NO_R:	rra			; (4)
	jr c, NO_T		; (12/7)
	ld d, _T		; (7)

	;; Row 1 right (102...104 T states)
NO_T:	ld bc, 0xDFFE		; (10)
	in a,(c)		; (12)
	rra			; (4)
	jr c, NO_P		; (12/7)
	ld d, _P		; (7)
NO_P:	rra			; (4)
	jr c, NO_O		; (12/7)
	ld d, _O		; (7)
NO_O:	rra			; (4)
	jr c, NO_I		; (12/7)
	ld d, _I		; (7)
NO_I:	rra			; (4)
	jr c, NO_U		; (12/7)
	ld d, _U		; (7)
NO_U:	rra			; (4)
	jr c, NO_Y		; (12/7)
	ld d, _Y		; (7)

	;; Row 2 left (102...104 T states)
NO_Y:	ld bc, 0xFDFE		; (10)
	in a,(c)		; (12)
	rra			; (4)
	jr c, NO_A		; (12/7)
	ld d, _A		; (7)
NO_A:	rra			; (4)
	jr c, NO_S		; (12/7)
	ld d, _S		; (7)
NO_S:	rra			; (4)
	jr c, NO_D		; (12/7)
	ld d, _D		; (7)
NO_D:	rra			; (4)
	jr c, NO_F		; (12/7)
	ld d, _F		; (7)
NO_F:	rra			; (4)
	jr c, NO_G		; (12/7)
	ld d, _G		; (7)

	;; Row 2 right (117...119 T states)
NO_G:	ld bc, 0xBFFE		; (10)
	in a,(c)		; (12)
	rra			; (4)
	rra			; (4)
	jr c, NO_L		; (12/7)
	ld d, _L		; (7)
NO_L:	rra			; (4)
	jr c, NO_K		; (12/7)
	ld d, _K		; (7)
NO_K:	rra			; (4)
	jr c, NO_J		; (12/7)
	ld d, _J		; (7)
NO_J:	rra			; (4)
	jr c, NO_H		; (12/7)
	ld d, _H		; (7)
NO_H:	ld a,(MODE)		; (13)
	and a			; (4)
	jp nz, MODE_4D		; (12) - constant timing
	
	;; Row 3 left (90...92 T states)
	ld bc, 0xFEFE		; (10)
	in a,(c)		; (12)
	rra			; (4)
	rra			; (4)
	jr c, NO_Z		; (12/7)
	ld d, _Z		; (7)
NO_Z:	rra			; (4)
	jr c, NO_X		; (12/7)
	ld d, _X		; (7)
NO_X:	rra			; (4)
	jr c, NO_C		; (12/7)
	ld d, _C		; (7)
NO_C:	rra			; (4)
	jr c, NO_V		; (12/7)
	ld d, _V		; (7)

	;; Row 3 right (78...92 T states)
NO_V:	ld bc, 0x7FFE		; (10)
	in a,(c)		; (12)
	rra			; (4)
	rra			; (4)
	rra			; (4)
	jr c, NO_M		; (12/7)
	ld d, _M		; (7)
NO_M:	rra			; (4)
	jr c, NO_N		; (12/7)
	ld d, _N		; (7)
NO_N:	rra			; (4)
	jr c, NO_B		; (12/7)
	ld d, _B		; (7)
	jr NO_B			; (12)

	;; Row 3 left (78...80 T states)
MODE_4D:
	ld bc, 0xFEFE		; (10)
	in a,(c)		; (12)
	rra			; (4)
	rra			; (4)
	rra			; (4)
	jr c, ND_Z		; (12/7)
	ld d, _Z		; (7)
ND_Z:	rra			; (4)
	jr c, ND_X		; (12/7)
	ld d, _X		; (7)
ND_X:	rra			; (4)
	jr c, ND_C		; (12/7)
	ld d, _C		; (7)

	;; Row 3 right (90...92 T states)
ND_C:	ld bc, 0x7FFE		; (10)
	in a,(c)		; (12)
	rra			; (4)
	rra			; (4)
	jr c, ND_M		; (12/7)
	ld d, _M		; (7)
ND_M:	rra			; (4)
	jr c, ND_N		; (12/7)
	ld d, _N		; (7)
ND_N:	rra			; (4)
	jr c, ND_B		; (12/7)
	ld d, _B		; (7)
ND_B:	rra			; (4)
	jr c, ND_V		; (12/7)
	ld d, _V		; (7)

	;; If key pressed, write to screen and store
	;; (No key - 30; Key - 52)
NO_B:	
ND_V:	ld hl, D_FILE+33*21+26	; (10)
	ld a,d			; (4)
	inc d			; (4)
	jr z, GC_NO_KEY		; (12/7)
	ld (hl),a		; (7)
	sub a, _9+1		; (7)
	ld (COORD),a		; (13)

	;; Advance game counter (48)
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	jr GC_KEY		; (7)
	
GC_NO_KEY:	
	;; Print clock (436)
	ld de, D_FILE+20*33+24	; (10)
	call PRINT_CLOCK	; (426)

	;; Wat (67)
	ld b,5			; (7)
GC_LOOP:
	djnz GC_LOOP		; (13/8)
	
	ret			; (10)

GC_KEY:
	;; Wait (372)
	ld b, 0x23		; (7)
GC_LOOP2:
	djnz GC_LOOP2		; (13/8)
	
TEND:	ret			; (10)

LINE50:	db 0x76, 0x00, 0x32, _REM	; 50 REM 

	;; ----------------------------------------------------------------
	;; Wait until no key is being pressed
	;;
	;; On entry:
	;;
	;; On exit:
	;;     af, bc, de, hl - corrupted
	;;
	;; Timing:
	;;     1,281 if key pressed
	;;     1,279 if no key pressed
	;; ----------------------------------------------------------------
WAIT_NO_KEY:
	;; Advance timer
	call INC_CLOCK 		; (124)

	;; Check for key-press
	call KSCAN		; (729)

	;; Check if HL = 0xFFFF, which indicates no key pressed (14)
	inc hl			; (6) HL = 0 ?
	ld a,h			; (4)
	or l			; (4)

	ld b,0x1E		; (7) Default wait time (used at end of
	                        ;     routine
	jr nz, WK_DUMMY 	; (12/7)
	ld b,0x1A		; (7) Reduce wait time
	
	;;  No key pressed, so advance to next game step
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Wait until end of V. Sync
WK_DUMMY:
	djnz WK_DUMMY		; (13/8)

	ret			; (10)

	;; ----------------------------------------------------------------
	;; Get first digit of row coordinate (0 or 1)
	;;
	;; On entry:
	;;
	;; On exit:
	;;     AF, BC, DE, HL corrupted
	;;     (COORD) contains first digit of selected coordinate
	;;
	;; Timing
	;;     1,271 if 1 pressed
	;;     1,278 if 0 pressed
	;;     1,278 if no key pressed	
	;; ----------------------------------------------------------------
GET_ROW_1:
	;; Advance timer
	call INC_CLOCK		; (124)
	
	;; Read keys 1,..., 5 (29 T-states)
	ld bc, 0xF7FE		; (10)
	in a,(c)		; (12)
	rra			; (4)

	;; Skip forward if '1' not pressed
	jr c, G1_NOT_1		; (12/7)

	;; Set A to partial row number and C to corresponding digit
	ld a,0x0A		; (7)
	ld c,_1			; (7)

	;; Set length of wait loop
	ld b, 0x2C		; (7)

	jr G1_DONE		; (12)
	
G1_NOT_1:
	;; Read key 6,...,0 (29)
	ld bc, 0xEFFE		; (10)
	in a,(c)		; (12)
	rra			; (4)

	;; Skip forward if '0' not pressed
	ld b,0x30		; (7) Set wait value
	jr c, G1_WAIT		; (12/7)

	;; Set A to partial row number and C to corresponding digit
	xor a			; (4)
	ld c,_0			; (7)

	;; Set length of wait loop
	ld b,0x2A		; (7)

G1_DONE:
	;; Valid digit has been selected, so store it and
	;; proceed to next step
	ld (COORD+1),a		; (13) Store partial coordinate
	ld a,c			; (4)  Get character code
	ld (D_FILE+21*33+27),a	; (13) Display digit
	
	;; Advance game sequence
	pop de 			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Wait until end of V. Sync (B set previously)
G1_WAIT:
	djnz G1_WAIT

	ld de, D_FILE+20*33+24	; (10)
	call PRINT_CLOCK	; (426)

	ret			; (10)

	;; ----------------------------------------------------------------
	;; Read second coordinate of row id
	;;
	;; On entry:
	;;
	;; On exit:
	;;     AF, BC, DE, HL corrupted
	;;     (COORD) contains the selected coordinate
	;;
	;; Timing
	;;     1,276 if number pressed
	;;     1,281 if no key pressed	
	;; ----------------------------------------------------------------
GET_ROW_0:
	;; Advance timer
	call INC_CLOCK		; (124)
	
	;; 268...270 T states
	call READNUM		; (17+251...253)

	ld a,d			; (4) Check if number key pressed
	inc a			; (4) Will be non-zero if so

	jr z, G0_NO_KEY 	; (12/7)

	;; Update saved coordinate
	ld a,(COORD+1)		; (13) Restore value
	add a,d			; (4)
	dec a			; (4)
	ld (COORD+1),a		; (13)

	;; Print keypress
	ld a,d			; (4)
	add a, _0		; (7)
	ld (D_FILE+21*33+28),a	; (13)

	;; Advance to next game step
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Wait (756)
	ld b,0x3C		; (7)
G0_LOOP:
	djnz G0_LOOP

	ret			; (10)
	
G0_NO_KEY:
	ld de, D_FILE+20*33+24	; (10)
	call PRINT_CLOCK	; (426)

	;; Wait (418)
	ld b, 0x22		; (7)
G0_LOOP_2:
	djnz G0_LOOP_2
	
	ret			; (10)
	
	;; ----------------------------------------------------------------
	;; Flip 3x3 tile based on user-inputted coordinate (in COORD)
	;; ----------------------------------------------------------------
	;; On entry:
	;;     (COORD) - user-input coordinate
	;; 
	;; On exit:
	;;    af, bc, de, hl - corrupted
	;; 
	;; Timing:
	;;     1,282 T states, if valid move
	;;     1,279 T states, if not a valid move
	;; ----------------------------------------------------------------
FLIP_IT_1:
	;; Advance timer
	call INC_CLOCK 		; (124)
	
	;; Retrieve coordinate into BC
	ld hl,COORD		; (10)
	ld c,(hl)		; (7)
	inc hl			; (6)
	ld b,(hl)		; (7)

	;; Check row number is in range
	ld a,b			; (4)
	cp 0x10			; (7)
	jr nc, FI1_INVALID	; (12/7)
	
	;; Convert coordinate to address ...
	call COL2ADDR		; (17 + 458)

	;; ... and flip tile block
	ld (COORD),hl		; (16)

	;; Update game-step counter
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Wait until end of V. Sync
	ld b,0x2B		; (7)
FI1_WAIT:
	djnz FI1_WAIT		; (13/8)
	
	ret			; (10)

FI1_INVALID:
	;; Return to coordinate selection
	pop de			; (10)
	pop hl			; (10)
	ld bc, 0xFFFA		; (10)
	add hl,bc		; (11)
	push hl			; (11)
	push de			; (11)

	;; Delay until end of V. Sync signal
	;; (1029)
	ld b, 0x4F
FI1_WAIT_2:
	djnz FI1_WAIT_2

	ret			; (10)
	
LINE60:	db 0x76, 0x00, 0x3C, _REM	; 60 REM 

	;; ----------------------------------------------------------------
	;; Flip 3x3 tile based on user-inputted coordinate (in COORD)
	;; ----------------------------------------------------------------
	;; On entry:
	;;     (COORD) - user-input coordinate
	;; 
	;; On exit:
	;;    af, bc, de, hl - corrupted
	;;
	;; Timing:
	;;     1,276 T states
	;; ----------------------------------------------------------------
FLIP_IT_2:
	;; Advance timer
	call INC_CLOCK		; (124)

	;; Retrieve coordinate into BC
	ld hl,COORD		; (10)
	ld c,(hl)		; (7)
	inc hl			; (6)
	ld b,(hl)		; (7)

	;; Retrieve address into HL
	ld hl,(COORD)		; (16)

	;; ... and flip tile block
	call FLIP9		; (17 + 784)

	;; Update game-step counter
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Wait until end of V. Sync (249)
	ld b,0x13		; (7)
FI2_WAIT:
	djnz FI2_WAIT		; (13/8)
	
	ret			; (10)

	;; ----------------------------------------------------------------
	;; Check if grid has been solved (indicated by asterisk count being
	;; zero).
	;;
	;; On entry:
	;;     IX - count of visible asterisks in grid
	;;     2OS - current game step
	;; 
	;; On exit:
	;;     IX - count of visible asterisks in grid
	;;     2OS - next game step (either next move or new game)
	;;     AF, BC, HL, DE - corrupted
	;; 
	;; Timing:
	;;    Solved - 1,286
	;;    Not solved - 1,285
	;; ----------------------------------------------------------------
CHECK_SOLVED:	
	;; Advance timer
	call INC_CLOCK		; (124)

	;; Transfer asterisk count to DE
	push ix			; (15)
	pop de			; (10)

	;; Check for zero
	ld a,d			; (4)
	or e			; (4)

	jr NZ, CS_NOT_SOLVED	; (12/7)

	;; Print congratulations
	;; 802 T states
	ld hl, DONE_MSG		; (10)
	ld bc, 0x001D		; (10)
	ld de, D_FILE+21*33+1	; (10)
	ldir			; ( = 28*27+16)

	;; Update game sequence counter to end-game
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Wait until end of V. Sync
	ld b, 0x14
CS_WAIT:
	djnz CS_WAIT
	
	;; 
	ret			; (10)

CS_NOT_SOLVED:
	;; Update game-step counter to request next move
	pop de			; (10)
	pop hl			; (10)
	ld bc, 0x0008		; (10) 
	and a			; (4)
	sbc hl,bc		; (15)
	push hl			; (11)
	push de			; (11)

	;; Wait until end of V. sync.
	ld b,0x50
CS_WAIT_2:
	djnz CS_WAIT_2

	ret			; (10)
	
DONE_MSG:
	db _SPACE, _G, _R, _I, _D, _SPACE, _S, _O
	db _L, _V, _E, _D,  _SPACE, _I, _N, _SPACE
	db _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE
	db _S, _E, _C, _S, _SPACE, _SPACE, _SPACE, _SPACE

	;; ----------------------------------------------------------------
	;; Print time taken to solve the grid
	;;
	;; Timing:
	;;     1,279 T states
	;; ----------------------------------------------------------------
PRINT_TIME:
	;; Clear in-game timer
	ld de,D_FILE+20*33+24	; (10)
	call BLANK_CLOCK	; (149)
	
	;; Print time to solve the grid
 	ld de,D_FILE+21*33+17	; (10)
	call PRINT_CLOCK	; (426)

	;; Advance to next game step
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Wait until end of V. cycle
	ld b,0x30		; (7)
PT_WAIT:
	djnz PT_WAIT

	ret			; (10)
	
	;; ----------------------------------------------------------------
	;; Wait for key
	;;
	;; On entry:
	;;
	;; On exit:
	;;
	;; Timing:
	;;     1,275 - if key pressed
	;;     1,274 - if no key pressed
	;; ----------------------------------------------------------------
RESTART_GAME:
	;; Check for no key pressed
	call KSCAN		; (712 + 17)

	;; Check if HL = 0xFFFF, which indicates no key pressed
	inc hl			; (6) HL = 0 ?
	ld a,h			; (4)
	or l			; (4)

	jr z, RG_NO_KEY 	; (12/7)

	;;  Key pressed, so advance to next game step
	pop de			; (10)
	pop hl			; (10)
	ld bc, 0x0010		; (10)
	and a			; (4)
	sbc hl,bc		; (15)
	push hl			; (11)
	push de			; (11)

	;; Wait (444)
	ld b, 0x22		; (7)
RG_DUMMY:
	djnz RG_DUMMY		; (13/8)

	ret			; (10)

RG_NO_KEY:		
	;; Wait (509)
	ld b,0x27		; (7)
RG_LOOP:	
	djnz RG_LOOP		; (13/8)
	
	ret			; (10)
	
LINE70:	db 0x76, 0x00, 0x46, _REM	; 70 REM 

	;; ----------------------------------------------------------------
	;; Convert grid coordinate into screen address
	;; 
	;; On entry:
	;;     b - row number (0...15)
	;;     c - column number (0...25)
	;; 
	;; On exit:
	;;     hl - screen address of cell at (b-1,c-1) -- that is top-left
	;;          of 3x3 tile block
	;;     bc,de,af - corrupted
	;; 
	;; Timing:
	;;     458 T states
	;; ----------------------------------------------------------------
COL2ADDR:	
	ld hl,D_FILE+3		; (10) Top, lefthand cormer of gameboard
	ld de,0x0021		; (10) Length of a screen row

	;; Work out idle-time adjustment to make address calc fixed time
	ld a,16			; (7)
	sub b			; (4) a = 1...16

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

	ret			; (10)


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
	;;     784 T states
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
	;; Timing usually 221...223 T-states (poosibly more, if multiple
	;; key presses)
READNUM:	
	ld d, 0xFF		; (7)

	;; Read left-hand half of row 0 (102...104 T states, possibly up
	;; to 110)
	ld bc, 0xF7FE		; (10)
	in a,(c)		; (12)

	rra			; (4)
	jr c, NO_1		; (12/7)
	ld d, 0x01		; (7)
NO_1:	rra			; (4)
	jr c, NO_2		; (12/7)
	ld d, 0x02		; (7)
NO_2:	rra			; (4)
	jr c, NO_3		; (12/7)
	ld d, 0x03		; (7)
NO_3:	rra			; (4)
	jr c, NO_4		; (12/7)
	ld d, 0x04		; (7)
NO_4:	rra			; (4)
	jr c, NO_5		; (12/7)
	ld d, 0x05		; (7)

	;; Read right-hand half of row 0 (102...104 T states, possibly
	;; up to 110)
NO_5:	ld bc, 0xEFFE		; (10)
	in a,(c)		; (12)

	rra			; (4)
	jr c, NO_0		; (12/7)
	ld d, 0x00		; (7)
NO_0:	rra			; (4)
	jr c, NO_9		; (12/7)
	ld d, 0x09		; (7)
NO_9:	rra			; (4)
	jr c, NO_8		; (12/7)
	ld d, 0x08		; (7)
NO_8:	rra			; (4)
	jr c, NO_7		; (12/7)
	ld d, 0x07		; (7)
NO_7:	rra			; (4)
	jr c, NO_6		; (12/7)
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
	
	;; ----------------------------------------------------------------
	;; Simple Random Number Generator
	;;
	;; On entry:
	;;      
	;; On exit:
	;;     a  - random number
	;;     de - corrupted
	;;     hl - corrupted
	;;
	;; Timing:
	;;     81 T-states
	;; ----------------------------------------------------------------
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

	;; ----------------------------------------------------------------
	;; Reset clock to zero (e.g., ready for new game)
	;;
	;; On entry:
	;;
	;; On exit:
	;;     a - corrupted
	;;
	;; Timing:
	;;     53 T states
	;; ----------------------------------------------------------------
RESET_CLOCK:
	xor a			; (4)
	ld (CLOCK),a		; (13)
	ld (CLOCK+1),a		; (13)
	ld (CLOCK+2),a		; (13)

	ret			; (10)
	
	;; ----------------------------------------------------------------
	;; Increment clock by two (assumed to be 2 100ths of a second)
	;;
	;; On entry:
	;;
	;; On exit:
	;;     a - corrupted
	;;     hl - corrupted
	;;
	;; Timing:
	;;     107 T states
	;; ----------------------------------------------------------------
INC_CLOCK:
	ld hl,CLOCK		; (10)

	;; Low byte
	ld a,(hl)		; (7)
	add a,0x02		; (7)
	daa			; (4)
	ld (hl),a		; (7)

	;; Middle byte
	inc hl			; (6)
	ld a,(hl)		; (7)
	adc a,0x00		; (7)
	daa			; (4)
	ld (hl),a		; (7)
	inc hl			; (6)

	;; High byte
	ld a,(hl)		; (7)
	adc a,0x00		; (7)
	daa			; (4)
	ld (hl),a		; (7)

	ret			; (10)
	
LINE80:	db 0x76, 0x00, 0x50, _REM	; 80 REM 

	;; ----------------------------------------------------------------
	;; Print clock (with two d.p.)
	;;
	;; On entry:
	;;     de - screen address to which to print (assumed to be far
	;;          enough away from right-hand boundary)
	;; 
	;; On exit:
	;;     a - corrupted
	;;     de - corrupted
	;;     hl - corrupted
	;;
	;; Timing:
	;;     409 T states
	;; ----------------------------------------------------------------
PRINT_CLOCK:
	ld hl,CLOCK+2		; (10) High digits of timer
	ld a,(hl)		; (7)
	call PR_DIGITS		; (114)

	dec hl
	ld a,(hl)		; (7)
	call PR_DIGITS		; (114)

	ld a,_FULLSTOP		; (7)
	ld (de),a		; (7)
	inc de			; (6)

	dec hl			; (6)
	ld a,(hl)		; (7)
	call PR_DIGITS		; (114)

	ret			; (10)

	;; ----------------------------------------------------------------
	;; Print binary coded two-digit decimal in A
	;;
	;; On entry:
	;;     a - contains two-digit decimal
	;;     de - contains screen address to print to
	;; 
	;; On exit:
	;;     a,b - corrupted
	;;     de - screen address of next character
	;;
	;; Timing:
	;;     97 T states
	;; ----------------------------------------------------------------
PR_DIGITS:
	ld b,a			; (4)
	srl a			; (8)
	srl a			; (8)
	srl a			; (8)
	srl a			; (8)
	add a, _0		; (7)
	ld (de),a		; (7)
	inc de			; (6)
	ld a,b			; (4)
	and 0x0F		; (7)
	add a, _0		; (7)
	ld (de),a		; (7)
	inc de			; (6)

	ret			; (10)

	;; ----------------------------------------------------------------
	;; Clear clock -- print seven spaces to blank out clock
	;;
	;; On entry:
	;;   de - Address of start of clock
	;;
	;; On exit:
	;;
	;; Timing:
	;;     129 T states
	;; ----------------------------------------------------------------
BLANK_CLOCK:	
	ld a, _SPACE		; (7)
	ld b,7			; (7)

	;; T = 6*26+21 = 105
BC_LOOP:
	ld (de),a		; (7)
	inc de			; (6)
	djnz BC_LOOP		; (13/8)

	ret			; (10)


	;; ----------------------------------------------------------------
	;; Print game grid
	;; ----------------------------------------------------------------
PRINT_GRID:
	ld hl, D_FILE
	ld (hl),_EOL-1		; Done to avoid 0x76 in BASIC
	inc (hl)
	inc hl
	
	call PRINT_CO_ROW
	call PRINT_BO_ROW

	ld bc,0x1001
PG_LOOP:
	push bc
	call PRINT_GR_ROW
	pop bc
	
	ld a,c
	add a,0x01
	daa
	ld c,a
	
	djnz PG_LOOP
	
	call PRINT_BO_ROW
	call PRINT_CO_ROW

	ld b, 0x04
PG_LOOP_2:
	push bc
	call PRINT_BL_ROW
	pop bc
	djnz PG_LOOP_2

	ret

	
	;; ----------------------------------------------------------------
	;; Print coordinate row
	;;
	;; On entry:
	;;   hl - Address in display buffer of start of row
	;;
	;; On exit:
	;;   hl - Address in display buffer of next row
	;; ----------------------------------------------------------------
PRINT_CO_ROW:
	ld (hl), _CHEQUERBOARD
	inc hl
	ld (hl), _CHEQUERBOARD
	inc hl
	ld (hl), _CHEQUERBOARD
	inc hl

	ld b,26
	ld a,_A
PC_LOOP:
	ld (hl),a
	inc a
	inc hl
	djnz PC_LOOP

	ld (hl), _CHEQUERBOARD
	inc hl
	ld (hl), _CHEQUERBOARD
	inc hl
	ld (hl), _CHEQUERBOARD
	inc hl

	ld (hl), _EOL-1
	inc (hl)
	inc hl

	ret

	;; ----------------------------------------------------------------
	;; Print grid-edge row
	;; 
	;; On entry:
	;;   hl - Address in display buffer of start of row
	;;
	;; On exit:
	;;   hl - Address in display buffer of next row
	;; ----------------------------------------------------------------
PRINT_BO_ROW:
	ld (hl), _CHEQUERBOARD
	inc hl
	ld (hl), _CHEQUERBOARD
	inc hl

	ld b, 28
BO_LOOP:
	ld (hl),_SPACE+0x80
	inc hl
	djnz BO_LOOP
	

	ld (hl), _CHEQUERBOARD
	inc hl
	ld (hl), _CHEQUERBOARD
	inc hl

	ld (hl),_EOL-1
	inc (hl)
	inc hl
	
	ret

	;; ----------------------------------------------------------------
	;; Print grid row
	;; 
	;; On entry:
	;;   hl - Address in display buffer of start of row
	;;   c  - row coordinate
	;;
	;; On exit:
	;;   hl - Address in display buffer of next row
	;; ----------------------------------------------------------------
PRINT_GR_ROW:
	ld de, 0x01E		; Row offset between left and right coordinate
	
	ld a,c			; Transfer row coordinate to A
	and 0xF0		; Isolate high digit

	jr z, GR_CONT
	ld a, 0x01
GR_CONT:
	add a,_0

	ld (hl),a
	add hl,de
	ld (hl),a
	sbc hl,de
	inc hl
	
	ld a,c			; Isolate low digit
	and 0x0F
	add a,_0

	ld (hl),a
	add hl,de
	ld (hl),a
	sbc hl,de
	inc hl

	ld b,28
GR_LOOP:
	ld (hl),_SPACE+0x80
	inc hl
	djnz GR_LOOP
	
	
	inc hl
	inc hl

	ld (hl),_EOL-1
	inc (hl)
	inc hl
	
	ret

	;; ----------------------------------------------------------------
	;; Print blank row
	;; ----------------------------------------------------------------
PRINT_BL_ROW:
	ld b, 0x20
BL_LOOP:
	ld (hl), _SPACE
	inc hl
	djnz BL_LOOP

	ld (hl),_EOL-1
	inc (hl)
	inc hl

	ret

LINE100:
 	db 0x76, 0x00, 0x64, _RANDOMIZE, 0x3A, 0x38, 0x37, 0xDA, 0x1D
 	db 0x22, 0x20, 0x1E, 0x24, 0xD9

	
BASIC_END:
	db 0x76
	
VARS:	db 0x80

E_LINE: db 0xB0, 0x76		; Inv-K, EOL

	ds $4800-$
D_FILE:
	include "hampson_gameboard.asm"
END:	

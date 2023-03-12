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

	org 0x6000
DISPLAY:
	;; Locate display memory at start of game code
	include "hampson_gameboard.asm"
	
	;; Entry point from BASIC
START:
	;; Point system variables to display info, so ROM
	;; display-write routines work
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
	dw FLIP_TILE_1		; ??? T states
	dw FLIP_TILE_2		; ??? T states
	dw REQ_COORD		; 1283 T states
	dw GET_COL		; 1283--1287 T states
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
	
	;; ----------------------------------------------------------------
	;; Start new game
	;; ----------------------------------------------------------------
	;; Usually 1,287 T states (aim for 1,283)
NEW_GAME:
	;; Print message asking user to choose difficult level (613)
	ld hl, SKILL_MSG	; (10)
PROF:	ld bc, 0x001C		; (10)
	ld de, DISPLAY+21*33+1	; (10)
	ldir			; ( = 27*21+16)

	;; Read number from keyboard (268...270 T states)
	call READNUM		; (17+251...253)

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
	ld (DISPLAY+21*33+27),a ; (13)
	ld a,b			; (4)

	;; Reset counter and set increment
	ld hl, 0x0000		; (10)
	ld de, 0x40		; (10)

	;; 19 + (N-1)*24 = 19 ... 211
NG_ADD:	add hl,de		; (11)
	djnz NG_ADD		; (13/8)

	;; Store iteration count for new step (use COORD to avoid
	;; wasting memory)
	ld (COUNT),hl		; (16)

	;; Idle loop to ensure consistent runtime
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
	
SKILL_MSG:
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
	;; Print message to request coordinate
	;;
	;; Timing:
	;;     1,278 T-states
	;; ----------------------------------------------------------------
REQ_COORD:	
	;; Copy message to row 21 of display (613)
	ld hl, COORD_MSG	; (10)
	ld bc, 0x001E		; (10)
	ld de, DISPLAY+21*33+1	; (10)
	ldir			; ( = 21*27+16)

	;; Update game-sequence counter (48)
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	ld de, DISPLAY+20*33+24	; (10)
	call PRINT_CLOCK	; (426)
	
	;; Pad routine to fill V. Sync period (175)
	ld b, 0x0D		; (7)
RC_LOOP:
	djnz RC_LOOP		; (13/8)
	
	ret			; (10)

COORD_MSG:
	db _SPACE, _E, _N, _T, _E, _R, _SPACE, _M
	db _O, _V, _E, _S, _SPACE, _LEFTPARENTH, _C, _O
	db _L, _SPACE, _F, _I, _R, _S, _T, _RIGHTPARENTH
	db _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE, _SPACE


	;; ----------------------------------------------------------------
	;; Wait until no key is being pressed
	;;
	;; On entry:
	;;
	;; On exit:
	;;     af, bc, de, hl - corrupted
	;;
	;; Timing:
	;;     
	;; ----------------------------------------------------------------
WAIT_NO_KEY:
	;; Advance timer
	call INC_CLOCK 		; (124)

	;; Check for key-press (729)
	call KSCAN		; (712 + 17)

	;; Check if HL = 0xFFFF, which indicates no key pressed (14)
	inc hl			; (6) HL = 0 ?
	ld a,h			; (4)
	or l			; (4)

	ld b,0x1E		; (7) Default wait time (used at end of
	                        ;     routine
	jr nz, WK_DUMMY 	; (12/7)
	ld b,0x19		; (7) Reduce wait time
	
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
	;;
	;; Timing
	;; 
	;; ----------------------------------------------------------------
GET_ROW_1:
	;; Advance timer
	call INC_CLOCK		; (124)
	
	;; Read keys 1,..., 5 (29 T-states)
	ld bc, 0xF7FE		; (10)
	in a,(c)		; (12)
	cp 0x7E			; (7)

	;; Skip forward if '1' not pressed
	jr nz, GR_NOT_1		; (12/7)

	;; Set A to partial row number and C to corresponding digit
	ld a,0x0A		; (7)
	ld c,_1			; (7)

	;; Set length of wait loop
	ld b, 0x4D		; (7)

	jr GR_DONE		; (12)
	
GR_NOT_1:
	;; Read key 6,...,0 (29)
	ld bc, 0xEFFE		; (10)
	in a,(c)		; (12)
	cp 0x7E			; (7)

	;; Skip forward if '0' not pressed
	ld b,0x2F		; (7) Set wait value
	jr nz, GR_WAIT		; (12/7)

	;; Set A to partial row number and C to corresponding digit
	xor a			; (4)
	ld c,_0			; (7)

	;; Set length of wait loop
	ld b,0x4B		; (7)

GR_DONE:
	;; Valid digit has been selected, so store it and
	;; proceed to next step
	ld (COORD+1),a		; (13) Store partial coordinate
	ld a,c			; (4)  Get character code
	ld (DISPLAY+21*33+27),a	; (13) Display digit
	
	;; Advance game sequence
	pop de 			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Wait until end of V. Sync (B set previously)
GR_WAIT:
	djnz GR_WAIT

	ld de, DISPLAY+20*33+24	; (10)
	call PRINT_CLOCK	; (426)

	ret			; (10)

	;; ----------------------------------------------------------------
	;; Read second coordinate of row id
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
	ld (DISPLAY+21*33+28),a	; (13)

	;; Advance to next game step
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	;; Need 1283-515 T states
	ld b,0x3B
G0_LOOP:
	djnz G0_LOOP

	ret
	
G0_NO_KEY:

	;; 414 +
	ld de, DISPLAY+20*33+24	; (10)
	call PRINT_CLOCK	; (426)

	ld b, 0x21
G0_LOOP_2:
	djnz G0_LOOP_2
	
	ret			; (10)
	
	;; ----------------------------------------------------------------
	;; Read column reference
	;; ----------------------------------------------------------------
	;; 763 + ??? T-states (aim for 1,283 T states)
GET_COL:
	;; Advance timer
	call INC_CLOCK		; (124)
	
	;; 589--591 T-states
	ld d, 0xFF		; (7)
	ld bc, 0xFBFE		; (10)
	in a,(c)		; (12)

	;; (95..97)
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

	;; (22)
NO_T:	ld bc, 0xDFFE		; (10)
	in a,(c)		; (12)

	;; (95...97)
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

	;; (22)
NO_Y:	ld bc, 0xFDFE		; (10)
	in a,(c)		; (12)

	;; (95...97)
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

	;; (22)
NO_G:	ld bc, 0xBFFE		; (10)
	in a,(c)		; (12)

	;; (76...78)
	cp 0x7D			; (7)
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

	;; (22)
NO_H:	ld bc, 0xFEFE		; (10)
	in a,(c)		; (12)

	;; (76...78)
	cp 0x7D			; (7)
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

	;; (22)
NO_V:	ld bc, 0x7FFE		; (10)
	in a,(c)		; (12)

	;; (57..59)
	cp 0x7B			; (7)
	jr nz, NO_M		; (12/7)
	ld d, _M		; (7)
NO_M:	cp 0x77			; (7)
	jr nz, NO_N		; (12/7)
	ld d, _N		; (7)
NO_N:	cp 0x6F			; (7)
	jr nz, NO_B		; (12/7)
	ld d, _B		; (7)

	;; (No key - 30; Key - 52)
NO_B:	ld hl, DISPLAY+33*21+26	; (10)
	ld a,d			; (4)
	inc d			; (4)
	jr z, NO_KEY_PRESSED	; (12/7)
	ld (hl),a		; (7)
	sub a, _9+1		; (7)
	ld (COORD),a		; (13)

	;; (48)
	pop de			; (10)
	pop hl			; (10)
	inc hl			; (6)
	push hl			; (11)
	push de			; (11)

	jr KEY_PRESSED		; (7)
	
NO_KEY_PRESSED:	
	;; 787 so far
	ld de, DISPLAY+20*33+24	; (10)
	call PRINT_CLOCK	; (426)

	ld b,3
KLOOP2:	djnz KLOOP2
	
	ret			; (10)
	
KEY_PRESSED:	
	;; 7 + 8 +(N-1)*13
	ld b, 0x1D		; (7)
KLOOP1:	djnz KLOOP1		; (13/8)
	
	ret			; (10)
	
	;; ----------------------------------------------------------------
	;; Flip 3x3 tile based on user-inputted coordinate (in COORD)
	;; ----------------------------------------------------------------
	;; On entry:
	;;     (COORD) - user-input coordinate
	;; On exit:
	;;
	;; Timing:
	;;     1,364 T states
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
	ld b,0x29		; (7)
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
	ld b, 0x4F
FI1_WAIT_2:
	djnz FI1_WAIT_2

	ret
	
	;; ----------------------------------------------------------------
	;; Flip 3x3 tile based on user-inputted coordinate (in COORD)
	;; ----------------------------------------------------------------
	;; On entry:
	;;     (COORD) - user-input coordinate
	;; On exit:
	;;
	;; Timing:
	;;     1,364 T states
	;; ----------------------------------------------------------------
FLIP_IT_2:
	;; Advance timer
	;; ld hl,(FRAME)		; (16)
	;; inc hl			; (6)
	;; ld (FRAME),hl		; (16)
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

	;; Wait until end of V. Sync
	ld b,0x11		; (7)
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
	ld de, DISPLAY+21*33+1	; (10)
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
	;;     1,285 T states
	;; ----------------------------------------------------------------
PRINT_TIME:
	;; Clear in-game timer
	ld de,DISPLAY+20*33+24	; (10)
	call BLANK_CLOCK	; (149)
	
	;; Print time to solve the grid
 	ld de,DISPLAY+21*33+17	; (10)
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
	;; Wait for no key
	;; ----------------------------------------------------------------
RESTART_GAME:
	;; Check for no key pressed
	call KSCAN		; (712 + 17)

	;; Check if HL = 0xFFFF, which indicates no key pressed
	inc hl			; (6) HL = 0 ?
	ld a,h			; (4)
	or l			; (4)

	jr z, RG_NO_KEY 	; (12/7)

	;;  No key pressed, so advance to next game step
	pop de			; (10)
	pop hl			; (10)
	ld bc, 0x000E		; (10)
	and a			; (4)
	sbc hl,bc		; (15)
	push hl			; (11)
	push de			; (11)

	;; Wait 1,283 - 821 - 10 = 452
	ld b, 0x23
RG_DUMMY:
	;; 
	djnz RG_DUMMY

	ret

RG_NO_KEY:
	ld b,0x28
RG_LOOP:	
	djnz RG_LOOP
	
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
	;;     458 T states
	;; ----------------------------------------------------------------
COL2ADDR:	
	ld hl,DISPLAY+3		; (10) Top, lefthand cormer of gameboard
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
	
	;; ----------------------------------------------------------------
	;; Translate key coordinate into character
	;; ----------------------------------------------------------------
	;; On entry:
	;; B - column id from KSCAN
	;; C - row id from KSCAN
	;;
	;; On exit:
	;; A - character of key pressed (or SPACE)
	;; bc, de, hl - corrupted
	;; ----------------------------------------------------------------
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

	
	;; ----------------------------------------------------------------
	;; Print contents of HL to address held in DE
	;; ----------------------------------------------------------------
PRINT_HL:
	ld   bc,-10000
        call ONEDIGIT
        ld   bc,-1000
        call ONEDIGIT
        ld   bc,-100
        call ONEDIGIT
	ld a,_FULLSTOP
	ld (de),a
	inc de
        ld   c,-10
        call ONEDIGIT
        ld   c,b
ONEDIGIT:
	ld   a,_0-1
DIVIDEME:
	inc  a
        add  hl,bc
        jr   c,DIVIDEME
        sbc  hl,bc
        ld   (de),a
        inc  de
        ret

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

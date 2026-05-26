	include "..\utilities\zx80_chars.asm"

_INV:	equ 0x80
_SP:	equ _SPACE
_WK:    equ _W
_SB:	equ _INV
_WP:	equ _WK + _SB
_BK:	equ _B
_BP:	equ _BK + _SB
_CR:	equ 0x76
	
	;; ZX80 (4K) ROM routines
PRPOS:		equ 0x06E0
PRINT:		equ 0x0720

	;; ZX80 (4K) System variables
VARS:		equ 0x4008
D_FILE:		equ 0x400C

	;; Program variables and working storage (overrides some system
	;; variables)
INITIAL: 	equ 0x4019
SQCHK:	 	equ 0x401C		
FRAMES:		equ 0x401E
SCANSQR:	equ 0x4020
POINTER:	equ 0x4022
LBASE:		equ POINTER
WKBOARD:	equ 0x4B3C 	; 4B3C--4B67: WKBOARD Working copy of
				; board
	
	;; 4C04		BEGIN
	org 0x4C04
	
	;; 4C04	4C15	SPRINT		Sub: Print string
	;;
	;; On entry:
	;;   TOS - Start of string (that is return address for CALL)
	;;
	;; On exit:
	;;   TOS - return address (immediately following string in
	;;         parent routine).
SPRINT:	pop hl			; Retrieve address of next character
	ld a,(hl)		; Retrieve it
	inc hl			; Advanced pointer
	push hl
	cp 0xFF			; Check for end of string
	ret z			; and return, if so

	;; Prepare to print (set print position)
	push af
	call PRPOS
	pop af

	;; Print character (using ROM routine)
	call PRINT

	;; Move on to next character
	jr SPRINT

	;; 4C15	4C96	PBOARD ***     	Sub: Print board (inc. board
	;; 		       		data). Entry point from BASIC.
PBOARD: call SPRINT
	
INIT_BRD:
	db _SP,  _1,  _2,  _3,  _4,  _5,  _6,  _7,  _8, _CR
	db  _1, _SP, _WP, _SP, _WP, _SP, _WP, _SP, _WP,  _1, _CR
	db  _2, _WP, _SP, _WP, _SP, _WP, _SP, _WP, _SP,  _2, _CR
	db  _3, _SP, _WP, _SP, _WP, _SP, _WP, _SP, _WP,  _3, _CR
	db  _4, _SB, _SP, _SB, _SP, _SB, _SP, _SB, _SP,  _4, _CR
	db  _5, _SP, _SB, _SP, _SB, _SP, _SB, _SP, _SB,  _5, _CR
	db  _6, _BP, _SP, _BP, _SP, _BP, _SP, _BP, _SP,  _6, _CR
	db  _7, _SP, _BP, _SP, _BP, _SP, _BP, _SP, _BP,  _7, _CR
	db  _8, _BP, _SP, _BP, _SP, _BP, _SP, _BP, _SP,  _8, _CR
	db _SP,  _1,  _2,  _3,  _4,  _5,  _6,  _7,  _8, _CR
	db _CR, _CR, _CR
	db _SP, _SP, _SP, _SP, _SP, _SP, _SP, _SP
	db _SP, _SP, _SP, _SP, _SP, _SP
	db 0xFF
;; INIT_BRD:
;; 	db _SP,  _1,  _2,  _3,  _4,  _5,  _6,  _7,  _8, _CR
;; 	db  _1, _SP, _SB, _SP, _SB, _SP, _SB, _SP, _WP,  _1, _CR
;; 	db  _2, _SB, _SP, _WP, _SP, _SB, _SP, _SB, _SP,  _2, _CR
;; 	db  _3, _SP, _SB, _SP, _SB, _SP, _SB, _SP, _SB,  _3, _CR
;; 	db  _4, _SB, _SP, _WP, _SP, _SB, _SP, _SB, _SP,  _4, _CR
;; 	db  _5, _SP, _SB, _SP, _BP, _SP, _SB, _SP, _SB,  _5, _CR
;; 	db  _6, _SB, _SP, _SB, _SP, _SB, _SP, _SB, _SP,  _6, _CR
;; 	db  _7, _SP, _SB, _SP, _SB, _SP, _SB, _SP, _SB,  _7, _CR
;; 	db  _8, _SB, _SP, _SB, _SP, _SB, _SP, _SB, _SP,  _8, _CR
;; 	db _SP,  _1,  _2,  _3,  _4,  _5,  _6,  _7,  _8, _CR
;; 	db _CR, _CR, _CR
;; 	db _SP, _SP, _SP, _SP, _SP, _SP, _SP, _SP
;; 	db _SP, _SP, _SP, _SP, _SP, _SP
;; 	db 0xFF

	ret
	
	;; 4C97    4C9A    TABLE	Table of move directions
TABLE:	db 0xFA, 0xFB, 0x06, 0x05 ; NE, NW, SW, SE

;; 4C9B	4CBB	ERROR		Sub: Print error message (entry point at
;; 				4CA7) 
IMOVE:	db _I, _L, _L, _E, _G, _A, _L, _SPACE
	db _M, _O, _V, _E

	;; Print error message
	;;
	;; On entry:
	;;   TOS - location of error code (printable character)
	;;
	;; On exit:
	;;   Returns to parent of calling routine
	
ERROR:	pop hl			; Retrieve error code, which immediately
	ld a,(hl)		; follows call to this routine

	;; Set DE to point to print location
	ld hl,(D_FILE)	
	ld de, 0x0070		
	add hl,de
	ex de,hl

	;; Set HL to point to message and BC to length of message
	ld hl,IMOVE
	ld bc, 0x000C
	ldir

	;; Print error code
	inc de
	ld (de),a

	;; Return to parent of calling routine
	ret
		

	;; 4CBC	4CE3	GAMEOVER	Sub: End-game sequence
	;; End-game sequence
	;;
	;; On entry, C contains 0xBC (inverted "W")
GAMEOVER:
	ld hl,WKBOARD
	ld b,0x2C

	;; Step over working copy of board, inverting characters
POSSIBLY:
	ld a,(hl)		; Retrieve character
	or _INV			; Clear King flag, so can check for 
	cp c			; normal white piece

	ret z			; Return if found white piece: game is
				; not over
	inc hl			; Next square
	djnz POSSIBLY

	;; Padding for ZX81 (8K ROM) version of code
	nop
	nop
	nop
	nop
	nop
	nop

	;; At this point, we know there are no computer pieces left
INVERT:	ld hl,(D_FILE)
	ld b, 0x6C
COVER:	inc hl
	ld a,(hl)

	;; Skip characters with code up to and including "9"
	cp _9
	jr nc, NOINV

	;; Skip for space characters
	and a
	jr z,NOINV

	;; Set inverse flag
	or _INV
	ld (hl),a

	;; Repeat if not end of board
NOINV:	djnz COVER

	pop hl			; Discard top-level return address

	ret
	
	
	;; 4CE4 START *** Game entry point from BASIC (w/ move in A$)

	;; 4CE4 4CF4 BOARDCOPY Copy interesting part of board to WKBOARD
BOARDCOPY:
	ld hl,(D_FILE)
	ld de,0x000D		; Advance to start of (active) board 
	add hl,de
	ld de,WKBOARD
	ld b,0x2C		; Length of active section of board
NSCOPY:	ldi
	inc hl			; Skip not-used squares
	
	djnz NSCOPY
	

	;; 4CF5--4CFA   NEXTLINE Not used on 4K ROM version (on 8K
	;; 		version, ensures the correct line is executed on
	;; 		return to BASIC).
NEXTLINE:
	nop			; On 8K ROM, can set next line for
	nop			; return to BASIC
	nop
	nop
	nop
	nop

	;; 4CFB--4D08 CLWIND Clear message window

	;; Clear message area
CLWIND:	ld hl,(D_FILE)
	ld de,0x0070
	add hl,de
	ld b,0x0E		; Width of message window

WIPEOUT:
	ld (hl),_SPACE
	inc hl
	djnz WIPEOUT

;; 4D09	4D67	MOVE		Intepret human player's move
MOVE:	ld hl,(VARS)
	call GET_STR_LEN
	nop			; Padding, to keep 
	;; inc hl
	;; ld a,(hl)

	;; Set A to FF for simple moves or moves-1 for complex
	;; moves. Minimum string length (for simple move) is
	;; 3. Multi-jump moves will be longer.
	dec a
	dec a
	dec a
	jr nz, NOTZERO
	cpl
NOTZERO:
	ld e,a
	;; inc hl
	;; inc hl
	ld a,(hl)
	ld b,a
	add a,a
	ld c,a
	add a,a
	add a,a
	inc hl
	push hl
	add a,b
	add a,c
	add a,(hl)
	rra

	jr c, NOERROR1

ERROR1:	pop hl
	call ERROR
	db _1

NOERROR1:
	add a,0x0E ; (WKBOARD & 0x00FF) - 0x2E
	ld l,a
	ld h,WKBOARD>>8
	ld c,(hl)

	;; Blank square
	ld b,0x80
LOOP:	ld (hl),b
	ex (sp),hl		; Put WKBOARD posn on stack and retrieve
	inc hl 			; string location
	ld (POINTER),hl
	ld a,(hl)		; Retrieve move command (A, B, C, or D)

	;; Find corresponding move in TABLE
	add a, 0x71
	ld l,a
	ld h, TABLE>>8

	;; Retrieve direction and check if valid
	ld d,(hl)
	pop hl
	ld a,b
	and d
	cpl
	and c
	cp 0x27
	jr nz, ERROR1

	;; Find next square
	ld a,l
	add a,d
	ld l,a

	;; Retrieve contents and check if blank
	ld a,(hl)
	cp b

	;; Skip forward if not
	jr nz,NEXT

	;; Check if single move, otherwise an error
	ld a,e
	inc a
	jr z,CONTINUE
	call ERROR
	db _2

	;; Counter in square to which we plan to move, so check is
	;; opponent
NEXT:	or b
	cp 0xBC
	jr z, NOERROR3
ERROR3:	call ERROR
	db _3

	;; Have found an opponents counter
NOERROR3:
	ld (hl),b		; Blank it

	;;  Move again (jumping counter)
	ld a,l
	add a,d
	ld l,a

	;; Check next square in blank. Otherwise can't jump
CONTENT:
	ld a,(hl)
	cp b
	jr nz, ERROR3

;; 4D68	4D7A	CONTINUE	Check if player's piece is promoted
CONTINUE:
	ld a,l
	cp 0x40
	jr nc, NOKING
	ld a,e
	inc a
	cp 0x02
	jr c, NOERROR4
	call ERROR
	db _4
NOERROR4:
	ld c,0x27
NOKING:	ld (hl),c		; Write counter to location
	push hl			; Put WKBOARD position back on stack
	ld hl,(POINTER)		; Retrieve string location

	;; Check if move is complete
	dec e
	ld a,e
	ex (sp),hl
	rla			; Effectively, does E contain 0xFF / 0xFE
	jr nc, LOOP		; Repeat if not

	pop hl
	ld c,0xBC
	call GAMEOVER
	
;; 4D8A	4DA8	BDSCAN		Check for possible computer moves

BOARDSCAN:			;4D8A
	ld (LBASE),SP		; Save base of stack
	ld bc,0x0000
	push bc
	ld hl,WKBOARD
NXTCHK:	ld a,(hl)
	or 0x80			; Do not worry about king
	cp _W+0x80		; Is it computer piece

	ld (SQCHK),hl		; Save current square
	jp z, EVALUATE

KPCHKNG:
	ld hl,(SQCHK)		; Restore current square
	inc l
	ld a,l
	cp 0x66			; Check if end of board
	jr nz, NXTCHK
	

	;; Simple random number generator, picks an integer 0, .... B-1
	;; 
CHOOSE:	ld a,(FRAMES)		;4DA9
REPEAT:	sub b
	jr nc,REPEAT
	add a,b
	pop bc
	ld b,c
	jr z, FIRSTOFF
NSQOFF:	inc sp
NEXTOFF:
	inc sp
	djnz NEXTOFF
	ld b,c
	dec a
	jr nz, NSQOFF

FIRSTOFF:
	pop hl
	ld h,WKBOARD>>8
	ld b,c
NEXTSTEP:
	dec sp
	pop de
	ld c,(hl)
	ld (hl),_SPACE+0x80
	ld a,l
	add a,e
	ld l,a
	ld a,(hl)
	cp 0x80
	jr z,SQUARE
	ld (hl),0x80
	ld a,l
	add a,e
	ld l,a
SQUARE:	ld (hl),c
	djnz NEXTSTEP

	ld sp,(LBASE)
	ld c,0xA7
	call GAMEOVER
	
;; 4DDE	4DF0	BDPRINT		Duplicate working board to screen (and
;; 				exit to BASIC)
BDPRINT:
	ld hl,(D_FILE)
	ld de,0x000D
	add hl,de
	ex de,hl
	ld hl,WKBOARD
	ld b,0x2C
LDI:	ldi
	inc de
	djnz LDI

	ret
	

	;; 4DF1	4E42	SQUAREVAL	Sub: Work out value of square
	;;                           +------------+
	;;                           |            |
	;;                           |  human's   |
	;;                           |   piece    |
	;;      PROTECTING           |            |
	;;                           |            |
	;;              +------------+------------+            +------------+
	;;              |            |                         |            |
	;;              | computer's |                         |  human's   |
	;;              |   piece    |                         |   piece    |
	;;              |            |                         |            |
	;;              |            |                         |            |
	;; +------------+------------+            +------------+------------+
	;; |   square   |                         |   square   |
	;; |   being    |                         |   being    |
	;; |   valued   |                         |   valued   |
	;; |     --     |                         |     --     |
	;; |     us     |                         |     us     |
	;; +------------+            +------------+------------+
	;;                           |            |
	;;                           |            |
	;;                           |   blank    |        IN DANGER
	;;                           |   square   |
	;;                           |            |
	;;                           +------------+
SQUAREVAL:
	;; Save registers
	push bc
	push de
	push hl

	ld b,0x00		; Flag to dictate what is checked
				; (0=protection; 1=danger)

STARTOFF:
	ld de, TABLE		; DE points to directions table

	;; Retrieve next direction into C
NOWT:	ld a,(de)
	ld c,a

	;; Check for end of table (fragile, as relies on knowing what
	;; follows table)
	sub 0x2E		
	jr z, EXIT

	inc e			; Advance pointer to next direction in
				; table (why not inc DE?), for
				; subsequent loop

	;; Restore location of square being evaluated from stack
	pop hl
	push hl
	ld h, WKBOARD>>8	; Retrieve high-byte of workspace-board
				; address

	;; Find next square in current direction (or next-but-one if
	;; checking for protection)
	ld a,l			; Requires accumulator
	add a,c			; Add direction offset
	bit 0,b			; Are we checking protection or danger
	jr nz, LA		; Skip if checking for danger
	add a,c			; Add direction offset again
LA:	ld l,a			; HL points to new square

	;; Work out if protected/ protecting
	ld a, %01111111		; 
	or c			; Set Bit 7, if direction is 'up' board
	and (hl)		; If player piece is normal and below or
				; king and anywhere, will be "B" (0x27);
				; otherwise, will be something else

	;; Move on if not an opportunity (B=0) / threat (B=1)
	cp _B
	jr nz, NOWT

	;; Reverse back one square and retrieve square's contents
	ld a,l			; 4E14
	sub c
	ld l,a
	ld a,(hl)

	;; Check for player piece
	scf
	rla			; 9-bit rotation left
	bit 0,b			;
	jr nz, LB
	cp 0x79			; If piece is a "B"
	jr nz, NOWT
	ld a,(hl)
	rla			; Carry set for normal/ reset for king


LB:	ccf
	ld a, 0x81
	rla
	rla
EXIT:	bit 0,b
	jr nz, LC

	inc b
	ld h,a
	ex (sp),hl

	push hl
	jr STARTOFF
LC:	ld d,a
	ld a,l
	sub c
	ld l,a
	ld a,(hl)
	cp 0x80
	jr z, NOWT
	ld a,d
	pop hl
	pop de
	
	sub d

	pop de
	pop bc

	ret
	
;; 4E43	4E9E	EVALUATE	Sub: Score possible computer move
EVALUATE:
	call SQUAREVAL
	add a, 0x80		; Normalise move score to 0x80
	ld (INITIAL),a
	
	ld de, TABLE
	ld c,l
NXTMRND:
	ld l,c
	ld h,WKBOARD>>8
NXTDIR:	ld a,(de)
	inc e
	bit 7,(hl)
	jr z,ANYDIR
	bit 7,a
	jr nz, NXTDIR
ANYDIR:	cp 0x2E
	jp z,KPCHKNG
	push bc

	ld b,a
	add a,c
	ld l,a
	ld a,(hl)
	ld h,b

	pop bc

	cp 0x80
TEST:	jr nz,WHAT
	ld (SCANSQR),de

	call SQUAREVAL

NEWPRI:	ld d,a
	ld a,(INITIAL)
	sub d
	ld d,a
	ld e,0x01
	ld l,c

	ex (sp),hl
	and a
	sbc hl,de
	jr z,EQUAL
	add hl,de
	ex (sp),hl
	jr nc, FORGETIT

	ld sp,(LBASE)
	ld b,0x00
	push de
	jr NEWITEM
EQUAL:	add hl,de
	ex (sp),hl
NEWITEM:
	inc b
	push hl
	inc sp
	inc sp
	ex (sp),hl
	dec sp
	dec sp
	ex (sp),hl

FORGETIT:
	ld de,(SCANSQR)
	jr NXTMRND
	
;; 4E9F	4ED1	WHAT		
WHAT:	ld (SCANSQR),de
	ld d,a
	and 0x7F
	cp 0x27
	jr z,FOUND
	ld de,(SCANSQR)
	jr NXTMRND
FOUND:	ld a,0x81
	rl d
	ccf
	rla
	rla
	ld d,a
	ld e,h
	ld a,l
	add a,h
	ld l,a
	ld h,WKBOARD>>8
	ld a,(hl)
	ld h,e
	cp 0x80
	jr z,JUMP
	ld de,(SCANSQR)
	jp NXTMRND
JUMP:	call SQUAREVAL
	sub d
	jr NEWPRI
	
	;;    4ED1	END

	;; Compute length and starto of contents ZX80 string array
	;;
	;; On entry:
	;;   HL - address of string variable
	;;
	;; On exit:
	;;   HL - address of string body
	;;   A - length of string
GET_STR_LEN:
	push bc			; Save registers
	push hl			; Save address of start of string
	
	ld b,0xFF		; Assume zero-length string
	ld a,_QUOTE		; A contains string terminator
				; (indicates end of string)
GSL_LOOP:
	inc b			;
	inc hl 			; Advance past variable name
	cp (hl)
	jr nz, GSL_LOOP

	ld a,b			; Move length to A
	pop hl			; Set HL to start of string body
	inc hl

	pop bc			; Restore BC

	ret
END:	

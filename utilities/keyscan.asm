	;; ----------------------------------------------------------------
	;; ZX80 keyboard scanning routines, copied from 4K ROM as version
	;; there is in-line and hence not CALL-able.
	;;
	;; There are two routines:
	;;   KSCAN - reads keyboard matrix and puts 'coordinates' of any
	;;     key being pressed into HL
	;;   FINDCHR - converts coordinates (from KSCAN) into ZX80 char
	;;     (though expects them to be in BC, not HL).
	;; 
	;; On ZX80, keyboard is read via Port 0xFE, using a 16-bit IN
	;; operation with upper byte set to indicated which half-row to
	;; read. A zero indicates a key is being pressed.
	;; 
	;; Bit        0  1  2  3  4 |  4  3  2  1  0
	;;            -  -  -  -  -    -  -  -  -  -
	;; $F7FE =    1  2  3  4  5    6  7  8  9  0   = $EFFE
	;; $FBFE =    Q  W  E  R  T    Y  U  I  O  P   = $DFFE
	;; $FDFE =    A  S  D  F  G    H  J  K  L N/L  = $BFFE
	;; $FEFE =   SH  Z  X  C  V    B  N  M  . SPC  = $7FFE
	;; ----------------------------------------------------------------
	include "zx80_chars.asm"

KTABLE:	equ 0x006C		; Location of key-code table in ROM
	
	;; ----------------------------------------------------------------
	;; Read keyboard and return coordinates of a key press. Only
	;; accepts a single keypress (or a shifted keypress)
	;;
	;; On entry:
	;;
	;; One exit:
	;;   (See keymap above for explanation)
	;;   l - half-row id of row containing key press
	;;   h - column id of key pressed, shifted left, wit Bit 0
	;;       indicating Shift status
	;; or:
	;;   hl=0xFFFF, if no key pressed
	;;
	;;   af, bc, de - always corrupted
	;; ----------------------------------------------------------------
KSCAN:	ld hl, 0xFFFF		; (10) Will hold coordinate of key being
                                ;      pressed. 0xFFFF means no key
	ld bc, 0xFEFE		; (10) Start at bottom-left, half row
	                        ;      B = %11111110
	in a,(c)		; (12) 
	or 0x01			; (7)  Ignore shift (dealt with later)

	;; 82*7 + 77 T-states
KLOOP:	or 0xE0			; (7) Only interested in low five bits
	ld d,a			; (4) Store for later

	;; Work out row id (if key pressed)
	cpl			; (4) 
	cp 0x01			; (7) Set carry, if A is zero (no key)
	sbc a,a			; (4) A = 00 (key pressed)/ FF (no key)
	or b			; (4) A = row (key pressed) FF (no key)
	and l			; (4) Add row id in L (if key pressed)
	ld l,a			; (4) L contains updated row-id info

	;; Update column id
	ld a,h			; (4) Retrieve current column-id info
	and d			; (4) Apply info from current half-row
	ld h,a			; (4) Store update column-id info

	;;  Check if more half-rows to read
LABEL:	rlc b			; (8)  Advance to next half-row
	in a,(c)		; (12) Read key presses
	jr c, KLOOP		; (12/7) Carry reset if have checked
	                        ;      All eight half-rows
	;; At this point, A contains result of reading bottom-left row
	;; (again)
	rra			; (4) Move 'Shift key' into Carry
	rl h			; (8) Store as Bit 0 of H

	ret			; (10)
	
	;; ----------------------------------------------------------------
	;; Translate key coordinate into character
	;; ----------------------------------------------------------------
	;; On entry:
	;;   B - column id from KSCAN
	;;   C - row id from KSCAN
	;;
	;; On exit:
	;;   a - character code of key pressed (or SPACE)
	;;   bc, de, hl - corrupted
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
	ld hl,KTABLE-1		; (10)
 	ld d,0x00		; (7)
	ld e,a			; (4)
	add hl,de		; (11)

	ld a, (hl)		; (7)
	
	ret			; (10)

	;; If more than one key is pressed (not including Shift) then ignore.
F2KEYS:	ld a,_SPACE		; (4) Load space char
	
	ret	  		; (10)


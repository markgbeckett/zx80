	;;
	;; Amazing Active Display, by Ron Bissell and Ken Macdonald
	;; Disassembled from a listing in Tim Hartnell, "Making The Most
	;; of Your ZX80", Computer Publications (1980).
	;;
	;; The original listing has been updated slightly, to address
	;; potential errors, including those noted in Syntax ZX80
	;; magazine, Vol. 2, N. 11, Page 2 -- notably:
	;; 
	;;   "In line 30, defining M$, change the 61st and 62nd hex digits
	;; (DE) to FE. Change the 75th and 76th digits (38) to
	;; (20). Change the 111th and 112th (EC) to FC.""
	;;
	;; The second change (38h to 20h is for NTSC television signals.
	;;
	;; I have also corrected the displacement for the final `jr`
	;; statement.

	;; 4K ROM routines and system variables required for the program
DISP_2:	equ 0x01AD
CL_EOD:	equ 0x05C2
UNSTACK_Z: equ 0x06E0
D_FILE:	equ 0x400C
FRAMES:	equ 0x401E
	
	org 0x4376		; Code is relocatable

START:	call UNSTACK_Z		; DE' = DF_EA; BC' = SPOSN
	call CL_EOD		; Clear upper display (inc EXX)
	ld bc, 0x0120		; Set SPOSN to row 22, col 1
	exx			; Switch out screen values
	call CL_EOD		; Clear upper display (EXX)

	jr WAIT			; Skip outputting frame on first pass

LOOP:	call DISP_2		; Output part of display

WAIT:	ld b,0x08		; Wait 106 T states
WLOOP:	djnz WLOOP

	;; Increment counter (when high byte overflows to zero, done)
	ld hl,(FRAMES)		; Used to pass wait counter from BASIC
	inc hl
	ld (FRAMES),hl

	;; Check if done
	ld a,h			; (4)
	cp 0x00			; (7) Original code has sbc a,0x00 here
	ret z			; (11/5)

	;; ??? Possibly, 6 T-state timing adjustment
	inc hl			; (6)

	in a,(0xFE)		; Turn on V. Sync generator

	ld a,0x38		; 56 scan lines

	ld (0x4023),a		; Effectively, IY + 0x23

	;; Wait for 1,432 T states
	ld b,0x5E		
WLOOP2:	djnz WLOOP2

	;; Turn off V. sync
	out (0xFE),a

	ld a, 0xEC		; For R register. Time left to generate
				; first scan line of top border
				; (Potentially 0xE9 is better)
	ld b, 0x19		; 24+1 end-of-line characters

	ld hl,(D_FILE)		; Point to start of display file
	set 7,h			; Add 0x8000 to D_FILE address

	call DISP_2		; Produce top border

	ld a,0xF3	        ; Timing coutner for first scan line of
				; bottom border
	inc b			; Increment row counter, B previously zero
	dec hl			; Point to end of display file (final HALT)

	dec (iy+0x23)		; Decrement blank-line counter

	jr LOOP			; Original is LOOP-1, which is half-way throug
          			; jr +03 instruction

	;; 4K ROM routines
PRPOS:	equ 0x06E0		
PRINT:	equ 0x0720
VARS:	equ 0x4008
FRAMES:	equ 16414
	

	;; Main program
	org 0x402B 		; REM statement at beginning of BASIC
	
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

SHPRINT:
	push af
	
	xor a
	call APRINT

	pop af

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
	
ICHECK:	ld hl,(FRAMES)
	ld bc, 0x0AAA
I_LOOP:	dec bc
	ld a,b
	or c
	jr nz, I_LOOP

	ld a,(FRAMES)
	cp l

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

	ld a,(hl)		; Print space plus contents of ADDRESS
	call SHPRINT

	ld a,(hl)
	bit 6,a			; Check if contents is printable character
	jr nz, NOPRINT		; If not, skip forward

	xor a			; Print space
	call APRINT

	ld a,(hl)		; Print character code
	call APRINT

NOPRINT:
	ld a, 0x75		; Print newline
	inc a
	call APRINT

	inc hl			; Advance to next address
	ld (ADDRESS),hl		; and save it

	djnz NXTAD		; Repeat, unless done

DONE:
	rst 0x08		; Return to BASIC
	db 0x00

INITIALISE:
	ld hl, (ADDRESS)
	ld (BEGIN),hl
	ld (LIMIT),hl
	ret

PRINTSTATS:
	ld hl, MDF_END
	call PRINTSTRING
	
	ld hl,(0x4010)
	ld a,h			; Print address
	call HPRINT

	ld a,l
	call HPRINT

	ld a,0x75
	inc a
	call APRINT
	
	ld hl, MBEGIN
	call PRINTSTRING
	
	ld hl,(BEGIN)

	ld a,h			; Print address
	call HPRINT

	ld a,l
	call HPRINT

	ld a,0x75
	inc a
	call APRINT
	
	ld hl, MLIMIT
	call PRINTSTRING
	
	ld hl,(LIMIT)
	ld a,h			; Print address
	call HPRINT

	ld a,l
	call HPRINT

	ld a,0x75
	inc a
	call APRINT
	
	ret

PRINTSTRING:
	ld a,(hl)
	
	cp 0xFF
	ret z

	call APRINT
	inc hl
	
	jr PRINTSTRING

END:	

MDF_END:  db 41, 43, 18, 42, 51, 41, 00, 255
MBEGIN:	  db 39, 42, 44, 46, 51, 00, 00, 255
MLIMIT:	  db 49, 46, 50, 46, 57, 00, 00, 255

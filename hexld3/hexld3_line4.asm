include "hexld3_line3_symbols.asm"

BLK_SIZE: equ 0x100		; Number of 16-bit words in a block

	org 0x4337

UADDR:	ld bc, 0x0000

PRADDR:	ld hl,(ADDRESS)

PRHL:	ld a,h
	call HPRINT

	ld a,l
	call HPRINT

	xor a
	call APRINT

	ret
	
BREAKPT:
	push iy
	push ix

	ex af, af'
	push af
	ex af,af'
	exx
	push bc
	push de
	push hl
	exx

	call REGS

	ld a, 0x75
	inc a
	call APRINT

	pop hl
	pop de
	pop bc
	pop af

	call REGS

	ld a, 0x75
	inc a
	call APRINT

	pop hl
	call PRHL

	pop hl
	call PRHL

	pop hl
	dec hl
	dec hl
	dec hl
	call PRHL

	call ICHECK

	ld a, 41

	jr z, BCI
	inc a

BCI:	call APRINT

	jp DONE

	;; Initialise one or more BASIC arrays to hold object-program
	;; for storing on tape. Arrays will be named A(), B(), ... All
	;; but the last array will contain 256 cells (512 bytes)
	;; 
INIT_ARRAY:
	;; Work out size of code block in bytes
	ld hl,(LIMIT)		; End of user code
	ld de,(BEGIN)		; Start of user code
	and a			; Clear carry
	sbc hl, de		; Compute length

	;; Return if zero, or otherwise will store a block of 0x10000
	;; bytes, which is incorrect.
	ret z

	;; Store address of next byte of code to be saved for later
	ld (ADD2),de		

	;; Work out how many 16-bit words are needed to hold object code
	;; (that is, divide size in bytes by 2 and round up)
	inc hl			; Ensures round up
	srl h			; Divide by two
	rr l

	; At this point, HL contains number of words needed to store the
	; data. 

	;; Initialise array name
	ld a,_A	| 0x80		; Name of first array (with array
				; indicator set)

	push af			; Save current array name

IA_LOOP:	
	ld bc, BLK_SIZE		; Assume will need maximum array size

	;; Check if last array and adjust size, if so
	ld a,h
	and a
	jr nz, IA_CREATE

	;; Update block size to be HL, since will fit in single array
	ld b,h			
	ld c,l

	;; At this point, BC contains array size (in words)
IA_CREATE:
	and a			; Update length of remainder of block
	sbc hl,bc

	push hl			; Save length of remainder of block and
	push bc			; and current array size (words)
	
	dec bc			; DIM expects maximum index, which is
				; one fewer than array size
	call DIM		; On return, HL stores address of next
				; byte after array
	pop de			; Retrieve array size and convert to
				; bytes (including two-byte header)
	ex de,hl		; Move into HL (preserving end of array
				; in DE)

	;; Compute 2*(array_length+1), which is size of array structure
	;; in memory
	inc hl
	add hl, hl

	push hl			; Store array-structure size

	ex de,hl		; Swap and end array structure into HL
				; and length of array structure into DE

	;; Find start of aray in memory
	and a			; Set HL to points to start of array
	sbc hl,de		; structure

	pop bc		     	; Retrieve array-structure size (bytes)
	dec bc			; Convert to array size (bytes) by
	dec bc			; deducting space for header
	
	pop de			; Temporarily retrieve size of remainder
	pop af			; of code (so can get array name)

	;; Write array name
	ld (hl),a

	;; Update array name and put back on stack (along with count of
	;; remaining code)
	inc a
	push af
	push de			; Store block count and final-block size

	;; Advance to start of array body
	inc hl
	inc hl			; Advance HL to start of array body

	;; ... and move to DE (destination) ready for block copy
	ex de,hl		; and move into DE

	ld hl,(ADD2)		; Retrieve current position in array
	ldir			; and copy block of code (BC contains
				; length, as calculated earlier)
	ld (ADD2),hl		; Store new code pointer
	
	;; Check if done (length of remaining code is zero)
	pop hl			; Retrieve length of remainder of code

IA_NEXT:
	ld a,h
	or l
	jr nz, IA_LOOP		; Repeat, if not

	;; Done
IA_DONE:
	pop af			; Balance stack
	scf			; Indicates success

	ret

	;; Copy object code from BASIC arrays in which it is stored for
	;; saving to tape to its executable location in memory
	;; On entry:
	;;   - BASIC arrays have been populated using STORE_NEW
	;;   - BEGIN = start of object code block
	;;   - ADD2 = length of object code block
RESTORE_CODE:
	;; Work out size of code block in bytes
	ld hl,(LIMIT)		; End of user code
	ld de,(BEGIN)		; Start of user code
	and a			; Clear carry
	sbc hl, de		; Compute length

	;; Return if zero, or otherwise will store a block of 0x10000
	;; bytes, which is incorrect.
	ret z

	;; Store address of next byte of code to be restored for later
	ld (ADD2),de		

	;; Work out how many 16-bit words are needed to hold object code
	;; (that is, divide size in bytes by 2 and round up)
	inc hl			; Ensures round up
	srl h			; Divide by two
	rr l

	;; Point DE to start of first array
	ld de,(VARS)

RC_LOOP:
	;; Advance to body of array
	inc de
	inc de

	;; Work out block size
	ld bc, BLK_SIZE

	;; Check if last array and adjust size, if so
	ld a,h
	and a
	jr nz, RC_READ

	;; Update block size to be HL, since will fit in single array
	ld b,h			
	ld c,l

	;; At this point, BC contains array size (in words)
RC_READ:
	and a			; Update length of remainder of block
	sbc hl,bc
	
	push hl			; Save code remainder

	;; Convert block length to bytes
	ld h,b
	ld l,c
	add hl,hl
	ld b,h
	ld c,l
	
	ld hl,(ADD2)		; Retrieve destination for next byte

	ex de,hl		; Prep for block copy

	ldir

	ex de,hl
	ld (ADD2),hl

	pop hl

	ld a,h
	or l
	jr nz, RC_LOOP

	;; Done
	scf

	ret

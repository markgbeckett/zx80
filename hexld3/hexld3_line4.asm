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
	ld hl,(LIMIT)
	ld de,(BEGIN)

	and a			; Reset Carry and zero A (needed later)
	sbc hl, de

	ld (ADD2),hl		; Store for later

	;; Check for zero-length code block
	ld a,h
	or l
	ret z
	
	;; Work out how many 16-bit words needed to hold object code
	;; (that is, divide size in bytes by 2 and round up)
	srl h
	rr l
	jr nc, IA_SKIP 		; Carry set if need to round up
	inc hl
IA_SKIP:
	; At this point, HL contains number of words needed to store the
	; data. This can be regarded as H arrays of 256 elements
	; (maximum possible) and one array of length L elements

	;; Create arrays
	ld a,_A			; Name of first array

	push af			; Save current array name
IA_LOOP:	
	ld bc, BLK_SIZE		; Assume maximum array size

	;; Check if last array and adjust size, if so
	ld a,h
	and a
	jr nz, IA_CREATE

	;; Update block size to be L
	ld b,h			; A is always zero
	ld c,l

	;; At this point, BC contains array size
IA_CREATE:
	and a			; Update block size
	sbc hl,bc
	push hl			; Save new block count and size

	push bc			; Save array size
	dec bc			; DIM expects maximum index, which is
				; one fewer than array size
	call DIM		; On return, HL stores address of next
				; byte after array
	pop de			; Retrieve array size and convert to
				; bytes (inlcuding two-byte header)
	ex de,hl		; Move into HL (preserving end of array)
	inc hl
	add hl, hl
	ex de,hl

	;; At this point, DE contains length of array structure and HL
	;; contains address immediately after array
	and a			; Set HL to points to start of array
	sbc hl,de		; structure

	pop de			; Retrieve block count and final-block size
	pop af			; Retrieve array name

	;; Write array name
	xor 0x80
	ld (hl),a
	xor 0x80

	;; Update array name
	inc a
	push af
	
	ex de,hl		; Retrieve block count and final-block
				; size into HL

	;; Check if more blocks
IA_NEXT:
	ld a,h
	or l
	jr nz, IA_LOOP

	;; Done
IA_DONE:
	pop af			; Balance stack
	scf			; Indicates success

	ret

	;; Reserve one or more blocks of 512 bytes in user variables, as
	;; BASIC integer arrays A(), B(), ...
	;; 
	;; On entry:
	;;   B - number of blocks to create
	;;
	;; On exit:
	;;   Carry - Set = success
RESV:	ld a,_A			; Set array name
        push af			; Save array name
RESBLK:	push bc			; Save block count

	ld bc, BLK_SIZE-1	; Max index for DIM
	call DIM

	;; Scan back to start of array
	ld de,2*BLK_SIZE+2
	and a
	sbc hl,de

	pop bc
	pop af

	xor $80			; Apply mask
	ld (hl),a	
	xor $80			; Revert mask
	
	;; Update array name
	inc a 			
	push af

	djnz RESBLK

	;; Balance stack and confirm success
RESDON:	pop af
	scf

	ret

	;; Write object code to sequence of BASIC arrays ready to SAVE
	;; to tape
	;;
	;; On entry:
	;;   - BASIC arrays have been created using RSEV
	;;   - BEGIN = start of object code block
	;;   - ADD2 = length of object code block
STORE_NEW:
	ld a,(ADD2+1)		; Retrieve high byte of length

	;; Divide by two and round up to give number of 512-byte blocks
	;; to be written
	srl a
	inc a
	
	;; Initialise transfer
	ld de,(VARS)		; Point to start of first array
	ld hl,(BEGIN)		; Point to start of object code

	;; Transfer object code into arrays, 512 bytes at a time
SN_BLK:	ld bc, 0x0200
	inc de			; Advance past BASIC array header
	inc de
	ldir

	;; Check if done
	dec a
	jr nz, SN_BLK

	ret

	;; Copy object code from BASIC arrays in which it is stored for
	;; saving to tape to its executable location in memory
	;; On entry:
	;;   - BASIC arrays have been populated using STORE_NEW
	;;   - BEGIN = start of object code block
	;;   - ADD2 = length of object code block
RETRIEVE_NEW:
	ld a,(ADD2+1)		; Retrieve high byte of length

	;; Divide by two and round up to give number of 512-byte blocks
	;; to be read from
	srl a
	inc a
	
	;; Initialise transfer
	ld hl,(VARS)		; Point to start of first array
	ld de,(BEGIN)		; Point to start of object code

	;; Transfer object code from arrays, 512 bytes at a time
RN_BLK:	ld bc, 0x0200
	inc hl			; Advance past BASIC array header
	inc hl
	ldir

	;; Check if done
	dec a
	jr nz, RN_BLK

	ret

	;; Check if sufficient space to create BASIC arrays without overriding the object code.
CHK_SPC:
	

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
	;; machine code for storing on tape
	;; 
INIT_ARRAY:
	call ARRAY		; Retrieve length of code in words (into HL)

	;; HL contains number of words
	ld b,h			; B contains high byte of code length
	ld a,l		
	and a
	jr z, IR_SKIP		; Check if multiple of 256
	inc b			; Need to round up number of blocks
				; (unless is multiple of 256)

	call RESV		; Make reservation

	ret
	
IR_SKIP:

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

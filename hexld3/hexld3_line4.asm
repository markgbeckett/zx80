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

INIT_ARRAY:
	call ARRAY		; Retrieve length of code in words

	;; HL contains number of words
	ld b,h
	ld a,l			; Check if multiple of 256
	and a
	jr z, IR_SKIP
	inc b

	call RESV

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

	
	

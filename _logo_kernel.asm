;
; ABB logo code
;

logo_draw
    sta WSYNC
    sleep 13                    ; 13     (13)
	lda #1                      ; 2     (15)
	sta VDELP0                  ; 3     (18)
	sta VDELP1                  ; 3     (21)
	lda #$A6                    ; 2     (23)
    sta COLUPF                  ; 3     (26)
    sleep 10                    ; 10    (36)
	sta RESP0                   ; 3     (39)
	sta RESP1                   ; 3     (42)
	lda #$20                    ; 2     (44)
	sta HMP1                    ; 2     (47)
    lda #$10                    ; 2     (49)
    sta HMP0                    ; 3     (52)
	lda #$33                    ; 2     (54)
	sta NUSIZ0                  ; 3     (57)
	STA NUSIZ1                  ; 3     (60)
	sta WSYNC
	sta HMOVE

    ; Blank Screen and Set Playfield

    ldy #logo_height-1
    lda logo_colors,y
    sta COLUP0
    sta COLUP1
LogoLoop
    sta WSYNC                       ; 3     (0)
    SLEEP 3
    lda logo_0,y                   ; 4     (7)
    sta GRP0                        ; 3     (10) 0 -> [GRP0]
    lda logo_1,y                   ; 4     (14)
    sta GRP1                        ; 3     (17) 1 -> [GRP1] ; 0 -> GRP0
    lda logo_2,y                   ; 4     (21)
    sta GRP0                        ; 3     (24*) 2 -> [GRP0] ; 1 -> GRP1
    ldx logo_4,y                   ; 4     (28) 4 -> X
	SLEEP 7
    lda logo_3,y                   ; 4     (39) 3 -> A
    sta GRP1                        ; 3     (45) 3 -> [GRP1] ; 2 -> GRP0
    lda #0                       ; 3     (42) 5 -> Y
    stx GRP0                        ; 3     (48) 4 -> [GRP0] ; 3 -> GRP1
    sta GRP1                        ; 3     (51) 5 -> [GRP1] ; 4 -> GRP0
    sta GRP0                        ; 3     (54) 5 -> GRP1
    lda logo_colors-1,y               ; 4     (61)
    sta COLUP0                      ; 3     (64)
    sta COLUP1                      ; 3     (67)
    dey                             ; 2     (69)
    bpl LogoLoop                    ; 3     (72)
logo_kernel_size = * - LogoLoop
    
    ldy #0
    sty GRP0
    sty GRP1
    sty GRP0
    sty GRP1
	sta VDELP0                  
	sta VDELP1                  
;	ldx #40
    ldx #((96 - (logo_height/2))-1)
LogoGap
    sta WSYNC
	dex                         ; 2     (2)
	bne LogoGap                 ; 2     (4)

	jmp logo_draw_return

   if >. != >[.+(logo_height)]
      align 256
   endif

; Paste image information here

logo_0
logo_5
logo_1
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000100
	BYTE %00001010
	BYTE %00001010
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000011
	BYTE %00000011
	BYTE %00000011
	BYTE %00000011
	BYTE %00000011
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
logo_height = . - logo_0

   if >. != >[.+(logo_height)]
      align 256
   endif

logo_2
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %01101100
	BYTE %10000100
	BYTE %01100110
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %11000000
	BYTE %11000000
	BYTE %11100000
	BYTE %11100000
	BYTE %11100000
	BYTE %11100000
	BYTE %11110000
	BYTE %11110000
	BYTE %11110000
	BYTE %11111000
	BYTE %11111000
	BYTE %11111000
	BYTE %01111000
	BYTE %01111100
	BYTE %01111100
	BYTE %00111100
	BYTE %00111100
	BYTE %00111110
	BYTE %00111110
	BYTE %00111110
	BYTE %00011111
	BYTE %00011111
	BYTE %00011111
	BYTE %00001111
	BYTE %00001111
	BYTE %00001111
	BYTE %00000111
	BYTE %00000111
	BYTE %00000111
	BYTE %00000111
	BYTE %00000011
	BYTE %00000011
	BYTE %00000011
	BYTE %00000011
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000001
	BYTE %00000011
	BYTE %00000011
	BYTE %00000011
	BYTE %10000111
	BYTE %10000111
	BYTE %11001111
	BYTE %11111110
	BYTE %11111110
	BYTE %11111110
	BYTE %11111100
	BYTE %01111100
	BYTE %01111000
	BYTE %00010000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000


   if >. != >[.+(logo_height)]
      align 256
   endif

logo_3
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00101011
	BYTE %00101001
	BYTE %00100001
	BYTE %00101000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000011
	BYTE %00000111
	BYTE %00000111
	BYTE %00001111
	BYTE %00001111
	BYTE %00001111
	BYTE %00001111
	BYTE %00001110
	BYTE %00011100
	BYTE %00011100
	BYTE %00011000
	BYTE %00011000
	BYTE %00011000
	BYTE %00011000
	BYTE %00011000
	BYTE %00111000
	BYTE %00110000
	BYTE %00110000
	BYTE %00110000
	BYTE %00110000
	BYTE %00110000
	BYTE %00110000
	BYTE %00110000
	BYTE %11100000
	BYTE %11100000
	BYTE %11100000
	BYTE %11100000
	BYTE %11100000
	BYTE %11100000
	BYTE %11100000
	BYTE %11000000
	BYTE %11000000
	BYTE %11000000
	BYTE %11000000
	BYTE %11000000
	BYTE %11000000
	BYTE %11000000
	BYTE %11000000
	BYTE %10000000
	BYTE %10000000
	BYTE %10000000
	BYTE %10000000
	BYTE %10000000
	BYTE %10000000
	BYTE %10000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000


   if >. != >[.+(logo_height)]
      align 256
   endif

logo_4
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00100000
	BYTE %00111000
	BYTE %10111000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %11000000
	BYTE %11100000
	BYTE %11100000
	BYTE %11110000
	BYTE %11110000
	BYTE %11110000
	BYTE %00110000
	BYTE %00010000
	BYTE %00010000
	BYTE %00010000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000
	BYTE %00000000


   if >. != >[.+(logo_height)]
      align 256
   endif

logo_colors
   .byte $0E
   .byte $0E
   .byte $0E
   .byte $0E
   .byte $0E
   .byte $0E
   .byte $0E
   .byte $E8
   .byte $E4
   .byte $E0
   .byte $DE
   .byte $DA
   .byte $D6
   .byte $D2
   .byte $D0
   .byte $CC
   .byte $C8
   .byte $C4
   .byte $C2
   .byte $BE
   .byte $BA
   .byte $B6
   .byte $B2
   .byte $B0
   .byte $AC
   .byte $A8
   .byte $A4
   .byte $A2
   .byte $9E
   .byte $9A
   .byte $96
   .byte $94
   .byte $90
   .byte $8C
   .byte $88
   .byte $86
   .byte $82
   .byte $7E
   .byte $7A
   .byte $76
   .byte $74
   .byte $70
   .byte $6C
   .byte $68
   .byte $66
   .byte $62
   .byte $5E
   .byte $5A
   .byte $58
   .byte $54
   .byte $50
   .byte $4C
   .byte $4A
   .byte $46
   .byte $42
   .byte $3E
   .byte $3A
   .byte $38
   .byte $34
   .byte $30
   .byte $2C
   .byte $2A
   .byte $26
   .byte $22
   .byte $1E
   .byte $1C
   .byte $18
   .byte $14
   .byte $10
   .byte $0E
   .byte $0E
   .byte $0C
   .byte $0C
   .byte $0E
   .byte $0E

    

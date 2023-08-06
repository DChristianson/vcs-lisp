;
; ABB logo draw
; Cribbed from Atari Background Builder
; SPACE: we can recover a lot of space here
;

logo_draw
	lda #68
	jsr sub_respxx
    sta WSYNC
	sta HMOVE
	ldx #1                      ;2   2  
	stx VDELP0                  ;3   5  
	stx VDELP1                  ;3   8
	stx NUSIZ0                  ;3  11
	dex                         ;2  13; get to zero
	stx NUSIZ1                  ;3  16
	lda #$10                    ;2  18
	sta WSYNC                   ;-----
	stx HMP0                    ;3   3
	sta HMP1                    ;3   6
	sta HMOVE                   ;3   9

    ldx #LOGO_HEIGHT-1
	ldy clock
_logo_loop
    sta WSYNC                   ;3   --
    sty COLUP0                  ;3    3
    sty COLUP1                  ;3    6
    lda LOGO_0,x                ;4   10
    sta GRP0                    ;3   13 
    lda LOGO_1,x                ;4   17
    sta GRP1                    ;3   20
    lda LOGO_2,x                ;4   24
    sta GRP0                    ;3   27
	iny                         ;2   29
	SLEEP 16                    ;16  45
	sta GRP1                    ;3   48	
    dex                         ;2   50
    bpl _logo_loop              ;2   52

	jmp logo_draw_return


; Paste image information here

LOGO_0
    byte $0,$46,$a8,$a8,$a6,$0,$0,$78,$7c,$3c,$3e,$1e,$1f,$f,$f,$7,$7,$3,$1,$1,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$20,$30,$38,$1f,$f,$7; 40
LOGO_HEIGHT = . - LOGO_0
LOGO_1
    byte $0,$c5,$45,$44,$65,$0,$0,$0,$0,$0,$0,$0,$1,$1,$81,$83,$c3,$c3,$e3,$e7,$fe,$fe,$7e,$7e,$3c,$3c,$3c,$1c,$18,$18,$18,$38,$30,$70,$70,$e0,$c0,$c0,$80; 40
LOGO_2
    byte $0,$64,$24,$27,$37,$0,$0,$3c,$7e,$72,$e0,$c0,$c0,$c0,$80,$80,$80,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0,$0; 40
    

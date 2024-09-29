   ; Graphics page 0 - function symbols
   ; Graphics page 1 - var symbols
   ; Graphics page 2 - misc menus

    align 256

SYMBOL_GRAPHICS_P0
SYMBOL_GRAPHICS_TERM
    byte $0,$0,$0,$50,$0,$20,$0,$0; 8
SYMBOL_GRAPHICS_MULT
    byte $0,$88,$d8,$70,$20,$70,$d8,$88; 8
SYMBOL_GRAPHICS_ADD
    byte $0,$20,$20,$20,$f8,$20,$20,$20; 8
SYMBOL_GRAPHICS_SUB
    byte $0,$0,$0,$0,$f8,$0,$0,$0; 8
SYMBOL_GRAPHICS_DIV
    byte $0,$80,$c0,$e0,$70,$38,$18,$8; 8
SYMBOL_GRAPHICS_MOD
    byte $0,$18,$98,$48,$20,$90,$c8,$c0; 8
SYMBOL_GRAPHICS_EQUALS
    byte $0,$0,$0,$f8,$0,$f8,$0,$0; 8
SYMBOL_GRAPHICS_GT
    byte $0,$c0,$60,$30,$18,$30,$60,$c0; 8
SYMBOL_GRAPHICS_LT
    byte $0,$18,$30,$60,$c0,$60,$30,$18; 8
SYMBOL_GRAPHICS_AND
    byte $0,$20,$f0,$80,$60,$80,$f0,$20; 8
SYMBOL_GRAPHICS_OR
    byte $0,$20,$20,$20,$20,$20,$20,$20; 8
SYMBOL_GRAPHICS_NOT
    byte $0,$20,$20,$0,$20,$20,$20,$20; 8
SYMBOL_GRAPHICS_CONS
    byte $0,$f8,$20,$a8,$20,$a8,$20,$f8; 8
SYMBOL_GRAPHICS_CAR
    byte $0,$f8,$e0,$a8,$e0,$a8,$e0,$f8; 8
SYMBOL_GRAPHICS_CDR
    byte $0,$f8,$38,$a8,$38,$a8,$38,$f8; 8
SYMBOL_F0 = $0f
SYMBOL_GRAPHICS_F0
    byte $0,$88,$98,$50,$30,$20,$20,$60; 8
SYMBOL_GRAPHICS_F1
    byte $0,$f8,$88,$40,$40,$20,$20,$10; 8
SYMBOL_GRAPHICS_F2
    byte $0,$e0,$20,$20,$70,$20,$20,$38; 8
SYMBOL_BEEP = $12
SYMBOL_GRAPHICS_BEEP
    byte $0,$c0,$d8,$d8,$58,$48,$48,$78; 8
SYMBOL_GRAPHICS_STACK_FN
    byte $0,$f8,$70,$20,$0,$50,$d8,$50; 8
SYMBOL_GRAPHICS_PLAYER_0_FN
    byte $0,$b8,$a8,$b8,$c0,$a0,$a0,$e0; 8
SYMBOL_GRAPHICS_PLAYER_1_FN
    byte $0,$b8,$90,$b0,$c0,$a0,$a0,$e0; 8
SYMBOL_GRAPHICS_BALL_FN
    byte $0,$0,$20,$70,$0,$70,$20,$0; 8
SYMBOL_GRAPHICS_J0
    byte $0,$f8,$f8,$f8,$70,$20,$20,$20; 8
SYMBOL_GRAPHICS_J1
    byte $0,$f8,$88,$88,$70,$20,$20,$20; 8
SYMBOL_GRAPHICS_APPLY_FN ;
    byte $0,$70,$88,$88,$68,$88,$70,$0; 8
SYMBOL_GRAPHICS_QUOTE
    byte $0,$0,$0,$10,$20,$20,$20,$0; 8
SYMBOL_GRAPHICS_HASH
    byte $0,$50,$f8,$f8,$50,$f8,$f8,$50; 8
SYMBOL_IF = $1c
SYMBOL_GRAPHICS_IF
    byte $0,$20,$0,$20,$38,$8,$88,$f8; 8
SYMBOL_LOOP = $1d
SYMBOL_GRAPHICS_LOOP
    byte $0,$38,$28,$28,$f8,$a0,$a0,$e0; 8
SYMBOL_PROGN = $1e
SYMBOL_GRAPHICS_PROGN
    byte $0,$20,$0,$20,$0,$20,$0,$20; 8
SYMBOL_BLANK = $1f
SYMBOL_GRAPHICS_BLANK ; pack blank bytes in
    byte $0,$0,$0,$0,$0,$0,$0,$0

    align 256

SYMBOL_GRAPHICS_P1
SYMBOL_ZERO = $20
SYMBOL_GRAPHICS_ZERO
    byte $0,$70,$88,$88,$88,$88,$88,$70; 8
SYMBOL_GRAPHICS_ONE
    byte $0,$70,$20,$20,$20,$20,$20,$60; 8
SYMBOL_GRAPHICS_TWO
    byte $0,$f8,$80,$80,$f8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_THREE
    byte $0,$f8,$8,$8,$f8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_FOUR
    byte $0,$8,$8,$8,$f8,$88,$88,$88; 8
SYMBOL_GRAPHICS_FIVE
    byte $0,$f8,$8,$8,$f8,$80,$80,$f8; 8
SYMBOL_GRAPHICS_SIX
    byte $0,$f8,$88,$88,$f8,$80,$80,$f8; 8
SYMBOL_GRAPHICS_SEVEN
    byte $0,$8,$8,$8,$8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_EIGHT
    byte $0,$f8,$88,$88,$f8,$88,$88,$f8; 8
SYMBOL_GRAPHICS_NINE
    byte $0,$8,$8,$8,$f8,$88,$88,$f8; 8
SYMBOL_A0 = $0a
SYMBOL_GRAPHICS_A0
    byte $0,$70,$88,$88,$78,$8,$f0,$0; 8
SYMBOL_GRAPHICS_A1
    byte $0,$f0,$88,$88,$88,$f0,$80,$80; 8
SYMBOL_GRAPHICS_A2
    byte $0,$70,$80,$80,$80,$80,$70,$0; 8
SYMBOL_GRAPHICS_A3
    byte $0,$78,$88,$88,$88,$78,$8,$8; 8
SYMBOL_GRAPHICS_STACK_VAR
    byte $0,$fe,$54,$54,$14,$14,$10,$10; 8
SYMBOL_GRAPHICS_LOOP_VAR
    byte $0,$10,$20,$20,$20,$00,$20,$00; 8
SYMBOL_GRAPHICS_CX0B
    byte $0,$b8,$a8,$b8,$80,$80,$88,$80; 8
SYMBOL_GRAPHICS_CX1B
    byte $0,$b8,$90,$b0,$80,$80,$88,$80; 8
SYMBOL_GRAPHICS_CX01
    byte $0,$b8,$90,$b0,$0,$e8,$a8,$e8; 8
SYMBOL_GRAPHICS_WORDS
SYMBOL_GRAPHICS_EV
    byte $0,$64,$84,$8a,$ca,$8a,$8a,$62; 8
SYMBOL_GRAPHICS_AL
    byte $0,$a6,$a8,$a8,$e8,$a8,$a8,$48; 8 
SYMBOL_GRAPHICS_CA
    byte $0,$6a,$8a,$8a,$8e,$8a,$8a,$64; 8
SYMBOL_GRAPHICS_LC
    byte $0,$66,$88,$88,$88,$88,$88,$86; 8
SYMBOL_GRAPHICS_TU
    byte $0,$c4,$2a,$2a,$4a,$8a,$8a,$64; 8
SYMBOL_GRAPHICS_NE
    byte $0,$a6,$aa,$aa,$aa,$a8,$a8,$c6; 8
SYMBOL_GRAPHICS_BA
    byte $0,$6a,$aa,$aa,$ae,$8a,$8a,$64; 8
SYMBOL_GRAPHICS_LL
    byte $0,$a6,$a8,$a8,$ac,$e8,$e8,$a6; 8
SYMBOL_GRAPHICS_DI
    byte $0,$c4,$24,$24,$44,$84,$84,$6e; 8
SYMBOL_GRAPHICS_SK
    byte $0,$aa,$aa,$ea,$a4,$aa,$aa,$4a; 8
SYMBOL_GRAPHICS_MA
    byte $0,$c4,$24,$24,$44,$84,$84,$6e; 8
SYMBOL_GRAPHICS_ZE
    byte $0,$68,$88,$88,$ce,$8a,$8a,$66; 8


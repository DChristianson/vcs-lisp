    processor 6502
    include "vcs.h"
    include "macro.h"

NTSC = 0
PAL60 = 1

    IFNCONST SYSTEM
SYSTEM = NTSC
    ENDIF

; ----------------------------------
; constants

#if SYSTEM = NTSC
; NTSC Colors
WHITE = $0f
BLACK = 0
RED = $30
LOGO_COLOR = $C4
CURSOR_COLOR = $86
SCANLINES = 262
#else
; PAL Colors
WHITE = $0E
BLACK = 0
RED = $42
LOGO_COLOR = $53
CURSOR_COLOR = $86
SCANLINES = 262
#endif

INITIAL_LAVA_INTERVAL = 255
CHAR_HEIGHT = 8
STEPS_LEAD = 2

; ----------------------------------
; vars

  SEG.U VARS

    ORG $80

; frame-based "clock"
clock              ds 1
game_state         ds 1

; combined player input
; bits: f...rldu
player_input       ds 2
; debounced p0 input
player_input_latch ds 1

tower              ds 3

; ----------------------------------
; code

  SEG
    ORG $F000

Reset
CleanStart
    ; do the clean start macro
            CLEAN_START

            lda #WHITE
            sta COLUP0
            sta COLUP1

newFrame

    ; 3 scanlines of vertical sync signal to follow

            ldx #%00000010
            stx VSYNC               ; turn ON VSYNC bit 1
            ldx #0

            sta WSYNC               ; wait a scanline
            sta WSYNC               ; another
            sta WSYNC               ; another = 3 lines total

            stx VSYNC               ; turn OFF VSYNC bit 1

    ; 37 scanlines of vertical blank to follow

;--------------------
; VBlank start

            lda #%00000010
            sta VBLANK

            lda #42    ; vblank timer will land us ~ on scanline 34
            sta TIM64T

    ; check reset switches
            lda #$01
            bit SWCHB
            bne _end_switches
            jmp CleanStart
_end_switches


;---------------------
;  update kernels

            ; update clock
            inc clock

            ; update player input
jx_update
            ldx #1
            lda SWCHA
            and #$0f
_jx_update_loop
            sta player_input,x 
            lda #$80
            and INPT4,x        
            ora player_input,x 
            sta player_input,x 
_jx_update_no_signal
            dex
            bmi _jx_update_end
            lda SWCHA
            lsr
            lsr
            lsr
            lsr
            ldy player_input   
            jmp _jx_update_loop
_jx_update_end
            tya ; debounce p0 joystick
            eor #$8f           
            ora player_input   
            sta player_input_latch

;---------------------
; end vblank

            ldx #$00
endVBlank_loop          
            cpx INTIM
            bmi endVBlank_loop
            stx VBLANK

            sta WSYNC ; SL 35

            sta WSYNC
            sta HMOVE
            ldx #192
            jsr sub_wsync_loop


;--------------------
; Overscan start

waitOnOverscan
            ldx #30
            jsr sub_wsync_loop
            jmp newFrame

;
; game control subroutines
;

sub_wsync_loop
_header_loop
            sta WSYNC
            dex
            bne _header_loop
            rts


;     0                          0000 00000000
;     1 %00010000  3     111     0000 01110000 
;     2 %00001000  5    11111    0000 11111000 
;     4 %00000100  7   1111111   1000 11111100 
;     8 %00000010  9  111111111  1100 11111110 
;    16 %00000001 11 11111111111 1110 11111111 

;     0                          0000 00000000 00000000`
;     1 %00010000  3     111     0001 11000000 00000000
;     2 %00001000  5    11111    0011 11100000 00000000
;     4 %00000100  7   1111111   0111 11110000 00000000
;     8 %00000010  9  111111111  1111 11111000 00000000
;    16 %00000001 11 11111111111 1111 11111100 10000000

;     0                          00000000 00000000`
;     1 %00010000 3      111     00011111 00111111
;     2 %00001000  5    11111    00001111 00011111
;     4 %00000100  7   1111111   00000111 00001111
;     8 %00000010  9  111111111  00000011 00000111
;    16 %00000001 11 11111111111 00000001 00000011

; ----------------------------------
; symbol graphics 

    ORG $FE00

PF0DataA
	.byte %11100000
	.byte %11000000
	.byte %10000000
	.byte %00000000
	.byte %00000000

PF1DataA
	.byte %11111111
	.byte %11111110
	.byte %11111100
	.byte %11111000
	.byte %01110000

PF2DataA
	.byte %11111100
	.byte %11111000
	.byte %11110000
	.byte %11100000
	.byte %11000000

PF0DataB
	.byte %11110000
	.byte %11110000
	.byte %01110000
	.byte %00110000
	.byte %00010000

PF1DataB
	.byte %00011111
	.byte %00001111
	.byte %00000111
	.byte %00000011
	.byte %00000001

PF2DataB
	.byte %00111111
	.byte %00011111
	.byte %00001111
	.byte %00000111
	.byte %00000011

    
    ORG $FF00

    ; standard lookup for hmoves
STD_HMOVE_BEGIN
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END
LOOKUP_STD_HMOVE = STD_HMOVE_END - 256


;-----------------------------------------------------------------------------------
; the CPU reset vectors

    ORG $FFFA

    .word Reset          ; NMI
    .word Reset          ; RESET
    .word Reset          ; IRQ

    END
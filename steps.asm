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

steps_wsync        ds 1
steps_respx        ds 1
steps_hmove_a      ds 1
steps_hmove_b      ds 1

; combined player input
; bits: f...rldu
player_input       ds 2
; debounced p0 input
player_input_latch ds 1
; reserve for game data
steps              ds 8
num_steps          ds 1
player_step        ds 1
player_score       ds 1
lava_step          ds 1
lava_timer         ds 1

draw_s0_addr ds 2
draw_s1_addr ds 2

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
            ; bootstrap steps
            jsr sub_steps_init

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

gx_update
            ldx player_step
            dex
            jsr sub_step_getx
            tay
            lda player_input_latch
            ror
            bcs _gx_update_check_down
            jmp gx_go_up
_gx_update_check_down
            ror
            bcs _gx_update_check_left
            jmp gx_go_down
_gx_update_check_left
            ror
            bcs _gx_update_check_right
            jmp gx_go_down
_gx_update_check_right
            ror
            bcs gx_update_return
            jmp gx_go_up
gx_update_return

;---------------------
; end vblank

            ldx #$00
endVBlank_loop          
            cpx INTIM
            bmi endVBlank_loop
            stx VBLANK

            sta WSYNC ; SL 35

gx_steps_resp
            lda steps_respx
            ldy steps_hmove_a
            jsr sub_respxx
            sta WSYNC
            sta HMOVE
            ldx steps_wsync
            jsr sub_wsync_loop
            ; shim hmove
            tya                     
            bmi _gx_shim_swap 
            lda #$00
            sta HMP1
            sta HMP0
            lda #$00
            jmp _gx_shim_end
_gx_shim_swap
            lda #$40
            sta HMP0
            lda #$00
            sta HMP1
            lda #$08
            ; end shim
_gx_shim_end
            sta REFP0
            jsr sub_draw_lead_steps
            ldx num_steps
            dex
gx_step_draw
            sta WSYNC
            sta HMOVE
            ; get player graphic
            lda #>SYMBOL_GRAPHICS_S00_ZERO
            sta draw_s0_addr + 1
            sta draw_s1_addr + 1
            lda #<SYMBOL_GRAPHICS_S12_BLANK
            cpx player_step
            bne _gx_set_s0
            lda #<SYMBOL_GRAPHICS_S11_NUTS
_gx_set_s0
            sta draw_s0_addr
            ; get step graphic
            jsr sub_step_getx
            asl
            asl
            asl
            sta draw_s1_addr
            ldy #CHAR_HEIGHT - 1
_gx_draw_loop
            sta WSYNC
            lda (draw_s0_addr),y
            sta GRP0
            lda (draw_s1_addr),y
            sta GRP1
            dey 
            bpl _gx_draw_loop
            lda steps_hmove_a
            sta HMP0
            sta HMP1
            dex 
            bpl gx_step_draw
            ; end steps
            lda steps_hmove_b
            sta HMP0
            sta HMP1
            jsr sub_draw_lead_steps

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

sub_draw_lead_steps
            ldx #STEPS_LEAD-1
_draw_lead_loop
            sta WSYNC
            sta HMOVE
            ; get player graphic
            lda #>SYMBOL_GRAPHICS_S00_ZERO
            sta draw_s0_addr + 1
            sta draw_s1_addr + 1
            lda #<SYMBOL_GRAPHICS_S12_BLANK
            sta draw_s0_addr
            lda #<SYMBOL_GRAPHICS_S00_ZERO
            sta draw_s1_addr
            ldy #CHAR_HEIGHT - 1
_draw_lead_step_loop
            sta WSYNC
            lda (draw_s0_addr),y
            sta GRP0
            lda (draw_s1_addr),y
            sta GRP1
            dey 
            bpl _draw_lead_step_loop
            lda steps_hmove_b
            sta HMP0
            sta HMP1
            dex 
            bpl _draw_lead_loop
            ; end steps
            rts

sub_steps_init
            ; bootstrap steps
            lda #(160)
            sta steps_wsync
            lda #(53)
            sta steps_respx
            ldx #0
            stx player_score
            inx ; save a byte
            stx player_step            
            ldx #INITIAL_LAVA_INTERVAL
            stx lava_timer
            ldx #$90
            stx steps_hmove_a
            ldx #$70
            stx steps_hmove_b
            lda #$05
sub_steps_advance
            sta num_steps
            sec
            sbc #1
            lsr 
            tax 
            lda #$01
            bcs _bootstrap_steps_odd
            lda #$00
_bootstrap_steps_odd
            sta steps,x
            dex
            lda #$11
_bootstrap_steps_loop
            sta steps,x
            dex
            bpl _bootstrap_steps_loop
            ; visual 
            ; swap hmoves
            lda steps_hmove_a
            ldx steps_hmove_b
            sta steps_hmove_b
            stx steps_hmove_a
            ; calc size of steps array
            lda num_steps       ; num_steps * 7
            asl                 ;  = num_steps * (8 - 1)
            asl                 ;  = num_steps * 8 - num_steps
            asl                 ; .
            sec                 ; .
            sbc num_steps       ; .
            tax
            ; calc respx
            sec
            sbc #((STEPS_LEAD + 4) * 7)
            bit steps_hmove_a
            bpl _add_steps_respx
            eor #$ff
            clc
            adc #1
_add_steps_respx
            clc
            adc steps_respx
            sta steps_respx
            ; calc wsync
            txa
            eor #$ff
            clc
            adc #1
            clc
            adc steps_wsync
            bpl _add_steps_wsync
            lda #20
_add_steps_wsync
            sta steps_wsync
            ; done
            rts

sub_respxx
            ; a has position
            sta WSYNC               ; --
_respxx_loop
            sbc #15                 ;2    2
            sbcs _respxx_loop        ;2/3  4
            tax                     ;2    6
            lda LOOKUP_STD_HMOVE,x  ;5   11
            sta HMP0                ;3   14
            sta HMP1                ;3   17
            tya                     ;2   19
            bmi _respxx_swap        ;2   21
            sta.w RESP0             ;4   25
            sta RESP1               ;3   28
            rts
_respxx_swap            
            sta RESP1               ;3   25
            sta RESP0               ;3   28
            rts

sub_step_getx
            ; x has step number
            cpx num_steps
            bcs _step_get_overflow
            txa
            lsr
            tay
            lda steps,y
            bcc _step_get_lo
            lsr
            lsr
            lsr
            lsr
_step_get_lo
            and #$0f
            rts
_step_get_overflow            
            lda #12
            rts

gx_go_up
            tya
            jmp _gx_go_add_step
gx_go_down
            tya
            eor #$ff
            clc
            adc #1
_gx_go_add_step
            clc
            adc player_step
            beq _gx_go_fall
            cmp num_steps
            bcc _gx_go_save_step
            bne _gx_go_fall
            ; win
            inc player_score
            lda player_score
            lsr
            ldx #4
_gx_add_steps
            inx
            lsr
            bne _gx_add_steps
            txa
            jsr sub_steps_advance
_gx_go_fall
            ; fall and recover
            lda #1
_gx_go_save_step
            sta player_step
            jmp gx_update_return

; ----------------------------------
; symbol graphics 

    ORG $FE00
    
SYMBOL_GRAPHICS_S00_ZERO
    byte $0,$70,$88,$88,$88,$88,$88,$70; 8
SYMBOL_GRAPHICS_S01_ONE
    byte $0,$70,$20,$20,$20,$20,$20,$60; 8
SYMBOL_GRAPHICS_S02_TWO
    byte $0,$f8,$80,$80,$f8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_S03_THREE
    byte $0,$f8,$8,$8,$f8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_S04_FOUR
    byte $0,$8,$8,$8,$f8,$88,$88,$88; 8
SYMBOL_GRAPHICS_S05_FIVE
    byte $0,$f8,$8,$8,$f8,$80,$80,$f8; 8
SYMBOL_GRAPHICS_S06_SIX
    byte $0,$f8,$88,$88,$f8,$80,$80,$f8; 8
SYMBOL_GRAPHICS_S07_SEVEN
    byte $0,$8,$8,$8,$8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_S08_EIGHT
    byte $0,$f8,$88,$88,$f8,$88,$88,$f8; 8
SYMBOL_GRAPHICS_S09_NINE
    byte $0,$8,$8,$8,$f8,$88,$88,$f8; 8
SYMBOL_GRAPHICS_S10_FLAG
    byte $0,$c0,$c0,$c0,$ff,$ff,$ff,$ff; 8
SYMBOL_GRAPHICS_S11_NUTS
    byte $0,$1c,$3c,$3e,$6c,$6c,$46,$6; 8
SYMBOL_GRAPHICS_S12_BLANK
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8

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
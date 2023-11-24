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

CHAR_HEIGHT = 8
DRAW_TABLE_SIZE = 18
DRAW_TABLE_BYTES = DRAW_TABLE_SIZE

JUMP_TABLE_SIZE = 16
JUMP_TABLE_BYTES = JUMP_TABLE_SIZE / 2

GAME_STATE_START   = 0
GAME_STATE_CLIMB   = 1
GAME_STATE_SCROLL  = 2

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
player_step        ds 1 ; step the player is at
player_goal        ds 1 ; next goal
player_score       ds 1 ; how far the player has traveled

; game state
jump_table           ds JUMP_TABLE_BYTES 
jump_table_end_byte  ds 1 ; last byte of jump table
jump_table_offset    ds 1 ; where to locate jump table for drawing
jump_table_size      ds 1 ; number of entries in jump table

; drawing registers
steps_wsync        ds 1 ; amount to shim steps up/down
steps_respx        ds 1 ; initial pos
draw_steps_dir     ds 1 ; steps direction
draw_player_dir    ds 1 ; player direction
draw_hmove_a       ds 1 ; initial HMOVE
draw_hmove_b       ds 1 ; reverse HMOVE
draw_flight_offset ds 1 ; flight to start at
draw_step_offset   ds 1 ; what step do we start drawing at
draw_table         ds DRAW_TABLE_BYTES
draw_s0_addr       ds 2
draw_s1_addr       ds 2


; random var
seed
random             ds 2
maze_ptr           ds 1

; DONE
;  - basic step display
;  - static sprite moves according to rules
;  - debug steps
; TODO
;  - visual 1
;   - start on ground (first step below)
;   - stair outlines
;   - smooth scroll up
;   - values disappear as you climb
;  - sounds 1
;   - bounce up/down fugue
;   - fall down notes
;   - landing song
;   - final success
;  - gameplay 1
;   - start
;   - status display
;   - win condition
;   - mix of puzzles
;  - visual 2
;   - animated jumps
;   - background
;  - gameplay 2
;   - lava
;   - second player

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
            sta COLUPF

            lda #>SYMBOL_GRAPHICS
            sta draw_s0_addr + 1
            sta draw_s1_addr + 1

            ; init RNG
            lda #17
            sta seed
            sta seed + 1
            jsr sub_galois

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

            lda #GAME_STATE_SCROLL
            cmp game_state
            bne jx_update
            rts

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
            bit draw_player_dir
            bmi _gx_update_rev_left
_gx_update_rev_right
            jmp gx_go_down
_gx_update_check_right
            ror
            bcs gx_update_return
            bit draw_player_dir
            bmi _gx_update_rev_right
_gx_update_rev_left
            jmp gx_go_up
gx_update_return

gx_continue

;---------------------
; end vblank

            ldx #$00
endVBlank_loop          
            cpx INTIM
            bmi endVBlank_loop
            stx VBLANK

            sta WSYNC ; SL 35


gx_score
            lda player_score
            asl
            asl
            asl
            sta draw_s1_addr
            ldy #(CHAR_HEIGHT - 1)
_gx_score_loop
            sta WSYNC
            lda (draw_s1_addr),y
            sta GRP1
            dey
            bpl _gx_score_loop

            ; shim wsync
            ldx steps_wsync
            jsr sub_wsync_loop

gx_steps_resp
            jsr sub_steps_respxx
            ldx #DRAW_TABLE_SIZE - 1
gx_step_draw
            sta WSYNC
            sta HMOVE
            ; read graphics
            ; phg.ssss
            lda draw_table,x
            ; get player graphic
            ldy #<SYMBOL_GRAPHICS_S12_BLANK
            asl 
            bcc _gx_draw_set_p0
            ldy #<SYMBOL_GRAPHICS_S11_NUTS
_gx_draw_set_p0
            sty draw_s0_addr
            ; swap directions
            asl
            pha
            lda draw_hmove_a
            sta HMP0
            sta HMP1
            bcc _gx_draw_end_swap_direction
            lda draw_hmove_a
            ldy draw_hmove_b
            sty HMP0
            sty draw_hmove_a
            sta draw_hmove_b
_gx_draw_end_swap_direction
            pla
            ; get step graphic
            asl
            sta draw_s1_addr
            ; check ground bit
            lda #$00
            bcc _gx_draw_set_pf
            lda #$ff
_gx_draw_set_pf
            ldy #CHAR_HEIGHT - 1
_gx_draw_loop
            sta WSYNC
            sta PF0
            sta PF1
            sta PF2
            lda (draw_s0_addr),y
            sta GRP0
            lda (draw_s1_addr),y
            sta GRP1
            lda #$00
            dey 
            bpl _gx_draw_loop
            dex 
            bpl gx_step_draw
            ; end steps

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

sub_steps_init
            lda #53
            sta steps_respx
            lda #(160 - DRAW_TABLE_SIZE * CHAR_HEIGHT)
            sta steps_wsync
            ; jump init
            lda #6
            sta jump_table_size
            lsr
            sec
            sbc #1
            sta jump_table_end_byte
            jsr sub_gen_steps
            ldx jump_table_size
            dex
            stx player_goal
sub_steps_clear
            ; clear draw table
            ldx #(DRAW_TABLE_SIZE - 1)
            lda #0
_steps_draw_clear_loop
            sta draw_table,x
            dex
            bpl _steps_draw_clear_loop
sub_steps_flights
            ; add flight markers
            ldy draw_flight_offset
            lda draw_step_offset; current step
_steps_draw_flights
            clc
            adc FLIGHTS,y
            cmp #DRAW_TABLE_SIZE
            bpl _steps_draw_flights_end
            tax
            lda #$40
            sta draw_table,x
            dex
            txa
            iny
            jmp _steps_draw_flights 
_steps_draw_flights_end
sub_steps_jump
            ldx jump_table_end_byte
            lda jump_table_size
            clc
            adc jump_table_offset
            tay
            dey
_steps_draw_jumps
            lda jump_table,x
            lsr
            lsr
            lsr
            lsr
            ora draw_table,y
            sta draw_table,y
            dey
            lda jump_table,x
            and #$0f
            ora draw_table,y
            sta draw_table,y
            dey
            dex
            bpl _steps_draw_jumps
            rts

sub_steps_advance
            ; move jump table "up" to next flight
            lda jump_table_size
            sec
            sbc #1
            clc
            adc jump_table_offset
            tax 
            clc 
            adc jump_table_size
            sec
            sbc #(DRAW_TABLE_SIZE - 1)
            bmi _sub_steps_advance_save
            ; scroll
            jsr sub_steps_scroll
            jmp sub_steps_advance
_sub_steps_advance_save
            stx jump_table_offset
            lda #GAME_STATE_SCROLL ; BUGBUG: kludgey
            cmp game_state
            bne _sub_steps_advance_end
            lda draw_steps_dir
            eor #$ff
            sta draw_steps_dir
_sub_steps_advance_end
            lda #GAME_STATE_CLIMB
            sta game_state
            lda draw_player_dir
            eor #$88 ; invert plqyer dir between 8 and 0
            sta draw_player_dir
            sta REFP0
            jmp sub_steps_clear     

sub_steps_scroll
            ; lda steps_wsync
            ; clc
            ; adc #1
            ; and #$07
            ; sta steps_wsync
            ;  bne _sub_scroll_cont
            dec jump_table_offset
            ldy draw_flight_offset
            dec draw_step_offset
            lda draw_step_offset
            clc
            adc FLIGHTS,y
            sec
            sbc #1
            bne _sub_scroll_cont
            iny
            sty draw_flight_offset
            lda #0
            sta draw_step_offset
_sub_scroll_cont
            lda #GAME_STATE_SCROLL
            sta game_state
            jmp gx_continue ; will continue later

FLIGHTS
    byte 6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6
    ;10,12,12,12,12,14,14,14,14,16,16,16,16,16,16
MAX_FLIGHTS = . - FLIGHTS

MAZES
    ; byte $33, $11, $00
    ; byte $23, $12, $00
    ; byte $22, $22, $30
    ; byte $34, $21, $30
    ; byte $45, $12, $24, $00
    ; byte $23, $12, $11, $00
    ; byte $25, $14, $12, $20
    ; byte $25, $32, $11, $10

sub_steps_respxx
            lda steps_respx
            ldy draw_steps_dir
            sta WSYNC               ; --
_respxx_loop
            sbc #15                 ;2    2
            sbcs _respxx_loop       ;2/3  4
            tax                     ;2    6
            lda LOOKUP_STD_HMOVE,x  ;5   11
            sta HMP0                ;3   14
            sta HMP1                ;3   17
            tya                     ;2   19
            bpl _respxx_swap        ;2   21
            sta.w RESP0             ;4   25
            sta RESP1               ;3   28
            sta WSYNC               ;
            sta HMOVE               ;3    3
            lda #$70                ;2    5
            sta draw_hmove_a        ;3    8
            lda #$90                ;2   10
            sta draw_hmove_b        ;3   13
            lda #$00                ;2   15
            sta HMP0                ;3   21
            sta HMP1                ;3   24
            rts                     ;6   30
_respxx_swap            
            sta RESP1               ;3   25
            sta RESP0               ;3   28
            sta WSYNC
            sta HMOVE
            lda #$90                ;2    5
            sta draw_hmove_a        ;3    8
            lda #$70                ;2   10
            sta draw_hmove_b        ;3   13
            lda #$40                ;3   21
            sta HMP0                ;3   24
            lda #$00                ;3   27
            sta HMP1                ;3   30
            rts                     ;6   36

sub_step_getx
            txa ; x has step number
            lsr ; div by 2
            tay
            lda jump_table,y
            bcc _step_get_lo
            lsr
            lsr
            lsr
            lsr
_step_get_lo
            and #$0f
            rts 

sub_gen_steps
            ldx jump_table_end_byte
            lda #$01
            sta jump_table,x
            dex
            lda #$11
_sub_gen_steps_loop
            sta jump_table,x
            dex
            bpl _sub_gen_steps_loop
            rts

sub_galois  ; 16 bit lfsr from: https://github.com/bbbradsmith/prng_6502/tree/master
            lda seed+1
            tay ; store copy of high byte
            ; compute seed+1 ($39>>1 = %11100)
            lsr ; shift to consume zeroes on left...
            lsr
            lsr
            sta seed+1 ; now recreate the remaining bits in reverse order... %111
            lsr
            eor seed+1
            lsr
            eor seed+1
            eor seed+0 ; recombine with original low byte
            sta seed+1
            ; compute seed+0 ($39 = %111001)
            tya ; original high byte
            sta seed+0
            asl
            eor seed+0
            asl
            eor seed+0
            asl
            asl
            asl
            eor seed+0
            sta seed+0
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
            cmp player_goal
            bcc _gx_go_save_step
            bne _gx_go_fall
            ; win
            inc player_score
            jsr sub_steps_advance
_gx_go_fall
            ; fall and recover
            lda #0
_gx_go_save_step
            sta player_step
            jsr sub_redraw_player_step
            jmp gx_update_return

sub_redraw_player_step
            ldx #(DRAW_TABLE_BYTES - 1)
_sub_redraw_player_loop
            lda #$7f
            and draw_table+1,x
            sta draw_table+1,x
            dex
            bpl _sub_redraw_player_loop
            lda player_step
            clc 
            adc jump_table_offset
            tax
            lda #$80
            ora draw_table+1,x
            sta draw_table+1,x
            rts

; ----------------------------------
; symbol graphics 

    ORG $FE00
    
SYMBOL_GRAPHICS
SYMBOL_GRAPHICS_S00_ZERO
    byte $0,$70,$88,$88,$88,$70,$0,$0; 8
SYMBOL_GRAPHICS_S01_ONE
    byte $0,$70,$20,$20,$20,$60,$0,$0; 8 
SYMBOL_GRAPHICS_S02_TWO
    byte $0,$f8,$80,$f8,$8,$f8,$0,$fe; 8 
SYMBOL_GRAPHICS_S03_THREE
    byte $0,$f8,$8,$f8,$8,$f8,$0,$fe; 8 
SYMBOL_GRAPHICS_S04_FOUR
    byte $0,$8,$8,$f8,$88,$88,$0,$fe; 8 
SYMBOL_GRAPHICS_S05_FIVE
    byte $0,$f8,$8,$f8,$80,$f8,$0,$fe; 8 
SYMBOL_GRAPHICS_S06_SIX
    byte $0,$f8,$88,$f8,$80,$f8,$0,$fe; 8 
SYMBOL_GRAPHICS_S07_SEVEN
    byte $0,$8,$8,$8,$8,$f8,$0,$fe; 8 
SYMBOL_GRAPHICS_S08_EIGHT
    byte $0,$f8,$88,$f8,$88,$f8,$0,$fe; 8 
SYMBOL_GRAPHICS_S09_NINE
    byte $0,$8,$8,$f8,$88,$f8,$0,$fe; 8 
SYMBOL_GRAPHICS_S10_FLAG
    byte $0,$c0,$c0,$ff,$ff,$ff,$0,$fe; 8 
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
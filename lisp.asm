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
LOGO_COLOR = $C4
SCANLINES = 262
#else
; PAL Colors
WHITE = $0E
BLACK = 0
LOGO_COLOR = $53
SCANLINES = 262
#endif

; REPL 0xxxyyyy (x = game type, y = controls)
GAME_STATE_EDIT       = %00000000
; EVAL 1xxxyyyy (x = game type, y = controls)
GAME_STATE_EVAL       = %10000000
GAME_STATE_EVAL_APPLY = %10000001 ; returning from suspend

FUNCTION_TABLE_SIZE = 4
CELL_SIZE           = 2
HEAP_CELLS          = 32
HEAP_SIZE           = HEAP_CELLS * CELL_SIZE
HEAP_CAR_ADDR       = $0000
HEAP_CDR_ADDR       = $0001
NULL                = $00

FUNCTION_REF_IF  = $ca   
FUNCTION_SYMBOL_F0  = 11 ; beginning of function symbols
ARGUMENT_SYMBOL_A0  = 15 ; beginning of argument symbols
NUMERIC_SYMBOL_ZERO = 19
HEADER_HEIGHT = 60
EDITOR_LINES  = 5
PROMPT_HEIGHT = EDITOR_LINES * 18
FOOTER_HEIGHT = 26
DISPLAY_COLS = 6
CHAR_HEIGHT = 8

; ----------------------------------
; heap

  SEG.U HEAP

    ORG $80

; 32 cell heap
heap               ds HEAP_SIZE 

; ----------------------------------
; vars

  SEG.U VARS

    ORG $C0

; heap pointers to user defined symbols
function_table     ds FUNCTION_TABLE_SIZE
f0 = function_table
f1 = function_table + 1
f2 = function_table + 2
f3 = function_table + 3
; pointer to free cell list
free               ds 1
; pointer to repl cell
repl               ds 1
; return value from functions
accumulator        ds CELL_SIZE
; frame-based "clock"
clock              ds 1
; game state
game_state         ds 1
; debounce input
player_input       ds 2
; reserve for game data
game_data          ds 8

; ----------------------------------
; repl kernel vars
; for repl display

  SEG.U REPL

    ORG $D4


repl_scroll    ds 1 ; lines to scroll
repl_edit_line ds 1 ; editor line BUGBUG: collapse with col?
repl_edit_col  ds 1 ; editor column BUGBUG: collapse with line?
repl_prev_cell ds 1
repl_curr_cell ds 1
repl_last_line ds 1 ; last line

repl_display_list   ds EDITOR_LINES ; 6 line display, cell to display on each line
repl_display_indent ds EDITOR_LINES ; 6 line display, 4 bits indent level x 4 bits line width

repl_bcd       ds 3 ; numeric conversion BUGBUG: need?
repl_tmp_accumulator
repl_tmp_scroll ds 1 ; temporary cell storage during encoding BUGBUG: need?
repl_gx_addr
repl_tmp_width      ; temporary NUSIZ storage during draw BUGBUG: need?
repl_s5_addr   ds 2
repl_s4_addr   ds 2
repl_s3_addr   ds 2
repl_s2_addr   ds 2
repl_s1_addr   ds 2
repl_s0_addr   ds 2
repl_editor_line ds 1; temporary line counter storage

; ----------------------------------
; eval kernel vars
; for expression eval
  SEG.U EVAL

    ORG $D4

;eval_x           ds 1
eval_next        ds 1 ; next action to take
eval_frame       ds 1 ; top of stack for current frame
eval_env         ds 1 ; top of stack for calling frame
eval_func_ptr    ds 2 ; tmp pointer to function we are calling
temp1            ds 1 ; KLUDGE
temp2            ds 1 ; KLUDGE

; ----------------------------------
; code

  SEG
    ORG $F000

Reset
CleanStart
    ; do the clean start macro
            CLEAN_START

    ; one PF color
            lda #WHITE
            sta COLUPF

    ; bootstrap heap
            ldx #(HEAP_SIZE - 1)
            lda #NULL
            sta heap,x
            dex
            sta heap,x
            dex
            ldy #NULL
            lda #<(heap + HEAP_SIZE - 2)
            sec
_bootstrap_heap_loop
            sta heap,x
            sbc #2
            dex
            sty heap,x
            dex
            bpl _bootstrap_heap_loop

    include "_heap_init.asm"

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

            ; 
            ; do eval and repl updates BUGBUG: only one at a time
            lda game_state
            beq repl_update
            jmp eval_update
update_return

;---------------------
; end vblank

            ldx #$00
endVBlank_loop          
            cpx INTIM
            bmi endVBlank_loop
            stx VBLANK

            sta WSYNC ; SL 35

            lda game_state
            beq _jmp_repl_draw ; BUGBUG is there a better way -- jump table?
            jmp eval_draw
_jmp_repl_draw
            jmp repl_draw

;--------------------
; Overscan start

waitOnOverscan
            ldx #30
waitOnOverscan_loop
            sta WSYNC
            dex
            bne waitOnOverscan_loop
            jmp newFrame

;-------------------
; Timer sub
; BUGBUG: need - or inline?
waitOnTimer
            ldx #$00
waitOnTimer_loop          
            cpx INTIM
            bmi waitOnTimer_loop
            rts

; -------------------
; Display kernels

    include "_repl_kernel.asm"

    include "_eval_kernel.asm"

    include "_logo_kernel.asm"
;-----------------------------------
; function kernels

FUNC_S00_MULT
    ; TODO: BOGUS implementation
    ldx eval_frame
    clc
    lda -2,x
    rol
    sta accumulator
    lda -1,x
    rol
    sta accumulator + 1
    jmp exec_frame_return
FUNC_S01_ADD
    ldx eval_frame
    lda -2,x
    clc
    adc -4,x
    sta accumulator
    lda -1,x
    adc -3,x
    sta accumulator+1
    jmp exec_frame_return
FUNC_S02_SUB
    ; TODO: BOGUS implementation
    ldx eval_frame
    lda -1,x
    sec
    sbc -3,x
    sta accumulator + 1
    lda -2,x
    sbc -4,x
    sta accumulator
    jmp exec_frame_return
FUNC_S03_DIV
    ; TODO: BOGUS implementation
    ldx eval_frame
    clc
    lda -1,x
    ror
    sta accumulator+1
    lda -2,x
    ror
    sta accumulator
    jmp exec_frame_return
FUNC_S04_EQUALS
    ; TODO: BOGUS implementation
    ldx eval_frame
    lda -1,x
    sec
    sbc -3,x
    sta accumulator
    lda -2,x
    sbc -4,x
    sta accumulator+1
    jmp exec_frame_return
FUNC_S05_GT
FUNC_S06_LT
FUNC_S07_AND
FUNC_S08_OR
FUNC_S09_NOT
FUNC_S0A_IF
            jmp exec_frame_return

; ----------------------------------
; data

    ORG $FD00

LOOKUP_SYMBOL_FUNCTION
LOOKUP_SYMBOL_VALUE
    word FUNC_S00_MULT
    word FUNC_S01_ADD
    word FUNC_S02_SUB
    word FUNC_S03_DIV
    word FUNC_S04_EQUALS
    word FUNC_S05_GT
    word FUNC_S06_LT
    word FUNC_S07_AND
    word FUNC_S08_OR
    word FUNC_S09_NOT
    word FUNC_S0A_IF
    word FUNC_S0B_F0
    word FUNC_S0C_F1
    word FUNC_S0D_F2
    word FUNC_S0E_F3
    word #$0000
    word #$0000
    word #$0000
    word #$0000
    word #$0000 ; S13_ZERO
    word #$0001 ; S14_ONE
    word #$0002 ; S15_TWO   
    word #$0003 ; S16_THREE  
    word #$0004 ; S17_FOUR   
    word #$0005 ; S18_FIVE   
    word #$0006 ; S19_SIX 
    word #$0007 ; S1A_SEVEN   
    word #$0008 ; S1B_EIGHT  
    word #$0009 ; S1C_NINE  


; ----------------------------------
; symbol graphics 

    ORG $FE00

SYMBOL_GRAPHICS_EMPTY
    byte $00,$00,$00,$00,$00,$00,$00,$00; 8
SYMBOL_GRAPHICS_S00_MULT
    byte $0,$0,$50,$70,$20,$70,$50,$0; 8
SYMBOL_GRAPHICS_S01_ADD
    byte $0,$20,$20,$20,$f8,$20,$20,$20; 8
SYMBOL_GRAPHICS_S02_SUB
    byte $0,$0,$0,$0,$f8,$0,$0,$0; 8
SYMBOL_GRAPHICS_S03_DIV
    byte $0,$80,$c0,$e0,$70,$38,$18,$8; 8
SYMBOL_GRAPHICS_S04_EQUALS
    byte $0,$0,$0,$f0,$0,$f0,$0,$0; 8
SYMBOL_GRAPHICS_S05_GT
    byte $0,$c0,$60,$30,$18,$30,$60,$c0; 8
SYMBOL_GRAPHICS_S06_LT
    byte $0,$18,$30,$60,$c0,$60,$30,$18; 8
SYMBOL_GRAPHICS_S07_AND
    byte $0,$20,$f0,$80,$60,$80,$f0,$20; 8
SYMBOL_GRAPHICS_S08_OR
    byte $0,$20,$20,$20,$20,$20,$20,$20; 8
SYMBOL_GRAPHICS_S09_NOT
    byte $0,$20,$20,$0,$20,$20,$20,$20; 8
SYMBOL_GRAPHICS_S0A_IF
    byte $0,$20,$0,$20,$38,$8,$88,$f8; 8
SYMBOL_GRAPHICS_S0B_F0
    byte $0,$88,$90,$50,$20,$20,$20,$40; 8
SYMBOL_GRAPHICS_S0C_F1
    byte $0,$20,$20,$0,$d8,$50,$20,$40; 8
SYMBOL_GRAPHICS_S0D_F2
    byte $0,$50,$50,$0,$d8,$50,$20,$40; 8
SYMBOL_GRAPHICS_S0E_F3
    byte $0,$70,$70,$0,$d8,$50,$20,$40; 8
SYMBOL_GRAPHICS_S0F_A0
    byte $0,$70,$88,$88,$78,$8,$88,$70; 8
SYMBOL_GRAPHICS_S10_A1
    byte $0,$f0,$88,$88,$88,$f0,$80,$80; 8
SYMBOL_GRAPHICS_S11_A2
    byte $0,$70,$88,$80,$80,$80,$88,$70; 8
SYMBOL_GRAPHICS_S12_A3
    byte $0,$78,$88,$88,$88,$78,$8,$8; 8
SYMBOL_GRAPHICS_S13_ZERO
    byte $0,$70,$88,$88,$88,$88,$88,$70; 8
SYMBOL_GRAPHICS_S14_ONE
    byte $0,$70,$20,$20,$20,$20,$20,$60; 8
SYMBOL_GRAPHICS_S15_TWO
    byte $0,$f8,$80,$80,$f8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_S16_THREE
    byte $0,$f8,$8,$8,$f8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_S17_FOUR
    byte $0,$8,$8,$8,$f8,$88,$88,$88; 8
SYMBOL_GRAPHICS_S18_FIVE
    byte $0,$f8,$8,$8,$f8,$80,$80,$f8; 8
SYMBOL_GRAPHICS_S19_SIX
    byte $0,$f8,$88,$88,$f8,$80,$80,$f8; 8
SYMBOL_GRAPHICS_S1A_SEVEN
    byte $0,$8,$8,$8,$8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_S1B_EIGHT
    byte $0,$f8,$88,$88,$f8,$88,$88,$f8; 8
SYMBOL_GRAPHICS_S1C_NINE
    byte $0,$8,$8,$8,$f8,$88,$88,$f8; 8
SYMBOL_GRAPHICS_S1D_HASH
    byte $0,$50,$f8,$f8,$50,$f8,$f8,$50; 8
SYMBOL_GRAPHICS_S1E_MULT
SYMBOL_GRAPHICS_S1F_MULT


    ORG $FF00

    ; standard lookup for hmoves
STD_HMOVE_BEGIN
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END
LOOKUP_STD_HMOVE = STD_HMOVE_END - 256

FREE_LOOKUP_TABLE
    byte $00, $01, $03, $07, $0f, $1f, $3f, $7f, $ff


; ----------------------------------
; symbol graphics lookup 
; 64 bytes starts at upper half of page
; this aligns with symbol indexes 
    
    ORG $FFC0

LOOKUP_SYMBOL_GRAPHICS = $FF00
SYMBOL_GRAPHICS_LOOKUP_TABLE
    byte #<SYMBOL_GRAPHICS_S00_MULT
    byte #<SYMBOL_GRAPHICS_S01_ADD
    byte #<SYMBOL_GRAPHICS_S02_SUB
    byte #<SYMBOL_GRAPHICS_S03_DIV
    byte #<SYMBOL_GRAPHICS_S04_EQUALS
    byte #<SYMBOL_GRAPHICS_S05_GT
    byte #<SYMBOL_GRAPHICS_S06_LT
    byte #<SYMBOL_GRAPHICS_S07_AND
    byte #<SYMBOL_GRAPHICS_S08_OR 
    byte #<SYMBOL_GRAPHICS_S09_NOT
    byte #<SYMBOL_GRAPHICS_S0A_IF
    byte #<SYMBOL_GRAPHICS_S0B_F0
    byte #<SYMBOL_GRAPHICS_S0C_F1
    byte #<SYMBOL_GRAPHICS_S0D_F2
    byte #<SYMBOL_GRAPHICS_S0E_F3
    byte #<SYMBOL_GRAPHICS_S0F_A0
    byte #<SYMBOL_GRAPHICS_S10_A1
    byte #<SYMBOL_GRAPHICS_S11_A2
    byte #<SYMBOL_GRAPHICS_S12_A3
    byte #<SYMBOL_GRAPHICS_S13_ZERO
    byte #<SYMBOL_GRAPHICS_S14_ONE
    byte #<SYMBOL_GRAPHICS_S15_TWO
    byte #<SYMBOL_GRAPHICS_S16_THREE
    byte #<SYMBOL_GRAPHICS_S17_FOUR
    byte #<SYMBOL_GRAPHICS_S18_FIVE
    byte #<SYMBOL_GRAPHICS_S19_SIX
    byte #<SYMBOL_GRAPHICS_S1A_SEVEN
    byte #<SYMBOL_GRAPHICS_S1B_EIGHT
    byte #<SYMBOL_GRAPHICS_S1C_NINE
    byte #<SYMBOL_GRAPHICS_S1D_HASH
    byte #<SYMBOL_GRAPHICS_S1E_MULT
    byte #<SYMBOL_GRAPHICS_S1F_MULT

;-----------------------------------------------------------------------------------
; the CPU reset vectors

    ORG $FFFA

    .word Reset          ; NMI
    .word Reset          ; RESET
    .word Reset          ; IRQ

    END
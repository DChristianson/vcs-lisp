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

; game state sxxxyyyi
; s = state (edit/eval), x = game type, y = mode, i = input mask
; REPL 0xxxyyyi
GAME_STATE_EDIT        = %00000000
GAME_STATE_EDIT_KEYS   = %00000001
; EVAL 1xxxyyyi
GAME_STATE_EVAL        = %10000000
GAME_STATE_EVAL_APPLY  = %10000001

FUNCTION_TABLE_SIZE = 3
CELL_SIZE           = 2
HEAP_CELLS          = 32
HEAP_SIZE           = HEAP_CELLS * CELL_SIZE
HEAP_CAR_ADDR       = $0000
HEAP_CDR_ADDR       = $0001
REPL_CELL_ADDR      = #repl - 1 ; virtual cell
NULL                = $00

HEADER_HEIGHT = 60
EDITOR_LINES  = 5
LINE_HEIGHT = CHAR_HEIGHT + 10
PROMPT_HEIGHT = EDITOR_LINES * LINE_HEIGHT
FOOTER_HEIGHT = 26
DISPLAY_COLS = 6
CHAR_HEIGHT = 8
REPL_DISPLAY_MARGIN = 16

FRAME_ARG_OFFSET_LSB = -1
FRAME_ARG_OFFSET_MSB = -2

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

; pointer to free cell list
free               ds 1
; pointer to repl cell
repl               ds 1
; heap pointers to user defined symbols
function_table     ds FUNCTION_TABLE_SIZE
f0 = function_table
f1 = function_table + 1
f2 = function_table + 2
; return value from functions
accumulator        ds CELL_SIZE
accumulator_car = accumulator
accumulator_cdr = accumulator + 1
accumulator_msb = accumulator
accumulator_lsb = accumulator + 1 
; frame-based "clock"
clock              ds 1
; game state
game_state         ds 1
; combined player input
; bits: f...rldu
player_input       ds 2
; debounced p0 input
player_input_latch ds 1
; reserve for game data
game_data          ds 8

; ----------------------------------
; repl kernel vars
; for repl display

  SEG.U REPL

    ORG $D4

repl_menu_tab  ds 1 ; which menu tab is active BUGBUG: collapse with game state?
repl_scroll    ds 1 ; lines to scroll
repl_edit_line ds 1 ; editor line BUGBUG: collapse with col?
repl_edit_col  ds 1 ; editor column BUGBUG: collapse with line?
repl_edit_sym  ds 1 ; editor symbol
repl_prev_cell ds 1
repl_curr_cell ds 1
repl_last_line ds 1 ; last line in BUGBUG: can be tmp?

repl_display_list   ds EDITOR_LINES ; 6 line display, cell to display on each line
repl_display_indent ds EDITOR_LINES ; 6 line display, 4 bits indent level x 4 bits line width

repl_fmt_arg   ds 2 ; numeric conversion BUGBUG: need?
repl_tmp_width      ; ds 1  temporary NUSIZ storage during layout BUGBUG: need?
repl_gx_addr
repl_s5_addr   ds 2
repl_tmp_indent     ; ds 1  temporary indent storage during layout BUGBUG: need?
repl_tmp_cell_count ; ds 1 temporary cell countdown during layout BUGBUG: need?
repl_s4_addr   ds 2
repl_tmp_scroll      ; ds 1temporary cell storage during layout BUGBUG: need?
repl_s3_addr   ds 2
repl_s2_addr   ds 2
repl_s1_addr   ds 2
repl_s0_addr   ds 2
repl_editor_line ds 1; line counter storage during editor display

; ----------------------------------
; eval kernel vars
; for expression eval
  SEG.U EVAL

    ORG $D4

eval_next        ds 1 ; next action to take
eval_frame       ds 1 ; top of stack for current frame
eval_env         ds 1 ; top of stack for calling frame
eval_func_ptr    ds 2 ; tmp pointer to function we are calling
eval_tmp_exp0    ds 1 ; scratch area for fp
eval_tmp_exp1    ds 1 ; scratch area for fp

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
            jsr heap_init

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
            ; 
            ; do eval and repl updates
            lda game_state ; BUGBUG: make a jump tables?
            bmi _jx_eval_update
            jmp repl_update
_jx_eval_update
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
            bpl _jmp_repl_draw ; BUGBUG is there a better way -- jump table?
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

;--------------------
; GC sub
gc
            tax
            beq gcDone
            lda #0
            pha
            txa
            pha            
_gc_loop
            pla
            beq gcDone
            tax
_gc_car
            lda HEAP_CAR_ADDR,x
            bpl _gc_free ; free a number
            cmp #$40
            bmi _gc_cdr
            pha ; recurse down car
_gc_cdr
            lda HEAP_CDR_ADDR,x
            beq _gc_free
            pha
_gc_free
            lda free
            sta HEAP_CDR_ADDR,x
            stx free
            jmp _gc_loop
gcDone
            rts

;------------------
; heap modification subs

set_cdr
            ; free the cdr of x and replace with contents of a
            ; return state undefined
            tay
            lda HEAP_CDR_ADDR,x
            sty HEAP_CDR_ADDR,x
            jsr gc
            rts

alloc_cdr
            ; add new cell at cdr of x from free
            lda free
            sta HEAP_CDR_ADDR,x
            tax
            lda HEAP_CDR_ADDR,x
            sta free
            lda #0
            sta HEAP_CDR_ADDR,x
            rts

; -------------------
; Display kernels

    include "_math_kernel.asm"

    include "_repl_kernel.asm"

    include "_eval_kernel.asm"

    include "_logo_kernel.asm"

    include "_heap_init.asm"

; ----------------------------------
; data

    ORG $FD00

LOOKUP_SYMBOL_FUNCTION
LOOKUP_SYMBOL_VALUE
LOOKUP_SYMBOL_VALUE_MSB
LOOKUP_SYMBOL_VALUE_LSB = LOOKUP_SYMBOL_VALUE_MSB + 1
    word #$0000;
    word FUNC_S01_MULT
    word FUNC_S02_ADD
    word FUNC_S03_SUB
    word FUNC_S04_DIV
    word FUNC_S05_EQUALS
    word FUNC_S06_GT
    word FUNC_S07_LT
    word FUNC_S08_AND
    word FUNC_S09_OR
    word FUNC_S0A_NOT
FUNCTION_REF_IF = $C0 + (. - LOOKUP_SYMBOL_FUNCTION) / 2
    word FUNC_S0B_IF
FUNCTION_SYMBOL_F0 = (. - LOOKUP_SYMBOL_FUNCTION) / 2 ; beginning of functions
    word FUNC_S0C_F0
    word FUNC_S0D_F1
    word FUNC_S0E_F2
    word FUNC_S0F_F3
ARGUMENT_SYMBOL_A0 = (. - LOOKUP_SYMBOL_VALUE) / 2 ; beginning of arguments
    word $0000
    word $0000
    word $0000
    word $0000
NUMERIC_SYMBOL_ZERO = (. - LOOKUP_SYMBOL_VALUE) / 2 ; beginning of numbers
    dc.s %0000000000000000 ; S14_ZERO
    dc.s %0000000000000001 ; S15_ONE
    dc.s %0000000000000010 ; S16_TWO   
    dc.s %0000000000000011 ; S17_THREE  
    dc.s %0000000000000100 ; S18_FOUR   
    dc.s %0000000000000101 ; S19_FIVE   
    dc.s %0000000000000110 ; S1A_SIX 
    dc.s %0000000000000111 ; S1B_SEVEN   
    dc.s %0000000000001000 ; S1C_EIGHT  
    dc.s %0000000000001001 ; S1D_NINE  

; ----------------------------------
; symbol graphics 

    ORG $FE00

SYMBOL_GRAPHICS_S00_TERM
    byte $0,$0,$0,$50,$0,$20,$0,$0; 8
SYMBOL_GRAPHICS_S01_MULT
    byte $0,$88,$d8,$70,$20,$70,$d8,$88; 8
SYMBOL_GRAPHICS_S02_ADD
    byte $0,$20,$20,$20,$f8,$20,$20,$20; 8
SYMBOL_GRAPHICS_S03_SUB
    byte $0,$0,$0,$0,$f8,$0,$0,$0; 8
SYMBOL_GRAPHICS_S04_DIV
    byte $0,$80,$c0,$e0,$70,$38,$18,$8; 8
SYMBOL_GRAPHICS_S05_EQUALS
    byte $0,$0,$0,$f0,$0,$f0,$0,$0; 8
SYMBOL_GRAPHICS_S06_GT
    byte $0,$c0,$60,$30,$18,$30,$60,$c0; 8
SYMBOL_GRAPHICS_S07_LT
    byte $0,$18,$30,$60,$c0,$60,$30,$18; 8
SYMBOL_GRAPHICS_S08_AND
    byte $0,$20,$f0,$80,$60,$80,$f0,$20; 8
SYMBOL_GRAPHICS_S09_OR
    byte $0,$20,$20,$20,$20,$20,$20,$20; 8
SYMBOL_GRAPHICS_S0A_NOT
    byte $0,$20,$20,$0,$20,$20,$20,$20; 8
SYMBOL_GRAPHICS_S0B_IF
    byte $0,$20,$0,$20,$38,$8,$88,$f8; 8
SYMBOL_GRAPHICS_S0C_F0
    byte $0,$88,$98,$50,$30,$20,$20,$60; 8
SYMBOL_GRAPHICS_S0D_F1
    byte $0,$f8,$88,$40,$40,$20,$20,$10; 8
SYMBOL_GRAPHICS_S0E_F2
    byte $0,$60,$20,$20,$70,$20,$20,$38; 8
SYMBOL_GRAPHICS_S0F_F3
    byte $0,$c0,$d8,$d8,$58,$48,$48,$78; 8
SYMBOL_GRAPHICS_S10_A0
    byte $0,$70,$88,$88,$78,$8,$f0,$0; 8
SYMBOL_GRAPHICS_S11_A1
    byte $0,$f0,$88,$88,$f0,$80,$80,$0; 8
SYMBOL_GRAPHICS_S12_A2
    byte $0,$70,$88,$80,$88,$70,$0,$0; 8
SYMBOL_GRAPHICS_S13_A3
    byte $0,$78,$88,$88,$78,$8,$8,$0; 8
SYMBOL_GRAPHICS_S14_ZERO
    byte $0,$70,$88,$88,$88,$88,$88,$70; 8
SYMBOL_GRAPHICS_S15_ONE
    byte $0,$70,$20,$20,$20,$20,$20,$60; 8
SYMBOL_GRAPHICS_S16_TWO
    byte $0,$f8,$80,$80,$f8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_S17_THREE
    byte $0,$f8,$8,$8,$f8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_S18_FOUR
    byte $0,$8,$8,$8,$f8,$88,$88,$88; 8
SYMBOL_GRAPHICS_S19_FIVE
    byte $0,$f8,$8,$8,$f8,$80,$80,$f8; 8
SYMBOL_GRAPHICS_S1A_SIX
    byte $0,$f8,$88,$88,$f8,$80,$80,$f8; 8
SYMBOL_GRAPHICS_S1B_SEVEN
    byte $0,$8,$8,$8,$8,$8,$8,$f8; 8
SYMBOL_GRAPHICS_S1C_EIGHT
    byte $0,$f8,$88,$88,$f8,$88,$88,$f8; 8
SYMBOL_GRAPHICS_S1D_NINE
    byte $0,$8,$8,$8,$f8,$88,$88,$f8; 8
SYMBOL_GRAPHICS_S1E_HASH
    byte $0,$50,$f8,$f8,$50,$f8,$f8,$50; 8
SYMBOL_GRAPHICS_S1F_BLANK
    byte $00,$00,$00,$00,$00,$00,$00,$00; 8

    ORG $FF00

    ; standard lookup for hmoves
STD_HMOVE_BEGIN
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END
LOOKUP_STD_HMOVE = STD_HMOVE_END - 256

FREE_LOOKUP_TABLE
    byte $00, $01, $03, $07, $0f, $1f, $3f, $7f, $ff

    ; menu graphics

SYMBOL_GRAPHICS_S00_EVAL
    byte $0,$64,$84,$8a,$ca,$8a,$8a,$62; 8
SYMBOL_GRAPHICS_S01_EVAL
    byte $0,$ae,$a8,$a8,$e8,$a8,$a8,$48; 8
SYMBOL_GRAPHICS_S00_DEFN
    byte $0,$c6,$a8,$a8,$ac,$a8,$a8,$c6; 8
SYMBOL_GRAPHICS_S01_DEFN
    byte $0,$80,$80,$80,$c0,$80,$80,$60; 8
SYMBOL_GRAPHICS_S00_CALC
    byte $0,$6a,$8a,$8a,$8e,$8a,$8a,$64; 8
SYMBOL_GRAPHICS_S01_CALC
    byte $0,$e6,$88,$88,$88,$88,$88,$86; 8
SYMBOL_GRAPHICS_S00_DISK
    byte $0,$ce,$a4,$a4,$a4,$a4,$a4,$ce; 8
SYMBOL_GRAPHICS_S01_DISK
    byte $0,$ea,$2a,$2a,$ec,$8a,$8a,$ea; 8
SYMBOL_GRAPHICS_S00_BALL
    byte $0,$ca,$aa,$aa,$ee,$aa,$aa,$c4; 8
SYMBOL_GRAPHICS_S01_BALL
    byte $0,$ee,$88,$88,$88,$88,$88,$88; 8
SYMBOL_GRAPHICS_S00_MAZE
    byte $0,$aa,$aa,$aa,$ae,$ea,$ea,$e4; 8
SYMBOL_GRAPHICS_S01_MAZE
    byte $0,$ee,$a8,$88,$4e,$28,$28,$ee; 8
SYMBOL_GRAPHICS_S00_FLAG
    byte $0,$c0,$c0,$c0,$ff,$ff,$ff,$ff; 8
SYMBOL_GRAPHICS_S01_NUTS
    byte $0,$1c,$3c,$3e,$6c,$6c,$46,$6; 8
SYMBOL_GRAPHICS_S00_LISP
    byte $0,$ee,$84,$84,$84,$84,$84,$8e; 8
SYMBOL_GRAPHICS_S01_LISP
    byte $0,$e8,$28,$28,$ee,$8a,$8a,$ee; 8

; ----------------------------------
; symbol graphics lookup 
; 64 bytes starts at upper half of page
; this aligns with symbol indexes 
    
    ORG $FFC0

LOOKUP_SYMBOL_GRAPHICS = $FF00
SYMBOL_GRAPHICS_LOOKUP_TABLE
    byte #<SYMBOL_GRAPHICS_S00_TERM
    byte #<SYMBOL_GRAPHICS_S01_MULT
    byte #<SYMBOL_GRAPHICS_S02_ADD
    byte #<SYMBOL_GRAPHICS_S03_SUB
    byte #<SYMBOL_GRAPHICS_S04_DIV
    byte #<SYMBOL_GRAPHICS_S05_EQUALS
    byte #<SYMBOL_GRAPHICS_S06_GT
    byte #<SYMBOL_GRAPHICS_S07_LT
    byte #<SYMBOL_GRAPHICS_S08_AND
    byte #<SYMBOL_GRAPHICS_S09_OR 
    byte #<SYMBOL_GRAPHICS_S0A_NOT
    byte #<SYMBOL_GRAPHICS_S0B_IF
    byte #<SYMBOL_GRAPHICS_S0C_F0
    byte #<SYMBOL_GRAPHICS_S0D_F1
    byte #<SYMBOL_GRAPHICS_S0E_F2
    byte #<SYMBOL_GRAPHICS_S0F_F3
    byte #<SYMBOL_GRAPHICS_S10_A0
    byte #<SYMBOL_GRAPHICS_S11_A1
    byte #<SYMBOL_GRAPHICS_S12_A2
    byte #<SYMBOL_GRAPHICS_S13_A3
    byte #<SYMBOL_GRAPHICS_S14_ZERO
    byte #<SYMBOL_GRAPHICS_S15_ONE
    byte #<SYMBOL_GRAPHICS_S16_TWO
    byte #<SYMBOL_GRAPHICS_S17_THREE
    byte #<SYMBOL_GRAPHICS_S18_FOUR
    byte #<SYMBOL_GRAPHICS_S19_FIVE
    byte #<SYMBOL_GRAPHICS_S1A_SIX
    byte #<SYMBOL_GRAPHICS_S1B_SEVEN
    byte #<SYMBOL_GRAPHICS_S1C_EIGHT
    byte #<SYMBOL_GRAPHICS_S1D_NINE
    byte #<SYMBOL_GRAPHICS_S1E_HASH
    byte #<SYMBOL_GRAPHICS_S1F_BLANK

MENU_GRAPHICS
    word #SYMBOL_GRAPHICS_S01_EVAL
    word #SYMBOL_GRAPHICS_S00_EVAL
    word #SYMBOL_GRAPHICS_S0C_F0
    word #SYMBOL_GRAPHICS_S00_DEFN
    word #SYMBOL_GRAPHICS_S0D_F1
    word #SYMBOL_GRAPHICS_S00_DEFN
    word #SYMBOL_GRAPHICS_S0E_F2
    word #SYMBOL_GRAPHICS_S00_DEFN

;-----------------------------------------------------------------------------------
; the CPU reset vectors

    ORG $FFFA

    .word Reset          ; NMI
    .word Reset          ; RESET
    .word Reset          ; IRQ

    END
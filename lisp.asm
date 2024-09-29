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

; game state sxxxyyyy
; s = state (edit/eval), x = game type, y = mode
; REPL 0xxxyyyi
GAME_STATE_EDIT          = %00000000
GAME_STATE_EDIT_KEYS     = %00000001
; EVAL 1xxxyyyi
GAME_STATE_EVAL          = %10000000
GAME_STATE_EVAL_APPLY    = %10000001
GAME_STATE_EVAL_CONTINUE = %10000010
; GAME types
GAME_TYPE_MASK           = %01110000
__GAME_TYPE_CALC         = %00000000
__GAME_TYPE_MUSIC        = %00010000
__GAME_TYPE_PADDLE       = %00100000
__GAME_TYPE_TOWER        = %00110000
__GAME_TYPE_STEPS        = %01000000

FUNCTION_TABLE_SIZE = 3
CELL_SIZE           = 2
HEAP_CELLS          = 32
HEAP_SIZE           = HEAP_CELLS * CELL_SIZE
HEAP_CAR_ADDR       = $0000
HEAP_CDR_ADDR       = $0001
REPL_CELL_ADDR      = #repl - 1 ; virtual cell
NULL                = $00

HEADER_HEIGHT = 40
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
; beep frequency and time
beep_f0            ds 1
beep_t0            ds 1
; reserve for game data
game_data          ds 6

; player graphics
gx_addr
gx_s4_addr         ds 2
gx_s3_addr         ds 2
gx_s2_addr         ds 2

; ----------------------------------
; repl kernel vars
; for repl display

  SEG.U REPL

    ORG $DA

; additional graphics addresses
gx_s1_addr          ds 2
gx_s0_addr          ds 2

repl_menu_tab       ds 1 ; which menu tab is active BUGBUG: collapse with game state?
repl_scroll         ds 1 ; lines to scroll
repl_edit_line      ds 1 ; editor line BUGBUG: collapse with col?
repl_edit_col       ds 1 ; editor column BUGBUG: collapse with line?
repl_edit_sym       ds 1 ; editor symbol
repl_prev_cell      ds 1
repl_curr_cell      ds 1
repl_last_line      ds 1 ; last line in BUGBUG: can be tmp?

repl_display_cursor ds 1 ; cursor position for display
repl_display_list   ds EDITOR_LINES ; 5 line display, cell to display on each line
repl_display_indent ds EDITOR_LINES ; 5 line display, 4 bits indent level + 4 bits line width

repl_keys_y       ds 1 ; y index of keys
repl_edit_y        ds 1 ;y index of edit line
repl_tmp_width   ds 1 ; ds 1  temporary NUSIZ storage during layout BUGBUG: need?
repl_tmp_indent       ; ds 1  temporary indent storage during layout BUGBUG: need?
repl_tmp_cell_count ds 1  ; ds 1 temporary cell countdown during layout BUGBUG: need?
repl_tmp_scroll        ; ds 1temporary cell storage during layout BUGBUG: need?
repl_editor_line ds 1  ; line counter storage during editor display

; ----------------------------------
; eval kernel vars
; for expression eval
  SEG.U EVAL

    ORG $DA

eval_next        ds 1 ; next action to take
eval_frame       ds 1 ; top of stack for current frame
eval_env         ds 1 ; top of stack for calling frame
eval_func_ptr    ds 2 ; jump pointer to kernel function

STACK_DANGER_ZONE = eval_func_ptr + 3 ; rough guess as to what is safe

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
            lda #0
            sta COLUBK
            sta NUSIZ0
            sta NUSIZ1

            lda game_state
            and #$70
            adc #$10
            jsr sub_fmt_word_no_mult 
            lda #70
            jsr sub_respxx
            lda #WHITE 
            ldy #-2    
            cpy repl_edit_line 
            bne _mode_set_colupx
            lda #CURSOR_COLOR
_mode_set_colupx
            sta COLUP0     
            sta COLUP1    
            jsr sub_draw_glyph_16px

            lda game_state
            and #$70
            lsr
            lsr
            lsr
            tax
            lda GAME_STATE_DRAW_JMP_HI,x
            pha
            lda GAME_STATE_DRAW_JMP_LO,x
            pha
            lda #0             
            sta WSYNC
            sta GRP0     
            sta GRP1 
            sta GRP0     
            sta COLUBK
            lda #WHITE
            sta COLUP0
            sta COLUP1
            rts
game_draw_return

            lda game_state
            bpl _jmp_repl_draw ; BUGBUG is there a better way -- jump table?
            jmp logo_draw
_jmp_repl_draw
            jmp repl_draw


game_state_init_noop
    jmp game_state_init_return

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
            beq oom
            sta HEAP_CDR_ADDR,x
            tax
            lda HEAP_CDR_ADDR,x
            sta free
            lda #0
            sta HEAP_CDR_ADDR,x
            rts

oom
            ; we are out of memory
            ; BUGBUG: need some kind of error display
            ; for now will pull address we were at from stack and drop in accumulator
            pla
            sta accumulator_car
            pla
            sta accumulator_cdr
            jmp _repl_update_edit_done ; BUGBUG: if we alloc anywhere other than editor will need a trap addr

; -------------------
; Display kernels

    include "_repl_kernel.asm"

    include "_math_kernel.asm"

    include "_eval_kernel.asm"

    include "_calc_kernel.asm"

    include "_music_kernel.asm"

    include "_game_kernel.asm"

    include "_tower_kernel.asm"

    include "_logo_kernel.asm"

    include "_heap_init.asm"

; interleaved jump table
; BUGBUG: notation for this?
GAME_STATE_DRAW_JMP_LO
GAME_STATE_DRAW_JMP_HI = GAME_STATE_DRAW_JMP_LO + 1
    word (repl_draw_accumulator-1)
    word (repl_draw_music-1)
    word (repl_draw_game-1)
    word (repl_draw_tower-1)

GAME_STATE_INIT_JMP_LO
GAME_STATE_INIT_JMP_HI = GAME_STATE_INIT_JMP_LO + 1
    word (game_state_init_noop-1)
    word (game_state_init_noop-1)
    word (repl_init_game-1)
    word (repl_init_tower-1)

; ----------------------------------
; data

    include "_graphics_symbols.asm"

    ORG $FF00

    ; standard lookup for hmoves
STD_HMOVE_BEGIN
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END
LOOKUP_STD_HMOVE = STD_HMOVE_END - 256

    ; eval
LOOKUP_SYMBOL_FUNCTION
    word $0000
    word FUNC_S01_MULT-1
    word FUNC_S02_ADD-1
    word FUNC_S03_SUB-1
    word FUNC_S04_DIV-1
    word FUNC_MOD-1
    word FUNC_S05_EQUALS-1
    word FUNC_S06_GT-1
    word FUNC_S07_LT-1
    word FUNC_S08_AND-1
    word FUNC_S09_OR-1
    word FUNC_S0A_NOT-1
    word $0000 ; CONS
    word $0000 ; CAR
    word $0000 ; CDR
    word FUNC_F0-1
    word FUNC_F1-1
    word FUNC_F2-1
    word FUNC_BEEP-1
    word FUNC_STACK-1
    word FUNC_POS_P0-1
    word FUNC_POS_P1-1
    word FUNC_POS_BL-1
    word FUNC_J0-1
    word FUNC_J1-1

MENU_PAGE_0_LO
    byte <SYMBOL_GRAPHICS_TERM
    byte <SYMBOL_GRAPHICS_MULT
    byte <SYMBOL_GRAPHICS_ADD
    byte <SYMBOL_GRAPHICS_SUB

    byte <SYMBOL_GRAPHICS_DIV
    byte <SYMBOL_GRAPHICS_MOD
    byte <SYMBOL_GRAPHICS_EQUALS
    byte <SYMBOL_GRAPHICS_GT

    byte <SYMBOL_GRAPHICS_LT
    byte <SYMBOL_GRAPHICS_AND
    byte <SYMBOL_GRAPHICS_OR
    byte <SYMBOL_GRAPHICS_NOT

    byte <SYMBOL_GRAPHICS_IF
    byte <SYMBOL_GRAPHICS_F0
    byte <SYMBOL_GRAPHICS_F1
    byte <SYMBOL_GRAPHICS_F2

    byte <SYMBOL_GRAPHICS_A0
    byte <SYMBOL_GRAPHICS_A1
    byte <SYMBOL_GRAPHICS_A2
    byte <SYMBOL_GRAPHICS_A3

    byte <SYMBOL_GRAPHICS_HASH
    byte <SYMBOL_GRAPHICS_ZERO
    byte <SYMBOL_GRAPHICS_ONE
    byte <SYMBOL_GRAPHICS_TWO

    byte <SYMBOL_GRAPHICS_THREE
    byte <SYMBOL_GRAPHICS_FOUR
    byte <SYMBOL_GRAPHICS_FIVE
    byte <SYMBOL_GRAPHICS_SIX

    byte <SYMBOL_GRAPHICS_SEVEN
    byte <SYMBOL_GRAPHICS_EIGHT
    byte <SYMBOL_GRAPHICS_NINE
    byte <SYMBOL_GRAPHICS_BEEP

    byte <SYMBOL_GRAPHICS_PROGN
    byte <SYMBOL_GRAPHICS_LOOP
    byte <SYMBOL_GRAPHICS_J0
    byte <SYMBOL_GRAPHICS_J1

    byte <SYMBOL_GRAPHICS_PLAYER_0_FN
    byte <SYMBOL_GRAPHICS_PLAYER_1_FN
    byte <SYMBOL_GRAPHICS_BALL_FN
    byte <SYMBOL_GRAPHICS_CX01

    byte <SYMBOL_GRAPHICS_CX0B
    byte <SYMBOL_GRAPHICS_CX1B
    byte <SYMBOL_GRAPHICS_APPLY_FN
    byte <SYMBOL_GRAPHICS_STACK_FN

    byte <SYMBOL_GRAPHICS_LOOP_VAR
    byte <SYMBOL_GRAPHICS_STACK_VAR

MENU_PAGE_0_HI
    byte >SYMBOL_GRAPHICS_TERM
    byte >SYMBOL_GRAPHICS_MULT
    byte >SYMBOL_GRAPHICS_ADD
    byte >SYMBOL_GRAPHICS_SUB
    byte >SYMBOL_GRAPHICS_DIV
    byte >SYMBOL_GRAPHICS_TERM
    byte >SYMBOL_GRAPHICS_EQUALS
    byte >SYMBOL_GRAPHICS_GT
    byte >SYMBOL_GRAPHICS_LT
    byte >SYMBOL_GRAPHICS_AND
    byte >SYMBOL_GRAPHICS_OR
    byte >SYMBOL_GRAPHICS_NOT
    byte >SYMBOL_GRAPHICS_IF
    byte >SYMBOL_GRAPHICS_F0
    byte >SYMBOL_GRAPHICS_F1
    byte >SYMBOL_GRAPHICS_F2
    byte >SYMBOL_GRAPHICS_A0
    byte >SYMBOL_GRAPHICS_A1
    byte >SYMBOL_GRAPHICS_A2
    byte >SYMBOL_GRAPHICS_A3
    byte >SYMBOL_GRAPHICS_HASH
    byte >SYMBOL_GRAPHICS_ZERO
    byte >SYMBOL_GRAPHICS_ONE
    byte >SYMBOL_GRAPHICS_TWO
    byte >SYMBOL_GRAPHICS_THREE
    byte >SYMBOL_GRAPHICS_FOUR
    byte >SYMBOL_GRAPHICS_FIVE
    byte >SYMBOL_GRAPHICS_SIX
    byte >SYMBOL_GRAPHICS_SEVEN
    byte >SYMBOL_GRAPHICS_EIGHT
    byte >SYMBOL_GRAPHICS_NINE
    byte >SYMBOL_GRAPHICS_BEEP
    byte >SYMBOL_GRAPHICS_PROGN
    byte >SYMBOL_GRAPHICS_LOOP
    byte >SYMBOL_GRAPHICS_J0
    byte >SYMBOL_GRAPHICS_J1

    byte >SYMBOL_GRAPHICS_PLAYER_0_FN
    byte >SYMBOL_GRAPHICS_PLAYER_1_FN
    byte >SYMBOL_GRAPHICS_BALL_FN
    byte >SYMBOL_GRAPHICS_CX01

    byte >SYMBOL_GRAPHICS_CX0B
    byte >SYMBOL_GRAPHICS_CX1B
    byte >SYMBOL_GRAPHICS_APPLY_FN
    byte >SYMBOL_GRAPHICS_STACK_FN
    
    byte >SYMBOL_GRAPHICS_LOOP_VAR
    byte >SYMBOL_GRAPHICS_STACK_VAR

;-----------------------------------------------------------------------------------
; the CPU reset vectors

    ORG $FFFA

    .word Reset          ; NMI
    .word Reset          ; RESET
    .word Reset          ; IRQ

    END
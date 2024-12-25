;-----------------------------------
; math functions

FUNC_S01_MULT
            ; naive multiplication 
            ;  - on invocation we clear the accumulator
            ;  - we subtract 1 from arg0 and save in place
            ;  - if arg0 < 0 we return normally
            ;  - otherwise add arg1 to the accumulator
            ;  - we then push an empty frame to the stack
            ;  - next vblank we will re-execute and continue
            lda #0
            sta accumulator_msb
            sta accumulator_lsb
_mult_continue
            ldx eval_frame
            sed
            sec
            lda FRAME_ARG_OFFSET_LSB,x
            sbc #1
            sta FRAME_ARG_OFFSET_LSB,x
            lda FRAME_ARG_OFFSET_MSB,x
            sbc #0
            sta FRAME_ARG_OFFSET_MSB,x
            bcc _mult_return
            clc
            lda FRAME_ARG_OFFSET_LSB - 2,x
            adc accumulator_lsb
            sta accumulator_lsb
            lda FRAME_ARG_OFFSET_MSB - 2,x
            adc accumulator_msb
            and #$0f
            sta accumulator_msb
            cld
            jsr eval_wait
            jmp _mult_continue
_mult_return
            cld
            jmp exec_frame_return

FUNC_S02_ADD
            ldx eval_frame
            sed
            clc
            lda FRAME_ARG_OFFSET_LSB,x
            adc FRAME_ARG_OFFSET_LSB - 2,x
            sta accumulator_lsb
            lda FRAME_ARG_OFFSET_MSB,x
            adc FRAME_ARG_OFFSET_MSB - 2,x
            cld
            and #$0f
            sta accumulator_msb
            jmp exec_frame_return

FUNC_S03_SUB
            ldx eval_frame
            jsr _FUNC_SUB_A0_A1
            sty accumulator_lsb
            and #$0f
            sta accumulator_msb
            jmp exec_frame_return

_FUNC_SUB_A0_A1
            ; subtract a0 from a1 return lsb in y, msb in a
            sed
            sec
            lda FRAME_ARG_OFFSET_LSB,x
            sbc FRAME_ARG_OFFSET_LSB - 2,x
            tay
            lda FRAME_ARG_OFFSET_MSB,x
            sbc FRAME_ARG_OFFSET_MSB - 2,x
            cld
            rts

FUNC_MOD
            ldx eval_frame
_mod_continue
            ldx eval_frame
            jsr _FUNC_SUB_A0_A1         
            bmi _mod_return
            and #$0f
            sta FRAME_ARG_OFFSET_MSB,x
            sty FRAME_ARG_OFFSET_LSB,x
            jsr eval_wait
            jmp _mod_continue
_mod_return            
            lda FRAME_ARG_OFFSET_MSB,x
            sta accumulator_msb
            lda FRAME_ARG_OFFSET_LSB,x
            sta accumulator_lsb
            jmp exec_frame_return

FUNC_S04_DIV
            lda #0
            sta accumulator_lsb
            sta accumulator_msb
_div_continue
            ldx eval_frame
            jsr _FUNC_SUB_A0_A1
            bmi _div_return
            sta FRAME_ARG_OFFSET_MSB,x
            sty FRAME_ARG_OFFSET_LSB,x
            lda #1
            clc
            adc accumulator_lsb
            sta accumulator_lsb
            lda #0
            adc accumulator_msb
            sta accumulator_msb
            jsr eval_wait
            jmp _div_continue
_div_return            
            cld
            jmp exec_frame_return

FUNC_S05_EQUALS
            ; Normalize 
            ldx eval_frame
            lda FRAME_ARG_OFFSET_LSB,x
            cmp FRAME_ARG_OFFSET_LSB - 2,x
            bne _return_false
            lda FRAME_ARG_OFFSET_MSB,x
            cmp FRAME_ARG_OFFSET_MSB - 2,x
            bne _return_false
            beq _return_true

FUNC_S06_GT
            ldx eval_frame
            clc ; intentionally set carry bit so == is false
            lda FRAME_ARG_OFFSET_LSB,x
            sbc FRAME_ARG_OFFSET_LSB - 2,x
            lda FRAME_ARG_OFFSET_MSB,x
            sbc FRAME_ARG_OFFSET_MSB - 2,x
            bcc _return_false
            bcs _return_true

FUNC_S07_LT
            ldx eval_frame
            clc ; intentionally set carry bit so == is false
            lda FRAME_ARG_OFFSET_LSB - 2,x
            sbc FRAME_ARG_OFFSET_LSB,x
            lda FRAME_ARG_OFFSET_MSB - 2,x
            sbc FRAME_ARG_OFFSET_MSB,x
            bcc _return_false
            bcs _return_true

FUNC_S08_AND
            ; and return second arg if first is true
            ldx eval_frame
            lda FRAME_ARG_OFFSET_LSB,x
            ora FRAME_ARG_OFFSET_MSB,x
            beq _return_false 
            ; will return contents of accumulator = second (last) arg
            jmp exec_frame_return

FUNC_S09_OR
            ; short circuit or
            ldx eval_frame
            lda FRAME_ARG_OFFSET_LSB,x
            ora FRAME_ARG_OFFSET_MSB,x
            beq _or_return
            ; first arg was true, return it
            lda FRAME_ARG_OFFSET_LSB,x
            sta accumulator_lsb
            lda FRAME_ARG_OFFSET_MSB,x
            sta accumulator_msb
_or_return
            jmp exec_frame_return

FUNC_S0A_NOT
            ; Normalize 
            ldx eval_frame
            lda FRAME_ARG_OFFSET_LSB,x
            ora FRAME_ARG_OFFSET_MSB,x
            bne _return_false
_return_true
            lda #1
            byte $2c
_return_false
            lda #0
            sta accumulator_lsb
            sta accumulator_msb
            jmp exec_frame_return

FUNC_CAR
            ldy eval_frame
            ldx #FRAME_ARG_OFFSET_LSB,y
            lda HEAP_CAR_ADDR,x
            jmp _fun_car_cdr_eval
FUNC_CDR
            ldy eval_frame
            ldx #FRAME_ARG_OFFSET_LSB,y
            lda HEAP_CDR_ADDR,x
_fun_car_cdr_eval
            bpl _fun_car_cdr_exit
            cmp #$c0
            bpl _fun_car_cdr_copy_symbol
            tax
            lda HEAP_CAR_ADDR,x
            bpl _fun_car_cdr_copy_number
            stx accumulator_cdr
            lda #SYMBOL_QUOTE + $c0
            sta accumulator_car
_fun_car_cdr_exit
            jmp exec_frame_return
_fun_car_cdr_copy_number
            sta accumulator_car
            lda HEAP_CDR_ADDR,x
            sta accumulator_cdr
            jmp exec_frame_return
_fun_car_cdr_copy_symbol
            and #$0f
            sta accumulator_lsb
            lda #0
            sta accumulator_msb
            jmp exec_frame_return

FUNC_CONS
            ; safety: if we have less than two args, make sure last is null ref
            lda #0
            pha
            lda #SYMBOL_QUOTE + $c0
            pha
            ldx eval_frame
            dex
            dex
            jsr alloc_cell
            sty accumulator_car
            beq _cons_null
            dex
            dex
            jsr alloc_cell
            sty accumulator_cdr
            ldx #accumulator_car
            jsr alloc_cell
_cons_null
            sty accumulator_cdr
            lda #SYMBOL_QUOTE + $c0
            sta accumulator_car
            jmp exec_frame_return

FUNC_BEEP
            ; beep 0 = silence, 1-8 note, 9 = buzz
            ;  - we count down from arg1
            ;  - if arg1 == 0 we return normally
            ;  - otherwise load note into audio registers and accumulator
            ldx eval_frame
            ; get timer
            lda FRAME_ARG_OFFSET_LSB - 2,x
            and #$0f ; take least significant digit
            beq _beep_end
            asl      ; x 4
            asl      ;
            sta FRAME_ARG_OFFSET_LSB - 2,x
            ; play sound
            lda FRAME_ARG_OFFSET_LSB,x
            and #$0f
            sta beep_n0             ; accumulator_lsb
            beq _func_beep_setvol
            tax
            cmp #$09 
            bpl _func_beep_buzz
            lda #12
            byte $2c
_func_beep_buzz
            lda #7
            sta AUDC0
            ldy BEEPS_TAB-1,x
            sty AUDF0
_func_beep_setvol
            sta AUDV0
_beep_continue
            ldx eval_frame
            dec FRAME_ARG_OFFSET_LSB - 2,x         ; use as timer
            beq _beep_end
            jsr eval_wait
            jmp _beep_continue
_beep_end
            lda #0
            sta AUDV0
            sta accumulator_msb
            jmp exec_frame_return
  
BEEPS_TAB
            byte 19, 17, 15, 14, 12, 11, 10, 9, 31

FUNC_STACK
            ldx eval_frame
            ldy FRAME_ARG_OFFSET_LSB,x
            jsr sub_repl_find_tower_top
            stx accumulator_lsb
            ldx eval_frame
            ldy FRAME_ARG_OFFSET_LSB-2,x
            jsr sub_repl_find_tower_top
            bmi _func_stack_legal_move
_func_stack_check_base
            cpx accumulator_lsb
            beq _func_stack_illegal_move  
            bpl _func_stack_legal_move  
            txa
            ldx eval_frame
            ldy FRAME_ARG_OFFSET_LSB,x
            ldx accumulator_lsb
            sta accumulator_lsb
_func_stack_legal_move
            txa
            bmi _func_stack_save
            lda tower_disc_0,x
            lsr
            and #$f8
_func_stack_save
            ora TOWER_STACK_MASK,y
            ldx accumulator_lsb
            bmi _func_stack_illegal_move
            sta tower_disc_0,x
            byte $2C ; SPACE skip next instruction
_func_stack_illegal_move
            lda #0 ; return 0 if illegal move, 1 if legal
            jmp _func_jkcx_exit

FUNC_JX
            ldy eval_frame
            ldx FRAME_ARG_OFFSET_LSB,y
            lda player_input,x
_func_jkcx_exit
            ; write a to accumulator
            sed
            clc
            adc #$0
            cld
            sta accumulator_lsb
            lda #0
            sta accumulator_msb
            jmp exec_frame_return

_func_kx_loop
            sta accumulator_lsb ; TRICKY: song and calc mode both monitor the accumulator
            sta accumulator_msb ; TRICKY: song and calc mode both monitor the accumulator
            lda FRAME_ARG_OFFSET_LSB-2,y ; read second arg
            ora FRAME_ARG_OFFSET_MSB-2,y
            beq _func_kx_input
            jsr eval_wait
FUNC_KX
            ldy eval_frame
            ldx FRAME_ARG_OFFSET_LSB,y
            lda player_input_latch,x
            beq _func_kx_loop
_func_kx_input
            ldy #0
            sty player_input_latch,x
            beq _func_jkcx_exit

FUNC_REFLECT
            ; PONG reflection
            lda game_bl_dir
            bpl _func_jkcx_exit            

FUNC_CX
            sta CXCLR ; clear collision and run one cycle
            jsr eval_wait
            ldy #8
            ldx game_bl_dir
            lda game_bl_x
            beq _func_cx_wall_l
            cmp #$7f
            beq _func_cx_wall_r
            lda game_bl_y            
            beq _func_cx_wall_d
            cmp #$1f
            beq _func_cx_wall_u
_func_cx_check
            lda #4
            bit CXPPMM
            bmi _func_jkcx_exit
            lsr
            bit CXP1FB
            bvs _func_cx_reflect
            lsr
            bit CXP0FB
            bvs _func_cx_reflect
            lsr
            beq _func_jkcx_exit 
_func_cx_reflect
            ; calc pong reflection
            tay
            lda game_bl_y
            sec
            sbc game_p0_y-1,y ; SPACE: y is 1 or 2
            and #$07
            tax
            lda REFL_UD,x
            clc
            adc X_DIR+1,y
_func_reflect_save          
            sta game_bl_dir
            tya
            bpl _func_jkcx_exit
_func_cx_wall_l
            lda #3
            byte $2c
_func_cx_wall_r
            lda #1
            clc
            adc REPL_KEY_ROW-1,x
            adc REPL_KEY_ROW-1,x
            adc REPL_KEY_ROW-1,x
            bpl _func_reflect_save
_func_cx_wall_u
            lda #8
            byte $2c
_func_cx_wall_d
            lda #2
            clc
            adc X_DIR-1,x
            bpl _func_reflect_save

REFL_UD
    byte 8, 8, 8, 5, 5, 2, 2, 2

FUNC_MOVE
            ; get player
            ldx eval_frame
            lda FRAME_ARG_OFFSET_LSB,x
            and #$03 ; SAFETY: unsafe access if > 2
            tay
            txa
            tsx
            stx tmp_eval_stack
            sec 
            sbc tmp_eval_stack
            cmp #7 ; check if 3+ args
            bpl FUNC_MOVE_XY
            lda accumulator_lsb
            and #$0f ; ignore bcd values > 9; SAFETY: unsafe access if not a BCD value
            beq _func_move_exit
            cpy #2
            bne _skip_save_bl_dir
            sta game_bl_dir
_skip_save_bl_dir
            tax
            lda X_DIR-1,x
            clc
            adc game_p0_x,y
            and #$7f
            sta game_p0_x,y
            lda Y_DIR-1,x
            clc
            adc game_p0_y,y
            and #$1f
            sta game_p0_y,y
            ; set player direction
            cpy #2
            bpl _func_move_exit
            lda X_DIR-1,x
            asl
            lda game_px_shape
            beq _func_move_exit
            ora REFL_X,y
            bcs _skip_clear_refl_bit
            eor REFL_X,y
_skip_clear_refl_bit
            sta game_px_shape
            bpl _func_move_exit ; should always be trie
FUNC_MOVE_XY
            ; move xy
            ldx eval_frame
            jsr _conv_bcd16
            and #$7f
            sta game_p0_x,y
            dex
            dex
            jsr _conv_bcd16
            and #$1f
            sta game_p0_y,y
_func_move_exit
            jmp exec_frame_return
_conv_bcd16
            lda FRAME_ARG_OFFSET_LSB-2,x
            and #$0f
            asl FRAME_ARG_OFFSET_MSB-2,x
            beq _conv_bcd16_lsb
            adc #100
_conv_bcd16_lsb            
            sta accumulator_lsb
            lda FRAME_ARG_OFFSET_LSB-2,x
            and #$f0
            lsr             
            sta tmp_eval_stack
            lsr
            lsr
            adc tmp_eval_stack
            adc accumulator_lsb            
            rts
    
FUNC_SHAPE
            ; get player and set shape
            lda accumulator_lsb
            and #$01
            sta game_px_shape
            jmp exec_frame_return

FUNC_DEC
            ; subtract 1 from accumulator
            sed 
            lda accumulator_lsb
            sec
            sbc #1
            sta accumulator_lsb
            lda accumulator_msb
            sbc #0
            sta accumulator_msb
            cld
            jmp exec_frame_return
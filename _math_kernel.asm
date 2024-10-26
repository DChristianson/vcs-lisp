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
            ldy #0
            sty accumulator_lsb
            lda FRAME_ARG_OFFSET_LSB,x
            cmp FRAME_ARG_OFFSET_LSB - 2,x
            bne _equals_return
            lda FRAME_ARG_OFFSET_MSB,x
            cmp FRAME_ARG_OFFSET_MSB - 2,x
            bne _equals_return
            ldy #$01 ; BUGBUG: TRUE
_equals_return
            sty accumulator_msb
            jmp exec_frame_return

FUNC_S06_GT
            ldx eval_frame
            ldy #0
            sty accumulator_lsb
            clc ; intentionally set carry bit so == is false
            lda FRAME_ARG_OFFSET_LSB,x
            sbc FRAME_ARG_OFFSET_LSB - 2,x
            lda FRAME_ARG_OFFSET_MSB,x
            sbc FRAME_ARG_OFFSET_MSB - 2,x
            bcc _gt_return
            ldy #$01 ; BUGBUG: TRUE
_gt_return
            sty accumulator_msb
            jmp exec_frame_return

FUNC_S07_LT
            ldx eval_frame
            ldy #0
            sty accumulator_lsb
            clc ; intentionally set carry bit so == is false
            lda FRAME_ARG_OFFSET_LSB - 2,x
            sbc FRAME_ARG_OFFSET_LSB,x
            lda FRAME_ARG_OFFSET_MSB - 2,x
            sbc FRAME_ARG_OFFSET_MSB,x
            bcc _lt_return
            ldy #$01 ; BUGBUG: TRUE
_lt_return
            sty accumulator_msb
            jmp exec_frame_return

FUNC_S08_AND
            ldx eval_frame
            ldy #0
            sty accumulator_lsb
            lda FRAME_ARG_OFFSET_LSB,x
            ora FRAME_ARG_OFFSET_MSB,x
            beq _and_return
            lda FRAME_ARG_OFFSET_LSB - 2,x
            ora FRAME_ARG_OFFSET_MSB - 2,x
            beq _and_return
            ldy #$01 ; BUGBUG: TRUE
_and_return
            sty accumulator_msb
            jmp exec_frame_return

FUNC_S09_OR
            ldx eval_frame
            ldy #0
            sty accumulator_lsb
            ldy #$01 ; BUGBUG: TRUE
            lda FRAME_ARG_OFFSET_LSB,x
            ora FRAME_ARG_OFFSET_LSB - 2,x
            bne _or_return
            lda FRAME_ARG_OFFSET_MSB,x
            ora FRAME_ARG_OFFSET_MSB - 2,x
            bne _or_return
            ldy #0
_or_return
            sty accumulator_msb
            jmp exec_frame_return

FUNC_S0A_NOT
            ; Normalize 
            ldx eval_frame
            ldy #0
            sty accumulator_lsb
            lda FRAME_ARG_OFFSET_LSB,x
            bne _not_return
            lda FRAME_ARG_OFFSET_MSB,x
            bne _not_return
            ldy #$01 ; BUGBUG: TRUE
_not_return
            sty accumulator_msb
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
            ; beep
            ;  - we count down from arg1
            ;  - if arg1 == 0 we return normally
            ;  - otherwise load note into audio registers and accumulator
            ldx eval_frame
            ; get timer
            lda FRAME_ARG_OFFSET_LSB - 2,x
            and #$0f ; take least significant digit
            asl      ; x 4
            asl      ;
            sta beep_t0
            beq _beep_end
            ; play sound
            lda #4
            sta AUDC0
            lda #8
            sta AUDV0
            lda FRAME_ARG_OFFSET_MSB,x
            sta accumulator_msb
            lda FRAME_ARG_OFFSET_LSB,x
            sta accumulator_lsb
            and #$0f ; modulo frequency            
            sta AUDF0
            sta beep_f0            
_beep_continue
            dec beep_t0
            beq _beep_end
            jsr eval_wait
            jmp _beep_continue
_beep_end
            lda #0
            sta AUDV0
            sta beep_f0
            jmp exec_frame_return

FUNC_STACK
            ldx eval_frame
            ldy FRAME_ARG_OFFSET_LSB,x
            jsr sub_repl_find_tower_top
            cpx #0
            bmi _func_stack_illegal_move
            stx accumulator_lsb
            ldx eval_frame
            ldy FRAME_ARG_OFFSET_LSB-2,x
            jsr sub_repl_find_tower_top
            cpx #0
            bpl _func_stack_check_base
            lda #$80
            jmp _func_stack_save
_func_stack_check_base
            cpx accumulator_lsb
            bmi _func_stack_illegal_move  
            lda tower_disc_0,x
            lsr
            and #$f8
_func_stack_save
            ora TOWER_STACK_MASK,y
            ldx accumulator_lsb
            sta tower_disc_0,x
_func_stack_illegal_move
            jmp exec_frame_return

FUNC_J0
            ldx #0
            byte #$2c ; skip next 2 bytes
FUNC_J1
            ldx #1
_func_jx_store
            lda player_input,x
            eor #$8f ; invert
            sta accumulator_lsb
            lda #0
            sta accumulator_msb
            jmp exec_frame_return

FUNC_POS_P0
            ldy #game_p0_x
            byte #$2c ; skip next 2 bytes
FUNC_POS_P1
            ldy #game_p1_x
_func_pos_store
            ldx eval_frame
            jsr sub_store_acc
            dex
            dex
            iny
            iny
            jsr sub_store_acc            
            jmp exec_frame_return

FUNC_POS_BL
            ldx eval_frame
            ldy #game_bl_x
            jsr sub_store_acc
            ldy #game_bl_y
            jsr sub_store_acc            
            jmp exec_frame_return

sub_store_acc
            lda FRAME_ARG_OFFSET_MSB,x
            and #$0f
            sta accumulator_lsb
            asl
            asl
            clc
            adc accumulator_lsb
            asl
            lda FRAME_ARG_OFFSET_LSB,x
            lsr
            lsr
            lsr
            lsr
            clc
            adc accumulator_lsb
            sta accumulator_lsb
            asl
            asl
            clc
            adc accumulator_lsb
            sta accumulator_lsb
            lda FRAME_ARG_OFFSET_LSB,x
            and #$0f
            adc accumulator_lsb
            sta #0,y
            rts

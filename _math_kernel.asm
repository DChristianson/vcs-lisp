


sub_fmt
            lda #<SYMBOL_GRAPHICS_S1E_HASH
            sta repl_s1_addr
            lda #<SYMBOL_GRAPHICS_S1F_BLANK
            sta repl_s5_addr
            WRITE_DIGIT_LO repl_fmt_arg+1, repl_s2_addr ;16 15
            WRITE_DIGIT_HI repl_fmt_arg, repl_s3_addr   ;14 29
            WRITE_DIGIT_LO repl_fmt_arg, repl_s4_addr   ;16 45
            rts

;-----------------------------------
; function kernels

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
            sed
            sec
            lda FRAME_ARG_OFFSET_LSB,x
            sbc FRAME_ARG_OFFSET_LSB - 2,x
            sta accumulator_lsb
            lda FRAME_ARG_OFFSET_MSB,x
            sbc FRAME_ARG_OFFSET_MSB - 2,x
            cld
            and #$0f
            sta accumulator_msb
            jmp exec_frame_return

FUNC_S04_DIV
            lda #0
            sta accumulator_lsb
            sta accumulator_msb
            ldx eval_frame
            ; BUGBUG: code as a rational
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
            ldy #$10
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
            ldy #$10
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
            ldy #$10
_lt_return
            sty accumulator_msb
            jmp exec_frame_return

FUNC_S08_AND
            ; Normalize 
            ldx eval_frame
            ldy #0
            sty accumulator_lsb
            lda FRAME_ARG_OFFSET_LSB,x
            ora FRAME_ARG_OFFSET_MSB,x
            beq _and_return
            lda FRAME_ARG_OFFSET_LSB - 2,x
            ora FRAME_ARG_OFFSET_MSB - 2,x
            bne _and_return
            ldy #$10
_and_return
            sty accumulator_msb
            jmp exec_frame_return

FUNC_S09_OR
            ; Normalize 
            ldx eval_frame
            ldy #0
            sty accumulator_lsb
            ldy #$10
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
            ldy #$10
_not_return
            sty accumulator_msb
            jmp exec_frame_return

FUNC_S0F_BEEP
            ; beep
            ;  - we subtract 1 from arg1 and save in place
            ;  - if arg1 < 0 we return normally
            ;  - otherwise load note into audio registers
_beep_continue
            ldx eval_frame
            sed
            sec
            lda FRAME_ARG_OFFSET_LSB - 2,x
            sbc #1
            sta FRAME_ARG_OFFSET_LSB - 2,x
            lda FRAME_ARG_OFFSET_MSB - 2,x
            sbc #0
            sta FRAME_ARG_OFFSET_MSB - 2,x
            cld
            bcc _beep_end
            ; play sound
            lda #4
            sta AUDC0
            lda #8
            sta AUDV0
            lda FRAME_ARG_OFFSET_LSB,x
            sta AUDF0
            jsr eval_wait
            jmp _beep_continue
_beep_end
            lda #0
            sta AUDV0
            jmp exec_frame_return


FUNC_S0B_IF ; BUGBUG this is a special form
            jmp exec_frame_return ; SPACE: don't need to copy this around

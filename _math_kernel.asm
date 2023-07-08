


sub_fmt
            lda #>SYMBOL_GRAPHICS_S14_ZERO
            sta repl_s0_addr + 1
            sta repl_s1_addr + 1
            sta repl_s2_addr + 1
            sta repl_s3_addr + 1
            sta repl_s4_addr + 1
            sta repl_s5_addr + 1
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
            lda #0
            sta accumulator_lsb
            sta accumulator_msb
            ldx eval_frame
            ; BUGBUG: code as a continuation
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

FUNC_S0B_IF ; BUGBUG this is a special form
            jmp exec_frame_return
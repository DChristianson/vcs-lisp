


sub_fmt
            ; http://forum.6502.org/viewtopic.php?f=2&t=4894 
            lda #0
            sta repl_bcd 
            sta repl_bcd + 1
            sta repl_bcd + 2
            lda repl_fmt_arg + 1 ; BUGBUG readability / endianness changes
            and #$3c
            beq _sub_fmt_done
            lsr
            lsr
            sec
            sbc #4
            tax ; put exponent in x
            lda repl_fmt_arg + 1
            and #$03
            ora #$04
            sta repl_fmt_arg + 1
            ; skip first 5 bits
            ldy #4
_sub_bcd_advance
            asl repl_fmt_arg
            rol repl_fmt_arg + 1
            dey
            bpl _sub_bcd_advance
            sed ;decimal flag
_sub_fmt_loop
            asl repl_fmt_arg
            rol repl_fmt_arg + 1
            lda repl_bcd
            adc repl_bcd
            sta repl_bcd
            lda repl_bcd + 1
            adc repl_bcd + 1
            sta repl_bcd + 1
            dex
            bpl _sub_fmt_loop
            cld
_sub_fmt_done
            lda #>SYMBOL_GRAPHICS_S14_ZERO
            sta repl_s0_addr
            sta repl_s1_addr
            sta repl_s2_addr
            sta repl_s3_addr
            sta repl_s4_addr
            sta repl_s5_addr
            WRITE_DIGIT_HI repl_bcd+2, repl_s0_addr ;14 38
            WRITE_DIGIT_LO repl_bcd+2, repl_s1_addr ;16 54
            WRITE_DIGIT_HI repl_bcd+1, repl_s2_addr ;14 68
            WRITE_DIGIT_LO repl_bcd+1, repl_s3_addr ;16 15
            WRITE_DIGIT_HI repl_bcd, repl_s4_addr   ;14 29
            WRITE_DIGIT_LO repl_bcd, repl_s5_addr   ;16 45
            rts


FUNC_S03_SUB
            ; negate arg1 and do add
            ldx eval_frame
            lda FRAME_ARG_OFFSET_MSB - 2,x
            eor #$40
            sta FRAME_ARG_OFFSET_MSB - 2,x
            jmp _sub_add 

_sub_add_zero_arg0
            lda FRAME_ARG_OFFSET_MSB - 2,x
            sta accumulator_msb
            lda FRAME_ARG_OFFSET_LSB - 2,x
            sta accumulator_lsb
            jmp exec_frame_return
_sub_add_zero_arg1
            lda FRAME_ARG_OFFSET_MSB,x
            sta accumulator_msb
            lda FRAME_ARG_OFFSET_LSB,x
            sta accumulator_lsb
            jmp exec_frame_return
_sub_add_swap
            ; do swap
            ; BUGBUG use loop or sub?
            lda FRAME_ARG_OFFSET_MSB,x
            ldy FRAME_ARG_OFFSET_MSB - 2,x
            sta FRAME_ARG_OFFSET_MSB - 2,x
            sty FRAME_ARG_OFFSET_MSB,x
            lda FRAME_ARG_OFFSET_LSB,x
            ldy FRAME_ARG_OFFSET_LSB - 2,x
            sta FRAME_ARG_OFFSET_LSB - 2,x
            sty FRAME_ARG_OFFSET_LSB,x
            lda eval_tmp_exp1
            ldy eval_tmp_exp0
            sty eval_tmp_exp1
            sta eval_tmp_exp0
            jmp _sub_add_normalize
FUNC_S02_ADD
            ; BUGBUG should work in theory
            ldx eval_frame
_sub_add
            ; recover exponent
            lda FRAME_ARG_OFFSET_MSB,x
            and #$3c 
            beq _sub_add_zero_arg0
            lsr
            lsr
            sta eval_tmp_exp0
            lda FRAME_ARG_OFFSET_MSB - 2,x
            and #$3c
            beq _sub_add_zero_arg1
            lsr
            lsr
            sta eval_tmp_exp1
            ; recover mantissa
            lda FRAME_ARG_OFFSET_MSB,x
            and #$43
            ora #$04
            sta FRAME_ARG_OFFSET_MSB,x
            cmp #$40
            bmi _sub_add_skip_negate_arg0
            eor #$bf
            sta FRAME_ARG_OFFSET_MSB,x
            lda FRAME_ARG_OFFSET_LSB,x
            eor #$ff
            clc
            adc #1
            sta FRAME_ARG_OFFSET_LSB,x
            lda FRAME_ARG_OFFSET_MSB,x
            adc #0
            sta FRAME_ARG_OFFSET_MSB,x
_sub_add_skip_negate_arg0
            lda FRAME_ARG_OFFSET_MSB - 2,x
            and #$43
            ora #$04
            sta FRAME_ARG_OFFSET_MSB - 2,x
            cmp #$40
            bmi _sub_add_skip_negate_arg1
            eor #$bf
            sta FRAME_ARG_OFFSET_MSB - 2,x
            lda FRAME_ARG_OFFSET_LSB - 2,x
            eor #$ff
            clc
            adc #1
            sta FRAME_ARG_OFFSET_LSB - 2,x
            lda FRAME_ARG_OFFSET_MSB - 2,x
            adc #0
            sta FRAME_ARG_OFFSET_MSB - 2,x
_sub_add_skip_negate_arg1
            ldy eval_tmp_exp1
_sub_add_normalize
            cpy eval_tmp_exp0
            beq _sub_add_skipswap
            ; swap / normalize exponents
            bcs _sub_add_swap
            ; do normalize
            lda #$80  
            adc FRAME_ARG_OFFSET_MSB - 2,x ; set carry bit if negative
            ror FRAME_ARG_OFFSET_MSB - 2,x
            ror FRAME_ARG_OFFSET_LSB - 2,x
            iny
            jmp _sub_add_normalize
_sub_add_skipswap
            ; perform add
            clc
            lda FRAME_ARG_OFFSET_LSB,x
            adc FRAME_ARG_OFFSET_LSB - 2,x
            sta accumulator_lsb
            lda FRAME_ARG_OFFSET_MSB,x
            adc FRAME_ARG_OFFSET_MSB - 2,x
            sta accumulator_msb
            ; check for zero
            bne _sub_add_skip_zero
            cmp accumulator_lsb
            beq _sub_add_done
_sub_add_skip_zero
            ; check for overflow
            and #$08
            beq _sub_add_skip_overflow
            inc eval_tmp_exp0
            lsr accumulator_msb
            ror accumulator_lsb
_sub_add_skip_overflow
            ; check for underflow
            lda #$04
_sub_add_underflow_loop
            bit accumulator_msb
            bne _sub_add_skip_underflow 
            asl accumulator_lsb
            rol accumulator_msb
            dec eval_tmp_exp0
            jmp _sub_add_underflow_loop
_sub_add_skip_underflow
            ; store exponent
            lda accumulator_msb
            and #$03
            sta accumulator_msb
            lda eval_tmp_exp0
            asl
            asl
            ora accumulator_msb
            sta accumulator_msb
            ; done
_sub_add_done
            jmp exec_frame_return

;-----------------------------------
; function kernels

FUNC_S01_MULT
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
FUNC_S04_DIV
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
FUNC_S05_EQUALS
    ; TODO: BOGUS implementation
    ldx eval_frame
    ldy #0
    lda FRAME_ARG_OFFSET_LSB,x
    cmp FRAME_ARG_OFFSET_LSB - 2,x
    bne _equals_return
    lda FRAME_ARG_OFFSET_MSB,x
    cmp FRAME_ARG_OFFSET_MSB - 2,x
    bne _equals_return
    ldy #$7f
_equals_return
    sty accumulator_lsb
    sty accumulator_msb
    jmp exec_frame_return
FUNC_S06_GT
FUNC_S07_LT
FUNC_S08_AND
FUNC_S09_OR
FUNC_S0A_NOT
FUNC_S0B_IF
            jmp exec_frame_return



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
FUNC_S02_ADD
    ldx eval_frame
    lda -2,x
    clc
    adc -4,x
    sta accumulator
    lda -1,x
    adc -3,x
    sta accumulator+1
    jmp exec_frame_return
FUNC_S03_SUB
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
    lda -1,x
    sec
    sbc -3,x
    sta accumulator
    lda -2,x
    sbc -4,x
    sta accumulator+1
    jmp exec_frame_return
FUNC_S06_GT
FUNC_S07_LT
FUNC_S08_AND
FUNC_S09_OR
FUNC_S0A_NOT
FUNC_S0B_IF
            jmp exec_frame_return
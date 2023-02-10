repl_update
            ; check fire button
            lda INPT4
            bmi _repl_update_skip_eval
            lda #GAME_STATE_EVAL
            sta game_state
_repl_update_skip_eval
            ; check indent level
            lda #$80
            lda SWCHA
            rol
            bcs _repl_update_skip_right
            lda #1
            jmp _repl_update_set_indent
_repl_update_skip_right
            rol
            bcs _repl_update_skip_left
            lda #-1
            jmp _repl_update_set_indent
_repl_update_skip_left
            lda #0
_repl_update_set_indent
            clc
            adc repl_cursor
            sta repl_cursor
            ; convert accumulator to BCD
            ; http://forum.6502.org/viewtopic.php?f=2&t=4894 
            sed
            lda #0
            sta repl_bcd
            sta repl_bcd+1
            sta repl_bcd+2
            lda accumulator
            sta repl_tmp_accumulator
            lda accumulator+1
            sta repl_tmp_accumulator+1
            ldx #16
_repl_update_bin2bcd16_bit
            asl repl_tmp_accumulator
            rol repl_tmp_accumulator + 1
            lda repl_bcd
            adc repl_bcd
            sta repl_bcd
            lda repl_bcd+1
            adc repl_bcd+1
            sta repl_bcd+1
            lda repl_bcd+2
            adc repl_bcd+2
            sta repl_bcd+2
            dex
            bne _repl_update_bin2bcd16_bit
            cld
            ; prep symbol graphics
            ldy #(DISPLAY_COLS - 1) * 2
_prep_repl_loop
            lda #>SYMBOL_GRAPHICS_S00_MULT
            sta repl_gx_addr + 1,y
            dey
            dey
            bpl _prep_repl_loop
            ; done
            jmp update_return

;----------------------
; Repl display
;

repl_draw

header
            ldx #HEADER_HEIGHT
_header_loop
            sta WSYNC
            dex
            bpl _header_loop

            ; PROMPT
            ; draw repl cell tree
prompt
            lda repl_cursor
            and #$f8
            sta repl_level
            lda #(PROMPT_HEIGHT * 76 / 64)
            sta TIM64T
            lda repl
            pha ; push repl to stack
            tsx ; 
prompt_next_line
            ; lock missiles to players
            lda #2
            sta RESMP0
            sta RESMP1
            ; load repl level
            sta WSYNC              ; --
            lda repl_level         ;3    3
            sec                    ;2    5
_prompt_repos_loop
            sbc #15                ;2    7
            bcs _prompt_repos_loop ;2/3  9
            tay                    ;2   11
            lda LOOKUP_STD_HMOVE,y ;4   15
            sta HMP0               ;3   18
            sta HMP1               ;3   21
            sta RESP0              ;3   24
            sta RESP1              ;3   27
            sta WSYNC              ;--
            sta HMOVE              ;3    3
            lda #WHITE             ;2    5
            sta COLUP0             ;3    8
            sta COLUP1             ;3   11
            lda #0                 ;2   13
            ldx #$10               ;2   15
            ldy #$60               ;2   17
            SLEEP 10               ;10  27
            sta RESMP0             ;3   30
            sta RESMP1             ;3   33
            sta HMP0               ;3   36
            stx HMP1               ;3   39
            sty HMM0               ;3   42
            lda #$70               ;2   44
            sta HMM1               ;3   47
            SLEEP 13               ;13  60
            sta HMOVE              ;3   63

prompt_encode
            pla
            bne _prompt_encode_start
            jmp prompt_done
_prompt_encode_start
            ldy #(DISPLAY_COLS - 1) * 2
_prompt_encode_loop
            tax
            lda HEAP_CAR_ADDR,x ; read car
            bpl _prompt_encode_clear_dec ; BUGBUG: handle #
            cmp #$40
            bpl _prompt_encode_recurse
_prompt_encode_addchar
            stx repl_cell_addr ; push down current cell
            tax
            lda LOOKUP_SYMBOL_GRAPHICS,x
            sta repl_gx_addr,y
            ldx repl_cell_addr 
            lda HEAP_CDR_ADDR,x ; read cdr
            beq _prompt_encode_clear_dec
            dey
            dey
            bpl _prompt_encode_loop
            ; list is too long, we need to indent
            ; push next address on the stack
            pha
            lda #8 ; BUGBUG: may not be enough
            clc
            adc repl_level
            pha
            ldx #0            
            jmp prompt_encode_end
_prompt_encode_recurse
            ; we need to recurse so we need push t
            ; contents of the cdr
            ; contents of the car
            sta repl_cell_addr ; set car aside
            lda HEAP_CDR_ADDR,x 
            pha 
            lda #8 ; BUGBUG: may not be enough
            clc
            adc repl_level
            pha
            lda repl_cell_addr
            pha
            lda #8 ; BUGBUG: duplicate code
            clc
            adc repl_level
            pha
            jmp _prompt_encode_clear
_prompt_encode_clear_dec
            dey
            dey
            bpl _prompt_encode_clear
            ldx #0
            jmp prompt_encode_end
_prompt_encode_clear
            tya
            lsr
            tax
            lda #<SYMBOL_GRAPHICS_EMPTY
_prompt_encode_clear_loop
            sta repl_gx_addr,y
            dey
            dey
            bpl _prompt_encode_clear_loop
prompt_encode_end
            lda DISPLAY_COLS_NUSIZ0,x
            ora #$30
            sta NUSIZ0 
            lda DISPLAY_COLS_NUSIZ1,x
            ora #$30
            sta NUSIZ1              
            sta WSYNC ; shim
            lda #2
            sta ENAM0
            sta ENAM1
            sta WSYNC ; shim
            lda DISPLAY_COLS_NUSIZ0,x    ;4    4
            sta NUSIZ0                   ;3    7
            lda DISPLAY_COLS_NUSIZ1,x    ;4   11
            sta NUSIZ1                   ;3   14
            ldy #CHAR_HEIGHT - 1         ;2   24
            lda #1                       ;2   26
            bit clock                    ;3   29
            bne prompt_draw_odd    
prompt_draw_even
            sta WSYNC
_prompt_draw_even_loop
_prompt_draw_even_loop_e
            SLEEP 2                      ;2    2/44
_prompt_draw_even_loop_d
            SLEEP 3                      ;3    5
_prompt_draw_even_loop_c
            SLEEP 3                      ;3    8
_prompt_draw_even_loop_b
            SLEEP 2                      ;2    10/52
_prompt_draw_even_loop_a
            SLEEP 3                      ;3    13
_prompt_draw_even_loop_9
            SLEEP 3                      ;3    16
_prompt_draw_even_loop_8
            SLEEP 2                      ;2    18/60
_prompt_draw_even_loop_7
            SLEEP 3                      ;3    21
_prompt_draw_even_loop_6
            SLEEP 3                      ;3    24
_prompt_draw_even_loop_5
            SLEEP 2                      ;2    26/68
_prompt_draw_even_loop_4
            SLEEP 3                      ;3    29/71
_prompt_draw_even_loop_3
            SLEEP 3                      ;3    32/74
_prompt_draw_even_loop_2
            SLEEP 2                      ;2    34/--
_prompt_draw_even_loop_1
            SLEEP 3                      ;3    37/3
_prompt_draw_even_loop_0
            SLEEP 3                      ;3    6
            lda (repl_s0_addr),y         ;5   11
            sta GRP0                     ;3   14
            lda #0                       ;2   16
            sta GRP1                     ;3   19
            lda (repl_s2_addr),y         ;5   24
            sta GRP0                     ;3   27
            lda (repl_s4_addr),y         ;5   32
            sta GRP0                     ;3   35
            dey                          ;2   37
            SLEEP 39                     ;39  76
            SLEEP 4                      ;4    4
            lda #0                       ;2    6
            sta GRP0                     ;3    9
            lda (repl_s1_addr),y         ;5   14
            sta GRP1                     ;3   17
            SLEEP 4                      ;4   21
            lda (repl_s3_addr),y         ;5   26
            sta GRP1                     ;3   29
            lda (repl_s5_addr),y         ;5   34
            sta GRP1                     ;3   37
            dey                          ;2   39
            bpl _prompt_draw_even_loop   ;2/3 41/42
            jmp prompt_draw_end
prompt_draw_odd
_prompt_draw_odd_loop
            lda repl_level
            sec
            sta WSYNC                  ;--
_prompt_draw_odd_i_0
            sbc #15                    ;2    2
            bcs _prompt_draw_odd_i_0   ;2    4
            lda #0                     ;2    6
            sta GRP0                   ;3    9
            lda (repl_s1_addr),y       ;5   14
            sta GRP1                   ;3   17
            lda (repl_s3_addr),y       ;5   22
            sta GRP1                   ;3   25
            lda (repl_s5_addr),y       ;5   30
            sta GRP1                   ;3   33
            dey                        ;2   38
            lda repl_level
            sec
            sta WSYNC                  ;--
_prompt_draw_odd_i_1
            sbc #15                    ;2    2
            bcs _prompt_draw_odd_i_1   ;2    4
            lda (repl_s0_addr),y       ;5   14
            sta GRP0                   ;3   17
            lda #0                     ;2    6
            sta GRP1                   ;3    9
            lda (repl_s2_addr),y       ;5   23
            sta GRP0                   ;3   26
            lda (repl_s4_addr),y       ;5   31
            sta GRP0                   ;3   34
            dey                        ;2   35
            bpl _prompt_draw_odd_loop ;2/3  37/38
            sta WSYNC
prompt_draw_end
            lda DISPLAY_COLS_NUSIZ0,x
            ora #$30
            sta NUSIZ0 
            lda DISPLAY_COLS_NUSIZ1,x
            ora #$30
            sta NUSIZ1              
            sta WSYNC
            lda #0
            sta GRP0
            sta GRP1
            sta ENAM0
            sta ENAM1
            ; load stack + 1
            tsx 
            cpx #$ff
            ; if stack at ff, we are done
            beq prompt_done
            pla
            sta repl_level
            jmp prompt_next_line
prompt_done
            jsr waitOnTimer

            
; ACCUMULATOR
accumulator_draw
            lda #3
            sta NUSIZ0
            sta NUSIZ1
            WRITE_DIGIT_HI repl_bcd+2, repl_s0_addr
            WRITE_DIGIT_LO repl_bcd+2, repl_s1_addr
            WRITE_DIGIT_HI repl_bcd+1, repl_s2_addr
            WRITE_DIGIT_LO repl_bcd+1, repl_s3_addr
            WRITE_DIGIT_HI repl_bcd, repl_s4_addr
            WRITE_DIGIT_LO repl_bcd, repl_s5_addr
            sta WSYNC
            ldy #CHAR_HEIGHT - 1
            lda #1
            bit clock
            bne accumulator_draw_odd
accumulator_draw_even
_accumulator_draw_even_loop
            sta WSYNC                  ;--
            lda #0                     ;2    2
            sta GRP1                   ;3    5
            lda (repl_s0_addr),y       ;5   10
            sta GRP0                   ;3   13
            SLEEP 5                    ;5   18
            lda (repl_s2_addr),y       ;5   23
            sta GRP0                   ;3   26
            lda (repl_s4_addr),y       ;5   31
            sta GRP0                   ;3   33
            dey                        ;2   35
            sta WSYNC                  ;--
            lda #0                     ;2    2
            sta GRP0                   ;3    5
            lda (repl_s1_addr),y       ;5   10
            sta GRP1                   ;3   13
            SLEEP 8                    ;8   21
            lda (repl_s3_addr),y       ;5   26
            sta GRP1                   ;3   29
            lda (repl_s5_addr),y       ;5   34
            sta GRP1                   ;3   37
            dey                        ;2   39
            bpl _accumulator_draw_even_loop ;2/3 41/42
            jmp accumulator_draw_end
accumulator_draw_odd
_accumulator_draw_odd_loop
            sta WSYNC                  ;--
            lda #0                     ;2    2
            sta GRP0                   ;3    5
            lda (repl_s1_addr),y       ;5   10
            sta GRP1                   ;3   13
            SLEEP 8                    ;5   18
            lda (repl_s3_addr),y       ;5   23
            sta GRP1                   ;3   26
            lda (repl_s5_addr),y       ;5   31
            sta GRP1                   ;3   34
            dey                        ;2   36
            sta WSYNC                  ;--
            lda #0                     ;2    2
            sta GRP1                   ;3    5
            lda (repl_s0_addr),y       ;5   10
            sta GRP0                   ;3   13
            SLEEP 5                    ;2   15
            lda (repl_s2_addr),y       ;5   20
            sta GRP0                   ;3   23
            lda (repl_s4_addr),y       ;5   28
            sta GRP0                   ;3   31
            dey                        ;2   33
            bpl _accumulator_draw_odd_loop ;2/3 46/47
            jmp accumulator_draw_end
accumulator_draw_end
            sta WSYNC
            lda #0
            sta NUSIZ0
            sta NUSIZ1
            sta PF1
            sta PF2
            sta GRP0
            sta GRP1

            ; FREEBAR
freebar
            ldy #0
            ldx free
_free_bar_loop
            lda HEAP_CDR_ADDR,x
            bpl _free_bar_len
            iny
            tax
            jmp _free_bar_loop
_free_bar_len
            tya
            sec
            sbc #16
            bcs _free_gt_16
            adc #16 
            ldx #00
            stx free_pf3 
            stx free_pf4 
            jmp _free_half
_free_gt_16
            ldx #$ff
            stx free_pf1
            stx free_pf2
            ldx #2
_free_half
            sec
            sbc #8
            bcs _free_gt_8
            adc #8
            ldy #0
            sty free_pf2,x
            jmp _free_quarter
_free_gt_8
            ldy #$ff
            sty free_pf1,x
            inx
_free_quarter
            tay
            lda FREE_LOOKUP_TABLE,y
            sta free_pf1,x

            ldx #4
_free_draw_loop
            sta WSYNC
            lda #$ee         ;2   2
            sta GRP0        ;3   5
            lda #$ee         ;2   7
            sta GRP1        ;3  10
            lda free_pf1    ;3  13
            sta PF1         ;3  16
            lda free_pf2    ;3  19
            sta PF2         ;3  22
            SLEEP 15        ;15 37
            lda free_pf3    ;3  40
            sta PF1         ;3  43
            SLEEP 7         ;7  50 
            lda free_pf4    ;3  53
            sta PF2         ;3  56
            dex             ;2  58
            bpl _free_draw_loop
            lda #0
            sta PF1
            sta PF2
            sta GRP0
            sta GRP1



            ; FOOTER
footer
            ldx #FOOTER_HEIGHT
_footer_loop
            sta WSYNC
            dex
            bpl _footer_loop

            jmp waitOnOverscan
;
; 1 - 0 0
; 2 - 0 0
; 3 - 1 0
; 4 - 1 1
; 5 - 3 1
; 6 - 3 3
;
DISPLAY_COLS_NUSIZ0
    byte 3
DISPLAY_COLS_NUSIZ1
    byte 3,1,1,0,0,0

    MAC WRITE_DIGIT_HI 
            lda {1}
            and #$f0
            lsr
            lsr
            clc
            adc #<SYMBOL_GRAPHICS_S13_ZERO
            sta {2}
    ENDM

    MAC WRITE_DIGIT_LO
            lda {1}
            and #$0f
            asl
            asl
            asl
            clc
            adc #<SYMBOL_GRAPHICS_S13_ZERO
            sta {2}
    ENDM


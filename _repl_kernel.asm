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
            sta WSYNC               ; --
            lda repl_level          ;3    3
            sec                     ;2    5
_prompt_repos_loop
            sbc #15                 ;2    7
            sbcs _prompt_repos_loop ;2/3  9
            tay                     ;2   11
            lda LOOKUP_STD_HMOVE,y  ;5   16
            sta HMP0                ;3   19
            sta HMP1                ;3   22
            sta RESP0               ;3   25
            sta RESP1               ;3   28
            sta WSYNC               ;--
            sta HMOVE               ;3    3
            lda #WHITE              ;2    5
            sta COLUP0              ;3    8
            sta COLUP1              ;3   11
            lda #0                  ;2   13 ; -- BUGBUG: messy
            ldx #$10                ;2   15
            ldy #$60                ;2   17
            SLEEP 10                ;10  27
            sta RESMP0              ;3   30
            sta RESMP1              ;3   33
            lda #$00                ;2   35 ; -- BUGBUG: messy
            sta HMP0                ;3   38
            stx HMP1                ;3   41
            sty HMM0                ;3   44
            lda #$70                ;2   46
            sta HMM1                ;3   49
            SLEEP 11                ;11  60
            sta HMOVE               ;3   63

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
            tya
            lsr
            tax
            jmp _prompt_encode_clear
_prompt_encode_clear_dec
            tya
            lsr
            tax
            dey
            dey
            bmi prompt_encode_end
_prompt_encode_clear
            lda #<SYMBOL_GRAPHICS_EMPTY
_prompt_encode_clear_loop
            sta repl_gx_addr,y
            dey
            dey
            bpl _prompt_encode_clear_loop
prompt_encode_end
            lda DISPLAY_COLS_NUSIZ0,x    ;4    4
            ora #$30                     ;2    6
            sta NUSIZ0                   ;3    9
            lda DISPLAY_COLS_NUSIZ1,x    ;4   20
            ora #$30                     ;2   22
            sta NUSIZ1                   ;3   25
            sta WSYNC ; shim
            lda #2                       ;2   11
            sta ENAM0                    ;3   14
            cpx #5                       ;2   16
            bcs _prompt_skip_enam1
            sta ENAM1                    ;3   28
_prompt_skip_enam1
            sta WSYNC ; shim
            lda DISPLAY_COLS_NUSIZ0,x    ;4    4
            sta NUSIZ0                   ;3    7
            lda DISPLAY_COLS_NUSIZ1,x    ;4   11
            sta NUSIZ1                   ;3   14
            stx repl_width               ;3   17
            ldy #CHAR_HEIGHT - 1         ;2   19
            tsx                          ;2   21
            stx repl_stack               ;3   24
            lda #1                       ;2   26
            sta VDELP0                   ;3   29
            sta VDELP1                   ;3   32
            lda repl_level               ;3   35
            sec                          ;2   37
_prompt_delay_loop
            sbc #24                      ;2   39
            SLEEP 3                      ;3   42
            bcs _prompt_delay_loop       ;2/3 44
            adc #16                      ;2   46
            bmi _prompt_draw_entry_0     ;2   48 ; -24, transition at +0  
            SLEEP 3                      ;3   51
            beq _prompt_draw_entry_1     ;2   53 ;  -8, transition at +3
            jmp _prompt_draw_entry_2     ;3   56 ; -16, transition at +5
_prompt_draw_loop    ; 46
            SLEEP 6                      ;5   49
_prompt_draw_entry_0 ; 49          
            SLEEP 2                      ;2   51
_prompt_draw_entry_1 ; 54
_prompt_draw_entry_2 ; 56
            SLEEP 8                      ;8   59/62/64
            lda (repl_s0_addr),y         ;5   64/67/69
            sta GRP0                     ;3   67/70/72
            lda (repl_s1_addr),y         ;5   72/75/ 1
            sta GRP1                     ;3   75/ 2/ 4
            lda (repl_s2_addr),y         ;5    4/ 7/ 9
            sta GRP0                     ;3    7/10/12
            lax (repl_s4_addr),y         ;5   12/15/17
            txs                          ;2   14/17/19
            lax (repl_s3_addr),y         ;5   19/22/24
            lda (repl_s5_addr),y         ;5   24/27/29
_prompt_draw_entry
            stx GRP1                     ;3   23   0 -  9  !0!8 ** ++ 32 40
            tsx                          ;2   25   9 - 15   0!8!16 24 ++ 40
            stx GRP0                     ;3   28  15 - 24   0 8!16!** ++ 40
            sta GRP1                     ;3   31  24 - 33   0 8 16!24!** ++
            sty GRP0                     ;3   34  33 - 42   0 8 16 24!32!**
            dey                          ;2   36
            bpl _prompt_draw_loop        ;2   38  
 
            sta WSYNC
            ldx repl_width
            lda DISPLAY_COLS_NUSIZ0,x
            ora #$30
            sta NUSIZ0 
            lda DISPLAY_COLS_NUSIZ1,x
            ora #$30
            sta NUSIZ1  
                        
            sta WSYNC
            lda #0
            sta VDELP0
            sta VDELP1
            sta GRP0
            sta GRP1
            sta ENAM0
            sta ENAM1
            ; load stack + 1
            ldx repl_stack
            txs
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
            sta GRP0

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


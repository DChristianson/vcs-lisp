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

            ; BUGBUG: TODO: add scrolling
            ldy #(EDITOR_LINES - 1)
            lda repl_cursor
            and #$f8
            sta repl_display_indent,y
            lda repl
_prep_repl_line_loop
            sta repl_display_list,y
_prep_repl_line_scan
            tax
            lda HEAP_CAR_ADDR,x ; read car
            bpl _prep_repl_line_complex
            cmp #$40
            bpl _prep_repl_line_complex
            lda HEAP_CDR_ADDR,x ; read cdr
            bne _prep_repl_line_scan
            jmp _prep_repl_line_next
_prep_repl_line_complex
            ldx repl_display_list,y; BUGBUG: TODO; re-use dl
            lda HEAP_CDR_ADDR,x ; read cdr
            pha
            lda HEAP_CAR_ADDR,x ; read head car
            sta repl_display_list,y
            bpl _prep_repl_line_next
            cmp #$40
            bmi _prep_repl_line_next
            jmp _prep_repl_line_scan
_prep_repl_line_next
            dey
            bmi _prep_repl_line_end
            tsx ; check stack
            txa
            eor #$ff ; invert
            beq _prep_repl_line_clear
            asl ; multiply by 8
            asl
            asl
            sta repl_display_indent,y
            pla ; pull from stack
            bpl _prep_repl_line_next ; null
            sta repl_display_list,y
            jmp _prep_repl_line_complex
_prep_repl_line_clear
            lda #0
_prep_repl_line_clear_loop
            sta repl_display_indent,y
            sta repl_display_list,y
            dey
            ; BUGBUG: need to set indent? probably not
            bpl _prep_repl_line_clear_loop
_prep_repl_line_end
            ldx #$ff ; clean stack
            txs 

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
            lda #(PROMPT_HEIGHT * 76 / 64) 
            sta TIM64T
            lda #(EDITOR_LINES - 1)
            sta repl_editor_line
prompt_next_line
            ; lock missiles to players
            lda #2
            sta RESMP0
            sta RESMP1
            ; load repl level
            ldy repl_editor_line
            sta WSYNC               ; --
            lda repl_display_indent,y ;4  4
            sec                     ;2    6
_prompt_repos_loop
            sbc #15                 ;2    8
            sbcs _prompt_repos_loop ;2/3 10
            tax                     ;2   12
            lda LOOKUP_STD_HMOVE,x  ;5   17
            sta HMP0                ;3   20
            sta HMP1                ;3   23
            sta RESP0               ;3   26
            sta RESP1               ;3   29
            sta WSYNC               ;--
            sta HMOVE               ;3    3
            lda #WHITE              ;2    5
            sta COLUP0              ;3    8
            sta COLUP1              ;3   11
            SLEEP 10                ;10  21
            lda #0                  ;2   23 
            sta RESMP0              ;3   26
            sta RESMP1              ;3   29
            sta HMP0                ;3   32
            lda #$10                ;2   34
            sta HMP1                ;3   37
            lda #$60                ;2   39
            sta HMM0                ;3   42
            lda #$70                ;2   44
            sta HMM1                ;3   47
            SLEEP 13                ;13  60
            sta HMOVE               ;3   63

prompt_encode
            lda repl_display_list,y
            beq _prompt_encode_blank
            bpl _prompt_encode_blank ; BUGBUG: TODO: number
            cmp #$40
            bpl _prompt_encode_list
_prompt_encode_symbol
            ldy #(DISPLAY_COLS - 1) * 2
            tax
            lda LOOKUP_SYMBOL_GRAPHICS,x
            sta repl_gx_addr,y
            dey
            dey
            jmp _prompt_encode_clear
_prompt_encode_list
            ldy #(DISPLAY_COLS - 1) * 2
_prompt_encode_list_loop
            sta repl_cell_addr
            tax
            lda HEAP_CAR_ADDR,x ; read car
            tax
            lda LOOKUP_SYMBOL_GRAPHICS,x
            sta repl_gx_addr,y
            dey
            dey
            bmi _prompt_encode_list_end 
            ldx repl_cell_addr
            lda HEAP_CDR_ADDR,x
            bne _prompt_encode_list_loop
            jmp _prompt_encode_clear
_prompt_encode_list_end
            ldx #0
            jmp _prompt_encode_end
_prompt_encode_blank
            ldy #(DISPLAY_COLS - 1) * 2
_prompt_encode_clear
            tya
            lsr
            tax
            lda #$0
_prompt_encode_clear_loop
            sta repl_gx_addr,y
            dey
            dey
            bpl _prompt_encode_clear_loop
_prompt_encode_end            
            lda DISPLAY_COLS_NUSIZ0,x    ;4    4
            ora #$30                     ;2    6
            sta NUSIZ0                   ;3    9
            lda DISPLAY_COLS_NUSIZ1,x    ;4   20
            cpx #4                       ;2   16
            bcs _prompt_skip_enam1
            ora #$30                     ;2   22
_prompt_skip_enam1            
            sta NUSIZ1                   ;3   25
            sta WSYNC ; shim
            lda #2                       ;2   11
            sta ENAM0                    ;3   14
            sta ENAM1                    ;3   28
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
            cpx #4 
            bcs _prompt_skip_enam1_1
            ora #$30      
_prompt_skip_enam1_1
            sta NUSIZ1  
            ldx repl_stack 
            txs           
            sta WSYNC
            lda #0
            sta VDELP0
            sta VDELP1                  
            sta GRP0
            sta GRP1
            sta ENAM0
            sta ENAM1
            dec repl_editor_line
            bmi prompt_done
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


repl_update
            ; check fire button
            lda INPT4
            bmi _repl_update_skip_eval
            lda #GAME_STATE_EVAL
            sta game_state
_repl_update_skip_eval
            ; check indent level
            lda player_input
            eor #$f0
            ldx SWCHA
            stx player_input
            ora player_input
            rol
            rol
            rol
            bcs _repl_update_skip_down
            lda #1
            jmp _repl_update_set_cursor
_repl_update_skip_down
            rol
            bcs _repl_update_skip_move
            lda #-1
_repl_update_set_cursor
            clc
            adc repl_cursor
            bpl _repl_update_check_scroll_up
            lda #0
_repl_update_check_scroll_up
            sta repl_cursor
            cmp repl_scroll
            bpl _repl_update_check_scroll_down
            sta repl_scroll
            jmp _repl_update_skip_move
_repl_update_check_scroll_down
            sec 
            sbc #(EDITOR_LINES-1)
            cmp repl_scroll
            bmi _repl_update_skip_move
            sta repl_scroll
_repl_update_skip_move

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

            ; calculate visiple program
            ldy #(EDITOR_LINES - 1)
            lda repl_scroll
            sta repl_tmp_scroll
            lda #0
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
            dec repl_tmp_scroll
            bpl _prep_repl_line_next_skip_dey
            dey
            bmi _prep_repl_line_end
_prep_repl_line_next_skip_dey
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
            dec repl_tmp_scroll
            bpl _prep_repl_line_clear_loop
            dey
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

; ACCUMULATOR
accumulator_draw
            sta WSYNC                               ;--  0
            lda #3                                  ;2   2
            sta NUSIZ0                              ;3   5
            sta NUSIZ1                              ;3   8
            lda #$0                                 ;2  10
            sta COLUBK
            sta HMP0                                ;3  13
            lda #$e0                                ;2  15
            sta HMP1                                ;3  18
            sta RESP0                               ;3  21
            sta RESP1                               ;3  24
            WRITE_DIGIT_HI repl_bcd+2, repl_s0_addr ;16 40
            WRITE_DIGIT_LO repl_bcd+2, repl_s1_addr ;16 56
            WRITE_DIGIT_HI repl_bcd+1, repl_s2_addr ;16 72
            sta HMOVE                               ;3  75
            WRITE_DIGIT_LO repl_bcd+1, repl_s3_addr ;16 15
            WRITE_DIGIT_HI repl_bcd, repl_s4_addr   ;16 31
            WRITE_DIGIT_LO repl_bcd, repl_s5_addr   ;16 47
            ldy #CHAR_HEIGHT - 1                    ;2  49
            lda #1                                  ;2  51
            bit clock                               ;3  54
            bne accumulator_draw_odd                ;3  57
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
                
            ; PROMPT
            ; draw repl cell tree
prompt
            lda #(PROMPT_HEIGHT * 76 / 64) 
            sta TIM64T
            ldy #(EDITOR_LINES - 1)
            sty repl_editor_line
prompt_next_line
            ; lock missiles to players
            lda #2
            sta RESMP0
            sta WSYNC               ; --
            sta RESMP1              ; 3   3
            lda repl_display_indent,y ;4  7
            sec                     ;2    9
_prompt_repos_loop
            sbc #15                 ;2   11
            sbcs _prompt_repos_loop ;2/3 13
            tax                     ;2   15
            lda LOOKUP_STD_HMOVE,x  ;5   20
            sta HMP0                ;3   23
            sta HMP1                ;3   26
            sta RESP0               ;3   29
            sta RESP1               ;3   32
            SLEEP 7                 ;7   40
            sta HMBL                ;3   43
            sta RESBL               ;3   46
            sta WSYNC               ;--
            lda #WHITE              ;2    2
            sta COLUP0              ;3    5
            sta COLUP1              ;3    8
            sta COLUPF              ;3   11
            tya                     ;2   13
            eor #$ff                ;2   15
            clc                     ;2   17
            adc #(EDITOR_LINES)     ;2   19
            clc                     ;2   21   
            adc repl_scroll         ;3   24
            cmp repl_cursor         ;3   27
            bne _prompt_skip_cursor_bk ;2 29
            ldx #$02                ;2   31
            jmp _prompt_cursor_bk   ;3   34
_prompt_skip_cursor_bk
            and #$01                ;2   32
            tax                     ;2   34
_prompt_cursor_bk
            lda DISPLAY_REPL_COLORS,x ;4 38
            SLEEP 32                ;32  70
            sta HMOVE
            sta COLUBK              ;3   76
            SLEEP 22                ;22  22
            lda #0                  ;2   24
            sta RESMP0              ;3   27
            sta RESMP1              ;3   30
            lda #$f0                ;2   32
            sta HMP0                ;3   35
            lda #$10                ;2   37
            sta HMP1                ;3   40
            sta HMBL                ;3   43
            lda #$60                ;2   45
            sta HMM0                ;3   48 
            lda #$70                ;2   50
            sta HMM1                ;3   53
            SLEEP 7                 ;7   60
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
            cpx #0                       ;2   30
            bne _prompt_skip_enabl       ;2   32
            sta ENABL                    ;3   35
_prompt_skip_enabl
            sta WSYNC ; shim
            lda DISPLAY_COLS_NUSIZ0,x    ;4    4
            sta NUSIZ0                   ;3    7
            lda DISPLAY_COLS_NUSIZ1,x    ;4   11
            sta NUSIZ1                   ;3   14
            stx repl_width               ;3   17
            lda #1                       ;2   19
            sta VDELP0                   ;3   22
            sta VDELP1                   ;3   25
            ldy repl_editor_line         ;3   28
            lda repl_display_indent,y    ;4   32
            ldy #CHAR_HEIGHT - 1         ;2   34
            sec                          ;2   36
_prompt_delay_loop
            sbc #24                      ;2   38
            SLEEP 3                      ;3   41
            sbcs _prompt_delay_loop      ;2/3 43
            adc #16                      ;2   45
            sbmi _prompt_draw_entry_0    ;2   47 ; -24, transition at +0  
            SLEEP 4                      ;4   51
            bne _prompt_draw_entry_2     ;2   53 ; -16, transition at +5
            jmp _prompt_draw_entry_1     ;3   56 ;  -8, transition at +3
_prompt_draw_loop    ; 40
            SLEEP 5                      ;5   45  
_prompt_draw_entry_0 ; 45/48          
_prompt_draw_entry_2 ; 45/48/--/54
            SLEEP 5                      ;2   50/53/--/59
_prompt_draw_entry_1 ; 50/53/56/59
            SLEEP 6                      ;9   56/59/62/65
            lda (repl_s0_addr),y         ;5   61/64/67/69
            sta GRP0                     ;3   64/67/70/72
            lda (repl_s1_addr),y         ;5   69/72/75/ 1
            sta GRP1                     ;3   72/75/ 2/ 4
            lda (repl_s2_addr),y         ;5    1/ 4/ 7/ 9
            sta GRP0                     ;3    4/ 7/10/12
            lax (repl_s4_addr),y         ;5    9/12/15/17
            txs                          ;2   11/14/17/19
            lax (repl_s3_addr),y         ;5   16/19/22/24
            lda (repl_s5_addr),y         ;5   21/24/27/29
_prompt_draw_entry
            stx GRP1                     ;3   24   0 -  9  !0!8 ** ++ 32 40
            tsx                          ;2   26   9 - 15   0!8!16 24 ++ 40
            stx GRP0                     ;3   29  15 - 24   0 8!16!** ++ 40
            sta GRP1                     ;3   32  24 - 33   0 8 16!24!** ++
            sty GRP0                     ;3   35  33 - 42   0 8 16 24!32!**
            dey                          ;2   37
            bpl _prompt_draw_loop        ;2   39  
 
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
            ldx #$ff ; reset the stack 
            txs           
            sta WSYNC
            lda #0
            sta VDELP0
            sta VDELP1                  
            sta GRP0
            sta GRP1
            sta ENAM0
            sta ENAM1
            sta ENABL
            ldy repl_editor_line
            dey 
            bmi prompt_done
            sty repl_editor_line
            jmp prompt_next_line
prompt_done
            jsr waitOnTimer
            sta WSYNC
            sta COLUBK

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
DISPLAY_REPL_COLORS
    byte #$7A,#$7E,#$86 ; BUGBUG: make pal safe

    MAC WRITE_DIGIT_HI 
            lda {1}                         ;3  3
            and #$f0                        ;2  5
            lsr                             ;2  7
            lsr                             ;2  9
            clc                             ;2 11
            adc #<SYMBOL_GRAPHICS_S13_ZERO  ;2 13
            sta {2}                         ;3 15
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


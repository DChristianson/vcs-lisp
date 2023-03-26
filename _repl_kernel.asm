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
            adc repl_edit_line
            bpl _repl_update_check_scroll_up
            lda #0
_repl_update_check_scroll_up
            cmp repl_last_line
            bcc _repl_update_check_limit
            lda repl_last_line
_repl_update_check_limit
            sta repl_edit_line
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

            ; calculate visible program
            ldy #(EDITOR_LINES - 1)
            lda repl_scroll
            sta repl_tmp_scroll
            lda #0
            sta repl_display_indent,y
            lda repl
_prep_repl_line_scan
            sta repl_display_list,y
            ldx #$ff
            stx repl_tmp_width
_prep_repl_line_scan_loop
            tax
            lda HEAP_CAR_ADDR,x ; read car
            bpl _prep_repl_line_complex
            cmp #$40
            bpl _prep_repl_line_complex
            inc repl_tmp_width
            lda HEAP_CDR_ADDR,x ; read cdr
            bne _prep_repl_line_scan_loop
            jmp _prep_repl_line_next
_prep_repl_line_complex
            lda #0
            sta repl_tmp_width
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
            lda repl_display_indent,y
            clc
            adc repl_tmp_width
            sta repl_display_indent,y
            dec repl_tmp_scroll
            bpl _prep_repl_line_next_skip_dey
            dey
            bmi _prep_repl_line_end
_prep_repl_line_next_skip_dey
            tsx ; check stack
            txa
            eor #$ff ; invert
            beq _prep_repl_line_clear
            asl
            asl
            asl
            sta repl_display_indent,y ; columns to indent (from prev line)
            pla ; pull from stack
            bpl _prep_repl_line_next_skip_dey ; null
            sta repl_display_list,y
            jmp _prep_repl_line_complex
_prep_repl_line_clear
            lda repl_scroll
            clc
            adc #EDITOR_LINES
            tax
            lda #0
_prep_repl_line_clear_loop
            sta repl_display_indent,y
            sta repl_display_list,y
            dex
            dey
            bpl _prep_repl_line_clear_loop
_prep_repl_line_end
            stx repl_last_line ; either -1 or last cleared line
            ldx #$ff ; clean stack
            txs 

            ; done
            jmp update_return

;----------------------
; Repl display
;
            align 256
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
            sta RESMP1     
            ; load hpos
            lda repl_display_indent,y ;4  4
            and #$f8                ;2    6
            sec                     ;2    8
            ; get ready to strobe player position
            sta WSYNC               ; --
_prompt_repos_loop
            sbc #15                 ;2    2
            sbcs _prompt_repos_loop ;2/3  4
            tax                     ;2    6
            lda LOOKUP_STD_HMOVE,x  ;5   11
            sta HMP0                ;3   14
            sta HMP1                ;3   17
            lda repl_display_indent,y ;4 21
            and #$01                ;2   23
            bne _prompt_repos_swap  ;2/3 25
            sta.w RESP0             ;3   29 shim to 29
            sta RESP1               ;3   32
            jmp _prompt_repos_swap_end
_prompt_repos_swap
            sta RESP1               ;3   29
            sta RESP0               ;3   32
_prompt_repos_swap_end
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
            cmp repl_edit_line         ;3   27
            bne _prompt_skip_cursor_bk ;2 29
            ldx #$02                ;2   31
            jmp _prompt_cursor_bk   ;3   34
_prompt_skip_cursor_bk
            and #$01                ;2   32
            tax                     ;2   34
_prompt_cursor_bk
            lda DISPLAY_REPL_COLORS,x ;4 38
            SLEEP 32                ;32  70
            sta HMOVE               ;3   73
            sta COLUBK              ;3   76
            SLEEP 14                ;14  14
            lda repl_display_indent,y ;4 18
            and #$01                ;2   10
            bne _prompt_swap_hpos   ;2/3 22
            lda #$f0                ;2   24
            sta HMP0                ;3   27
            lda #$10                ;2   29
            sta HMP1                ;3   32
            lda #$60                ;2   34
            sta HMM0                ;3   37 
            lda #$70                ;2   39
            sta HMM1                ;3   42
            jmp _prompt_final_hpos  ;3   45
_prompt_swap_hpos
            lda #$f0                ;2   25
            sta HMP1                ;3   28
            lda #$10                ;2   30
            sta HMP0                ;3   33
            lda #$60                ;2   35
            sta HMM1                ;3   38 
            lda #$70                ;2   40
            sta HMM0                ;3   43
            SLEEP 2                 ;2   45
_prompt_final_hpos
            lda #0                  ;2   47
            sta RESMP0              ;3   50
            sta RESMP1              ;3   53
            SLEEP 7                 ;7   60
            sta HMOVE               ;3   63
            
prompt_encode
            lda repl_display_list,y
            beq _prompt_encode_blank
            bpl _prompt_encode_blank ; BUGBUG: TODO: number
            cmp #$40
            bpl _prompt_encode_list
_prompt_encode_symbol
            tax
            lda LOOKUP_SYMBOL_GRAPHICS,x
            sta repl_s4_addr
            jmp _prompt_encode_end
_prompt_encode_list
            tax
            ; load indent level onto stack so we can jmp
            lda repl_display_indent,y 
            and #$07
            asl ; multiply by two
            tay
            lda PROMPT_ENCODE_JMP+1,y
            pha
            lda PROMPT_ENCODE_JMP,y
            pha
            rts
            ; unrolled encoding loop
_prompt_encode_s0
            MAP_CAR repl_s0_addr
_prompt_encode_s1
            MAP_CAR repl_s1_addr
_prompt_encode_s2
            MAP_CAR repl_s2_addr
_prompt_encode_s3
            MAP_CAR repl_s3_addr
_prompt_encode_s4
            MAP_CAR repl_s4_addr
            jmp _prompt_encode_end
_prompt_encode_blank
            ldx #CHAR_HEIGHT + 4
_prompt_encode_blank_loop
            sta WSYNC
            dex
            bpl _prompt_encode_blank_loop
            jmp prompt_end_line
_prompt_encode_end
            lda #0
            sta repl_s5_addr

            jmp prompt_display

            align 256

prompt_display
            ; ------------------------------------
            ; display kernel mechanics
            ; NUSIZ0 / NUSIZ1
            ;         - S0 S1  0  1  0  1  0 B1 B0
            ; 1 - 0 0 - 30 00             30 00 00 
            ; 2 - 2 0 - 30 31          31 30 01 00 
            ; 3 - 2 2 - 31 31       31 31 31 01 01
            ; 4 - 3 2 - 33 31    33 31 33 31 03 01 
            ; 5 - 3 3 - 33 33 33 33 33 33 33 03 03
            ; GRP0 / GRP1
            ;                 G0 G1 G2 G3 G4 G5

            ldy repl_editor_line         ;3    3
            lda repl_display_indent,y    ;4    7
            sta WSYNC ; shim
            and #$07                     ;2    2
            tax                          ;2    4
            lda repl_display_indent,y    ;4    8
            and #$f8                     ;2   10
            clc                          ;2   12
            adc DISPLAY_COLS_INDENT,x    ;4   16
            sec                          ;2   18
_prompt_delay_loop
            sbc #24                      ;2   --
            SLEEP 3                      ;3   --
            sbcs _prompt_delay_loop      ;2/3 32
            adc #16                      ;2   34
            sbmi _prompt_draw_entry_0    ;2/3 36 ; -24, transition at +0  
            SLEEP 4                      ;4   40
            bne _prompt_draw_entry_2     ;2   42 ; -16, transition at +5
            jmp _prompt_draw_entry_1     ;3   46 ;  -8, transition at +3
_prompt_draw_entry_0 ; 37          
_prompt_draw_entry_2 ; 37/--/43
            SLEEP 5                      ;5   42/--/48  + shim
_prompt_draw_entry_1 ; 42/45/48
              
            lda #1                       ;2   67
            sta VDELP0                   ;3   69
            sta VDELP1                   ;3   72
            lda DISPLAY_COLS_NUSIZ0_A,x  ;4   --
            sta NUSIZ0                   ;3    3
            lda DISPLAY_COLS_NUSIZ1_A,x  ;4    7
            sta NUSIZ1                   ;3   10
            lda #2                       ;2   12
            sta ENAM0                    ;3   15
            sta ENAM1                    ;3   18

            ldy DISPLAY_COLS_NUSIZ1_B,x  ;4   22
            lda DISPLAY_COLS_NUSIZ0_B,x  ;4   26
            sty NUSIZ1                   ;3   29  24 - 33
            sta NUSIZ0                   ;3   32  33 - 42
            ldx #14                      ;2   34
_prompt_draw_start_loop ; skip a line
            dex                          ;2   36/30 (2x15 = 30)
            bpl _prompt_draw_start_loop  ;2/3 38/32 (1x2 + 3x14 = 44)
            ldy #CHAR_HEIGHT - 1         ;2   34
      
_prompt_draw_loop    ; 40
            SLEEP 16                     ;16   56  
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
            sbpl _prompt_draw_loop       ;2   39  

            ldx #$ff ; reset the stack   ;2   41
            txs                          ;2   43
            lda #0                       ;2   45
            sta VDELP0                   ;3   48
            sta VDELP1                   ;3   51
            sta GRP0                     ;3   54
            sta GRP1                     ;3   57

            ldy repl_editor_line         ;3   60
            lda repl_display_indent,y    ;4   64
            and #$07                     ;2   66
            tax                          ;2   68
            lda DISPLAY_COLS_NUSIZ0_A,x  ;4   72
            sta NUSIZ0                   ;3   75
            lda DISPLAY_COLS_NUSIZ1_A,x  ;4    3
            sta NUSIZ1                   ;3    6
            ldy DISPLAY_COLS_NUSIZ1_B,x  ;4   10
            lda DISPLAY_COLS_NUSIZ0_B,x  ;4   14
            SLEEP 18                     ;18  32
            sty NUSIZ1                   ;3   35
            sta NUSIZ0                   ;3   38

            sta WSYNC
            lda #0          
            sta ENAM0
            sta ENAM1
prompt_end_line
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
            ;         - S0 S1  0  1  0  1  0 E1 B0
            ; 1 - 0 0 - 30 00             30 00 00  
            ; 2 - 2 0 - 30 31          31 30 01 00 
            ; 3 - 2 2 - 31 31       31 31 31 01 01
            ; 4 - 3 2 - 31 33    33 31 33 31 03 01 
            ; 5 - 3 3 - 33 33 33 33 33 33 33 03 03  
PROMPT_ENCODE_JMP
    word _prompt_encode_s4-1
    word _prompt_encode_s3-1
    word _prompt_encode_s2-1
    word _prompt_encode_s1-1
    word _prompt_encode_s0-1

DISPLAY_COLS_INDENT
    byte 80,88,96,104,112 
DISPLAY_COLS_NUSIZ0_A
    byte $30,$30,$31,$31,$33
DISPLAY_COLS_NUSIZ1_A
    byte $00,$31,$31,$33,$33
DISPLAY_COLS_NUSIZ0_B
    byte $00,$00,$01,$01,$03
DISPLAY_COLS_NUSIZ1_B
    byte $00,$01,$01,$03,$03
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

    MAC MAP_CAR
            ldy HEAP_CAR_ADDR,x ; read car
            lda LOOKUP_SYMBOL_GRAPHICS,y
            sta {1}
            lda HEAP_CDR_ADDR,x
            tax
    ENDM

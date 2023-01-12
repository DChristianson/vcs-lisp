sub_repl_update
            ; update frame
            inc frame
            ; prep symbol graphics
            ldy #(DISPLAY_COLS - 1) * 2
_prep_repl_loop
            lda #>SYMBOL_GRAPHICS_S00_MULT
            sta repl_gx_addr + 1,y
            dey
            dey
            bpl _prep_repl_loop
            rts

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
            lda #42    ; timer will land us ~ on scanline + 34
            sta TIM64T
            ; do one repos loop at the top 
            ; use HMOVE to handle indenting
            sta WSYNC
            lda #8
_prompt_repos_loop
            sbc #15
            bcs _prompt_repos_loop
            tay
            lda LOOKUP_STD_HMOVE,y
            sta HMP0
            sta HMP1
            sta RESP0
            sta RESP1
            sta WSYNC             ;--
            sta HMOVE             ;3    3
            lda #3                ;2    5
            sta NUSIZ0            ;3    8
            sta NUSIZ1            ;3   11
            lda #WHITE            ;2   13
            sta COLUP0            ;3   16
            sta COLUP1            ;3   19
            lda #0                ;2   21
            ldx #$70              ;2   23
            sta HMP0              ;3   26
            stx HMP1              ;3   29
            SLEEP 23              ;23  52
            sta HMOVE             ;3   55


prompt_encode
            lda repl
prompt_next_line
            ldy #(DISPLAY_COLS - 1) * 2
_prompt_encode_loop
            tax
            lda HEAP_CAR_ADDR,x ; read car
            bpl _prompt_encode_clear ; BUGBUG: handle #
            cmp #$40
            bpl _prompt_encode_recurse
_prompt_encode_addchar
            stx tmp_cell_addr ; push down current cell
            tax
            lda LOOKUP_SYMBOL_GRAPHICS,x
            sta repl_gx_addr,y
            ldx tmp_cell_addr 
            lda HEAP_CDR_ADDR,x ; read cdr
            beq _prompt_encode_clear
            dey
            dey
            bpl _prompt_encode_loop
            ; list is too long, we need to indent
            ; push next address on the stack
            pha
            jmp prompt_encode_end
_prompt_encode_recurse
            ; we need to recurse so we need push t
            ; contents of the cdr
            ; contents of the car
            sta tmp_cell_addr ; set car aside
            lda HEAP_CDR_ADDR,x 
            beq _prompt_encode_recurse_skip_cdr
            pha 
_prompt_encode_recurse_skip_cdr
            lda tmp_cell_addr
            pha
_prompt_encode_clear
            dey
            dey
            lda #<SYMBOL_GRAPHICS_EMPTY
_prompt_encode_clear_loop
            sta repl_gx_addr,y
            dey
            dey
            bpl _prompt_encode_clear_loop
prompt_encode_end
            
            sta WSYNC ; shim

            ldy #CHAR_HEIGHT - 1
            lda #1
            bit frame
            bne prompt_draw_odd
prompt_draw_even
_prompt_draw_even_loop
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
            bpl _prompt_draw_even_loop ;2/3 41/42
            jmp prompt_draw_end
prompt_draw_odd
_prompt_draw_odd_loop
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
            bpl _prompt_draw_odd_loop ;2/3 46/47
            jmp prompt_draw_end
prompt_draw_end
            tsx
            inx
            beq prompt_done
            pla
            jmp prompt_next_line
prompt_done
            jsr waitOnTimer

            ; FREEBAR
freebar
            ldy #0
            sty NUSIZ0
            sty NUSIZ1
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
            
            ; BUGBUG: TODO: OUTPUT / MENU

            ; FOOTER
footer
            ldx #FOOTER_HEIGHT
_footer_loop
            sta WSYNC
            dex
            bpl _footer_loop

            jmp waitOnOverscan
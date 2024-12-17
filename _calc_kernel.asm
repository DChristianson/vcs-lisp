repl_draw_accumulator
            ldx #HEADER_HEIGHT / 2
            jsr sub_wsync_loop
            ; convert accumulator to BCD
            ldx #<accumulator
            jsr sub_fmt_number
            ; prep for a 24 px sprite graphic
            lda #68
            jsr sub_respxx
            ldx #1                      ;2   2  
            stx VDELP0                  ;3   5  
            stx VDELP1                  ;3   8
            stx NUSIZ0                  ;3  11
            lda #$10                    ;2  13
            sta WSYNC                   ;-----
            stx HMP0                    ;3   3
            sta HMP1                    ;3   6
            sta HMOVE                   ;3   9
            ldy #CHAR_HEIGHT - 1        ;2  70
_accumulator_draw_loop    ; 40/41 w page jump
            sta WSYNC                   ;-   --
            lda (gx_s2_addr),y          ;5    5
            sta GRP0                    ;3    8
            lda (gx_s3_addr),y          ;5   13
            sta GRP1                    ;3   16
            lda (gx_s4_addr),y          ;5   21
            sta GRP0                    ;3   24
            ldx #4                      ;2   26
_accumulator_delay_loop
            dex                         ;2   28/33/38/43
            bne _accumulator_delay_loop ;3/2 31/36/41/45
            stx GRP1                    ;3   48  / space - x is zero
            dey                         ;2   50  
            bpl _accumulator_draw_loop  ;2   41  
            jsr sub_clr_pf
            ldx #HEADER_HEIGHT / 2 - 1
            jsr sub_wsync_loop
            jmp game_draw_return

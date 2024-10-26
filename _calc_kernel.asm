repl_draw_accumulator
            ldx #HEADER_HEIGHT / 2
            jsr sub_wsync_loop
            jsr sub_draw_accumulator
            ldx #HEADER_HEIGHT / 2 - 1
            jsr sub_wsync_loop
            jmp game_draw_return

sub_draw_accumulator
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
            dex                         ;2  13; get to zero
            stx NUSIZ1                  ;3  16
            lda #$10                    ;2  18
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
            SLEEP 19                    ;---- BUGBUG: SPACE
            lda #0                      ;5   31
            sta GRP1                    ;3   34
            sta GRP0                    ;3   37 
            dey                         ;2   39  
            bpl _accumulator_draw_loop  ;2   41  
            jsr sub_clr_pf
            rts
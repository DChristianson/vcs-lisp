repl_draw_accumulator
            ldx #28
            jsr sub_wsync_loop
            ; convert accumulator to BCD
            ldx #<accumulator
            jsr sub_fmt_number
            ; prep for a 24 px sprite graphic
            lda #68
            jsr sub_respxx
            ldx #1                      ;2   2  
            stx NUSIZ0                  ;3   8
            lda #$10                    ;2  10
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
            ldx #4                      ;2   18
_accumulator_delay_loop
            dex                         ;2   20/25/30/35
            bne _accumulator_delay_loop ;3/2 23/28/33/38
            lda (gx_s4_addr),y          ;5   43
            dey                         ;2   45  ; timing: swap these around
            sta GRP0                    ;3   48
            bpl _accumulator_draw_loop  ;2   41  
            ldx #28
            jsr sub_wsync_loop
            jmp game_draw_return

repl_draw_accumulator
            ldx #HEADER_HEIGHT / 2
            jsr sub_wsync_loop
            jsr sfd_draw_accumulator
            ldx #HEADER_HEIGHT / 2
            jsr sub_wsync_loop
            jmp repl_draw_return

sfd_draw_accumulator
            ; convert accumulator to BCD
            lda accumulator_msb
            sta repl_fmt_arg + 1
            lda accumulator_lsb
            sta repl_fmt_arg
            jsr sub_fmt
            jsr sub_prep_repl_graphics
            lda #68
            jsr sub_respxx
            sta WSYNC
            sta HMOVE
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

            ldy #CHAR_HEIGHT - 1         ;2  70
_accumulator_draw_loop    ; 40/41 w page jump
            sta WSYNC                    ;-   --
            lda (repl_s2_addr),y         ;5    5
            sta GRP0                     ;3    8
            lda (repl_s3_addr),y         ;5   13
            sta GRP1                     ;3   16
            lda (repl_s4_addr),y         ;5   21
            sta GRP0                     ;3   24
            SLEEP 17                     ;----
            lda (repl_s5_addr),y         ;5   31
            sta GRP1                     ;3   34
            sta GRP0                     ;3   37 
            dey                          ;2   39  
            bpl _accumulator_draw_loop   ;2   41  
            sta WSYNC
            lda #0
            sta NUSIZ0
            sta NUSIZ1
            sta VDELP0                              ;3
            sta VDELP1                              ;3
            ldx #$fd ; reset stack pointer
            txs            
            rts

repl_draw_music
        ;; BUGBUG: Draw 8 music symbols
        ;; color whichever one is playing
        ldx #(HEADER_HEIGHT / 4)
        jsr sub_wsync_loop
        lda #$40       ; BUGBUG - magic constant screen pos 
        jsr sub_respxx ; position both players at once
        sta WSYNC
        sta HMOVE
        lda #5 ; double size players
        sta NUSIZ0
        sta NUSIZ1
        ldy #2               ; load gx_s3 with the musical note
        lda #SYMBOL_BEEP     ; .
        jsr sub_fmt_symbol   ; 
        ldy #0               ; load gx_s4 with the musical note
        sty HMP0       ; take advantage of y = 0 to clear HMP0
        lda #SYMBOL_BEEP     ; .
        jsr sub_fmt_symbol   ; . 
        lda #$80       ; move player 1 to right by 8
        sta HMP1       ; .
        sta WSYNC     
        sta HMOVE
        ; draw glyphs
        ldx #$07
_music_loop
        txa
        lsr ; multiply by 32 by shifting right and rolling
        ror ; .
        ror ; .
        ror ; .
        sta COLUP0
        sec
        sbc #$10
        sta COLUP1
        dex 
        jsr sub_draw_glyph_16px
        dex
        bpl _music_loop
_music_end
        lda #0
        sta NUSIZ0
        sta NUSIZ1
        ldx #(HEADER_HEIGHT / 4)
        jsr sub_wsync_loop
        jmp game_draw_return

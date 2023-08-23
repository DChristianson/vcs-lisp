
repl_draw_music
        ;; BUGBUG: Draw 8 music symbols
        ;; color whichever one is playing
        ldx #(HEADER_HEIGHT / 4)
        jsr sub_wsync_loop
        lda #$4f
        jsr sub_respxx
        sta WSYNC
        sta HMOVE
        lda #5
        sta NUSIZ0
        sta NUSIZ1
        ldy #2
        lda #SYMBOL_BEEP
        jsr sub_fmt_symbol
        dey
        dey
        lda #SYMBOL_BEEP
        jsr sub_fmt_symbol
        lda #0
        pha
        lda #$10
        clc
        ldx #3
_music_color_loop        
        pha
        adc #$10
        pha
        adc #$10
        dex
        bpl _music_color_loop
_music_loop
        pla 
        beq _music_end
        sta COLUP0
        pla
        sta COLUP1
        jsr sub_draw_glyph_2
        jmp _music_loop
_music_end
        lda #0
        sta NUSIZ0
        sta NUSIZ1
        ldx #(HEADER_HEIGHT / 4)
        jsr sub_wsync_loop
        jmp repl_draw_return

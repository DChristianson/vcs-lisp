
repl_draw_music
        ;; BUGBUG: Draw 8 music symbols
        ;; color whichever one is playing
        ldx #(HEADER_HEIGHT / 4)
        jsr sub_wsync_loop
        ldx #$50
        jsr sub_respxx
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
        ldx #MUSIC_GRAPHICS
        jsr sub_draw_glyph_2
        jmp _music_loop
_music_end
        ldx #(HEADER_HEIGHT / 4)
        jsr sub_wsync_loop
        jmp repl_draw_return


repl_draw_music
        ldx #(HEADER_HEIGHT / 2)
        jsr sub_wsync_loop
        ldx #$50
        ldy #$00
        jsr sub_respxx
        ldx #<SYMBOL_GRAPHICS_S13_A3
        jsr sub_draw_glyph_2
        ldx #(HEADER_HEIGHT / 2)
        jsr sub_wsync_loop
        jmp repl_draw_return

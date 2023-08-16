

repl_draw_game
        ldx #(HEADER_HEIGHT / 2)
        jsr sub_wsync_loop
        ldx #$50
        jsr sub_respxx
        ldx #SYMBOL_BEEP
        jsr sub_draw_glyph_2
        ldx #(HEADER_HEIGHT / 2)
        jsr sub_wsync_loop
        jmp repl_draw_return

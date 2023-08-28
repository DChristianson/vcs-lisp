
repl_draw_steps
        ldx #(HEADER_HEIGHT / 2)
        jsr sub_wsync_loop
        ldx #$50
        jsr sub_respxx
        ldx #SYMBOL_BEEP
        jsr sub_draw_glyph_16px
        ldx #(HEADER_HEIGHT / 2)
        jsr sub_wsync_loop
        jmp game_draw_return

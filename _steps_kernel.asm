
steps_maze = game_data + 0 
steps_player_pos = gx_s4_addr + 1

repl_init_steps
        lda #SYMBOL_BLANK
        sta steps_maze + 5
        lda #SYMBOL_BEEP
        sta steps_maze + 4
        lda #$20
        ldx #3
_init_steps_loop
        sta steps_maze,x
        dex
        bpl _init_steps_loop
        lda #1
        sta steps_player_pos
        jmp game_state_init_return

repl_draw_steps
        lda #90
        jsr sub_respxx
        lda #$70
        sta HMP0
        sta HMP1
        ldx #5
_draw_steps_loop
        cpx steps_player_pos
        lda steps_maze,x
        ldy #4
        jsr sub_fmt_symbol
        lda #SYMBOL_F0
        ldy #2
        jsr sub_fmt_symbol
        jsr sub_draw_glyph_16px
        sta WSYNC
        sta HMOVE
        dex
        bpl _draw_steps_loop
        jmp game_draw_return

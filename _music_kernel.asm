
repl_draw_music
        ;; BUGBUG: Draw 8 music symbols
        ;; color whichever one is playing
        ldx #7
        jsr sub_wsync_loop
        lda #$40       ; BUGBUG - magic constant screen pos 
        jsr sub_respxx ; position both players at once
        lda #5 ; double size players
        sta NUSIZ0
        sta NUSIZ1
        ldy #2               ; load gx_s3 with the musical note
        lda #SYMBOL_BEEP     ; .
        jsr sub_fmt_symbol   ; 
        ldy #0               ; load gx_s4 with the musical note
        sty HMP0             ; take advantage of y = 0 to clear HMP0
        lda #SYMBOL_BEEP     ; .
        jsr sub_fmt_symbol   ; . 
        lda #$80       ; move player 1 to right by 8
        sta HMP1       ; .
        sta WSYNC     
        sta HMOVE
        ; draw glyphs
        ldx #$08
_music_loop
        txa
        sec
        sbc #1
        lsr ; multiply by 32 by shifting right and rolling
        ror ; .
        ror ; .
        ror ; .
        tay
        cpx beep_f0
        bne _music_loop_save_colup0
        ldy #WHITE
_music_loop_save_colup0
        sty COLUP0
        sec
        sbc #$10
        dex 
        tay
        cpx beep_f0
        bne _music_loop_save_colup1
        ldy #WHITE
_music_loop_save_colup1
        sty COLUP1
        jsr sub_draw_glyph_16px
        dex
        bne _music_loop
_music_end
        lda #0
        sta NUSIZ0
        sta NUSIZ1
        ldx #6
        jsr sub_wsync_loop
        jmp game_draw_return

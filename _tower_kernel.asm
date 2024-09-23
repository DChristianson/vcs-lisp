
repl_draw_tower
        ldx #(HEADER_HEIGHT / 2)
        jsr sub_wsync_loop
        ldy #5
_draw_tower_loop
        lda #$80
        sta PF0
        lda #$ff
        sta PF1
        lda #$1f
        sta PF2
        ldx #2
        jsr sub_wsync_loop
        lda #0
        sta PF0
        sta PF1
        sta PF2
        ldx #2
        jsr sub_wsync_loop
        dey
        bpl _draw_tower_loop
        ldx #(HEADER_HEIGHT / 2)
        jsr sub_wsync_loop
        jmp game_draw_return
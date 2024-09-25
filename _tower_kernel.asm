
repl_draw_tower
        lda #$01
        sta CTRLPF
        lda #WHITE
        sta COLUPF
        ldx #11 ; BUGBUG: magic number
        jsr sub_wsync_loop
        ldy #4
_draw_tower_loop
        lda #$80
        sta PF0
        lda #$ff
        sta PF1
        lda #$f8
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
        ldx #11 ; BUGBUG: magic number
        jsr sub_wsync_loop
        jmp game_draw_return


game_p0_x = game_data + 0
game_p1_x = game_data + 1
game_p0_y = game_data + 2
game_p1_y = game_data + 3
game_bl_x = game_data + 4
game_bl_y = game_data + 5

repl_draw_game
        ldx #1
_game_respx_loop
        jsr sub_respx_object
        dex
        bpl _game_respx_loop
        ldx #4
        jsr sub_respx_object
        sta WSYNC
        sta HMOVE
        
        lda #$ff
        sta GRP0
        sta GRP1
        sta ENABL
        ldy #HEADER_HEIGHT
_draw_game_loop
        sta WSYNC
        dey
        bpl _draw_game_loop
        lda #$00
        sta GRP0
        sta GRP1
        sta ENABL
        jmp repl_draw_return

sub_respx_object
        lda game_p0_x,x
        sta WSYNC
        SLEEP 3                  ;3  3
        sec                      ;2  5
_respx_object_loop
        sbc #15                  ;2  7
        bpl _respx_object_loop   ;2  9
        tay                      ;2 11
        lda LOOKUP_STD_HMOVE,y   ;4 15 
        sta HMP0,x               ;4 19
        sta RESP0,x              ;4 23
        rts
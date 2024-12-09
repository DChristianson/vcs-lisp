

game_p0_x = game_data + 0
game_p1_x = game_data + 1
game_bl_x = game_data + 2
game_p0_y = game_data + 3
game_p1_y = game_data + 4
game_bl_y = game_data + 5
game_p0_shape = game_data + 6
game_p1_shape = game_data + 7

game_p0_h = gx_s4_addr + 0
game_p1_h = gx_s4_addr + 1
game_bl_h = gx_s4_addr + 2
game_p0_s = gx_s4_addr + 3
game_p1_s = gx_s4_addr + 4

repl_init_game
        ldy #16
        ldx #2
_repl_init_game_loop
        lda OBJ_X,x
        sta game_p0_x,x
        sty game_p0_y,x
        lda #1
        sta game_p0_shape,x
        dex
        bpl _repl_init_game_loop
        jmp game_state_init_return

OBJ_X
        byte 5, 123, 64
OBJ_TAB
        byte 0, 1
POW_2_4
        byte 4, 8

repl_draw_game
        ; resp all objects
        ldy #2
_game_respx_loop
        ldx game_p0_y,y
        stx game_p0_h,y
        ldx game_p0_shape,y
        stx game_p0_s,y ; BUGBUG: overwrite
        lda game_p0_x,y
        sta WSYNC
        sec                      ;2  5
_respx_object_loop
        sbc #15                  ;2  7
        bpl _respx_object_loop   ;2  9
        tax                      ;2 11
        lda LOOKUP_STD_HMOVE,x   ;4 15 
        ldx OBJ_TAB,y
        sta HMP0,x               ;4 19
        sta RESP0,x              ;4 23
        dey
        bpl _game_respx_loop

        sta WSYNC
        sta HMOVE
        lda #$10
        sta CTRLPF        
        ldy #31
_draw_game_loop
        ldx #1
        sta WSYNC
_game_setup_gfx_loop
        lda #$00                 ;3    3
        dec game_p0_h,x          ;6    9
        bpl _game_skip_gfx       ;2/3 11
        dec game_p0_s,x          ;6   17
        bmi _game_skip_gfx       ;2/3 19
        lda #$18                 ;2   21
_game_skip_gfx
        sta GRP0,x               ;4   25
        dex
        bpl _game_setup_gfx_loop
        sta WSYNC
        lda #$00
        dec game_bl_h
        bne _game_skip_bl_gfx
        lda #$02
_game_skip_bl_gfx
        sta ENABL
        dey
        bpl _draw_game_loop
        sta WSYNC
        jmp game_draw_return

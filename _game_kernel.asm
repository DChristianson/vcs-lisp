

game_p0_x = game_data + 0
game_p1_x = game_data + 1
game_p0_y = game_data + 2
game_p1_y = game_data + 3
game_bl_x = game_data + 4
game_bl_y = game_data + 5
game_p0_h = gx_s4_addr + 0
game_p1_h = gx_s4_addr + 1
game_bl_h = gx_s4_addr + 2

repl_init_game
        lda #5
        sta game_p0_x
        lda #76
        sta game_bl_x
        lda #140
        sta game_p1_x
        lda #12
        sta game_p0_y
        sta game_p1_y
        sta game_bl_y
        jmp game_state_init_return

repl_draw_game
        ; resp all objects
        ldx #1
_game_respx_loop
        lda game_p0_x,x
        jsr sub_respx_object
        lda game_p0_y,x
        sta game_p0_h,x
        dex
        beq _game_respx_loop
        ldx #4
        lda game_bl_x
        jsr sub_respx_object
        lda game_bl_y
        sta game_bl_h

        sta WSYNC
        sta HMOVE
        lda #$10
        sta CTRLPF        
        ldy #23
_draw_game_loop
        sta WSYNC
        ldx #1
_game_setup_gfx_loop
        lda #$00
        dec game_p0_h,x
        bne _game_skip_gfx
        lda #$18
_game_skip_gfx
        sta GRP0,x
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



game_p0_x = game_data + 0
game_p1_x = game_data + 1
game_bl_x = game_data + 2
game_p0_y = game_data + 3
game_p1_y = game_data + 4
game_bl_y = game_data + 5
game_px_shape = game_data + 6
game_bl_dir = game_data + 7

game_px_addr_lo = gx_s4_addr + 0 ; make this addr loc match gx_s2_addr
game_px_addr_hi = gx_s4_addr + 1 ; to avoid glitches in repl reading unitialized gx vars

repl_init_game
        ldx #3
_repl_init_game_loop
        lda OBJ_X-1,x
        sta game_p0_x-1,x
        lda OBJ_Y-1,x
        sta game_p0_y-1,x
        dex
        bne _repl_init_game_loop ; SPACE: make sure x ends at zero
        stx game_px_shape
        stx game_bl_dir
        jmp game_state_init_return

OBJ_X
        byte 5, 123, 64
OBJ_Y
        byte 12, 12, 16
OBJ_TAB
        byte 0, 1
POW_2_4
REFL_X
        byte 4, 8

repl_draw_game
        ; resp all objects
        ldy #2
_game_respx_loop
        lda game_p0_x,y          ;5   5
        sta WSYNC                ;------
        sec                      ;2   2
_respx_object_loop
        sbc #15                  ;2   4
        bpl _respx_object_loop   ;2*  6
        tax                      ;2   8
        lda LOOKUP_STD_HMOVE,x   ;4  12 
        ldx OBJ_TAB,y            ;4  16
        sta HMP0,x               ;4  20
        sta RESP0,x              ;4  24
        sta WSYNC                ;3  27
        lda game_px_shape
        and #$01
        beq _respx_skip_colorize
        lda SPRITE_COLORS,y
        sta COLUP0,y
_respx_skip_colorize
        dey                      ;2  29
        bpl _game_respx_loop     ;3  32
        sta WSYNC                ;-----
        sta HMOVE
        lda game_px_shape
        and #$01
        tax
        lda #>SYMBOL_GRAPHICS_P0
        sta game_px_addr_hi
        lda GAME_SHAPE_LO,x
        sta game_px_addr_lo
        lda game_px_shape
        sta REFP1
        asl
        sta REFP0

        lda #$10
        sta CTRLPF  
        ldx #32
_draw_game_loop
        txa                        ;2    2
        sec        
        sbc game_p0_y              ;3    5
        tay                        ;2    7
        and #$f8                   ;2    9
        beq _game_skip_gfx_0       ;2/3 11
        ldy #0                     ;2   13
_game_skip_gfx_0
        lda (game_px_addr_lo),y    ;5   18
        sec                        ;  get ready for next sbc
        sta WSYNC
        sta GRP0                   ;3    3
        txa                        ;2    5
        sbc game_p1_y              ;3    8
        tay                        ;2   10
        and #$f8                   ;2   12
        beq _game_skip_gfx_1       ;2/3 14
        ldy #0                     ;2   16
_game_skip_gfx_1
        lda (game_px_addr_lo),y    ;5   21
        sta GRP1                   ;3   24
        lda #$00
        cpx game_bl_y
        bne _game_skip_bl_gfx
        lda #$02
_game_skip_bl_gfx
        sta WSYNC
        sta ENABL
        dex
        bne _draw_game_loop
        stx GRP0
        stx GRP1
        stx ENABL
        stx REFP0          
        stx REFP1
        jmp game_draw_return_no_clr

GAME_SHAPE_LO
        byte <SYMBOL_GRAPHICS_OR
        byte <SYMBOL_GRAPHICS_SQRL

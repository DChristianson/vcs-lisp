
; tower of hanoi

tower_disc_0 = game_data + 0 
tower_disc_1 = game_data + 1
tower_disc_2 = game_data + 2
tower_disc_3 = game_data + 3
tower_disc_4 = game_data + 4

tower_tmp_level = game_data + 5

curr_disc_pf0 = gx_s4_addr + 0
curr_disc_pf1 = gx_s4_addr + 1
curr_disc_pf2 = gx_s4_addr + 2
curr_disc_pf5 = gx_s4_addr + 4 ; deliberately inverted, and 4 away from pf0
curr_disc_pf4 = gx_s4_addr + 5 ; deliberately 4 away from pf1
curr_disc_pf3 = gx_s4_addr + 6;

; data representation:
; yyyyyxxx - top 5 bits select what level the disc appears on, bottom 3 select the stack
;          - stacks: A=001, B=010, C=100
;          - levels: 10000 = level 5 (lowest), 01000 = level 4 
; initial state:
; 00001001
; 00010001
; 00100001
; 01000001
; 10000001
repl_init_tower
        lda #$81
        ldx #4
_repl_init_tower_loop
        sta tower_disc_0,x
        lsr
        eor #$01
        dex
        bpl _repl_init_tower_loop
        jmp game_state_init_return

repl_draw_tower
        lda #$01
        sta CTRLPF
        lda #WHITE
        sta COLUPF
        ldx #25 ; BUGBUG: magic number
        jsr sub_wsync_loop
        lda #$08
        sta tower_tmp_level
_draw_tower_loop
        jsr sub_clr_pf
        ldx #6
_draw_tower_clear_loop
        sta curr_disc_pf0,x
        dex
        bpl _draw_tower_clear_loop
        ldx #4
_draw_tower_draw_disc_loop
        lda tower_disc_0,x
        bit tower_tmp_level
        beq _draw_tower_skip_disc
        and #$06
        tay
        and #$02
        bne _draw_tower_draw_disc_b
_draw_tower_draw_disc_ac
        lda TOWER_DISC_AC_PF1,x
        ora curr_disc_pf1,y
        sta curr_disc_pf1,y
        cpx #4
        bne _draw_tower_skip_disc
        lda #$80
        sta curr_disc_pf0,y
        lda #$01
        bpl _draw_tower_draw_disc_ac_base
_draw_tower_draw_disc_b
        ldy #0
        lda TOWER_DISC_B_PF2,x
        ora curr_disc_pf2,y
_draw_tower_draw_disc_ac_base
        sta curr_disc_pf2,y
_draw_tower_skip_disc
        dex
        bpl _draw_tower_draw_disc_loop
        ldx #4
_draw_tower_draw_level_loop
        sta WSYNC                       ;-- --
        lda curr_disc_pf0               ;3   3
        sta PF0                         ;3   6
        ldy #-1                         ;2   8
_draw_tower_level_half
        lda curr_disc_pf2,y             ;4  12-23 ; intentional wraparound
        sta PF2,y                       ;4  16-27
        iny                             ;2  18-29
        beq _draw_tower_level_half      ;2* 30-31
        lda curr_disc_pf5               ;3  34
        sta PF0                         ;3  37
        lda curr_disc_pf4               ;3  40
        sta PF1                         ;3  43
        lda curr_disc_pf3               ;3  46
        sta PF2                         ;3  49
        dex
        bpl _draw_tower_draw_level_loop
        asl tower_tmp_level
        bne _draw_tower_loop
_draw_tower_loop_end
        jsr sub_clr_pf
        sta WSYNC
        lda #$18
        sta PF1
        lda #$80
        sta PF2
        jmp game_draw_return

        ; y = stack, x will be top disk 0-4
sub_repl_find_tower_top
        ldx #0
_find_top_disc_loop
        lda TOWER_STACK_MASK,y
        and tower_disc_0,x
        bne _find_top_disc
        inx
        cpx #5
        bne _find_top_disc_loop
        ldx #$80
_find_top_disc
        rts

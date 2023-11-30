    processor 6502
    include "vcs.h"
    include "macro.h"

NTSC = 0
PAL60 = 1

    IFNCONST SYSTEM
SYSTEM = NTSC
    ENDIF

; ----------------------------------
; constants

#if SYSTEM = NTSC
; NTSC Colors
WHITE = $0f
BLACK = 0
RED = $30
LOGO_COLOR = $C4
CURSOR_COLOR = $86
SCANLINES = 262
#else
; PAL Colors
WHITE = $0E
BLACK = 0
RED = $42
LOGO_COLOR = $53
CURSOR_COLOR = $86
SCANLINES = 262
#endif

CLOCK_HZ = 60
STAIRS_MARGIN = 2
NUM_AUDIO_CHANNELS = 2

CHAR_HEIGHT = 8
DRAW_TABLE_SIZE = 19
DRAW_TABLE_BYTES = DRAW_TABLE_SIZE

JUMP_TABLE_SIZE = 16
JUMP_TABLE_BYTES = JUMP_TABLE_SIZE / 2

GAME_STATE_INIT    = 0
GAME_STATE_START   = 1
GAME_STATE_CLIMB   = 2
GAME_STATE_JUMP    = 3
GAME_STATE_SCROLL  = 4
GAME_STATE_FALL    = 5
GAME_STATE_WIN     = 6

; ----------------------------------
; vars

  SEG.U VARS

    ORG $80

; frame-based "clock"
frame              ds 1
game_state         ds 1

; game audio
audio_timer        ds 2
audio_tracker      ds 2

; combined player input
; bits: f...rldu
player_input       ds 2
; debounced p0 input
player_input_latch ds 1
player_step        ds 1 ; step the player is at
player_jump        ds 1 ; jump counter
player_inc         ds 1 ; direction of movement
player_goal        ds 1 ; next goal
player_score       ds 1 ; decimal score
player_flight      ds 1 ; current flight
player_clock       ds 1 ; for player timer
player_timer       ds 2 ; game timer

; game state
jump_table           ds JUMP_TABLE_BYTES 
jump_table_end_byte  ds 1 ; last byte of jump table
jump_table_offset    ds 1 ; where to locate jump table for drawing
jump_table_size      ds 1 ; number of entries in jump table

; drawing registers
draw_bugbug_margin ds 1
draw_steps_respx   ds 1
draw_steps_dir     ds 1 ; top of steps direction
draw_steps_wsync   ds 1 ; amount to shim steps up/down
draw_base_dir      ds 1 ; base of steps direction
draw_base_lr       ds 1 ; base of steps lr position
draw_player_dir    ds 1 ; player direction
draw_hmove_a       ds 1 ; initial HMOVE
draw_hmove_b       ds 1 ; reverse HMOVE
draw_flight_offset ds 1 ; flight to start at
draw_step_offset   ds 1 ; what step do we start drawing at
draw_table         ds DRAW_TABLE_BYTES
draw_s0_addr       ds 2
draw_s1_addr       ds 2
draw_s2_addr       ds 2
draw_s3_addr       ds 2

; random var
seed
random             ds 2
maze_ptr           ds 2

; DONE
;  - basic step display
;  - static sprite moves according to rules
;  - debug steps
;  - visual 1
;   - start on ground (first step below)
;   - smooth scroll up
;   - values disappear as you climb
;  - gameplay 1
;   - start mode
;   - win condition
;   - score display
;   - timer display
;   - mix of puzzles
;   - climb step by step 
;   - time based randomization
;   - fall step by step
; MVP
;  - sounds 1
;   - bounce up/down fugue
;   - fall down notes
;   - landing song
;   - final success
;  - gameplay 1
;   - no fall penalty from start step
;   - difficulty select
;  - visual 2
;   - title 
; TODO
;  - sounds 2
;   - fugueify sounds
;  - visual 3
;   - climb animation 
;   - fall tumble animation
;   - varied color background
;   - stair outlines
;   - animated jumps + targeting
;   - color stairs
;   - contrasting background
;   - PF gutters
;  - gameplay 2
;   - tweak scoring
;   - maze variety? (generate)
;  - gameplay 3
;   - time limit (lava?)
; NODO
;  - second player

; ----------------------------------
; code

  SEG
    ORG $F000

Reset
CleanStart
    ; do the clean start macro
            CLEAN_START

            lda #WHITE
            sta COLUP0
            sta COLUP1
            sta COLUPF

            lda #>SYMBOL_GRAPHICS
            sta draw_s0_addr + 1
            sta draw_s1_addr + 1
            sta draw_s2_addr + 1
            sta draw_s3_addr + 1

            ; init RNG
            lda #17
            sta seed
            sta seed + 1
            jsr sub_galois

newFrame

    ; 3 scanlines of vertical sync signal to follow

            ldx #%00000010
            stx VSYNC               ; turn ON VSYNC bit 1
            ldx #0

            sta WSYNC               ; wait a scanline
            sta WSYNC               ; another
            sta WSYNC               ; another = 3 lines total

            stx VSYNC               ; turn OFF VSYNC bit 1

    ; 37 scanlines of vertical blank to follow

;--------------------
; VBlank start

            lda #%00000010
            sta VBLANK

            lda #42    ; vblank timer will land us ~ on scanline 34
            sta TIM64T

    ; check reset switches
            lda #$01
            bit SWCHB
            bne _end_switches
            jmp CleanStart
_end_switches


;---------------------
;  update kernels


            inc frame

ax_update   
            ldx #NUM_AUDIO_CHANNELS - 1
_ax_loop 
            lda audio_tracker,x
            beq _ax_next
            ldy audio_timer,x
            beq _ax_next_note
            dey
            sty audio_timer,x
            jmp _ax_next
_ax_next_note
            tay
            lda AUDIO_TRACKS,y
            beq _ax_pause
            cmp #255
            beq _ax_stop
            sta AUDC0,x
            iny
            lda AUDIO_TRACKS,y
            sta AUDF0,x
            iny
            lda AUDIO_TRACKS,y
            sta AUDV0,x
            jmp _ax_next_timer
_ax_pause
            lda #$0
            sta AUDC0,x
            sta AUDV0,x
_ax_next_timer
            iny
            lda AUDIO_TRACKS,y
            sta audio_timer,x
            iny
            sty audio_tracker,x
            jmp _ax_next
_ax_stop ; got a 255
            iny 
            lda AUDIO_TRACKS,y ; store next track #
            sta audio_tracker,x 
            bne _ax_next_note ; if not zero loop back 
            sta AUDV0,x
            sta audio_timer,x
_ax_next
            dex
            bpl _ax_loop

            ; update player input
jx_update
            ldx #1
            lda SWCHA
            and #$0f
_jx_update_loop
            sta player_input,x 
            lda #$80
            and INPT4,x        
            ora player_input,x 
            sta player_input,x 
_jx_update_no_signal
            dex
            bmi _jx_update_end
            lda SWCHA
            lsr
            lsr
            lsr
            lsr
            ldy player_input   
            jmp _jx_update_loop
_jx_update_end
            tya ; debounce p0 joystick
            eor #$8f           
            ora player_input   
            sta player_input_latch

; process game state

            ldx game_state
            lda GX_JUMP_HI,x
            pha
            lda GX_JUMP_LO,x
            pha
            rts

GX_JUMP_LO
    byte <(gx_init-1)
    byte <(gx_start-1)
    byte <(gx_climb-1)
    byte <(gx_jump-1)
    byte <(gx_scroll-1)
    byte <(gx_fall-1)
    byte <(gx_win-1)
GX_JUMP_HI
    byte >(gx_init-1)
    byte >(gx_start-1)
    byte >(gx_climb-1)
    byte >(gx_jump-1)
    byte >(gx_scroll-1)
    byte >(gx_fall-1)
    byte >(gx_win-1)

gx_scroll
gx_fall
gx_jump
            ; continue from wherever we were
            rts

gx_init
            ; bootstrap steps
            jsr sub_steps_blank
            lda #TRACK_TITLE
            sta audio_tracker
            lda #GAME_STATE_START
            sta game_state
gx_start    
            ; start of climb
            bit player_input_latch
            bpl _start_game
            jsr sub_galois ; cycle randomization
            jmp gx_continue
_start_game
            jsr sub_steps_init
            lda #TRACK_START_GAME
            sta audio_tracker
            lda #GAME_STATE_CLIMB
            sta game_state
            jmp gx_continue
            
gx_win    
            lda frame
            sta COLUP0
            sta COLUP1
            lda player_input_latch
            eor #$8f
            bne _reset_game
            jmp gx_continue
_reset_game
            jmp Reset ; BUGBUG - more smart reset?

gx_climb
gx_update
            ldx player_step
            jsr sub_step_getx
            tay
            lda player_input_latch
            ror
            bcs _gx_update_check_down
            jmp gx_go_up
_gx_update_check_down
            ror
            bcs _gx_update_check_left
            jmp gx_go_down
_gx_update_check_left
            ror
            bcs _gx_update_check_right
            bit draw_player_dir
            bmi _gx_update_rev_left
_gx_update_rev_right
            jmp gx_go_down
_gx_update_check_right
            ror
            bcs gx_update_return
            bit draw_player_dir
            bmi _gx_update_rev_right
_gx_update_rev_left
            jmp gx_go_up
gx_update_return

gx_player_clock    
            lda player_clock
            clc
            adc #1
            cmp #CLOCK_HZ
            bmi _clock_save
            sed
            lda player_timer
            clc
            adc #1
            cmp #$60
            bne _clock_save_sec
            lda #0
            sec
_clock_save_sec
            sta player_timer
            lda player_timer + 1
            adc #0
            sta player_timer + 1
            cld
            lda #0
_clock_save
            sta player_clock 

gx_continue
            jsr sub_calc_respx
            ; prep some gx
            lda player_score
            ldx #0
            jsr sub_write_digit
            lda player_timer
            ldx #4
            jsr sub_write_digit

;---------------------
; end vblank

            ldx #$00
            stx REFP0
            stx NUSIZ0
            stx NUSIZ1
            stx VDELP0
            stx VDELP1
endVBlank_loop          
            cpx INTIM
            bmi endVBlank_loop
            stx VBLANK

            sta WSYNC ; SL 35

gx_score
            lda #120
            ldy #$ff
            jsr sub_steps_respxx
            ldy #(CHAR_HEIGHT - 1)
_gx_score_loop
            sta WSYNC
            lda (draw_s0_addr),y
            sta GRP0
            lda (draw_s1_addr),y
            sta GRP1
            dey
            bpl _gx_score_loop

gx_steps_resp
            lda draw_player_dir
            sta REFP0
            lda draw_steps_respx
            ldy draw_steps_dir
            jsr sub_steps_respxx

gx_step_draw

            ; last stair will shim
            sta WSYNC
            sta HMOVE
            lda draw_table + DRAW_TABLE_SIZE - 1
            MAC_WRITE_STAIR ; BUGBUG: sets a with PF value
            ldy draw_steps_wsync
_gx_draw_shim_hi
            MAC_DRAW_STAIR
            lda #$00 ; BUGBUG: sets a with PF value
            dey 
            bpl _gx_draw_shim_hi

            ; mid stairs (shift up)
            ldx #DRAW_TABLE_SIZE - 3
_gx_step_draw_loop
            sta WSYNC
            sta HMOVE
            lda draw_table + 1,x
            MAC_WRITE_STAIR 
            ldy #CHAR_HEIGHT - 1
_gx_draw_loop
            MAC_DRAW_STAIR
            lda #$00 ; BUGBUG: sets a with PF value
            dey 
            bpl _gx_draw_loop
            dex 
            bpl _gx_step_draw_loop

            ; last stair will shim
            sta WSYNC
            sta HMOVE
            lda draw_table
            MAC_WRITE_STAIR ; BUGBUG: sets a with PF value
            ldy #CHAR_HEIGHT - 1
_gx_draw_shim_lo
            MAC_DRAW_STAIR
            lda #$00 ; BUGBUG: sets a with PF value
            dey 
            cpy draw_steps_wsync
            bpl _gx_draw_shim_lo

gx_timer
            lda #0
            sta GRP0
            sta GRP1
            sta GRP0
            sta COLUBK
            sta REFP0
            lda #1
            sta NUSIZ0
            sta NUSIZ1
            sta VDELP0
            sta VDELP1
            lda #19
            ldy #$ff
            jsr sub_steps_respxx
            lda player_timer + 1
            ldx #0
            jsr sub_write_digit
            ldy #(CHAR_HEIGHT - 1)
_gx_timer_loop
            sta WSYNC
            lda (draw_s0_addr),y   ;5   5
            sta GRP0               ;3   8
            lda (draw_s1_addr),y   ;5  13
            sta GRP1               ;3  16
            lda (draw_s2_addr),y   ;5  21
            sta GRP0               ;2  24
            lda (draw_s3_addr),y   ;5  29
            sta GRP1               ;3  40
            sta GRP0
            dey
            bpl _gx_timer_loop


;--------------------
; Overscan start

waitOnOverscan
            ldx #30
            jsr sub_wsync_loop
            jmp newFrame

;
; game control subroutines
;

sub_wsync_loop
_header_loop
            sta WSYNC
            dex
            bpl _header_loop
            rts

sub_write_digit
            ; a is digit, x is zero page offset
            tay
            and #$0f
            asl
            asl
            asl
            sta draw_s1_addr,x
            tya
            and #$f0
            lsr
            sta draw_s0_addr,x
            rts

sub_steps_blank
            lda #$40 + ((SYMBOL_GRAPHICS_S12_BLANK - SYMBOL_GRAPHICS) / 8)
            ldx #(DRAW_TABLE_SIZE - 3)
_steps_blanks_loop
            sta draw_table + 2,x
            dex
            bpl _steps_blanks_loop
            lda #$80 + ((SYMBOL_GRAPHICS_S12_BLANK - SYMBOL_GRAPHICS) / 8)
            sta draw_table + 1
            lda #$20 + ((SYMBOL_GRAPHICS_S12_BLANK - SYMBOL_GRAPHICS) / 8)
            sta draw_table
            rts

sub_steps_init
            lda #5 ; BUGBUG magic number
            sta draw_base_lr
            ; jump init
            lda #$ff
            sta draw_base_dir
            lda #6
            jsr sub_gen_steps
sub_steps_refresh
            ; clear draw table
            ldx #(DRAW_TABLE_SIZE - 1)
            lda #0
_steps_draw_clear_loop
            sta draw_table,x
            dex
            bpl _steps_draw_clear_loop
sub_steps_flights
            ; add flight markers
            ldy draw_flight_offset
            lda draw_step_offset; current step
_steps_draw_flights
            sta draw_bugbug_margin
            clc
            adc FLIGHTS,y
            cmp draw_bugbug_margin
            beq _steps_draw_last_flight
            cmp #DRAW_TABLE_SIZE
            bpl _steps_draw_flights_end
            tax
            lda #$40
            sta draw_table,x
            dex
            txa
            iny
            jmp _steps_draw_flights 
_steps_draw_last_flight
            tax
            lda #$40 + ((SYMBOL_GRAPHICS_S12_BLANK - SYMBOL_GRAPHICS) / 8)
            jmp _steps_draw_blanks_start
_steps_draw_blanks_loop
            sta draw_table,x
_steps_draw_blanks_start
            inx
            cpx #DRAW_TABLE_SIZE
            bmi _steps_draw_blanks_loop            
_steps_draw_flights_end
sub_steps_jump
            ldx jump_table_end_byte
            lda jump_table_size
            clc
            adc jump_table_offset
            tay
            dey
_steps_draw_jumps
            lda jump_table,x
            lsr
            lsr
            lsr
            lsr
            ora draw_table,y
            sta draw_table,y
            dey
            bmi _steps_end_jumps
            lda jump_table,x
            and #$0f
            ora draw_table,y
            sta draw_table,y
            dey
            bmi _steps_end_jumps ; if offset is negative exit this loop
            dex
            bpl _steps_draw_jumps
_steps_end_jumps
            jsr sub_draw_player_step
sub_background
            ; draw ground and sky
            lda draw_flight_offset
            ora draw_step_offset
            bne _sub_background_end
            lda draw_table
            ora #$20
            sta draw_table
_sub_background_end
            rts

sub_steps_advance
            ; move jump table "up" to next flight
            ldy player_flight
            lda FLIGHTS,y
            beq sub_steps_win
            lsr
            tax
            lda MARGINS,x
            sta draw_bugbug_margin 
            lda jump_table_size
            sec
            sbc #1
            clc
            adc jump_table_offset
            tax 
            clc 
            adc FLIGHTS,y
            sec
            sbc draw_bugbug_margin
            bmi _sub_steps_advance_save

            ; scroll
            jsr sub_steps_scroll
            jmp sub_steps_advance
_sub_steps_advance_save
            stx jump_table_offset
            ldy player_flight
            lda #0
            sta player_step
            lda FLIGHTS,y
            jsr sub_gen_steps
            lda #GAME_STATE_CLIMB
            sta game_state
            lda draw_player_dir
            eor #$88 ; invert player dir between 8 and 0
            sta draw_player_dir
            jmp sub_steps_refresh ; redraw steps (will rts from there)

sub_steps_win
            lda #TRACK_WIN_GAME
            sta audio_tracker
            lda #GAME_STATE_WIN
            sta game_state
            rts

sub_steps_scroll
            lda draw_steps_wsync
            clc
            adc #1
            and #$07
            sta draw_steps_wsync
            bne _sub_scroll_cont
            dec jump_table_offset 
            ldy draw_flight_offset
            dec draw_step_offset
            lda #-1
            bit draw_base_dir
            bpl _sub_scroll_lr_calc
            lda #1
_sub_scroll_lr_calc
            clc
            adc draw_base_lr
            sta draw_base_lr
            lda draw_step_offset
            clc
            adc FLIGHTS,y
            sec
            sbc #1
            bne _sub_scroll_update
            iny
            sty draw_flight_offset
            lda draw_base_dir
            eor #$ff
            sta draw_base_dir
            lda #0
            sta draw_step_offset
_sub_scroll_update
            jsr sub_steps_refresh
_sub_scroll_cont
            lda #GAME_STATE_SCROLL
            sta game_state
            jmp gx_continue ; will continue later

sub_steps_respxx
            ; a is respx, y is direction
            sec
            sta WSYNC               ; --
_respxx_loop
            sbc #15                 ;2    2
            sbcs _respxx_loop       ;2/3  4
            tax                     ;2    6
            lda LOOKUP_STD_HMOVE,x  ;5   11
            sta HMP0                ;3   14
            sta HMP1                ;3   17
            tya                     ;2   19
            bpl _respxx_swap        ;2   21
            sta.w RESP0             ;4   25
            sta RESP1               ;3   28
            sta WSYNC               ;
            sta HMOVE               ;3    3
            lda #$70                ;2    5
            sta draw_hmove_a        ;3    8
            lda #$90                ;2   10
            sta draw_hmove_b        ;3   13
            SLEEP 10 ; BUGBUG: kludge
            lda #$20                ;2   15
            sta HMP0                ;3   21
            lda #$30
            sta HMP1                ;3   24
            rts                     ;6   30
_respxx_swap            
            sta RESP1               ;3   25
            sta RESP0               ;3   28
            sta WSYNC
            sta HMOVE
            lda #$90                ;2    5
            sta draw_hmove_a        ;3    8
            lda #$70                ;2   10
            sta draw_hmove_b        ;3   13
            SLEEP 10 ; BUGBUG: kludge
            lda #$40                ;3   21
            sta HMP0                ;3   24
            lda #$10                ;3   27
            sta HMP1                ;3   30
            rts                     ;6   36

sub_calc_respx
            ldx #0
            ldy draw_base_lr
            bit draw_base_dir
            bmi _calc_respx_right
_calc_respx_left
            lda draw_table + 1,x
            and #$40
            bne _calc_respx_switch_right
_calc_respx_switch_left
            dey
            inx
            cpx #(DRAW_TABLE_SIZE - 1)
            bne _calc_respx_left
            tya
            ldy #$00
            jmp _calc_respx_end
_calc_respx_right
            lda draw_table + 1,x
            and #$40
            bne _calc_respx_switch_left
_calc_respx_switch_right
            iny
            inx
            cpx #(DRAW_TABLE_SIZE - 1)
            bne _calc_respx_right
            dey
            tya
            ldy #$ff
_calc_respx_end
            sta draw_bugbug_margin
            asl
            asl
            asl
            sec
            sbc draw_bugbug_margin 
            clc 
            adc #STAIRS_MARGIN
            sta draw_steps_respx
            sty draw_steps_dir
            rts


sub_step_getx
            txa ; x has step number
            lsr ; div by 2
            tay
            lda jump_table,y
            bcc _step_get_lo
            lsr
            lsr
            lsr
            lsr
_step_get_lo
            and #$0f
            rts 

sub_gen_steps
            sta jump_table_size
            lsr
            sta maze_ptr ; save for multiply
            sec
            sbc #1
            sta jump_table_end_byte
            tay
            lda MAZE_PTR_HI,y
            sta maze_ptr + 1
            jsr sub_galois
            and #$f8 ; 32 get top 32 bits
            beq _sub_gen_steps_selected
            sta draw_bugbug_margin
            ldx #3
            lda #0
_sub_gen_steps_mul
            asl 
            asl draw_bugbug_margin
            bcc _sub_gen_steps_skip
            clc
            adc maze_ptr
_sub_gen_steps_skip
            dex 
            bpl _sub_gen_steps_mul
_sub_gen_steps_selected
            clc
            ldy jump_table_end_byte
            adc MAZE_PTR_LO,y
            sta maze_ptr
_sub_gen_steps_loop
            lda (maze_ptr),y
            sta jump_table,y
            dey
            bpl _sub_gen_steps_loop
            ldx jump_table_size
            dex
            stx player_goal
            rts
            
; test code - generate maze of all 1's
;             tax
;             lda #$01
;             sta jump_table,x
;             dex
;             lda #$11
; _sub_gen_steps_loop
;             sta jump_table,x
;             dex
;             bpl _sub_gen_steps_loop


sub_galois  ; 16 bit lfsr from: https://github.com/bbbradsmith/prng_6502/tree/master
            lda seed+1
            tay ; store copy of high byte
            ; compute seed+1 ($39>>1 = %11100)
            lsr ; shift to consume zeroes on left...
            lsr
            lsr
            sta seed+1 ; now recreate the remaining bits in reverse order... %111
            lsr
            eor seed+1
            lsr
            eor seed+1
            eor seed+0 ; recombine with original low byte
            sta seed+1
            ; compute seed+0 ($39 = %111001)
            tya ; original high byte
            sta seed+0
            asl
            eor seed+0
            asl
            eor seed+0
            asl
            asl
            asl
            eor seed+0
            sta seed+0
            rts            

gx_go_up
            lda #1
            jmp _gx_go_add_step
gx_go_down
            lda #-1
_gx_go_add_step
            sty player_jump
            sta player_inc
            lda #GAME_STATE_JUMP
            sta game_state
            ; intentional fallthrough to jump process

gx_process_jump
            lda player_inc
            clc
            adc player_step
            ; move player
            sta player_step
            bmi _gx_go_fall_down
            cmp player_goal
            bcc _gx_process_dec_jump
            bne _gx_go_fall_up
_gx_process_dec_jump
            tax
            asl
            asl
            asl
            clc 
            adc #TRACK_STEP_IDX
            sta audio_tracker
            txa
            dec player_jump
            beq _gx_process_jump_arrive
            ; continue movement
_gx_process_step_loop
            jsr _gx_go_redraw_player ; will continue back
            lda audio_tracker
            bne _gx_process_step_loop
            jmp gx_process_jump
_gx_process_jump_arrive
            ldx #GAME_STATE_CLIMB
            stx game_state
            cmp player_goal
            bne _gx_go_redraw_player
            ; advance
            lda #TRACK_LANDING
            sta audio_tracker
            ldy player_flight
            sed
            lda FLIGHTS,y
            lsr
            lsr
            clc
            adc player_score
            sta player_score
            cld
            iny
            sty player_flight
            jsr sub_steps_advance
            jmp _gx_go_redraw_player
_gx_go_fall_down
            lda #0
            sta player_step
            sta player_inc
            inc player_jump
            jmp _gx_go_fall
_gx_go_fall_up
            lda player_goal
            sta player_step
            sta player_jump
            lda #-1
            sta player_inc
_gx_go_fall
            ; fall and recover
            ldx #GAME_STATE_FALL
            stx game_state
            jsr _gx_go_redraw_player ; will continue back
            jmp gx_process_jump
_gx_go_redraw_player
            jsr sub_redraw_player_step
            jmp gx_update_return

sub_redraw_player_step
            ldx #(DRAW_TABLE_BYTES - 1)
_sub_redraw_player_loop
            lda #$7f
            and draw_table+1,x
            sta draw_table+1,x
            dex
            bpl _sub_redraw_player_loop
sub_draw_player_step
            lda player_step
            clc 
            adc jump_table_offset
            tax
            lda #$80
            ora draw_table+1,x
            sta draw_table+1,x
            rts

    MAC MAC_WRITE_STAIR
            ; read graphics from a
            ; phg.ssss
            ; get player graphic
            ldy #<SYMBOL_GRAPHICS_S12_BLANK
            asl 
            bcc ._gx_draw_set_p0
            ldy #<SYMBOL_GRAPHICS_S11_NUTS
._gx_draw_set_p0
            sty draw_s0_addr
            ; swap directions
            asl
            pha
            lda draw_hmove_a
            sta HMP0
            sta HMP1
            bcc ._gx_draw_end_swap_direction
            ldy draw_hmove_b
            sty HMP0
            sty draw_hmove_a
            sta draw_hmove_b
._gx_draw_end_swap_direction
            pla
            ; get step graphic
            asl
            sta draw_s1_addr
            ; check ground bit
            lda #$00
            bcc ._gx_draw_set_pf
            lda #$0f
._gx_draw_set_pf
    ENDM

    MAC MAC_DRAW_STAIR
            sta WSYNC
            sta COLUBK
            lda (draw_s0_addr),y
            sta GRP0
            lda (draw_s1_addr),y
            sta GRP1
    ENDM          

; ----------------------------------
; maze data 

    ORG $F900

MAZES_3

    byte $22,$22,$3 ; w: 0.13333333333333333 sol: 6
    byte $31,$21,$2 ; w: 0.4 sol: 6
    byte $14,$21,$2 ; w: 0.3 sol: 5
    byte $43,$11,$4 ; w: 0.4 sol: 5
    byte $21,$13,$3 ; w: 0.5 sol: 5
    byte $44,$11,$2 ; w: 0.3 sol: 5
    byte $32,$31,$1 ; w: 0.5 sol: 5
    byte $43,$14,$3 ; w: 0.4 sol: 5
    byte $44,$13,$3 ; w: 0.4 sol: 4
    byte $31,$43,$2 ; w: 0.5333333333333334 sol: 5
    byte $24,$23,$3 ; w: 0.5 sol: 5
    byte $24,$13,$3 ; w: 1.3333333333333333 sol: 6
    byte $42,$12,$3 ; w: 0.6666666666666667 sol: 5
    byte $42,$31,$3 ; w: 0.5333333333333334 sol: 4
    byte $14,$21,$3 ; w: 0.5333333333333333 sol: 6
    byte $14,$13,$3 ; w: 0.5 sol: 5
    byte $34,$43,$2 ; w: 0.4 sol: 4
    byte $43,$11,$4 ; w: 0.4 sol: 5
    byte $21,$13,$3 ; w: 0.5 sol: 5
    byte $44,$11,$2 ; w: 0.3 sol: 5
    byte $32,$31,$1 ; w: 0.5 sol: 5
    byte $43,$14,$3 ; w: 0.4 sol: 5
    byte $44,$13,$3 ; w: 0.4 sol: 4
    byte $31,$43,$2 ; w: 0.5333333333333334 sol: 5
    byte $24,$23,$3 ; w: 0.5 sol: 5
    byte $24,$13,$3 ; w: 1.3333333333333333 sol: 6
    byte $42,$12,$3 ; w: 0.6666666666666667 sol: 5
    byte $42,$31,$3 ; w: 0.5333333333333334 sol: 4
    byte $14,$21,$3 ; w: 0.5333333333333333 sol: 6
    byte $14,$13,$3 ; w: 0.5 sol: 5
    byte $34,$43,$2 ; w: 0.4 sol: 4
    byte $43,$11,$4 ; w: 0.4 sol: 5

MAZES_4

    byte $15,$32,$31,$1 ; sol: 7
    byte $15,$14,$43,$3 ; sol: 8
    byte $15,$42,$41,$2 ; sol: 7
    byte $43,$14,$24,$5 ; sol: 7
    byte $25,$35,$42,$2 ; sol: 8
    byte $22,$24,$13,$5 ; sol: 8
    byte $25,$15,$14,$5 ; sol: 7
    byte $25,$14,$33,$5 ; sol: 8
    byte $35,$41,$42,$4 ; sol: 7
    byte $15,$24,$33,$2 ; sol: 6
    byte $55,$42,$41,$4 ; sol: 8
    byte $35,$42,$31,$3 ; sol: 6
    byte $42,$54,$13,$5 ; sol: 7
    byte $43,$32,$13,$5 ; sol: 7
    byte $35,$44,$31,$2 ; sol: 7
    byte $51,$23,$13,$4 ; sol: 7
    byte $15,$42,$42,$3 ; sol: 8
    byte $35,$42,$41,$5 ; sol: 6
    byte $52,$43,$41,$2 ; sol: 8
    byte $25,$31,$43,$2 ; sol: 7
    byte $15,$32,$41,$1 ; sol: 8
    byte $52,$13,$43,$3 ; sol: 8
    byte $43,$35,$12,$5 ; sol: 8
    byte $43,$35,$31,$2 ; sol: 7
    byte $13,$35,$41,$2 ; sol: 8
    byte $25,$44,$31,$5 ; sol: 7
    byte $35,$32,$41,$1 ; sol: 7
    byte $15,$24,$43,$2 ; sol: 7
    byte $35,$35,$41,$4 ; sol: 8
    byte $35,$44,$31,$5 ; sol: 8
    byte $51,$21,$13,$4 ; sol: 8
    byte $52,$24,$13,$3 ; sol: 7

    ORG $FA00

MAZES_5

    byte $52,$16,$43,$61,$5 ; sol: 9
    byte $43,$46,$42,$51,$4 ; sol: 9
    byte $52,$46,$43,$31,$5 ; sol: 10
    byte $53,$52,$43,$41,$6 ; sol: 9
    byte $53,$26,$65,$51,$4 ; sol: 9
    byte $16,$26,$25,$34,$5 ; sol: 9
    byte $62,$62,$14,$45,$3 ; sol: 10
    byte $63,$51,$42,$31,$6 ; sol: 10
    byte $26,$43,$15,$15,$6 ; sol: 10
    byte $24,$54,$43,$41,$6 ; sol: 9
    byte $24,$54,$43,$41,$6 ; sol: 9
    byte $46,$52,$23,$54,$1 ; sol: 9
    byte $26,$15,$46,$15,$3 ; sol: 9
    byte $23,$46,$42,$51,$4 ; sol: 9
    byte $63,$54,$31,$25,$4 ; sol: 10
    byte $16,$25,$15,$45,$3 ; sol: 9
    byte $14,$53,$23,$63,$2 ; sol: 9
    byte $36,$46,$12,$25,$5 ; sol: 9
    byte $36,$26,$13,$24,$5 ; sol: 9
    byte $46,$65,$31,$45,$2 ; sol: 8
    byte $36,$41,$42,$15,$3 ; sol: 10
    byte $35,$64,$31,$61,$2 ; sol: 9
    byte $24,$65,$14,$64,$3 ; sol: 10
    byte $46,$65,$23,$14,$4 ; sol: 10
    byte $36,$26,$15,$64,$5 ; sol: 8
    byte $46,$42,$31,$25,$6 ; sol: 9
    byte $24,$16,$43,$65,$3 ; sol: 8
    byte $16,$52,$43,$45,$3 ; sol: 10
    byte $43,$35,$14,$25,$6 ; sol: 10
    byte $36,$51,$42,$45,$3 ; sol: 9
    byte $46,$62,$31,$15,$2 ; sol: 8
    byte $36,$65,$42,$45,$1 ; sol: 8

    ORG $FB00

MAZES_6

    byte $36,$76,$42,$43,$31,$5 ; sol: 11
    byte $27,$14,$65,$31,$17,$3 ; sol: 11
    byte $46,$65,$27,$14,$57,$3 ; sol: 11
    byte $27,$57,$31,$64,$34,$1 ; sol: 12
    byte $37,$64,$31,$54,$27,$5 ; sol: 12
    byte $27,$16,$45,$35,$42,$6 ; sol: 11
    byte $27,$57,$31,$65,$14,$4 ; sol: 12
    byte $57,$42,$63,$54,$41,$2 ; sol: 11
    byte $57,$52,$63,$54,$41,$7 ; sol: 12
    byte $57,$31,$46,$51,$53,$2 ; sol: 11
    byte $37,$26,$17,$54,$31,$7 ; sol: 11
    byte $27,$57,$31,$65,$34,$7 ; sol: 11
    byte $37,$72,$42,$51,$63,$2 ; sol: 11
    byte $57,$63,$14,$64,$25,$3 ; sol: 11
    byte $57,$53,$27,$64,$51,$3 ; sol: 11
    byte $73,$25,$75,$15,$74,$6 ; sol: 10
    byte $27,$17,$74,$35,$37,$6 ; sol: 10
    byte $57,$62,$73,$54,$13,$7 ; sol: 11
    byte $57,$13,$25,$64,$13,$3 ; sol: 11
    byte $57,$63,$27,$64,$14,$4 ; sol: 11
    byte $47,$62,$31,$65,$37,$4 ; sol: 10
    byte $57,$72,$35,$61,$64,$1 ; sol: 11
    byte $25,$47,$36,$15,$56,$7 ; sol: 10
    byte $57,$62,$23,$54,$13,$7 ; sol: 11
    byte $57,$62,$23,$54,$13,$5 ; sol: 12
    byte $47,$17,$24,$35,$37,$6 ; sol: 11
    byte $47,$62,$52,$51,$13,$7 ; sol: 11
    byte $24,$17,$53,$67,$43,$2 ; sol: 10
    byte $56,$72,$41,$61,$73,$2 ; sol: 10
    byte $57,$63,$21,$64,$13,$4 ; sol: 10
    byte $24,$17,$63,$64,$31,$5 ; sol: 10
    byte $65,$72,$41,$51,$43,$2 ; sol: 10

    ORG $FC00

MAZES_7

    byte $79,$35,$87,$51,$74,$89,$2 ; sol: 14
    byte $79,$85,$82,$53,$74,$69,$2 ; sol: 14
    byte $18,$93,$15,$65,$62,$94,$5 ; sol: 12
    byte $79,$28,$41,$46,$51,$94,$1 ; sol: 13
    byte $86,$92,$41,$71,$73,$13,$4 ; sol: 12
    byte $81,$75,$39,$26,$73,$84,$8 ; sol: 14
    byte $19,$75,$68,$24,$75,$56,$4 ; sol: 12
    byte $94,$87,$13,$74,$15,$67,$7 ; sol: 12
    byte $81,$95,$39,$24,$73,$86,$6 ; sol: 14
    byte $29,$15,$68,$24,$75,$56,$4 ; sol: 12
    byte $87,$54,$68,$35,$15,$96,$7 ; sol: 12
    byte $91,$97,$83,$25,$36,$77,$4 ; sol: 14
    byte $81,$95,$36,$27,$73,$84,$8 ; sol: 14
    byte $62,$53,$69,$14,$37,$81,$8 ; sol: 14
    byte $15,$79,$24,$86,$47,$56,$3 ; sol: 13
    byte $79,$29,$41,$37,$51,$58,$9 ; sol: 12
    byte $87,$24,$68,$35,$15,$96,$7 ; sol: 12
    byte $39,$98,$62,$19,$85,$47,$7 ; sol: 13
    byte $79,$28,$41,$46,$51,$53,$2 ; sol: 12
    byte $99,$85,$74,$23,$86,$74,$1 ; sol: 14
    byte $72,$99,$26,$17,$84,$85,$3 ; sol: 14
    byte $79,$29,$41,$36,$51,$58,$1 ; sol: 13
    byte $27,$64,$68,$35,$15,$96,$7 ; sol: 13
    byte $18,$39,$76,$22,$47,$85,$5 ; sol: 14
    byte $52,$69,$74,$11,$57,$83,$2 ; sol: 13
    byte $18,$39,$76,$12,$47,$85,$3 ; sol: 13
    byte $14,$59,$53,$86,$42,$67,$3 ; sol: 13
    byte $18,$39,$46,$62,$37,$85,$5 ; sol: 14
    byte $59,$82,$91,$36,$75,$49,$4 ; sol: 13
    byte $39,$95,$61,$24,$75,$59,$4 ; sol: 14
    byte $18,$39,$46,$62,$27,$85,$7 ; sol: 13
    byte $18,$39,$46,$52,$27,$85,$1 ; sol: 14

    ORG $FD00

MAZES_8

    byte $42,$69,$18,$84,$82,$37,$35,$8 ; sol: 13
    byte $52,$19,$83,$73,$65,$62,$69,$4 ; sol: 15
    byte $52,$69,$81,$79,$83,$62,$68,$4 ; sol: 15
    byte $82,$19,$83,$79,$35,$62,$61,$4 ; sol: 15
    byte $36,$86,$52,$91,$86,$27,$43,$2 ; sol: 14
    byte $87,$82,$53,$17,$68,$97,$14,$9 ; sol: 14
    byte $82,$93,$57,$61,$57,$84,$74,$4 ; sol: 14
    byte $74,$69,$48,$28,$36,$15,$59,$7 ; sol: 15
    byte $14,$69,$48,$28,$35,$35,$39,$7 ; sol: 16
    byte $36,$19,$48,$72,$78,$25,$67,$4 ; sol: 13
    byte $37,$96,$91,$25,$95,$75,$34,$8 ; sol: 13
    byte $28,$39,$86,$84,$24,$67,$14,$5 ; sol: 14
    byte $28,$47,$86,$56,$53,$69,$78,$1 ; sol: 15
    byte $73,$65,$59,$42,$86,$64,$13,$6 ; sol: 15
    byte $17,$98,$84,$25,$95,$96,$73,$9 ; sol: 13
    byte $35,$81,$41,$57,$93,$35,$62,$8 ; sol: 13
    byte $78,$39,$26,$64,$54,$67,$48,$1 ; sol: 14
    byte $49,$58,$21,$28,$74,$49,$86,$3 ; sol: 13
    byte $49,$58,$26,$97,$74,$49,$16,$3 ; sol: 14
    byte $69,$83,$49,$76,$32,$97,$58,$1 ; sol: 15
    byte $49,$58,$28,$28,$73,$29,$96,$1 ; sol: 15
    byte $28,$15,$86,$86,$43,$69,$78,$5 ; sol: 13
    byte $59,$51,$58,$72,$46,$83,$83,$3 ; sol: 15
    byte $28,$15,$86,$76,$63,$69,$78,$5 ; sol: 15
    byte $58,$39,$26,$64,$64,$67,$48,$1 ; sol: 13
    byte $49,$21,$83,$59,$76,$71,$34,$8 ; sol: 15
    byte $68,$29,$43,$57,$34,$65,$18,$4 ; sol: 13
    byte $76,$92,$23,$53,$96,$65,$81,$4 ; sol: 14
    byte $16,$49,$48,$72,$78,$85,$37,$4 ; sol: 13
    byte $19,$25,$39,$76,$32,$47,$58,$3 ; sol: 14
    byte $58,$39,$86,$24,$54,$67,$68,$1 ; sol: 14
    byte $56,$49,$48,$62,$79,$84,$37,$1 ; sol: 14


; ----------------------------------
; symbol graphics 

    ORG $FE00
    
SYMBOL_GRAPHICS
SYMBOL_GRAPHICS_S00_ZERO
    byte $0,$70,$88,$88,$88,$70,$0,$0; 8
SYMBOL_GRAPHICS_S01_ONE
    byte $0,$70,$20,$20,$20,$60,$0,$0; 8 
SYMBOL_GRAPHICS_S02_TWO
    byte $0,$f8,$80,$f8,$8,$f8,$0,$0; 8 
SYMBOL_GRAPHICS_S03_THREE
    byte $0,$f8,$8,$f8,$8,$f8,$0,$0; 8 
SYMBOL_GRAPHICS_S04_FOUR
    byte $0,$8,$8,$f8,$88,$88,$0,$0; 8 
SYMBOL_GRAPHICS_S05_FIVE
    byte $0,$f8,$8,$f8,$80,$f8,$0,$0; 8 
SYMBOL_GRAPHICS_S06_SIX
    byte $0,$f8,$88,$f8,$80,$f8,$0,$0; 8 
SYMBOL_GRAPHICS_S07_SEVEN
    byte $0,$8,$8,$8,$8,$f8,$0,$0; 8 
SYMBOL_GRAPHICS_S08_EIGHT
    byte $0,$f8,$88,$f8,$88,$f8,$0,$0; 8 
SYMBOL_GRAPHICS_S09_NINE
    byte $0,$8,$8,$f8,$88,$f8,$0,$0; 8 
SYMBOL_GRAPHICS_S10_FLAG
    byte $0,$c0,$c0,$ff,$ff,$ff,$0,$fe; 8 
SYMBOL_GRAPHICS_S11_NUTS
    byte $0,$1c,$3c,$3e,$6c,$6c,$46,$6; 8
SYMBOL_GRAPHICS_S12_BLANK
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8

    ORG $FF00

    ; standard lookup for hmoves
STD_HMOVE_BEGIN
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END
LOOKUP_STD_HMOVE = STD_HMOVE_END - 256

    ; maze data LUT
MAZE_PTR_LO 
    byte 0,0
    byte <MAZES_3
    byte <MAZES_4
    byte <MAZES_5
    byte <MAZES_6
    byte <MAZES_7
    byte <MAZES_8
MAZE_PTR_HI = . - 2
    byte >MAZES_3
    byte >MAZES_4
    byte >MAZES_5
    byte >MAZES_6
    byte >MAZES_7
    byte >MAZES_8

FLIGHTS
    byte 6,6,6,6,8,8,8,8,10,10,10,12,12,12,16,16,16,16,16,0
    ;10,12,12,12,12,14,14,14,14,16,16,16,16,16,16
MAX_FLIGHTS = . - FLIGHTS
MARGINS = . - 3
    byte 12,14,16,16,17,18

AUDIO_TRACKS ; AUDCx,AUDFx,AUDVx,T
     byte 0
TRACK_TITLE = . - AUDIO_TRACKS
     byte $0e,$09,$0a,$08
     byte $0e,$0f,$0a,$08
     byte $0e,$01,$0a,$08
     byte 255,0
TRACK_START_GAME = . - AUDIO_TRACKS
     byte $0e,$09,$0a,$08
     byte $0e,$01,$0a,$08
     byte $0e,$04,$0a,$08
     byte 255,0
TRACK_STEP_IDX = . - AUDIO_TRACKS
     byte $0e,$0f,$0a,$08,255,0,0,0
     byte $0e,$0e,$0a,$08,255,0,0,0
     byte $0e,$0d,$0a,$08,255,0,0,0
     byte $0e,$0c,$0a,$08,255,0,0,0
     byte $0e,$0b,$0a,$08,255,0,0,0
     byte $0e,$0a,$0a,$08,255,0,0,0
     byte $0e,$09,$0a,$08,255,0,0,0
     byte $0e,$08,$0a,$08,255,0,0,0
     byte $0e,$07,$0a,$08,255,0,0,0
     byte $0e,$06,$0a,$08,255,0,0,0
     byte $0e,$05,$0a,$08,255,0,0,0
     byte $0e,$04,$0a,$08,255,0,0,0
     byte $0e,$03,$0a,$08,255,0,0,0
     byte $0e,$02,$0a,$08,255,0,0,0
     byte $0e,$01,$0a,$08,255,0,0,0
     byte $0e,$00,$0a,$08,255,0,0,0
TRACK_FALLING = . - AUDIO_TRACKS
     byte $06,$2,$0a,$0f,255,0
TRACK_LANDING = . - AUDIO_TRACKS
     byte $06,$09,$0a,$08
     byte $06,$01,$0a,$08
     byte $06,$04,$0a,$08
     byte 255,0
TRACK_WIN_GAME = . - AUDIO_TRACKS
     byte $06,$2,$0a,$0f,255,0

;-----------------------------------------------------------------------------------
; the CPU reset vectors

    ORG $FFFA

    .word Reset          ; NMI
    .word Reset          ; RESET
    .word Reset          ; IRQ

    END
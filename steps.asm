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
SKY_BLUE = $A0
SKY_YELLOW = $FA
DARK_WATER = $A0
SUN_RED = $30
CLOUD_ORANGE = $22
GREY_SCALE = $02 
WHITE_WATER = $0A
EARTH_BROWN = $F1
TIMER_RED = $4f
GREEN = $B3
RED = $43
YELLOW = $1f
WHITE = $0f
BLACK = 0
BROWN = $F1
SCANLINES = 262
#else
; PAL Colors
; Mapped by Al_Nafuur @ AtariAge
SKY_BLUE = $92
SKY_YELLOW = $2A
DARK_WATER = $92
SUN_RED = $42
CLOUD_ORANGE = $44
GREY_SCALE = $02 
WHITE_WATER = $0A
EARTH_BROWN = $21
TIMER_RED = $6f
GREEN = $72
RED = $65
YELLOW = $2E
WHITE = $0E
BLACK = 0
BROWN = $21
SCANLINES = 262
#endif

ZARA_COLOR = WHITE_WATER
GROUND_COLOR = GREEN
LAVA_COLOR = RED
DARKS_LOGO = DARK_WATER + 8
LAVA_LOGO = LAVA_COLOR + 2
LEETS_LOGO = SKY_YELLOW + 2

CLOCK_HZ = 60
STAIRS_MARGIN = 2
NUM_AUDIO_CHANNELS = 2

CHAR_HEIGHT = 8
DRAW_TABLE_SIZE = 18

JUMP_TABLE_SIZE = 16
JUMP_TABLE_BYTES = JUMP_TABLE_SIZE
JUMP_SOLUTION_BYTES = JUMP_TABLE_SIZE / 8

FLIGHTS_TABLE_SIZE = 16
FLIGHTS_TABLE_BYTES = FLIGHTS_TABLE_SIZE

TIMER_RESP = 93
TITLE_RESP = 31
SQUIRREL_GANG_RESP = 46

LAVA_TIME_MODULUS = 8
PLAYER_STEP_HEALTH = ZARA_COLOR * 8

GAME_START_SECONDS = 3

GAME_STATE_TITLE   = 0
GAME_STATE_SELECT  = 1
GAME_STATE_START   = 2
GAME_STATE_CLIMB   = 3
GAME_STATE_JUMP    = 4
GAME_STATE_SCROLL  = 5
GAME_STATE_FALL    = 6
GAME_STATE_END     = 7

DIFFICULTY_LEVEL_ARRAY_MASK = $3
DIFFICULTY_LEVEL_LAVA = $4
DIFFICULTY_LEVEL_DARK = $8

AUDIO_VOLUME = 8

; ----------------------------------
; vars

  SEG.U VARS

    ORG $80

; frame-based "clock"
frame              ds 1
game_state         ds 1
difficulty_level   ds 1

; game audio
audio_sequence     ds 1 ; play multiple tracks in sequence
audio_timer        ds 2 ; time to next note
audio_tracker      ds 2 ; which note is playing
audio_vx           ds 1 ; volume

; random var
seed
random             ds 2

; combined player input
; bits: f...rldu
player_input         ds 2
; debounced p0 input
player_input_latch   ds 1
player_special_latch ds 1 ; latch for detecting sequences
player_step          ds 1 ; step the player is at
player_jump          ds 1 ; jump counter
player_invert        ds 1 ; player's last move
player_goal          ds 1 ; next goal
player_score         ds 1 ; decimal score
player_clock         ds 1 ; for player timer
player_timer         ds 2 ; game timer
player_health        ds 1 ; health left

; night_mode
sky_palette          ds 1 ; 

; lava control
lava_clock           ds 1
lava_height          ds 1 ; height on screen
lava_jump_offset     ds 1 ; height vs jump table

; game state
jump_table           ds JUMP_TABLE_BYTES 
jump_table_offset    ds 1 ; where to locate jump table for drawing
jump_table_size      ds 1 ; number of entries in jump table
;jump_solution        ds JUMP_SOLUTION_BYTES

; steps drawing
jump_layout_index    ds 1 ; layout index for jump table
base_layout_index    ds 1 ; layout index for base of stairs
jump_layout_repeat   ds 1 ; number of repeats left for jump table
base_layout_repeat   ds 1 ; number of repeats left for base of stairs

draw_colubk          ds 1
draw_ground_color    ds 1 ; ground color

draw_registers_start

; steps drawing registers
draw_steps_respx    ds 1
draw_steps_dir      ds 1 ; top of steps direction
draw_steps_wsync    ds 1 ; amount to shim steps up/down
draw_base_dir       ds 1 ; base of steps direction
draw_base_lr        ds 1 ; base of steps lr position
draw_base_flight    ds 1
draw_player_dir     ds 1 ; player's travel direction toward goal
draw_step_offset    ds 1 ; what step # do we start drawing at 
draw_lava_counter   ds 1 ; how far to lava counter
draw_player_sprite  ds 1 
draw_table          ds DRAW_TABLE_SIZE
draw_table_top      ds 1 ; steps to skip at start
draw_step_colors    ds DRAW_TABLE_SIZE
draw_cloud_index    ds 1
draw_cloud_side     ds 1

; draw vars used during draw kernels
draw_s0_addr        ds 2
draw_s1_addr        ds 2
draw_s2_addr        ds 2
draw_s3_addr        ds 2
draw_s4_addr        ds 2
draw_s5_addr        ds 2

; temp vars
temp_cloud_pf
temp_select_index
temp_solve_current
temp_step_offset
temp_margin
temp_level_ptr    ; (ds 2)
temp_maze_ptr     ; (ds 2)
temp_y  ds 1
temp_select_repeat
temp_layout_repeat
temp_step_start
temp_solve_jump
temp_p4 ds 1
temp_step_counter
temp_select_mask
temp_timer_stack
temp_rand ds 1
temp_cloud_side ds 1


   ; draw registers for title and select screen
   ORG draw_registers_start

; title color register
draw_c0            ds 1
; title drawing registers
draw_t0
draw_t0_p0_addr    ds 2
draw_t0_p1_addr    ds 2
draw_t0_p2_addr    ds 2
draw_t0_p3_addr    ds 2
draw_t0_p4_addr    ds 2
draw_t0_jump_addr  ds 2
draw_t0_data_addr  ds 2
draw_t1
draw_t1_p0_addr    ds 2
draw_t1_p1_addr    ds 2
draw_t1_p2_addr    ds 2
draw_t1_p3_addr    ds 2
draw_t1_p4_addr    ds 2
draw_t1_jump_addr  ds 2
draw_t1_data_addr  ds 2

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
;   - difficulty select
;   - do we need a score at all? no - just flights count
;  - sounds 1
;   - bounce up/down notes
;   - landing song
;   - final success
;   - jingles on transition moments
;   - fall down should use messed up voice/detuned scale
;  - visual 2
;   - time display have :
;   - PF gutters
;   - title 
;   - goal step has a graphic of some sort
;   - stair outlines
;   - color stairs
;   - tune colors
;   - colors don't have enough contrast
;   - no zeros on stairs
;   - highest step has crown
;   - player points in direction of travel
;   - fall tumble animation
;  - gameplay 2
;   - tweak scoring
;   - drop mazes 10 and 14
;   - improved select screen (directions l/r)
;   - improved game start (no press button, countdown start?)
;   - improved win no end early (scroll up win? double press)
;   - way to end game when no time limit?
;  - glitches
;   - jacked up select
;   - stabilize frames
;   - stabilize stair display horizontally
;   - when the player wins on a 16, can't see 
;   - steps at top of screen should be invisible
;   - stair display horizontal align is bad for 16 across
;   - steps at last flight should be invisible
;   - acorn needs to be shifted based on direction
;   - player needs to be shifted based on direction
;   - player is floating 2 above bottom of stair
;   - need the ground to appear properly
;   - select screen towers should start on left
;   - missing step edges on left of screen (GRP1 timing)
;   - steps at bottom glitch out with direction change
;   - timer display is jacked up
;   - countdown timer too long
;   - pressing select mid title forces the select music not the go tune
;   - pressing select mid title should kill all audio
;   - steps scale not progressive
;  - MVP DONE
;  - code size
;   - shrink or remove flights array
;   - optimize title screen
;  - sounds 2
;   - tuneup sound pass
;  - glitches
;   - frame rate low 243 in select
;   - frame rate high 270+ at top of tower
;   - counter has a glitch before dropoff
;   - player at second to last step has glitch
;   - dark mode doesn't handle ground
;   - select screen glitch
;   - select screen design, shows lava, etc
;   - no need block HMOVEs on title and select screens
;   - space the clouds out
;   - steps screen gaps in HMOVE coverage
;   - lava broken
;   - no clouds in lava
;   - steps screen 263+ lines
;   - top step pop in / shows a line, either remove or fix for real
;   - timer glitchy
;     -  clear GPx delay registers before timer
;     -  number display timing is funky, and we have a page boundary potentially
;   - 265 lines at win/lose
;   - glitch in title
;   - rightmost step cut off at 1
;   - player yellow on last flight
;   - jumpy looking scroll of sun and cloud
;   - l/r placement not optimal - steps cut off for extreme left and right 
;   - absolute leftmost step cut off 
;  - gameplay 3
;   - lava (time attack) mode - steps "catch fire"?
;      - lava should scroll appropriate to stairs scroll but "keep up" relative to bottom step 
;      - need fail state condition
;   - dark mode - limited step visibility, double button press "plays" solution musically
;      - sky black
;      - steps obscured
;  - sprinkles 1
;   - animated squirrels in title and select
;   - lava sound volume up if it is close
;   - sound when damaged
;   - some kind of dirge on lose
;  - sprinkles 2
;   - clouds in sky
;  - sprinkles 3
;   - lava move up and down a bit
;   - some kind of celebration on win
;      - sun/moon in sky?
;   - some kind of celebration on win
;      - go from dark to light for night missions?
;   - speech stems
;   - color flashes in titles
;      - fireworks / rainbow / flashing on win
; NOT DO
;  - code 
;   - shrink maze size (replace with generation) - 678 bytes data + code
;     - algorithmic maze gen
;     - use incremental maze construction to conserve VBLANK
;   - less data + code for title - 798 bytes data + code
;   - shrink audio size - 256 bytes + 122 bytes code
;  - sprinkles 4
;   - let's go encouragement
;   - scroll of menu
;   - should be no step edge in ground?
;  - visual 3
;   - jump animation 
;   - size 1 stairs no number?
;   - addressible colors on stairs
;   - horizontal screen transitions
;   - sky background color changes
;      - go from dark to light?
;      - gradient/lightened sky background
;   - extra celebration on win
;      - good job text
;  - gameplay 5
;   - player builds maze by dropping numbers?
;     - player builds maze as numbers drop?
;   - zero / missing steps in mazes
;   - stair swapping / maze changing mechanic
;      ****T G
;      ***T2 G
;      **2T3G
;   - breakable stairs - 1 or two touches cause break?
;   - flight jumping mechanic
;  - second player
;  - flag at goal step?
;   - no fall penalty from start step?

; ----------------------------------
; code

  SEG
    ORG $F000

Reset
CleanStart
    ; do the clean start macro
            CLEAN_START

            lda #1
            sta CTRLPF
            lda #$30
            sta PF0

            ; audio
            lda #AUDIO_VOLUME
            sta audio_vx
            
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
            ldx sky_palette
            lda SKY_PALETTE,x
            sta draw_colubk

ax_sequencer
            ; track sequencing
            ldx audio_sequence
            beq ax_update
            lda audio_tracker
            bne ax_update
            lda AUDIO_SEQUENCES,x
            beq ax_update
            sta audio_tracker
            inx
            lda AUDIO_SEQUENCES,x
            sta audio_tracker + 1
            lda #0
            sta audio_timer + 1 ; force sync
            inx
            stx audio_sequence
            
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
            beq _ax_stop
            lsr                        ; .......|C pull first bit
            bcc _ax_set_all_registers  ; .......|? if clear go to load all registers
            lsr                        ; 0......|C1 pull second bit
            bcc _ax_cx_vx              ; 0......|?1 if clear we are loading aud(c|v)x
            lsr                        ; 00fffff|C11 pull duration bit for later set
            sta AUDF0,x                ; store frequency
            bpl _ax_set_timer_delta    ; jump to duration (note: should always be positive)
_ax_cx_vx   lsr                        ; 00.....|C01
            bcc _ax_vx                 ; 00.....|?01  
            lsr                        ; 000cccc|C101
            sta AUDC0,x                ; store control
            bpl _ax_set_timer_delta    ; jump to duration (note: should always be positive)
_ax_vx
            lsr                        ; 000vvvv|C001
            sta AUDV0,x                ; store volume
_ax_set_timer_delta
            rol audio_timer,x          ; set new timer to 0 or 1 depending on carry bit
            bpl _ax_advance            ; done (note: should always be positive)
_ax_set_all_registers
            ; processing all registers
            lsr                        ; 00......|C0
            bcc _ax_set_suspause       ; 00......|?0 if clear we are suspausing
            lsr                        ; 0000fffff|C10 pull duration bit
            sta AUDF0,x                ; store frequency
            rol audio_timer,x          ; set new timer to 0 or 1 depending on carry bit
            iny                        ; advance 1 byte
            lda AUDIO_TRACKS,y         ; ccccvvvv|
            sta AUDV0,x                ; store volume
            lsr                        ; 0ccccvvv|
            lsr                        ; 00ccccvv|
            lsr                        ; 000ccccv|
            lsr                        ; 0000cccc|
            sta AUDC0,x                ; store control
            bpl _ax_advance            ; done (note: should always be positive)
_ax_set_suspause
            lsr                        ; 000ddddd|C00 pull bit 3 (reserved)
            sta audio_timer,x          ; store timer
            bcs _ax_advance          ; if set we sustain
            lda #0
            sta AUDV0,x             ; clear volume
_ax_advance
            iny
            sty audio_tracker,x
            jmp _ax_next
_ax_stop ; got a 0 
            sta AUDV0,x
            sta audio_timer,x
            sta audio_tracker,x
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

gx_climb
            lda #<SYMBOL_GRAPHICS_ZARA
            sta draw_player_sprite
gx_update
            ldx player_step
            lda jump_table,x ; load jump distance for any moves
            ;and #$0f SPACE: don't need
            tay
            lda player_input
            bpl _gx_update_special_latch
            sta player_special_latch
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
_gx_update_special_latch
            ; rol jump_solution ; SOLVE
            ; rol jump_solution + 1 ; SOLVE
            ; bcs _gx_update_rev_left ; SOLVE
            ; jmp gx_go_down ;  TESTING SOLVE
            and player_special_latch
            sta player_special_latch
            bne gx_update_return
            ; if we hit all the switches, exit
            jmp Reset
gx_update_return

            ldx #1
            jsr gx_player_clock
_update_lava
            ; lava
            lda lava_height
            beq _skip_lava_update
            lda lava_jump_offset
            sec
            sbc jump_table_offset
            bmi _update_lava_speedup
            clc
            sbc player_step
            bmi _skip_player_health_drain
            lda #1
            sta AUDC1
            dec player_health
            bpl _skip_lava_sound
            jsr sub_steps_lose
            jmp gx_continue
_skip_player_health_drain
            adc #8
            bpl _cutoff_lava_sound
            lda #0
_cutoff_lava_sound            
            sta AUDV1
            lda #3 ; (rumble voice)
            sta AUDC1
_skip_lava_sound
            lda frame
            and #LAVA_TIME_MODULUS
            beq _end_lava_update            
            dec lava_clock
            bne _end_lava_update            
_update_lava_speedup
            inc lava_height
            lda difficulty_level
            and #$03
            tax
            lda LAVA_SPEED,x
            sta lava_clock
_end_lava_update
_skip_lava_update

gx_continue
            jsr sub_calc_respx

            ; altitude
            ldx #LAVA_COLOR
            lda lava_height
            cmp #10 ; check if past first flight
            bpl _gx_continue_ground_calc
            ldx draw_colubk
            lda draw_base_flight
            ora draw_step_offset
            bne _gx_continue_ground_calc
            ldx #GROUND_COLOR
_gx_continue_ground_calc
            stx draw_ground_color
            lda lava_clock
            and #$01
            clc
            adc #138 ; magic number
            sec
            sbc lava_height
            sta draw_lava_counter
            
            ldx lava_jump_offset
_gx_continue_erase_clouds
            lda #$bf
            and draw_table,x
            sta draw_table,x
            dex
            bpl _gx_continue_erase_clouds

;---------------------
; climb screen


            jsr sub_vblank_loop
gx_step_draw           
            lda draw_steps_wsync
            sta temp_step_start
            lda #(DRAW_TABLE_SIZE - 1)
            sec
            sbc draw_table_top
            beq gx_steps_resp_a
            asl
            sta temp_step_counter
            asl
            asl
            adc temp_step_counter
            adc draw_steps_wsync
            sbc #3
            sta temp_step_counter
            lda #$0d
            sta REFP1
            sta CTRLPF
            lda #30
            jsr sub_steps_respxx_r
            lda #YELLOW
            sta COLUP0
            sta COLUP1
            ldy #$10 ; shim
            ldx temp_step_counter
            sta HMCLR
            sty HMP1
_gx_steps_sky_loop
            sta WSYNC
            sta HMOVE                    ;3   3
            cpx #$50                     ;2   5
            bpl _gx_steps_sky_skip_loop  ;2   7
            cpx #$40                     ;2   9
            bmi _gx_steps_sky_skip_loop  ;2  11
            lda #(CLOUD_PAT_PF1-$3f),x   ;4  15
            sta PF1                      ;3  18
            ldy #WHITE                   ;2  20
            lda #(SUN_PAT_SKY-$40),x     ;4  24
            sty COLUPF                   ;3  27
            sta GRP0                     ;3  30
            sta GRP1                     ;3  33
_gx_steps_sky_skip_loop
            lda #0
            sta PF1
            sta COLUPF
            sta HMP1
            sta temp_step_start ; SPACE: take advantage of the zero
            dex
            bpl _gx_steps_sky_loop
            sta REFP1
gx_steps_resp_a
            lda draw_steps_respx
            ldy draw_steps_dir
            jsr sub_steps_respxx; 
            ; set HMP0/1
            lda RESPXX_HMP0,y       ;4   13
            ldx RESPXX_HMP1,y       ;4   17
            tay                     ;2   19
            ; tweak player reflection
            lda draw_player_dir     ;3   22
            sty HMP0                ;3   25 
            stx HMP1                ;3   28
            bit player_invert
            bpl _gx_steps_resp_skip_invert
            eor #$ff
_gx_steps_resp_skip_invert
            sta REFP0
            tya
            ldy draw_player_dir            
            sec
            bne _gx_steps_shim_p0_r
            sbc #-16
            byte $2c
_gx_steps_shim_p0_r
            sbc #16
            sta HMP0           

            ; intentional 
            sta WSYNC
            sta HMOVE
            lda draw_table_top                ;3   3
            sta temp_step_counter             ;3   6
            ; clean up side counter
            clc                               ;2   8
            adc draw_cloud_side               ;3  11
            asl                               ;2  13
            and #$02                          ;2  15
            sta temp_cloud_side               ;3  18

            sta WSYNC

            ; setup PF addressing
            lda #>CLOUD_PAT_PF1
            sta draw_s2_addr+1
            lda #>CLOUD_PAT_PF5
            sta draw_s3_addr+1
            lda #<CLOUD_PAT_BLANK
            sta draw_s2_addr
            sta draw_s3_addr         
            
            lda #$05
            bit CXP0FB
            bpl _gx_step_draw_cx_p0pf
            lda #$01
_gx_step_draw_cx_p0pf
            sta CTRLPF
            sta CXCLR

            ; player colors
            lda player_health ; trick: color * 8
            lsr
            lsr
            lsr
            sta COLUP0


_gx_step_draw_loop
            sta WSYNC                         ;-----
            ; x is stair #
            ; read graphics from a
            ; pch.ssss
            ldx temp_step_counter             ;3   3
            lda draw_table,x                  ;4   7
            ; get step colors
            ldy draw_step_colors,x            ;4  11
            sty COLUP1                        ;3  14
            ; get player graphic 
            ldy #(<SYMBOL_GRAPHICS_BLANK)     ;2  16 
            asl                               ;2  18
            bcc ._gx_draw_set_p0              ;2  20
            ldy draw_player_sprite            ;3  23
._gx_draw_set_p0
            sty draw_s0_addr                  ;3  26
            ; cloud bit
            ldy #(<CLOUD_PAT_BLANK)           ;2  28
            asl                               ;2  30
            bcc ._gx_draw_skip_cloud          ;2  32
            ldy #(<CLOUD_PAT_PF1)             ;2  34
._gx_draw_skip_cloud
            sty temp_cloud_pf                 ;3  37
            ; save hmove swap bit
            asl                               ;2  39
            ; set step graphic
            sta draw_s1_addr                  ;3  42
            lax draw_steps_dir                ;3  45
            bcc ._gx_draw_end_swap_direction  ;2  47
            eor #$01                          ;2  49
._gx_draw_end_swap_direction
            sta draw_steps_dir                ;3  52
            ldy RESPXX_HMOVE_A,x              ;4  56
            sty HMP1                          ;3  59 
            tax                               ;2  61
            ldy RESPXX_HMOVE_A,x              ;4  65
            sty HMP0                          ;3  68
            lax temp_cloud_side               ;3  71
            eor #$02                          ;2  73

            sta WSYNC                         ;-----
            sta HMOVE                         ;3   3
            ldy temp_cloud_pf                 ;3   6
            sty draw_s2_addr,x                ;4  10
            sta temp_cloud_side               ;3  13
            lda draw_colubk                   ;3  16
            sta COLUBK                        ;3  19
            ldy temp_step_start               ;2  21
            beq ._gx_draw_skip_stair          ;2  23
            lda #$ff                          ;2  25
            sta GRP1                          ;3  28 ; BUGBUG: late
            ldx #WHITE                        ;2  30
            stx COLUPF                        ;3  33
            
_gx_draw_loop

            dec draw_lava_counter             ;5  36-38
            beq gx_lava                       ;2  38-40
            ; cloud a
            lda (draw_s3_addr),y              ;5  43-45
            sta PF1                           ;3  46-48
            lda (draw_s2_addr),y              ;5  51-53
            pha                               ;3  54-56
            ; end cloud a
            lda (draw_s1_addr),y              ;5  59-61
            ldx draw_steps_dir                ;3  62-64
            beq ._gx_draw_skip_shift_r        ;2  64-66
            lsr                               ;2  66-68
._gx_draw_skip_shift_r
            stx.w COLUPF                      ;3  64
            sta WSYNC                         ;--------
            ora STEP_MASK,x                   ;4   4
            sta GRP1                          ;3   7
            lda (draw_s0_addr),y              ;5  12
            sta GRP0                          ;3  15
            pla                               ;4  19
            ldx #WHITE                        ;2  21
            sta PF1                           ;3  24
            stx COLUPF                        ;3  27
._gx_draw_skip_lava
            dey                               ;2  29
            bne _gx_draw_loop                 ;2  31
._gx_draw_skip_stair
            ldx draw_ground_color             ;3  34
            lda #CHAR_HEIGHT                  ;2  36
            dec temp_step_counter             ;5  41
            bmi gx_timer                      ;2  43
            sec                               ;2  45
            bne ._gx_draw_skip_last_shim      ;2  47
            sbc draw_steps_wsync              ;3  50
            stx draw_colubk                   ;3  53
._gx_draw_skip_last
            sta temp_step_start               ;3  56
            ;ldy #0                           ;2  -- TIME:SPACE:already 0
            ; cloud b
            sty PF1                           ;3  59
            sty COLUPF                        ;3  62
            sty.w GRP0                        ;4  66
            sty.w GRP1                        ;4  70
            jmp _gx_step_draw_loop            ;3  73
._gx_draw_skip_last_shim
            SLEEP 2
            bne ._gx_draw_skip_last ; KLUDGE: balancing out timing

gx_lava
            lda temp_step_counter            ;3  42-43
            sta lava_jump_offset             ;3  45-46
            lda #0
            sta PF1
            sta COLUPF
            sta WSYNC                        ;--------
            lda (draw_s0_addr),y             ;5   5
            sta GRP0                         ;3   8
            lda #LAVA_COLOR                  ;2  10
            sta draw_colubk                  ;3  13
            sta COLUBK                       ;3  16
            bne ._gx_draw_skip_lava          ;3  19

gx_timer
            sty PF1                           ;3  47
            sty COLUPF                        ;3  50
            sty GRP1                          ;3  53 
            sty GRP0                          ;3  56 ; trick, GRP0 already 0, this forces vdel register clear on GRP1

            ; prep timer gx
            lda player_score
            ldx #8
            jsr sub_write_digit
            lda player_timer
            ldx #4
            jsr sub_write_digit
            ldx #0             
            lda player_timer + 1
            jsr sub_write_digit

            lda #>SYMBOL_GRAPHICS
            sta draw_s2_addr + 1
            sta draw_s3_addr + 1

            ; place digits
            lda #TIMER_RESP
            jsr sub_steps_respxx_3cr

            lda #0 ; set background: not counting but we should be starting sl 214
            sta COLUBK
            sta REFP0

            ; restore s2 addr


            ; set up HMP shim for next HMOVE
            lda #$10

            tsx
            stx temp_timer_stack
            sta WSYNC
            sta HMCLR
            sta HMP1
            sta HMOVE
            lda #WHITE
            ldx game_state
            cpx #GAME_STATE_START
            bne _gx_timer_color
            lda player_clock
            lsr
            lsr
            eor #TIMER_RED
_gx_timer_color
            sta COLUP0
            sta COLUP1
            ldy #(CHAR_HEIGHT) ; go one higher to create top line
_gx_timer_loop
            sta WSYNC
            SLEEP 3; 
            lda (draw_s0_addr),y   ;5   5
            sta GRP0               ;3   8
            lda (draw_s1_addr),y   ;5  13
            ora TIMER_MASK,y       ;4  17
            sta GRP1               ;3  20
            lda (draw_s2_addr),y   ;5  25
            sta GRP0               ;2  27
            lda (draw_s5_addr),y   ;5  32
            eor #$ff               ;2  34
            tax                    ;2  36
            txs                    ;2  38
            lax (draw_s3_addr),Y   ;5  43
            lda (draw_s4_addr),y   ;5  48
            eor #$ff               ;2  50
            stx GRP1               ;3  53
            tsx                    ;3  56
            sta GRP0               ;3  59
            stx GRP1               ;3  62
            sta GRP0               ;3  65
            dey                    ;2  67
            sbpl _gx_timer_loop     ;3  70
            ldx temp_timer_stack
            txs

gx_overscan
            lda #0
            sta GRP0
            sta GRP1
            sta GRP0
            sta WSYNC
            ldx #31
            jsr sub_wsync_loop
            jmp newFrame

;
; game states
;

gx_fall
            lda #1 ; (noise voice)
            sta AUDC0
            lda frame
            and #$0f
            bne gx_jump
            lda draw_player_sprite
            clc
            adc #8
            cmp #<(SYMBOL_GRAPHICS_TUMBLE_1 + 8)
            bne _gx_fall_save_spin
            lda #<SYMBOL_GRAPHICS_ZARA
_gx_fall_save_spin
            sta draw_player_sprite
gx_scroll
gx_jump
            ; continue from wherever we were
            rts

gx_title
            ; show title
            lda audio_sequence
            bne _skip_title_audio
            lda #SEQ_TITLE
            sta audio_sequence
_skip_title_audio
            bit player_input_latch
            bpl _start_select
            jsr sub_galois ; cycle randomization
            jmp gx_show_title
_start_select
            lda #0
            sta audio_tracker ; stop tracker
            sta audio_tracker + 1; stop tracker
            lda #SEQ_START_SELECT
            sta audio_sequence
            lda #GAME_STATE_SELECT
            sta game_state
            lda #1 ; initial difficulty
            jmp gx_difficulty_set

gx_select
            lda player_input_latch
            bpl _gx_select_start
            ror
            bcs _gx_select_check_down
            jmp gx_difficulty_up
_gx_select_check_down
            ror
            bcs _gx_select_check_left
            jmp gx_difficulty_down
_gx_select_check_left
            ror
            bcs _gx_select_check_right
            jmp gx_difficulty_down
_gx_select_check_right
            ror
            bcs _gx_select_continue
            jmp gx_difficulty_up
_gx_select_continue
            jsr sub_galois ; cycle randomization
            jmp gx_show_select
_gx_select_start
            ; bootstrap steps
            jsr sub_steps_init
            lda #GAME_STATE_START
            sta game_state
            lda #GAME_START_SECONDS
            sta player_timer
            lda #SEQ_START_GAME
            sta audio_sequence
            jmp gx_continue

gx_start    
            lda #<SYMBOL_GRAPHICS_ZARA
            sta draw_player_sprite
            ; countdown to start climb
            ldx #-1
            jsr gx_player_clock
            lda player_timer
            beq _start_game
            jmp gx_continue
_start_game
            lda #GAME_STATE_CLIMB
            sta game_state
            jmp gx_continue


;
; game control subroutines
;

sub_steps_init
            lda #9 ; magic number, first cloud pos
            sta draw_cloud_index
            lda #PLAYER_STEP_HEALTH
            sta player_health
            lda difficulty_level
            and #$03
            tay
            lda LEVELS,y
            sta base_layout_index
            sta jump_layout_index
            tay
            lda LAYOUTS,y
            and #LAYOUT_REPEAT_MASK
            lsr
            lsr
            lsr
            lsr
            sta base_layout_repeat
            sta jump_layout_repeat           
            lda #0
            sta draw_cloud_side
            ldx #(draw_table - draw_registers_start - 1)
_steps_blank_zero_loop
            sta draw_registers_start,x
            dex
            bpl _steps_blank_zero_loop
            sta draw_steps_wsync
            lda #>SYMBOL_GRAPHICS
            ldx #10
_steps_addr_loop
            sta draw_s0_addr + 1,x
            dex
            dex
            bpl _steps_addr_loop
            ; jump init
            lda #$ff
            sta draw_base_dir
            ; get horizontal offset
            lda difficulty_level
            and #$03
            tax
            lda LAYOUTS_LR,x
            sta draw_base_lr
            ; gen steps
            ldy base_layout_index
            lda LAYOUTS,y
            and #LAYOUT_COUNTER_MASK
            asl
            jsr sub_gen_steps    ; gen steps

sub_steps_refresh
            ; clear draw table and set colors
            ldx #(DRAW_TABLE_SIZE - 1)
            stx draw_table_top
            ldy #$00 + ((SYMBOL_GRAPHICS_BLANK - SYMBOL_GRAPHICS) / 8)
            lda #$1f
_steps_draw_clear_loop
            sty draw_table,x
            sta draw_step_colors,x
_steps_draw_step_colors_skip_0f
            clc
            adc #$10 ; move up a color class
            bvs _steps_draw_step_colors_skip_0f
            dex
            bpl _steps_draw_clear_loop
sub_steps_flights
            ; add flight markers
            ldy base_layout_index
            lda base_layout_repeat
            sta temp_layout_repeat
            ldx draw_step_offset; current step
            bne _steps_draw_flights
            lda draw_base_flight  ; KLUDGE: trick to find bottom of stairs
            beq _steps_draw_flights
            lda #$20 + ((SYMBOL_GRAPHICS_BLANK - SYMBOL_GRAPHICS) / 8)
            sta draw_table
_steps_draw_flights
            stx temp_step_offset
            lda LAYOUTS,y
            beq _steps_draw_last_flight
            and #LAYOUT_COUNTER_MASK
            asl ; 2x
            adc temp_step_offset
            cmp #DRAW_TABLE_SIZE
            bpl _steps_draw_flights_end
            tax
            lda #$20 + ((SYMBOL_GRAPHICS_BLANK - SYMBOL_GRAPHICS) / 8)
            sta draw_table-1,x
            dex
            dec temp_layout_repeat
            bpl _steps_draw_flights
            iny
            lda LAYOUTS,y
            and #LAYOUT_REPEAT_MASK
            lsr
            lsr
            lsr
            lsr
            sta temp_layout_repeat      
            jmp _steps_draw_flights 
_steps_draw_last_flight
            lda #$20 + ((SYMBOL_GRAPHICS_CROWN - SYMBOL_GRAPHICS) / 8) ; force crown stair (NOTE: should be $0f)
            sta draw_table,x
            stx draw_table_top ; adjust table top for last flight
            ldy #1
_steps_draw_last_flight_loop
            inx
            cpx #(DRAW_TABLE_SIZE)
            bpl _steps_draw_flights_end
            lda #$20 + ((SYMBOL_GRAPHICS_BLANK - SYMBOL_GRAPHICS) / 8) ; force blank stair
            sta draw_table,x
            lda draw_colubk
            sta draw_step_colors,x ; erase top steps
            stx draw_table_top ; move table top up
            dey
            bpl _steps_draw_last_flight_loop
_steps_draw_flights_end
            ; inject jump table graphics
            ldx jump_table_size
            dex
            txa
            clc
            adc jump_table_offset
            tay
_steps_draw_jumps
            lda #$08
            bit difficulty_level
            beq _steps_draw_all_jumps
            txa
            sec
            sbc player_step
            lsr
            bne _steps_draw_jump_skip
_steps_draw_all_jumps
            lda draw_table,y
            cmp #$2f ; KLUDGE: skip crown stair
            beq _steps_draw_jump_skip
            and #$f0
            sta draw_table,y
            lda jump_table,x
            ; and #$0f ;SPACE: don't need
            bne _steps_draw_goal_skip
            lda #((SYMBOL_GRAPHICS_ACORN - SYMBOL_GRAPHICS) / 8) ; acorn stair (NOTE: should be $0e)
_steps_draw_goal_skip
            ora draw_table,y
            sta draw_table,y
_steps_draw_jump_skip
            dey
            bmi _steps_draw_end_jumps ; if offset is negative exit this loop
            dex
            bpl _steps_draw_jumps
_steps_draw_end_jumps
            lda draw_cloud_index
            bpl _steps_draw_clouds_loop
            clc
            adc #$07
            sta draw_cloud_index
_steps_draw_clouds_loop
            tax
            lda draw_table,x
            ora #$40
            sta draw_table,x
            txa
            clc
            adc #$07
            cmp #(DRAW_TABLE_SIZE)       
            bmi _steps_draw_clouds_loop
sub_draw_player_step
            lda player_step
            clc 
            adc jump_table_offset
            tax
            lda #$80
            ora draw_table+1,x
            sta draw_table+1,x
            rts

gx_difficulty_up
            lda #1
            byte $2c
gx_difficulty_down
            lda #-1
            clc
            adc difficulty_level
            and #$0f
gx_difficulty_set
            sta difficulty_level
            ; setup visuals and audio
            lsr
            ldx #SEQ_SELECT_UP
            bcc _gx_select_skip_ax_down
            ldx #SEQ_SELECT_DOWN
_gx_select_skip_ax_down
            stx audio_sequence
            lsr
            tax
            lsr
            sta sky_palette
            ldy #0
            sta lava_jump_offset
            bcc _gx_select_skip_lava
            iny
_gx_select_skip_lava
            sty lava_height
            sty lava_clock
            ldy SELECT_ROW,x
            ldx #9
_gx_select_setup_loop
            lda #>SELECT_GRAPHICS
            sta draw_t0,x
            dex
            lda SELECT_ROW_0_DATA,y
            sta draw_t0,x
            dey
            dex 
            bpl _gx_select_setup_loop
            lda SELECT_ROW_0_DATA,y 
            sta draw_c0
            ; return
            jmp gx_show_select

sub_steps_advance
            ldx #0
            jsr sub_inc_layout
_sub_steps_advance_retry
            ; check if we need to move jump table "up" to next flight
            ldy jump_layout_index
            lda LAYOUTS,y
            and #LAYOUT_COUNTER_MASK
            tax ; next flight size / 2
            asl
            adc jump_table_size
            adc jump_table_offset
            sec
            sbc MARGINS,x
            bmi _sub_steps_advance_save 
            ; we are not where we need to be - scroll
            jsr sub_steps_scroll ; start scrolling - we will exit
            jmp _sub_steps_advance_retry
_sub_steps_advance_save
            lda jump_table_size
            sec
            sbc #1
            clc
            adc jump_table_offset
            sta jump_table_offset
            lda #0
            sta player_step
            lda #PLAYER_STEP_HEALTH ; restore health
            sta player_health
            txa ; next flight size / 2
            asl ; x2
            beq sub_steps_win
            jsr sub_gen_steps ; will set new jump table size
            lda #GAME_STATE_CLIMB
            sta game_state
            lda draw_player_dir
            eor #$ff ; invert player dir between 8 and 0
            sta draw_player_dir
            jmp sub_steps_refresh ; redraw steps (will rts from there)

sub_steps_win
            lda #SEQ_WIN_GAME
            sta audio_sequence
            lda #GAME_STATE_END
            sta game_state
            rts

sub_steps_scroll
            ldx lava_height
            beq _skip_lava_scroll
            dex
            beq _skip_lava_scroll
            stx lava_height
_skip_lava_scroll
            ldx draw_steps_wsync
            inx
            txa
            and #$07
            sta draw_steps_wsync
            bne _sub_scroll_cont
            dec jump_table_offset 
            ldy base_layout_index
            lda draw_base_flight
            beq _sub_scroll_landing_skip
            lda draw_step_offset
            bne _sub_scroll_landing_skip
            lda draw_base_dir
            eor #$ff
            sta draw_base_dir
_sub_scroll_landing_skip
            dec draw_step_offset
            lda #-1
            bit draw_base_dir
            bpl _sub_scroll_lr_calc
            lda #1
_sub_scroll_lr_calc
            clc
            adc draw_base_lr
            sta draw_base_lr
            lda LAYOUTS,y
            and #LAYOUT_COUNTER_MASK
            asl
            clc
            adc draw_step_offset
            sec
            sbc #1
            bne _sub_scroll_update
            ldx #1
            jsr sub_inc_layout
            inc draw_base_flight
            lda #0
            sta draw_step_offset
_sub_scroll_update
            dec draw_cloud_index
            dec draw_cloud_side
            jsr sub_steps_refresh
_sub_scroll_cont
            lda #GAME_STATE_SCROLL
            sta game_state
            jmp gx_continue ; will continue later

sub_inc_layout
            dec jump_layout_repeat,x
            bpl _sub_inc_layout_continue
            inc jump_layout_index,x
            ldy jump_layout_index,x
            ; increment flight
            lda LAYOUTS,y
            and #LAYOUT_REPEAT_MASK
            lsr
            lsr
            lsr
            lsr
            sta jump_layout_repeat,x
_sub_inc_layout_continue
            rts

sub_calc_respx
            ldx #-1
            ldy draw_base_lr
            bit draw_base_dir
            bmi _calc_respx_right
_calc_respx_left
            inx
            lda draw_table,x
            and #$20
            bne _calc_respx_switch_right
_calc_respx_switch_left
            dey
            cpx draw_table_top
            bmi _calc_respx_left
            tya
            ldy #$00
            jmp _calc_respx_end
_calc_respx_right
            inx
            lda draw_table,x
            and #$20
            bne _calc_respx_switch_left
_calc_respx_switch_right
            iny
            cpx draw_table_top
            bmi _calc_respx_right
            dey
            tya
            ldy #$01
_calc_respx_end
            sta temp_margin
            asl
            asl
            asl
            sec
            sbc temp_margin 
            clc 
            adc #STAIRS_MARGIN
            sta draw_steps_respx
            sty draw_steps_dir
            rts 

; solver (NOT USED)
; sub_solve_puzzle
;             tsx 
;             stx temp_solve_stack
;             ldx #0
;             ldy #0
;             sty jump_solution
;             sty jump_solution + 1
; _sub_solve_iter_down
;             stx temp_solve_current
;             lda jump_table,x
;             and #$0f
;             sta temp_solve_jump
;             clc 
;             adc temp_solve_current
;             cmp player_goal
;             beq _sub_solved
;             bpl _sub_solve_minus
;             tax
;             lda jump_table,x     ; check if we already stored this
;             and #$f0
;             bne _sub_solve_minus
;             sec
; _sub_solve_next
;             rol jump_solution
;             rol jump_solution + 1
;             lda temp_solve_current
;             pha
;             iny
;             tya
;             asl
;             asl
;             asl
;             asl
;             ora jump_table,x
;             sta jump_table,x
;             jmp _sub_solve_iter_down
; _sub_solve_minus
;             lda temp_solve_current
;             sec
;             sbc temp_solve_jump
;             bmi _sub_solve_iter_up
;             tax
;             lda jump_table,x     ; check if we already stored this
;             and #$f0
;             bne _sub_solve_iter_up
;             clc
;             jmp _sub_solve_next
; _sub_solve_iter_up
;             clc
;             ror jump_solution + 1
;             ror jump_solution
;             dey
;             pla
;             beq _sub_solve_failed
;             sta temp_solve_current
;             tax
;             lda jump_table,x
;             and #$0f
;             sta temp_solve_jump
;             jmp _sub_solve_minus
; _sub_solved
;             lda jump_solution + 1
; _sub_solved_rol
;             bmi _sub_solve_failed
;             rol jump_solution
;             rol jump_solution + 1
;             jmp _sub_solved_rol
; _sub_solve_failed
;             ldx temp_solve_stack
;             txs
;             rts        

gx_go_up
            lda #1
            jmp _gx_go_add_step
gx_go_down
            lda #-1
_gx_go_add_step
            sty player_jump
            sta player_invert
            lda #GAME_STATE_JUMP
            sta game_state
            ; intentional fallthrough to jump process

gx_process_jump
            lda player_invert
            clc
            adc player_step
            ; move player
            sta player_step
            bmi _gx_go_fall_down
            cmp player_goal
            bcc _gx_process_dec_jump
            bne _gx_go_fall_up
_gx_process_dec_jump
            tay ; set player location aside to compute audio queue
            sec 
            sbc player_goal
            clc
            adc #(JUMP_TABLE_SIZE - 1)
            tax 
            lda TRACK_FREQ_INDEX,x
            sta AUDF0
            lda TRACK_CHAN_INDEX,x
            sta AUDC0
            lda audio_vx
            sta AUDV0
            lda #8
            sta audio_timer
            lda #4 
            lda #TRACK_WAIT
            sta audio_tracker
            tya
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
            lda #SEQ_LANDING
            sta audio_sequence
            sed
            lda player_score
            clc
            adc #1
            sta player_score ; collect prize
            cld
            jsr sub_steps_advance
            jmp gx_update_return
_gx_go_fall_down
            lda #0
            sta player_step
            sta player_invert
            inc player_jump
            jmp _gx_go_fall
_gx_go_fall_up
            lda player_goal
            sta player_step
            sta player_jump
            lda #-1
            sta player_invert
_gx_go_fall
            ; fall and recover
            ldx #GAME_STATE_FALL
            stx game_state
            jsr _gx_go_redraw_player ; will continue back
            jmp gx_process_jump
_gx_go_redraw_player
            jsr sub_steps_refresh
            jmp gx_update_return

; ----------------------------------
; TITLE

   ORG $F700

COL_A0_PF0
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
COL_A1_PF1
    byte $80,$c0,$e0,$f0,$f8,$fc,$fe;,$ff; 8
COL_A0_PF1
    byte $ff,$7f,$3f,$1f,$f,$7,$3,$1; 8
COL_A0_PF2
    byte $81,$c1,$e1,$f1,$f9,$fd,$ff;,$ff; 8
COL_A2_PF0
    byte $ff;,$80,$80,$80,$80,$80,$80,$80; 8
COL_A2_PF1
    byte $80;,$80,$80,$80,$80,$80,$80,$80; 8
COL_BC_PF1
    byte $80,$80,$80,$80,$80,$80,$80;,$84; 8
COL_A5_PF3
    byte $84,$c4,$a4,$94,$8c,$84;,$80,$80; 8
COL_AA_PF5
    byte $80,$80,$80,$80,$80,$84,$86;,$87; 8
COL_A9_PF5
    byte $87,$87,$87,$83,$81,$80,$80,$84; 8
COL_A0_PF3 = COL_A0_PF0
COL_A0_PF4 = COL_A0_PF0
COL_A0_PF5 = COL_A0_PF0
COL_B0_PF0 = COL_A0_PF0
COL_B0_PF1 = COL_A0_PF0
COL_B0_PF2 = COL_A0_PF0
COL_B0_PF3 = COL_A0_PF0
COL_B0_PF4 = COL_A0_PF0
COL_A1_PF0 = COL_A0_PF1
COL_A1_PF2
    byte $80,$40,$20,$10,$8,$4,$2;,$1; 8
COL_A2_PF2
    byte $1,$2,$4,$8,$10,$20,$40,$80; 8
COL_A1_PF3 = COL_A0_PF0
COL_A1_PF4 = COL_A0_PF0
COL_A1_PF5 = COL_A0_PF0
COL_B1_PF0 = COL_A0_PF0
COL_B1_PF1 = COL_A0_PF0
COL_B1_PF2 = COL_A0_PF0
COL_B1_PF3 = COL_A0_PF0
COL_B1_PF4 = COL_A0_PF0
COL_A2_PF3 = COL_A0_PF0
COL_A2_PF4 = COL_A0_PF0
COL_A2_PF5 = COL_A0_PF0
COL_B2_PF0 = COL_A0_PF0
COL_B2_PF1 = COL_A0_PF0
COL_B2_PF2 = COL_A0_PF0
COL_B2_PF3 = COL_A0_PF0
COL_B2_PF4 = COL_A0_PF0
COL_A3_PF0 = COL_A2_PF2
COL_A3_PF1 = COL_A2_PF2
COL_B7_PF0
    byte $61,$21;,$1,$1,$1,$1,$1,$1; 8
COL_A3_PF2
    byte $1,$1,$1,$1,$1,$1;,$1,$1; 8
COL_BB_PF2
    byte $1,$1,$81,$c1,$21,$21,$21,$a1; 8
COL_A3_PF3 = COL_A0_PF1
COL_A3_PF4 = COL_A0_PF2
COL_A3_PF5 = COL_A0_PF0
COL_B3_PF0 = COL_A0_PF0
COL_B3_PF1 = COL_A0_PF0
COL_B3_PF2 = COL_A0_PF0
COL_B3_PF3 = COL_A0_PF0
COL_B3_PF4 = COL_A0_PF0
COL_A4_PF0 = COL_A0_PF1
COL_A4_PF1 = COL_A1_PF1
COL_A4_PF2 = COL_A0_PF1
COL_A4_PF3 = COL_A1_PF1
COL_A4_PF5 = COL_A0_PF0
COL_B4_PF0 = COL_A0_PF0
COL_B4_PF1 = COL_A0_PF0
COL_B4_PF2 = COL_A0_PF0
COL_B4_PF3 = COL_A0_PF0
COL_B4_PF4 = COL_A0_PF0
COL_A5_PF0 = COL_A2_PF0
COL_A5_PF2 = COL_A2_PF0
COL_A5_PF4
    byte $20,$20,$20,$20,$20;,$20,$20,$20; 8
COL_A4_PF4
    byte $20,$20,$20,$10,$8,$4,$2,$1; 8
COL_A5_PF5 = COL_A0_PF0
COL_B5_PF0 = COL_A0_PF0
COL_B5_PF1 = COL_A0_PF0
COL_B5_PF2 = COL_A0_PF0
COL_B5_PF3 = COL_A0_PF0
COL_B5_PF4 = COL_A0_PF0
COL_A6_PF0 = COL_A0_PF0
COL_A6_PF1 = COL_A0_PF0
COL_A6_PF2 = COL_A3_PF2
COL_A8_PF3
    byte $fc,$6,$5;,$4,$4,$4,$4,$4; 8
COL_A6_PF3
    byte $4,$4,$4,$4,$4,$4,$4,$4; 8
COL_A6_PF4 = COL_A5_PF4
COL_A6_PF5 = COL_A0_PF1
COL_B6_PF0 = COL_A0_PF2
COL_B6_PF1 = COL_A0_PF0
COL_B6_PF2 = COL_A0_PF0
COL_B6_PF3 = COL_A0_PF0
COL_B6_PF4 = COL_A0_PF0
COL_A7_PF0 = COL_A0_PF0
COL_A7_PF1 = COL_A0_PF0
COL_A7_PF2 = COL_A3_PF2
COL_A7_PF3 = COL_A6_PF3
COL_A7_PF4
    byte $ff,$7f,$3f,$3f,$2f,$27,$23,$21; 8
COL_A7_PF5 = COL_A1_PF1
COL_B7_PF1 = COL_A0_PF0
COL_B7_PF2 = COL_A0_PF0
COL_B7_PF3 = COL_A0_PF0
COL_B7_PF4 = COL_A0_PF0
COL_A8_PF0 = COL_A0_PF0
COL_A8_PF1 = COL_A0_PF0
COL_A8_PF2 = COL_A3_PF2
COL_A8_PF4 = COL_A2_PF1
COL_B8_PF0
    byte $10,$8,$84,$c2,$21,$21,$21,$a1; 8
COL_B8_PF1 = COL_A0_PF0
COL_B8_PF2 = COL_A0_PF0
COL_B8_PF3 = COL_A0_PF0
COL_B8_PF4 = COL_A0_PF0
COL_A9_PF0 = COL_A0_PF0
COL_A9_PF1 = COL_A0_PF0
COL_A9_PF2 = COL_A0_PF0
COL_A9_PF3 = COL_A0_PF0
COL_A9_PF4 = COL_A2_PF1
COL_B9_PF1 = COL_A0_PF1
COL_B9_PF2 = COL_A0_PF2
COL_B9_PF3 = COL_A0_PF0
COL_B9_PF4 = COL_A0_PF0
COL_AA_PF0 = COL_A0_PF0
COL_AA_PF1 = COL_A0_PF0
COL_AA_PF2 = COL_A0_PF0
COL_AA_PF3 = COL_A0_PF0
COL_AA_PF4 = COL_A2_PF1
COL_BA_PF0 = COL_A0_PF1
COL_BA_PF1 = COL_A1_PF1
COL_BA_PF2 = COL_B7_PF0
COL_BA_PF3 = COL_A0_PF0
COL_BA_PF4 = COL_A0_PF0
COL_AB_PF0 = COL_A0_PF0
COL_AB_PF1 = COL_A0_PF0
COL_AB_PF2 = COL_A0_PF0
COL_AB_PF3 = COL_A0_PF0
COL_AB_PF4 = COL_A2_PF0
COL_AB_PF5 = COL_A5_PF1
COL_BB_PF0 = COL_A2_PF1
COL_BB_PF1 = COL_A8_PF5
COL_BB_PF3 = COL_A0_PF0
COL_BB_PF4 = COL_A0_PF0
COL_AC_PF0 = COL_A0_PF0
COL_AC_PF1 = COL_A0_PF0
COL_AC_PF2 = COL_A0_PF0
COL_AC_PF3 = COL_A0_PF0
COL_AC_PF4 = COL_A0_PF0
COL_AC_PF5 = COL_A0_PF0
COL_BC_PF0 = COL_A2_PF1
COL_BC_PF2 = COL_A1_PF2
COL_BC_PF3 = COL_A0_PF1
COL_BC_PF4 = COL_A0_PF2
COL_AD_PF0 = COL_A0_PF0
COL_AD_PF1 = COL_A0_PF0
COL_AD_PF2 = COL_A0_PF0
COL_AD_PF3 = COL_A0_PF0
COL_AD_PF4 = COL_A0_PF0
COL_AD_PF5 = COL_A0_PF0
COL_BD_PF0 = COL_A2_PF1
COL_A8_PF5
    byte $86,$87,$87,$87,$84,$82,$81;,$80; 8
COL_A5_PF1
    byte $80,$c0,$a0,$90,$88,$84,$82;,$81; 8
COL_BD_PF1
    byte $81,$81,$81,$81,$81,$81,$81;,$81; 8
COL_B9_PF0
    byte $81,$c1,$e1,$f1,$f9,$fd,$7f,$3f; 8
COL_BD_PF2 = COL_A0_PF1
COL_BD_PF3 = COL_A1_PF1
COL_BD_PF4 = COL_A1_PF2
COL_AE_PF0 = COL_A0_PF0
COL_AE_PF1 = COL_A0_PF0
COL_AE_PF2 = COL_A0_PF0
COL_AE_PF3 = COL_A0_PF0
COL_AE_PF4 = COL_A0_PF0
COL_AE_PF5 = COL_A0_PF0
COL_BE_PF0 = COL_A2_PF0
COL_BE_PF1 = COL_A5_PF1
COL_BE_PF2 = COL_A2_PF0
COL_BE_PF3 = COL_A2_PF1
COL_BE_PF4 = COL_A2_PF2
COL_AF_PF0 = COL_A0_PF0
COL_AF_PF1 = COL_A0_PF0
COL_AF_PF2 = COL_A0_PF0
COL_AF_PF3 = COL_A0_PF0
COL_AF_PF4 = COL_A0_PF0
COL_AF_PF5 = COL_A0_PF0
COL_BF_PF0 = COL_A0_PF0
COL_BF_PF1 = COL_A0_PF0
COL_BF_PF2 = COL_A2_PF2
COL_BF_PF3 = COL_A2_PF2
COL_BF_PF4 = COL_A3_PF2
COL_AG_PF0 = COL_A0_PF0
COL_AG_PF1 = COL_A0_PF0
COL_AG_PF2 = COL_A0_PF0
COL_AG_PF3 = COL_A0_PF0
COL_AG_PF4 = COL_A0_PF0
COL_AG_PF5 = COL_A0_PF0
COL_BG_PF0 = COL_A0_PF0
COL_BG_PF1 = COL_A0_PF0
COL_BG_PF2 = COL_A0_PF1
COL_BG_PF3 = COL_A1_PF1
COL_BG_PF4 = COL_A1_PF2
COL_AH_PF0 = COL_A0_PF0
COL_AH_PF1 = COL_A0_PF0
COL_AH_PF2 = COL_A0_PF0
COL_AH_PF3 = COL_A0_PF0
COL_AH_PF4 = COL_A0_PF0
COL_AH_PF5 = COL_A0_PF0
COL_BH_PF0 = COL_A0_PF0
COL_BH_PF1 = COL_A0_PF0
COL_BH_PF2 = COL_A2_PF0
COL_BH_PF3 = COL_A5_PF1
COL_BH_PF4 = COL_A0_PF0

TITLE_WRITE_OFFSET
    byte 0,2,4,6,8,10,12

TITLE_ROW_HI
    byte >COL_A0_PF0
    byte >COL_A0_PF1
    byte >COL_A0_PF2
    byte >COL_A0_PF3
    byte >COL_A0_PF4
    byte >gx_title_1_delay_0
    byte >TITLE_ROW_1_DATA

sub_gen_steps
            sta jump_table_size
            lsr
            sta temp_maze_ptr ; save for multiply
            jsr sub_galois
            and #$f0 ; 16 mazes
            sta temp_rand
            ldx #3 ; 4 shifts
            lda #0
_sub_gen_steps_mul
            asl 
            asl temp_rand
            bcc _sub_gen_steps_skip
            clc
            adc temp_maze_ptr
_sub_gen_steps_skip
            dex 
            bpl _sub_gen_steps_mul
            clc
            ldy temp_maze_ptr
            dey
            adc MAZE_PTR_LO,y
            sta temp_maze_ptr
            lda MAZE_PTR_HI,y
            sta temp_maze_ptr + 1
            ldx jump_table_size
            dex
            stx player_goal
_sub_gen_steps_loop
            lda (temp_maze_ptr),y ; #$11; use to force maze of 1's
            lsr
            lsr
            lsr
            lsr
            sta jump_table,x
            dex
            lda (temp_maze_ptr),y ; #$11; use to force maze of 1's
            and #$0f
            sta jump_table,x
            dex
            dey
            bpl _sub_gen_steps_loop
            ;jmp sub_solve_puzzle
            rts
    
;--------------------
; Title Screen Kernel

gx_title_0            
            ldy #7                       ;2   
_gx_title_0_loop_0
            lda (draw_t0_p0_addr),y      ;5   
            sta GRP0                     ;3   6
_gx_title_0_loop_1
            lda (draw_t0_p1_addr),y      ;5  11
            sta GRP1                     ;3  14
            lda (draw_t0_p2_addr),y      ;5  19
            sta GRP0                     ;3  22
            lax (draw_t0_p3_addr),y      ;5  27
            lda (draw_t0_p4_addr),y      ;5  32
            sty temp_y                   ;3  35
            ldy #0                       ;2  37
            stx GRP1                     ;3  30
            sta GRP0                     ;3  43
            sty GRP1                     ;3  46
            sty GRP0                     ;3  49
            ldy temp_y                   ;3  52
            SLEEP 2                      ;2  54
            dey                          ;2  56
            bmi _gx_title_loop_0_jmp     ;2  58
            ldx TITLE_WRITE_OFFSET,y     ;4  62
            lda (draw_t0_data_addr),y    ;5  67
            sta draw_t1,x                ;4  71
            jmp _gx_title_0_loop_0       ;3  74
_gx_title_loop_0_jmp
            SLEEP 2                      ;2  61
            jmp (draw_t0_jump_addr)      ;5  66

gx_title_1           
            ldy #7                       ;2   2
_gx_title_1_loop_0
            lda (draw_t1_p0_addr),y      ;5   7
_gx_title_1_loop_1
            sta GRP0                     ;3  10
            lda (draw_t1_p1_addr),y      ;5  15
            sta GRP1                     ;3  18
            lda (draw_t1_p2_addr),y      ;5  23
            sta GRP0                     ;3  26
            lax (draw_t1_p3_addr),y      ;5  31
            lda (draw_t1_p4_addr),y      ;5  36
            sty temp_y                   ;3  39
            ldy #0                       ;2  41
            stx GRP1                     ;3  44
            sta GRP0                     ;3  47
            sty GRP1                     ;3  50
            sty GRP0                     ;3  53
            ldy temp_y                   ;3  56
            SLEEP 2                      ;2  58
            dey                          ;2  60
            bmi _gx_title_loop_1_jmp     ;2  62
            ldx TITLE_WRITE_OFFSET,y     ;4  66
            lda (draw_t1_data_addr),y    ;5  71
            sta draw_t0,x                ;4  75
            jmp _gx_title_1_loop_0       ;3  --
_gx_title_loop_1_jmp
            SLEEP 2                      ;2  65
            jmp (draw_t1_jump_addr)      ;5  70

gx_title_00       
            ldy #7                       ;2   1
_gx_title_00_loop_0
            lda draw_t0_p0_addr          ;3   4
_gx_title_00_loop_1
            sta GRP1                     ;3   7
            lda (draw_t0_p1_addr),y      ;5  12
            sta GRP0                     ;3  15
            lda COL_A0_PF2,y             ;4  19
            sta temp_p4                  ;3  22
            lax (draw_t0_p2_addr),y      ;5  27
            lda COL_A0_PF1,y             ;4  31
            sty temp_y                   ;3  34
            ldy temp_p4                  ;3  37
            stx GRP1                     ;3  40
            sta GRP0                     ;3  43
            sty GRP1                     ;3  46
            sty GRP0                     ;3  49
            ldy temp_y                   ;3  52
            dey                          ;2  54
            bmi _gx_title_loop_00_jmp    ;2  56
            ldx TITLE_WRITE_OFFSET,y     ;4  60
            lda (draw_t0_data_addr),y    ;5  65
            sta draw_t1,x                ;4  69
            ldx #0                       ;2  71 prep for next line
            stx GRP0                     ;3  74
            jmp _gx_title_00_loop_0      ;3   1
_gx_title_loop_00_jmp
            SLEEP 4                      ;3  61
            jmp (draw_t0_jump_addr)      ;5  66

gx_title_11       
            ldy #7                       ;2   2
_gx_title_11_loop_0
            lda draw_t1_p0_addr          ;3   5
_gx_title_11_loop_1
            sta GRP1                     ;3   8
            lda (draw_t1_p1_addr),y      ;5  13
            sta GRP0                     ;3  16
            lda COL_A0_PF2,y             ;4  20
            sta temp_p4                  ;3  23
            lax (draw_t1_p2_addr),y      ;5  28
            lda COL_A0_PF1,y             ;4  32
            sty temp_y                   ;3  35
            ldy temp_p4                  ;3  38
            stx GRP1                     ;3  41
            sta GRP0                     ;3  44
            sty GRP1                     ;3  47
            sty GRP0                     ;3  50
            ldy temp_y                   ;3  53
            dey                          ;2  55
            bmi _gx_title_loop_11_jmp    ;2  57
            ldx TITLE_WRITE_OFFSET,y     ;4  61
            lda (draw_t1_data_addr),y    ;5  66
            sta draw_t0,x                ;4  70
            ldx #0                       ;2  72 prep for next line
            stx GRP0                     ;3  75
            jmp _gx_title_11_loop_0      ;3   2
_gx_title_loop_11_jmp
            SLEEP 4                      ;3  61
            jmp (draw_t1_jump_addr)      ;5  66


gx_show_select
            lda #<gx_select_return
            sta draw_t0_jump_addr
            lda #>gx_select_return
            sta draw_t0_jump_addr + 1

            jsr sub_vblank_loop

            lda draw_c0
            sta COLUP0
            sta COLUP1

            ldx #12; draw_steps_wsync
            jsr sub_wsync_loop

            ; select
            bmi gx_title_start_draw ; space: Z flag should be set

gx_show_title
            ldx #WHITE
            stx COLUP0
            stx COLUP1
            jsr sub_vblank_loop

            ldx #13
            ldy #6
_gx_title_setup_loop
            lda TITLE_ROW_HI,y
            sta draw_t0,x
            sta draw_t1,x
            dex
            lda TITLE_ROW_0_DATA,y     
            sta draw_t0,x
            dex 
            dey
            bpl _gx_title_setup_loop

gx_title_start_draw
            sta WSYNC
            lda #TITLE_RESP
            jsr sub_steps_respxx_3cr;
            lda #$10 ; load this values for the *next* (late) hmove 
            sta WSYNC
            sta HMCLR
            sta HMP1
            sta HMOVE
            ldy #7                       ;2   2
            lda (draw_t0_p0_addr),y      ;5   7
            sta GRP0                     ;3  10
            lda #$80
            sta HMP0
            sta HMP1
            sta WSYNC
            jmp _gx_title_0_loop_1       ;3   3

gx_title_end
            lda #ZARA_COLOR
            sta COLUP0
            ldx #4
            jsr sub_wsync_loop
            inx ; SPACE: need 0, x is -1
            stx GRP1
            stx GRP0                     
            jsr sub_squirrel_refpxx
            lda #SQUIRREL_GANG_RESP
            jsr sub_steps_respxx_3cr
            dey ; SPACE: need 0, y is 1
            sty VDELP0
            sty VDELP1
            ldy #7                       
_draw_tx_end_loop
            sta WSYNC
            lda SYMBOL_GRAPHICS_ZARA,y   
            sta GRP0                     
            sta GRP1   
            dey                 
            bpl _draw_tx_end_loop

            lda #GROUND_COLOR
            sta COLUBK
            ldx #11
            lda lava_height
            beq _draw_tx_skip_lava
            sta WSYNC
            lda #LAVA_COLOR
            sta COLUBK
            dex
_draw_tx_skip_lava
            jsr sub_wsync_loop

            inx ; cheat and bump x up 1
            stx COLUBK
            stx REFP1

            ldx #10
            jsr sub_wsync_loop

            jmp gx_overscan

gx_title_0_hmove_7
            SLEEP 3                     ;11  73
            sta HMOVE
            jmp gx_title_0   

gx_title_0_delay_0
            SLEEP 3                    ;11  73
            jmp gx_title_0             ;3   --

gx_title_1_hmove_7
            ldy #7                       ;2   2
            lda (draw_t1_p0_addr),y      ;5  73
            sta HMOVE                    ;3  --
            SLEEP 3                      ;3   3
            jmp _gx_title_1_loop_1       ;3   6

gx_title_1_delay_0
            SLEEP 3                    ;11  73
            jmp gx_title_1              ;3   --

gx_title_00_hmove_7
            SLEEP 6                    ;11  72
            ldy #7                     ;2   2
            lda draw_t0_p0_addr        ;3   5
            sta HMOVE
            jmp _gx_title_00_loop_1    ; arrive at sc 4
        
gx_title_11_hmove_7
            SLEEP 5                    ;11  73
            sta HMOVE
            jmp gx_title_11      

;--------------------
; Select Screen

gx_select_return
            jsr sub_clear_gx

            lda #ZARA_COLOR
            sta COLUP0
            lda #WHITE
            sta COLUP1

            ldx #15
            jsr sub_wsync_loop

            lda #3 
            sta temp_select_repeat
            ora difficulty_level
            sta temp_select_index

_gx_show_select_flights_repeat
            ldx temp_select_repeat
            lda SELECT_FLIGHTS_RESPX,x
            jsr sub_steps_respxx_r 
            lda temp_select_index
            ldy #0
            cmp difficulty_level
            bne _gx_show_select_mask
            dey ; ldy #$ff ; SPACE: y already 0
_gx_show_select_mask
            sty temp_select_mask
            sta WSYNC
            sty GRP0
            sty GRP1
            sed
            clc
            adc #1
            cld
            ldx #0
            jsr sub_write_digit
            lda #>SYMBOL_GRAPHICS
            sta draw_s0_addr + 1
            sta draw_s1_addr + 1
            ldy #7
_gx_show_select_stairs_loop
            sta WSYNC
            lda (draw_s0_addr),y
            eor temp_select_mask
            sta GRP0
            lda (draw_s1_addr),y
            eor temp_select_mask
            sta GRP1
            sta WSYNC
            dey
            bpl _gx_show_select_stairs_loop  ;2   7
            iny
            sty GRP0
            sty GRP1
            dec temp_select_index
            dec temp_select_repeat
            bpl _gx_show_select_flights_repeat

            jmp gx_select_footer


STEP_MASK
    byte $01,$80

; ------------------------
; audio tracks

    ORG $FA00

AUDIO_TRACKS ; AUDCx,AUDFx,AUDVx,T
     byte 0

    include "_steps_tracks.asm"

; ----------------------------------
; maze data 

    ORG $FB00

TITLE_ROW_0_DATA
    byte <COL_A0_PF0
    byte <COL_A0_PF1
    byte <COL_A0_PF2
    byte <COL_A0_PF3
    byte <COL_A0_PF4
    byte <gx_title_1_delay_0
    byte <TITLE_ROW_1_DATA

TITLE_ROW_1_DATA
    byte <COL_A1_PF0
    byte <COL_A1_PF1
    byte <COL_A1_PF2
    byte <COL_A1_PF3
    byte <COL_A1_PF4
    byte <gx_title_0_delay_0
    byte <TITLE_ROW_2_DATA

TITLE_ROW_2_DATA
    byte <COL_A2_PF0
    byte <COL_A2_PF1
    byte <COL_A2_PF2
    byte <COL_A2_PF3
    byte <COL_A2_PF4
    byte <gx_title_1_delay_0
    byte <TITLE_ROW_3_DATA

TITLE_ROW_3_DATA
    byte <COL_A3_PF0
    byte <COL_A3_PF1
    byte <COL_A3_PF2
    byte <COL_A3_PF3
    byte <COL_A3_PF4
    byte <gx_title_0_delay_0
    byte <TITLE_ROW_4_DATA

TITLE_ROW_4_DATA
    byte <COL_A4_PF0
    byte <COL_A4_PF1
    byte <COL_A4_PF2
    byte <COL_A4_PF3
    byte <COL_A4_PF4
    byte <gx_title_1_delay_0
    byte <TITLE_ROW_5_DATA

TITLE_ROW_5_DATA
    byte <COL_A5_PF0
    byte <COL_A5_PF1
    byte <COL_A5_PF2
    byte <COL_A5_PF3
    byte <COL_A5_PF4
    byte <gx_title_00_hmove_7
    byte <TITLE_ROW_6_DATA

TITLE_ROW_6_DATA
    byte $01;<COL_A6_PF2
    byte <COL_A6_PF3
    byte <COL_A6_PF4
    byte <COL_A6_PF5
    byte <COL_B6_PF0
    byte <gx_title_1_hmove_7
    byte <TITLE_ROW_7_DATA

TITLE_ROW_7_DATA
    byte <COL_A7_PF2
    byte <COL_A7_PF3
    byte <COL_A7_PF4
    byte <COL_A7_PF5
    byte <COL_B7_PF0
    byte <gx_title_0_delay_0
    byte <TITLE_ROW_8_DATA

TITLE_ROW_8_DATA
    byte <COL_A8_PF2
    byte <COL_A8_PF3
    byte <COL_A8_PF4
    byte <COL_A8_PF5
    byte <COL_B8_PF0
    byte <gx_title_11_hmove_7
    byte <TITLE_ROW_9_DATA

TITLE_ROW_9_DATA
    byte $80; <COL_A9_PF4
    byte <COL_A9_PF5
    byte <COL_B9_PF0
    byte <COL_B9_PF1
    byte <COL_B9_PF2
    byte <gx_title_0_hmove_7
    byte <TITLE_ROW_A_DATA

TITLE_ROW_A_DATA
    byte <COL_AA_PF4
    byte <COL_AA_PF5
    byte <COL_BA_PF0
    byte <COL_BA_PF1
    byte <COL_BA_PF2
    byte <gx_title_1_delay_0
    byte <TITLE_ROW_B_DATA

TITLE_ROW_B_DATA
    byte <COL_AB_PF4
    byte <COL_AB_PF5
    byte <COL_BB_PF0
    byte <COL_BB_PF1
    byte <COL_BB_PF2
    byte <gx_title_00_hmove_7
    byte <TITLE_ROW_C_DATA

TITLE_ROW_C_DATA
    byte $80;<COL_BC_PF0
    byte <COL_BC_PF1
    byte <COL_BC_PF2
    byte <COL_BC_PF3
    byte <COL_BC_PF4
    byte <gx_title_1_hmove_7
    byte <TITLE_ROW_D_DATA

TITLE_ROW_D_DATA
    byte <COL_BD_PF0
    byte <COL_BD_PF1
    byte <COL_BD_PF2
    byte <COL_BD_PF3
    byte <COL_BD_PF4
    byte <gx_title_0_delay_0
    byte <TITLE_ROW_E_DATA

TITLE_ROW_E_DATA
    byte <COL_BE_PF0
    byte <COL_BE_PF1
    byte <COL_BE_PF2
    byte <COL_BE_PF3
    byte <COL_BE_PF4
    byte <gx_title_1_delay_0
    byte <TITLE_ROW_F_DATA

TITLE_ROW_F_DATA
    byte <COL_BF_PF0
    byte <COL_BF_PF1
    byte <COL_BF_PF2
    byte <COL_BF_PF3
    byte <COL_BF_PF4
    byte <gx_title_0_delay_0
    byte <TITLE_ROW_G_DATA

TITLE_ROW_G_DATA
    byte <COL_BG_PF0
    byte <COL_BG_PF1
    byte <COL_BG_PF2
    byte <COL_BG_PF3
    byte <COL_BG_PF4
    byte <gx_title_1_delay_0
    byte <TITLE_ROW_H_DATA

TITLE_ROW_H_DATA
    byte <COL_BH_PF0
    byte <COL_BH_PF1
    byte <COL_BH_PF2
    byte <COL_BH_PF3
    byte <COL_BH_PF4
    byte <gx_title_end
    byte <TITLE_ROW_H_DATA

MAZES_6

    byte $36,$76,$42,$43,$31,$05 ; sol: 11
    byte $27,$14,$65,$31,$17,$03 ; sol: 11
    byte $46,$65,$27,$14,$57,$03 ; sol: 11
    byte $27,$57,$31,$64,$34,$01 ; sol: 12

    byte $37,$64,$31,$54,$27,$05 ; sol: 12
    byte $27,$16,$45,$35,$42,$06 ; sol: 11
    byte $27,$57,$31,$65,$14,$04 ; sol: 12
    byte $57,$42,$63,$54,$41,$02 ; sol: 11

    byte $57,$52,$63,$54,$41,$07 ; sol: 12
    byte $57,$31,$46,$51,$53,$02 ; sol: 11
    byte $37,$26,$17,$54,$31,$07 ; sol: 11
    byte $27,$57,$31,$65,$34,$07 ; sol: 11

    byte $37,$72,$42,$51,$63,$02 ; sol: 11
    byte $57,$63,$14,$64,$25,$03 ; sol: 11
    byte $57,$53,$27,$64,$51,$03 ; sol: 11
    byte $73,$25,$75,$15,$74,$06 ; sol: 10

    ; byte $27,$17,$74,$35,$37,$06 ; sol: 10
    ; byte $57,$62,$73,$54,$13,$07 ; sol: 11
    ; byte $57,$13,$25,$64,$13,$03 ; sol: 11
    ; byte $57,$63,$27,$64,$14,$04 ; sol: 11
    ; byte $47,$62,$31,$65,$37,$04 ; sol: 10
    ; byte $57,$72,$35,$61,$64,$01 ; sol: 11
    ; byte $25,$47,$36,$15,$56,$07 ; sol: 10
    ; byte $57,$62,$23,$54,$13,$07 ; sol: 11
    ; byte $57,$62,$23,$54,$13,$05 ; sol: 12
    ; byte $47,$17,$24,$35,$37,$06 ; sol: 11
    ; byte $47,$62,$52,$51,$13,$07 ; sol: 11
    ; byte $24,$17,$53,$67,$43,$02 ; sol: 10
    ; byte $56,$72,$41,$61,$73,$02 ; sol: 10
    ; byte $57,$63,$21,$64,$13,$04 ; sol: 10
    ; byte $24,$17,$63,$64,$31,$05 ; sol: 10
    ; byte $65,$72,$41,$51,$43,$02 ; sol: 10

sub_vblank_loop
            ldx #$00
_end_vblank_loop          
            cpx INTIM
            bmi _end_vblank_loop
            stx VBLANK
            ; end
sub_clear_gx 
            stx WSYNC ; SL 35
            ldx draw_colubk
            stx COLUBK
            ldx #$00
            stx REFP0
            stx NUSIZ0
            stx NUSIZ1
            stx VDELP0
            stx VDELP1
            rts

SKY_PALETTE
    byte SKY_BLUE, BLACK

SELECT_FLIGHTS_RESPX
    byte 64,80,96,112


    ORG $FC00

SUN_PAT_SKY
    byte $00,$07,$0f,$1f,$3f,$3f,$3f,$3f
    byte $3f,$3f,$3f,$3f,$1f,$0f,$07,$00

    ; layouts
    ; nnnnffff = flight of length 2f, repeat n times (n+1 total)
    ; 00000000 = stop
LAYOUT_COUNTER_MASK = %00001111
LAYOUT_REPEAT_MASK = %11110000
LAYOUTS
LAYOUT_EASY= . - LAYOUTS
;    byte 3,2,0,2,0,0
    byte $23,$14,$16,0
LAYOUT_MED = . - LAYOUTS
;    byte 2,3,0,3,0,2
    byte $13,$24,$26,$18,0
LAYOUT_HARD = . - LAYOUTS
;    byte 0,5,0,7,0,4
    byte $44,$66,$38,0
LAYOUT_EXTRA = . - LAYOUTS
;    byte 0,0,0,0,0,16
    byte $f8,0

gx_end
            lda player_health
            bmi _player_lose
            lda frame
            and #$7f
            sta player_health
            byte $2c
_player_lose
            lda #BLACK
_gx_end_wait
            sta draw_colubk
            ldx draw_table_top
            sta draw_step_colors-1,x
            ; wait for song
            lda audio_tracker
            bne _wait_for_reset
            ; on button press restart
            bit player_input_latch
            bpl _reset_game
_wait_for_reset
            jmp gx_continue
_reset_game
            jmp Reset

gx_player_clock    
            ; x = 1 or -1 for count up or down
            ; does not handle counting down minutes
            lda player_clock
            clc
            adc #1
            cmp #CLOCK_HZ
            bmi _clock_save
            sed
            lda player_timer
            cpx #0
            bpl _clock_add
            sec
            sbc #1
            sta player_timer
            jmp _clock_save_out
_clock_add
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
_clock_save_out
            cld
            lda #0
_clock_save
            sta player_clock 
            rts

gx_select_footer
            ldx #10
            jsr sub_wsync_loop

            lda difficulty_level
            and #$03
            asl
            asl
            asl
            asl
            clc
            adc #7
            pha
            adc #31
            jsr sub_steps_respxx_r ;
            lda #$10 ; -1 HMOVE
            sta WSYNC
            sta HMCLR
            sta HMP1
            sta HMOVE
            pla
            tax
            ldy #7
_gx_show_select_motto_loop
            sta WSYNC
            lda SYMBOL_GRAPHICS_EZPZ_0,x
            sta GRP0
            lda SYMBOL_GRAPHICS_EZPZ_1,x
            sta GRP1
            sta WSYNC
            dex
            dey
            bpl _gx_show_select_motto_loop  ;2   7
            lda #$80
            sta GRP1
            ldx #3
            jsr sub_wsync_loop

            jmp gx_title_end

sub_galois  ; 16 bit lfsr from: https:;github.com/bbbradsmith/prng_6502/tree/master
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

LAYOUTS_LR 
    byte 8
    byte 6
    byte 6
    byte 2

sub_steps_lose
            lda #SEQ_LOSE_GAME
            sta audio_sequence
            lda #GAME_STATE_END
            sta game_state
            rts

SELECT_ROW
    byte 5,11,17,23

    ORG $FCF0
    ; this is duplicated at FDFO to simplify cloud display
CLOUD_PAT_PF5 = . - 1
;   byte #$00
    byte #$7c
    byte #$7c
    byte #$7c
    byte #$08
    byte #$08
    byte #$1f
    byte #$1f
    byte #$1f
CLOUD_PAT_BLANK_PF5
    byte $00,$00,$00,$00,$00,$00,$00,$00

    ORG $FD00

MAZES_8

    byte $69,$83,$49,$76,$32,$97,$58,$01 ; sol: 15
    byte $49,$58,$28,$28,$73,$29,$96,$01 ; sol: 15
    byte $52,$19,$83,$73,$65,$62,$69,$04 ; sol: 15
    byte $52,$69,$81,$79,$83,$62,$68,$04 ; sol: 15

    byte $82,$19,$83,$79,$35,$62,$61,$04 ; sol: 15
    byte $36,$86,$52,$91,$86,$27,$43,$02 ; sol: 14
    byte $87,$82,$53,$17,$68,$97,$14,$09 ; sol: 14
    byte $82,$93,$57,$61,$57,$84,$74,$04 ; sol: 14

    byte $74,$69,$48,$28,$36,$15,$59,$07 ; sol: 15
    byte $14,$69,$48,$28,$35,$35,$39,$07 ; sol: 16
    byte $36,$19,$48,$72,$78,$25,$67,$04 ; sol: 13
    byte $37,$96,$91,$25,$95,$75,$34,$08 ; sol: 13

    byte $28,$39,$86,$84,$24,$67,$14,$05 ; sol: 14
    byte $28,$47,$86,$56,$53,$69,$78,$01 ; sol: 15
    byte $73,$65,$59,$42,$86,$64,$13,$06 ; sol: 15
    byte $78,$39,$26,$64,$54,$67,$48,$01 ; sol: 14

    ; byte $17,$98,$84,$25,$95,$96,$73,$09 ; sol: 13
    ; byte $35,$81,$41,$57,$93,$35,$62,$08 ; sol: 13
    ; byte $49,$58,$21,$28,$74,$49,$86,$03 ; sol: 13
    ; byte $49,$58,$26,$97,$74,$49,$16,$03 ; sol: 14
    ; byte $28,$15,$86,$86,$43,$69,$78,$05 ; sol: 13
    ; byte $59,$51,$58,$72,$46,$83,$83,$03 ; sol: 15
    ; byte $42,$69,$18,$84,$82,$37,$35,$08 ; sol: 13
    ; byte $28,$15,$86,$76,$63,$69,$78,$05 ; sol: 15
    ; byte $58,$39,$26,$64,$64,$67,$48,$01 ; sol: 13
    ; byte $49,$21,$83,$59,$76,$71,$34,$08 ; sol: 15
    ; byte $68,$29,$43,$57,$34,$65,$18,$04 ; sol: 13
    ; byte $76,$92,$23,$53,$96,$65,$81,$04 ; sol: 14
    ; byte $16,$49,$48,$72,$78,$85,$37,$04 ; sol: 13
    ; byte $19,$25,$39,$76,$32,$47,$58,$03 ; sol: 14
    ; byte $58,$39,$86,$24,$54,$67,$68,$01 ; sol: 14
    ; byte $56,$49,$48,$62,$79,$84,$37,$01 ; sol: 14

MAZES_4

    byte $15,$32,$31,$01 ; sol: 7
    byte $15,$14,$43,$03 ; sol: 8
    byte $15,$42,$41,$02 ; sol: 7
    byte $43,$14,$24,$05 ; sol: 7

    byte $25,$35,$42,$02 ; sol: 8
    byte $22,$24,$13,$05 ; sol: 8
    byte $25,$15,$14,$05 ; sol: 7
    byte $25,$14,$33,$05 ; sol: 8

    byte $35,$41,$42,$04 ; sol: 7
    byte $15,$24,$33,$02 ; sol: 6
    byte $55,$42,$41,$04 ; sol: 8
    byte $42,$54,$13,$05 ; sol: 7

    byte $43,$32,$13,$05 ; sol: 7
    byte $35,$44,$31,$02 ; sol: 7
    byte $51,$23,$13,$04 ; sol: 7
    byte $15,$42,$42,$03 ; sol: 8
;    byte $35,$42,$31,$03 ; sol: 6
;    byte $35,$42,$41,$05 ; sol: 6
;    byte $52,$43,$41,$02 ; sol: 8
;    byte $25,$31,$43,$02 ; sol: 7
;    byte $15,$32,$41,$01 ; sol: 8
;    byte $52,$13,$43,$03 ; sol: 8
;    byte $43,$35,$12,$05 ; sol: 8
;    byte $43,$35,$31,$02 ; sol: 7
;    byte $13,$35,$41,$02 ; sol: 8
;    byte $25,$44,$31,$05 ; sol: 7
;    byte $35,$32,$41,$01 ; sol: 7
;    byte $15,$24,$43,$02 ; sol: 7
;    byte $35,$35,$41,$04 ; sol: 8
;    byte $35,$44,$31,$05 ; sol: 8
;    byte $51,$21,$13,$04 ; sol: 8
;    byte $52,$24,$13,$03 ; sol: 7

MAZES_3

    byte $22,$22,$03 ; w: 0.13333333333333333 sol: 6
    byte $31,$21,$02 ; w: 0.4 sol: 6
    byte $14,$21,$02 ; w: 0.3 sol: 5
    byte $43,$11,$04 ; w: 0.4 sol: 5

    byte $21,$13,$03 ; w: 0.5 sol: 5
    byte $44,$11,$02 ; w: 0.3 sol: 5
    byte $32,$31,$01 ; w: 0.5 sol: 5
    byte $43,$14,$03 ; w: 0.4 sol: 5

    byte $24,$13,$03 ; w: 1.3333333333333333 sol: 6
    byte $44,$13,$03 ; w: 0.4 sol: 4
    byte $31,$43,$02 ; w: 0.5333333333333334 sol: 5
    byte $24,$23,$03 ; w: 0.5 sol: 5

    byte $24,$13,$03 ; w: 1.3333333333333333 sol: 6
    byte $42,$12,$03 ; w: 0.6666666666666667 sol: 5
    byte $42,$31,$03 ; w: 0.5333333333333334 sol: 4
    byte $14,$21,$03 ; w: 0.5333333333333333 sol: 6

    ; byte $14,$13,$03 ; w: 0.5 sol: 5
    ; byte $34,$43,$02 ; w: 0.4 sol: 4
    ; byte $43,$11,$04 ; w: 0.4 sol: 5
    ; byte $21,$13,$03 ; w: 0.5 sol: 5
    ; byte $44,$11,$02 ; w: 0.3 sol: 5
    ; byte $32,$31,$01 ; w: 0.5 sol: 5
    ; byte $43,$14,$03 ; w: 0.4 sol: 5
    ; byte $44,$13,$03 ; w: 0.4 sol: 4
    ; byte $31,$43,$02 ; w: 0.5333333333333334 sol: 5
    ; byte $24,$23,$03 ; w: 0.5 sol: 5
    ; byte $42,$12,$03 ; w: 0.6666666666666667 sol: 5
    ; byte $42,$31,$03 ; w: 0.5333333333333334 sol: 4
    ; byte $14,$21,$03 ; w: 0.5333333333333333 sol: 6
    ; byte $14,$13,$03 ; w: 0.5 sol: 5
    ; byte $34,$43,$02 ; w: 0.4 sol: 4
    ; byte $43,$11,$04 ; w: 0.4 sol: 5

    ORG $FDF0
CLOUD_PAT_PF1 = . - 1
;    byte #$00
    byte #$1f
    byte #$1f
    byte #$1f
    byte #$08
    byte #$08
    byte #$7c
    byte #$7c
    byte #$7c
CLOUD_PAT_BLANK = . - 1
    byte $00,$00,$00,$00,$00,$00,$00,$00

; ----------------------------------
; symbol graphics 

    ORG $FE00
    
SYMBOL_GRAPHICS
SYMBOL_GRAPHICS_ZERO
    byte $0,$38,$44,$44,$44,$44,$44,$38; 8
SYMBOL_GRAPHICS_ONE
    byte $0,$38,$10,$10,$10,$10,$10,$30; 8
SYMBOL_GRAPHICS_TWO
    byte $0,$3c,$40,$40,$78,$4,$4,$7c; 8
SYMBOL_GRAPHICS_THREE
    byte $0,$78,$4,$4,$3c,$4,$4,$78; 8
SYMBOL_GRAPHICS_FOUR
    byte $0,$4,$4,$4,$3c,$44,$44,$44; 8
SYMBOL_GRAPHICS_FIVE
    byte $0,$78,$4,$4,$3c,$40,$40,$7c; 8
SYMBOL_GRAPHICS_SIX
    byte $0,$38,$44,$44,$78,$40,$40,$38; 8
SYMBOL_GRAPHICS_SEVEN
    byte $0,$10,$10,$10,$18,$c,$4,$7c; 8
SYMBOL_GRAPHICS_EIGHT
    byte $0,$38,$44,$44,$7c,$44,$44,$38; 8
SYMBOL_GRAPHICS_NINE
    byte $0,$38,$4,$4,$3c,$44,$44,$38; 8
SYMBOL_GRAPHICS_ZARA
    byte $0,$1c,$3c,$3e,$6c,$6c,$46,$6; 8
SYMBOL_GRAPHICS_TUMBLE_0
    byte $0,$38,$1c,$e,$3e,$7e,$7e,$68; 8
SYMBOL_GRAPHICS_TUMBLE_1
    byte $0,$c,$8c,$d8,$d8,$7c,$78,$38; 8
SYMBOL_GRAPHICS_BLANK
    byte $0,$0,$0,$0,$0,$0,$0,$0; 8
SYMBOL_GRAPHICS_ACORN
    byte $0,$10,$38,$7c,$7c,$0,$7c,$38; 8
SYMBOL_GRAPHICS_CROWN
    byte $0,$7c,$7c,$0,$7c,$7c,$54,$54; 8
SYMBOL_GRAPHICS_EZPZ_0
    byte $0,$8e,$ec,$ee,$0,$ea,$ce,$ee; 8
SYMBOL_GRAPHICS_EZPZ_1
    byte $0,$64,$4e,$ca,$0,$64,$4e,$ca; 8
SYMBOL_GRAPHICS_NORM_0
    byte $0,$ee,$8a,$ee,$0,$ae,$aa,$ee; 8
SYMBOL_GRAPHICS_NORM_1
    byte $0,$8e,$8c,$ee,$0,$8a,$8e,$ee; 8
SYMBOL_GRAPHICS_HARD_0
    byte $0,$ee,$8a,$ee,$0,$aa,$ee,$ae; 8
SYMBOL_GRAPHICS_HARD_1
    byte $0,$8e,$8c,$ee,$0,$8c,$8a,$ee; 8
SYMBOL_GRAPHICS_MEGA_0
    byte $0,$ea,$ee,$aa,$0,$32,$13,$1b; 8
SYMBOL_GRAPHICS_MEGA_1
    byte $0,$a4,$e4,$ee,$0,$90,$b8,$a8; 8
; SPACE: UNUSED GRAPHICS
; SYMBOL_GRAPHICS_LETSGO_0 
;     byte $0,$d,$19,$1d,$0,$ee,$8c,$8e; 8
; SYMBOL_GRAPHICS_LETSGO_1
;     byte $0,$d0,$48,$c8,$0,$4c,$44,$e6; 8
; SYMBOL_GRAPHICS_GOODJOB_0
;     byte $0,$ce,$4a,$ee,$0,$6e,$ca,$ee; 8
; SYMBOL_GRAPHICS_GOODJOB_1
;     byte $0,$e8,$e4,$84,$0,$ec,$aa,$ee; 8
; SYMBOL_GRAPHICS_STEPS_0  
;     byte $0,$80,$c4,$64,$ec,$cc,$66,$22; 8
; SYMBOL_GRAPHICS_STEPS_1
;     byte $0,$80,$c8,$a8,$cc,$ee,$66,$22; 8
; SYMBOL_GRAPHICS_STEPS_2
;     byte $0,$84,$c0,$64,$e4,$c4,$64,$20; 8
; SYMBOL_GRAPHICS_STEPS_3
;     byte $0,$e2,$6,$ee,$0,$ce,$a8,$ee; 8


TIMER_MASK
    byte $00,$00,$00,$01,$00,$01,$00,$00,$00

LEVELS
    byte LAYOUT_EASY  ; EASY
    byte LAYOUT_MED   ; MED
    byte LAYOUT_HARD  ; HARD
    byte LAYOUT_EXTRA ; EXTRA

sub_steps_respxx_3cr
            ; set up for 3 copies close display
            ldy #3
            sty NUSIZ0
            sty NUSIZ1
            sty VDELP0
            sty VDELP1
sub_steps_respxx_r
            ldy #1 ; most common direction: RESPO first
sub_steps_respxx
            ; a is respx, y is direction (0 or 1)
            sec
            sta WSYNC               ; --
_respxx_loop
            sbc #15                 ;2    2
            sbcs _respxx_loop       ;2/3  4
            tax                     ;2    6
            lda LOOKUP_STD_HMOVE,x  ;5   11
            sta HMP0                ;3   14
            sta HMP1                ;3   17
            cpy #0                  ;2   19 ;
            sbeq _respxx_swap       ;2   21
            sta.w RESP0             ;4   25
            sta RESP1               ;3   28
            sta WSYNC               ;------
            sta HMOVE               ;3    3
            rts                     ;6    9
_respxx_swap
            sta RESP1               ;3   25
            sta RESP0               ;3   28
            sta WSYNC               ;------
            sta HMOVE               ;3    3
            rts                     ;6    9

    ORG $FF00

    ; standard lookup for hmoves
STD_HMOVE_BEGIN
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END
LOOKUP_STD_HMOVE = STD_HMOVE_END - 256

LAVA_SPEED
    byte 100, 87, 50, 50

    ; maze data LUT
MAZE_PTR_LO = . - 2
    byte <MAZES_3
    byte <MAZES_4
    byte 0
    byte <MAZES_6
    byte 0
    byte <MAZES_8
MAZE_PTR_HI = . - 2
    byte >MAZES_3
    byte >MAZES_4
    byte 0
    byte >MAZES_6
    byte 0
    byte >MAZES_8

AUDIO_SEQUENCES
    byte 0
SEQ_WIN_GAME = . - AUDIO_SEQUENCES
SEQ_TITLE = . - AUDIO_SEQUENCES
    byte TRACK_TITLE_0_C00,TRACK_TITLE_0_C01
    byte TRACK_TITLE_1_C00,TRACK_TITLE_1_C01
    byte TRACK_TITLE_2_C00,TRACK_TITLE_2_C01
    byte TRACK_TITLE_3_C00,TRACK_TITLE_3_C01
SEQ_START_SELECT = . - AUDIO_SEQUENCES
SEQ_LANDING = . - AUDIO_SEQUENCES
SEQ_LOSE_GAME = . - AUDIO_SEQUENCES
    byte TRACK_TITLE_4_C00,TRACK_TITLE_4_C01
    byte 0
SEQ_START_GAME = . - AUDIO_SEQUENCES
    byte TRACK_TITLE_0_C00,TRACK_TITLE_0_C01
    byte 0
SEQ_SELECT_UP = . - AUDIO_SEQUENCES
    byte TRACK_STEP_0_C00,TRACK_WAIT
    byte 0
SEQ_SELECT_DOWN = . - AUDIO_SEQUENCES
    byte TRACK_STEP_1_C00,TRACK_WAIT
    byte 0

TRACK_FREQ_INDEX
    ; byte 31
    ; byte 27
    ; byte 26
    byte 26,23,21,19,15,13,10
    byte 27,26,23,20,19,17,16,15,11
    ;byte 9

TRACK_CHAN_INDEX
    byte 12,12,12,12,12,12,12
    byte 04,04,04,04,04,04,04,04,04

MARGINS
    byte 6,7,7,13,15,17,17,18,18

; overlapping tables for respxx swaps
RESPXX_HMOVE_A
    byte $90
    byte $70
RESPXX_HMP0
    byte $30
RESPXX_HMP1
    byte $10
    byte $30

; SELECT SYMS
SELECT_GRAPHICS
SELECT_SYMBOL_T
    byte $38,$28,$28,$28,$28,$ee,$82;,$fe; 8
SELECT_SYMBOL_S
    byte $fe,$82,$e2,$24,$48,$8e,$82;,$fe; 8
SELECT_SYMBOL_E
    byte $fe,$82,$9e,$82,$9a,$82,$82;,$fe; 8
SELECT_SYMBOL_L
    byte $fe,$82,$82,$9e,$90,$90,$90;,$f0; 8
SELECT_SYMBOL_P
    byte $f0,$90,$9e,$82,$9a,$82,$82;,$fe; 8
SELECT_SYMBOL_A
    byte $fe,$92,$92,$82,$92,$82,$82;,$fe; 8
SELECT_SYMBOL_R
    byte $fe,$92,$92,$86,$9a,$82,$82;,$fe; 8
SELECT_SYMBOL_K
    byte $fe,$92,$92,$86,$82,$9a,$9a,$fe; 8
SELECT_SYMBOL_D
    byte $fc,$82,$9a,$9a,$9a,$9a,$82,$fc; 8
SELECT_SYMBOL_V
    byte $38,$44,$82,$92,$92,$92,$92,$fe; 8

SELECT_ROW_0_DATA
    byte #ZARA_COLOR
    byte <SELECT_SYMBOL_S
    byte <SELECT_SYMBOL_T
    byte <SELECT_SYMBOL_E
    byte <SELECT_SYMBOL_P
    byte <SELECT_SYMBOL_S
    ; byte <gx_select_return
    ; byte >gx_select_return

SELECT_ROW_1_DATA
    byte #LAVA_LOGO
    byte <SELECT_SYMBOL_L
    byte <SELECT_SYMBOL_A
    byte <SELECT_SYMBOL_V
    byte <SELECT_SYMBOL_A
    byte <SELECT_SYMBOL_S
    ; byte <gx_select_return
    ; byte >gx_select_return

SELECT_ROW_2_DATA
    byte #DARKS_LOGO
    byte <SELECT_SYMBOL_D
    byte <SELECT_SYMBOL_A
    byte <SELECT_SYMBOL_R
    byte <SELECT_SYMBOL_K
    byte <SELECT_SYMBOL_S
    ; byte <gx_select_return
    ; byte >gx_select_return

SELECT_ROW_3_DATA
    byte #LEETS_LOGO
    byte <SELECT_SYMBOL_L
    byte <SELECT_SYMBOL_E
    byte <SELECT_SYMBOL_E
    byte <SELECT_SYMBOL_T
    byte <SELECT_SYMBOL_S
    ; byte <gx_select_return
    ; byte >gx_select_return

GX_JUMP_LO
    byte <(gx_title-1)
    byte <(gx_select-1)
    byte <(gx_start-1)
    byte <(gx_climb-1)
    byte <(gx_jump-1)
    byte <(gx_scroll-1)
    byte <(gx_fall-1)
    byte <(gx_end-1)
GX_JUMP_HI
    byte >(gx_title-1)
    byte >(gx_select-1)
    byte >(gx_start-1)
    byte >(gx_climb-1)
    byte >(gx_jump-1)
    byte >(gx_scroll-1)
    byte >(gx_fall-1)
    byte >(gx_end-1)

SQUIRREL_MOVE_PAT_0 = AUDIO_TRACKS
SQUIRREL_MOVE_PAT_1 = AUDIO_TRACKS + $1

sub_squirrel_refpxx
            lda frame
            lsr
            and #$70
            tax
            lda SQUIRREL_MOVE_PAT_0,x
            sta REFP0
            lda SQUIRREL_MOVE_PAT_1,x
            sta REFP1
            rts

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

;-----------------------------------------------------------------------------------
; the CPU reset vectors

    ORG $FFFA

    .word Reset          ; NMI
    .word Reset          ; RESET
    .word Reset          ; IRQ

    END
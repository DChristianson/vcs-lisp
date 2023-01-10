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
LOGO_COLOR = $C4
SCANLINES = 262
#else
; PAL Colors
WHITE = $0E
BLACK = 0
LOGO_COLOR = $53
SCANLINES = 262
#endif

FUNCTAB_SIZE = 4
CELL_SIZE = 2
HEAP_CELLS = 32
HEAP_SIZE = HEAP_CELLS * CELL_SIZE
HEAP_CAR_ADDR = $0000
HEAP_CDR_ADDR = $0001
NULL      = $00

HEADER_HEIGHT = 85
FOOTER_HEIGHT = 65
DISPLAY_COLS = 6
CHAR_HEIGHT = 8

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

; 32 cell heap
heap               ds HEAP_SIZE 
; heap pointers to user defined symbols
functab            ds FUNCTAB_SIZE
; pointer to free cell list
free               ds 1
; pointer to repl cell
repl               ds 1
; output number
output             ds CELL_SIZE

; scratchpad vars for all kernel routines and stack

frame         ds 1
repl_gx_addr
free_pf1
repl_s5_addr  ds 2
free_pf2
repl_s4_addr  ds 2
free_pf3
repl_s3_addr  ds 2
free_pf4
repl_s2_addr  ds 2
repl_s1_addr  ds 2
repl_s0_addr  ds 2
tmp_cell_addr ds 1

; ----------------------------------
; code

  SEG
    ORG $F000

Reset
CleanStart
    ; do the clean start macro
            CLEAN_START

    ; one PF color
            lda #WHITE
            sta COLUPF

    ; bootstrap heap
            ldx #(HEAP_SIZE - 1)
            lda #NULL
            sta heap,x
            dex
            sta heap,x
            dex
            ldy #NULL
            lda #<(heap + HEAP_SIZE - 2)
            sec
_bootstrap_heap_loop
            sta heap,x
            sbc #2
            dex
            sty heap,x
            dex
            bpl _bootstrap_heap_loop

    ; dummy program
            ldx #0
            ;
            ;(average x y)
            ;
            lda #%11000011
            sta heap,x
            inx
            lda #%10000010
            sta heap,x
            inx
            lda #%10000100
            sta heap,x
            inx
            lda #%10001010
            sta heap,x
            inx
            lda #%11000001
            sta heap,x
            inx
            lda #%10000110
            sta heap,x
            inx
            lda #%11001111
            sta heap,x
            inx
            lda #%10001000
            sta heap,x
            inx
            lda #%11010000
            sta heap,x
            inx
            lda #%00000000
            sta heap,x
            inx
            lda #%11010101
            sta heap,x
            inx
            lda #%00000000
            sta heap,x
            inx


        ; %11000011,%10000001
        ; %10000010,%10000101
        ; %11010101,%00000000
        ; %11000001,%10000011
        ; %11001111,%10000100
        ; %11010000,%00000000


    ; set free cell list
            lda #%10010010            
            sta free
            lda #%10000000            
            sta repl

        ; ;
        ; ;(square x)
        ; ;
        ; %11000000,%10000001
        ; %11001111,%10000010
        ; %11001111,%00000000
            ; ldx #$00
            ; lda #%11000000
            ; sta heap,x
            ; inx
            ; lda #%10000010
            ; sta heap,x
            ; inx
            ; lda #%11001111
            ; sta heap,x
            ; inx
            ; lda #%10000100
            ; sta heap,x
            ; inx
            ; lda #%11001111
            ; sta heap,x
            ; inx
            ; lda #%00000000
            ; sta heap,x


        ; ;
        ; ;(cube5 x)
        ; ;
        ; %11000000,%10000001
        ; %11001111,%10000010
        ; %11001111,%10000011
        ; %11001111,%10000100
        ; %11001111,%10000101
        ; %11001111,%00000000
            ; ldx #$00
            ; lda #%11000000
            ; sta heap,x
            ; inx
            ; lda #%10000010
            ; sta heap,x
            ; inx
            ; lda #%11001111
            ; sta heap,x
            ; inx
            ; lda #%10000100
            ; sta heap,x
            ; inx
            ; lda #%11001111
            ; sta heap,x
            ; inx
            ; lda #%10000110
            ; sta heap,x
            ; inx
            ; lda #%11001111
            ; sta heap,x
            ; inx
            ; lda #%10001000
            ; sta heap,x
            ; inx
            ; lda #%11001111
            ; sta heap,x
            ; inx
            ; lda #%10001010
            ; sta heap,x
            ; inx
            ; lda #%11001111
            ; sta heap,x
            ; inx
            ; lda #%00000000
            ; sta heap,x

        ; ;
        ; ;(cube10 x)
        ; ;
        ; %11000000,%10000001
        ; %11001111,%10000010
        ; %11001111,%10000011
        ; %11001111,%10000100
        ; %11001111,%10000101
        ; %11001111,%10000110
        ; %11001111,%10000111
        ; %11001111,%10001000
        ; %11001111,%10001001
        ; %11001111,%10001010
        ; %11001111,%00000000

        ; ;
        ; ;(cube31 x)
        ; ;
        ; %11000000,%10000001
        ; %11001111,%10000010
        ; %11001111,%10000011
        ; %11001111,%10000100
        ; %11001111,%10000101
        ; %11001111,%10000110
        ; %11001111,%10000111
        ; %11001111,%10001000
        ; %11001111,%10001001
        ; %11001111,%10001010
        ; %11001111,%10001011
        ; %11001111,%10001100
        ; %11001111,%10001101
        ; %11001111,%10001110
        ; %11001111,%10001111
        ; %11001111,%10010000
        ; %11001111,%10010001
        ; %11001111,%10010010
        ; %11001111,%10010011
        ; %11001111,%10010100
        ; %11001111,%10010101
        ; %11001111,%10010110
        ; %11001111,%10010111
        ; %11001111,%10011000
        ; %11001111,%10011001
        ; %11001111,%10011010
        ; %11001111,%10011011
        ; %11001111,%10011100
        ; %11001111,%10011101
        ; %11001111,%10011110
        ; %11001111,%10011111
        ; %11001111,%00000000

        ; ;
        ; ;(average x y)
        ; ;
        ; %11000011,%10000001
        ; %10000010,%10000101
        ; %11010101,%00000000
        ; %11000001,%10000011
        ; %11001111,%10000100
        ; %11010000,%00000000


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
; repl mode

            ; update frame
            inc frame

            ; prep symbol graphics
            ldy #(DISPLAY_COLS - 1) * 2
_prep_repl_loop
            lda #>SYMBOL_GRAPHICS_S00_MULT
            sta repl_gx_addr + 1,y
            dey
            dey
            bpl _prep_repl_loop


;---------------------
; end vblank

            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35
            lda #1
            sta CTRLPF ; reflect playfield
            lda #LOGO_COLOR
            sta COLUPF


            ; OK
header
            ldx #HEADER_HEIGHT
_header_loop
            sta WSYNC
            dex
            bpl _header_loop

            ; PROMPT
            ; draw repl cell tree
prompt
            lda #42    ; vblank timer will land us ~ on scanline + 34
            sta TIM64T
            ; do one repos loop at the top 
            ; use HMOVE to handle indenting
            sta WSYNC
            lda #8
_prompt_repos_loop
            sbc #15
            bcs _prompt_repos_loop
            tay
            lda LOOKUP_STD_HMOVE,y
            sta HMP0
            sta HMP1
            sta RESP0
            sta RESP1
            sta WSYNC             ;--
            sta HMOVE             ;3    3
            lda #3                ;2    5
            sta NUSIZ0            ;3    8
            sta NUSIZ1            ;3   11
            lda #WHITE            ;2   13
            sta COLUP0            ;3   16
            sta COLUP1            ;3   19
            lda #0                ;2   21
            ldx #$70              ;2   23
            sta HMP0              ;3   26
            stx HMP1              ;3   29
            SLEEP 23              ;23  52
            sta HMOVE             ;3   55


prompt_encode
            lda #0
            pha
            lda repl
prompt_next_line
            ldy #(DISPLAY_COLS - 1) * 2
_prompt_encode_loop
            tax
            lda HEAP_CAR_ADDR,x ; read car
            bpl _prompt_encode_clear ; BUGBUG: handle #
            cmp #$40
            bpl _prompt_encode_recurse
_prompt_encode_addchar
            stx tmp_cell_addr ; push down current cell
            tax
            lda LOOKUP_SYMBOL_GRAPHICS,x
            sta repl_gx_addr,y
            ldx tmp_cell_addr 
            lda HEAP_CDR_ADDR,x ; read cdr
            beq _prompt_encode_clear
            dey
            dey
            bpl _prompt_encode_loop
            ; list is too long, we need to indent
            ; push next address on the stack
            pha
            jmp prompt_encode_end
_prompt_encode_recurse
            ; we need to recurse so we need push t
            ; contents of the cdr
            ; contents of the car
            sta tmp_cell_addr ; set car aside
            lda HEAP_CDR_ADDR,x 
            beq _prompt_encode_recurse_skip_cdr
            pha 
_prompt_encode_recurse_skip_cdr
            lda tmp_cell_addr
            pha
_prompt_encode_clear
            dey
            dey
            lda #<SYMBOL_GRAPHICS_EMPTY
_prompt_encode_clear_loop
            sta repl_gx_addr,y
            dey
            dey
            bpl _prompt_encode_clear_loop
prompt_encode_end
            
            sta WSYNC ; shim

            ldy #CHAR_HEIGHT - 1
            lda #1
            bit frame
            bne prompt_draw_odd
prompt_draw_even
_prompt_draw_even_loop
            sta WSYNC                  ;--
            lda #0                     ;2    2
            sta GRP1                   ;3    5
            lda (repl_s0_addr),y       ;5   10
            sta GRP0                   ;3   13
            SLEEP 5                    ;5   18
            lda (repl_s2_addr),y       ;5   23
            sta GRP0                   ;3   26
            lda (repl_s4_addr),y       ;5   31
            sta GRP0                   ;3   33
            dey                        ;2   35
            sta WSYNC                  ;--
            lda #0                     ;2    2
            sta GRP0                   ;3    5
            lda (repl_s1_addr),y       ;5   10
            sta GRP1                   ;3   13
            SLEEP 8                    ;8   21
            lda (repl_s3_addr),y       ;5   26
            sta GRP1                   ;3   29
            lda (repl_s5_addr),y       ;5   34
            sta GRP1                   ;3   37
            dey                        ;2   39
            bpl _prompt_draw_even_loop ;2/3 41/42
            jmp prompt_draw_end
prompt_draw_odd
_prompt_draw_odd_loop
            sta WSYNC                  ;--
            lda #0                     ;2    2
            sta GRP0                   ;3    5
            lda (repl_s1_addr),y       ;5   10
            sta GRP1                   ;3   13
            SLEEP 8                    ;5   18
            lda (repl_s3_addr),y       ;5   23
            sta GRP1                   ;3   26
            lda (repl_s5_addr),y       ;5   31
            sta GRP1                   ;3   34
            dey                        ;2   36
            sta WSYNC                  ;--
            lda #0                     ;2    2
            sta GRP1                   ;3    5
            lda (repl_s0_addr),y       ;5   10
            sta GRP0                   ;3   13
            SLEEP 5                    ;2   15
            lda (repl_s2_addr),y       ;5   20
            sta GRP0                   ;3   23
            lda (repl_s4_addr),y       ;5   28
            sta GRP0                   ;3   31
            dey                        ;2   33
            bpl _prompt_draw_odd_loop ;2/3 46/47
            jmp prompt_draw_end
prompt_draw_end
            pla
            beq prompt_done
            jmp prompt_next_line
prompt_done
            jsr waitOnVBlank

            ; FREEBAR
freebar
            ldy #0
            sty NUSIZ0
            sty NUSIZ1
            ldx free
_free_bar_loop
            lda HEAP_CDR_ADDR,x
            bpl _free_bar_len
            iny
            tax
            jmp _free_bar_loop
_free_bar_len
            tya
            sec
            sbc #16
            bcs _free_gt_16
            adc #16 
            ldx #00
            stx free_pf3 
            stx free_pf4 
            jmp _free_half
_free_gt_16
            ldx #$ff
            stx free_pf1
            stx free_pf2
            ldx #2
_free_half
            sec
            sbc #8
            bcs _free_gt_8
            ldy #0
            sty free_pf2,x
            jmp _free_quarter
_free_gt_8
            ldy #$ff
            sty free_pf1,x
            inx
_free_quarter
            tay
            lda FREE_LOOKUP_TABLE,y
            sta free_pf1,x

            ldx #4
_free_draw_loop
            sta WSYNC
            lda #$ee         ;2   2
            sta GRP0        ;3   5
            lda #$ee         ;2   7
            sta GRP1        ;3  10
            lda free_pf1    ;3  13
            sta PF1         ;3  16
            lda free_pf2    ;3  19
            sta PF2         ;3  22
            SLEEP 15        ;15 37
            lda free_pf3    ;3  40
            sta PF1         ;3  43
            SLEEP 7         ;7  50 
            lda free_pf4    ;3  53
            sta PF2         ;3  56
            dex             ;2  58
            bpl _free_draw_loop
            lda #0
            sta PF1
            sta PF2
            sta GRP0
            sta GRP1
            
            ; BUGBUG: TODO: OUTPUT / MENU

            ; FOOTER
footer
            ldx #FOOTER_HEIGHT
_footer_loop
            sta WSYNC
            dex
            bpl _footer_loop

;--------------------
; Overscan start

waitOnOverscan
            ldx #30
waitOnOverscan_loop
            sta WSYNC
            dex
            bne waitOnOverscan_loop
            jmp newFrame

;------------------------
; vblank sub

waitOnVBlank
            ldx #$00
waitOnVBlank_loop          
            cpx INTIM
            bmi waitOnVBlank_loop
            stx VBLANK
            rts 

; ----------------------------------
; data

    ORG $FE00

    ; standard lookup for hmoves
STD_HMOVE_BEGIN
    byte $80, $70, $60, $50, $40, $30, $20, $10, $00, $f0, $e0, $d0, $c0, $b0, $a0, $90
STD_HMOVE_END
LOOKUP_STD_HMOVE = STD_HMOVE_END - 256

FREE_LOOKUP_TABLE
    byte $00, $01, $03, $07, $0f, $1f, $3f, $7f, $ff

SYMBOL_GRAPHICS_EMPTY
    byte $00,$00,$00,$00,$00,$00,$00,$00; 8
SYMBOL_GRAPHICS_S00_MULT
    byte $0,$88,$d8,$50,$20,$50,$d8,$88; 8
SYMBOL_GRAPHICS_S01_MULT
    byte $0,$0,$40,$40,$e0,$40,$40,$0; 8
SYMBOL_GRAPHICS_S02_MULT
    byte $0,$0,$0,$0,$e0,$0,$0,$0; 8
SYMBOL_GRAPHICS_S03_MULT
    byte $0,$80,$80,$40,$40,$40,$20,$20; 8
SYMBOL_GRAPHICS_S04_MULT
    byte $0,$0,$0,$e0,$0,$e0,$0,$0; 8
SYMBOL_GRAPHICS_S05_MULT
    byte $0,$0,$80,$40,$20,$40,$80,$0; 8
SYMBOL_GRAPHICS_S06_MULT
    byte $0,$0,$20,$40,$80,$40,$20,$0; 8
SYMBOL_GRAPHICS_S07_MULT
    byte $0,$40,$e0,$80,$e0,$80,$e0,$40; 8
SYMBOL_GRAPHICS_S08_MULT
    byte $0,$40,$40,$40,$40,$40,$40,$40; 8
SYMBOL_GRAPHICS_S09_MULT
    byte $0,$40,$40,$0,$40,$40,$40,$40; 8
SYMBOL_GRAPHICS_S0A_MULT
    byte $0,$40,$0,$40,$60,$20,$a0,$e0; 8
SYMBOL_GRAPHICS_S0B_MULT
    byte $0,$0,$0,$0,$a0,$a0,$40,$80; 8
SYMBOL_GRAPHICS_S0C_MULT
    byte $0,$40,$40,$0,$a0,$a0,$40,$80; 8
SYMBOL_GRAPHICS_S0D_MULT
    byte $0,$a0,$a0,$0,$a0,$a0,$40,$80; 8
SYMBOL_GRAPHICS_S0E_MULT
    byte $0,$e0,$e0,$0,$a0,$a0,$40,$80; 8
SYMBOL_GRAPHICS_S0F_A0
    byte $0,$70,$88,$88,$78,$8,$88,$70; 8
SYMBOL_GRAPHICS_S10_A1
    byte $0,$f0,$88,$88,$88,$f0,$80,$80; 8
SYMBOL_GRAPHICS_S11_A2
    byte $0,$70,$88,$80,$80,$80,$88,$70; 8
SYMBOL_GRAPHICS_S12_A3
    byte $0,$78,$88,$88,$88,$78,$8,$8; 8
SYMBOL_GRAPHICS_S13_ZERO
    byte $0,$40,$a0,$a0,$a0,$a0,$a0,$40; 8
SYMBOL_GRAPHICS_S14_ONE
    byte $0,$e0,$40,$40,$40,$40,$40,$c0; 8
SYMBOL_GRAPHICS_S15_TWO
    byte $0,$e0,$80,$80,$e0,$20,$20,$e0; 8
SYMBOL_GRAPHICS_S16_MULT
SYMBOL_GRAPHICS_S17_MULT
SYMBOL_GRAPHICS_S18_MULT
SYMBOL_GRAPHICS_S19_MULT
SYMBOL_GRAPHICS_S1A_MULT
SYMBOL_GRAPHICS_S1B_MULT
SYMBOL_GRAPHICS_S1C_MULT
SYMBOL_GRAPHICS_S1D_MULT
SYMBOL_GRAPHICS_S1E_MULT
SYMBOL_GRAPHICS_S1F_MULT


; ----------------------------------
; symbol graphics lookup 
; 64 bytes starts at upper half of page
; this aligns with symbol indexes 
    
    ORG $FFC0

LOOKUP_SYMBOL_GRAPHICS = $FF00
SYMBOL_GRAPHICS_LOOKUP_TABLE
    byte #<SYMBOL_GRAPHICS_S00_MULT
    byte #<SYMBOL_GRAPHICS_S01_MULT
    byte #<SYMBOL_GRAPHICS_S02_MULT
    byte #<SYMBOL_GRAPHICS_S03_MULT
    byte #<SYMBOL_GRAPHICS_S04_MULT
    byte #<SYMBOL_GRAPHICS_S05_MULT
    byte #<SYMBOL_GRAPHICS_S06_MULT
    byte #<SYMBOL_GRAPHICS_S07_MULT
    byte #<SYMBOL_GRAPHICS_S08_MULT
    byte #<SYMBOL_GRAPHICS_S09_MULT
    byte #<SYMBOL_GRAPHICS_S0A_MULT
    byte #<SYMBOL_GRAPHICS_S0B_MULT
    byte #<SYMBOL_GRAPHICS_S0C_MULT
    byte #<SYMBOL_GRAPHICS_S0D_MULT
    byte #<SYMBOL_GRAPHICS_S0E_MULT
    byte #<SYMBOL_GRAPHICS_S0F_A0
    byte #<SYMBOL_GRAPHICS_S10_A1
    byte #<SYMBOL_GRAPHICS_S11_A2
    byte #<SYMBOL_GRAPHICS_S12_A3
    byte #<SYMBOL_GRAPHICS_S13_ZERO
    byte #<SYMBOL_GRAPHICS_S14_ONE
    byte #<SYMBOL_GRAPHICS_S15_TWO
    byte #<SYMBOL_GRAPHICS_S16_MULT
    byte #<SYMBOL_GRAPHICS_S17_MULT
    byte #<SYMBOL_GRAPHICS_S18_MULT
    byte #<SYMBOL_GRAPHICS_S19_MULT
    byte #<SYMBOL_GRAPHICS_S1A_MULT
    byte #<SYMBOL_GRAPHICS_S1B_MULT
    byte #<SYMBOL_GRAPHICS_S1C_MULT
    byte #<SYMBOL_GRAPHICS_S1D_MULT
    byte #<SYMBOL_GRAPHICS_S1E_MULT
    byte #<SYMBOL_GRAPHICS_S1F_MULT

;-----------------------------------------------------------------------------------
; the CPU reset vectors

    ORG $FFFA

    .word Reset          ; NMI
    .word Reset          ; RESET
    .word Reset          ; IRQ

    END
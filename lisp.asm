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

FLKU_SIZE = 4
CELL_SIZE = 2
HEAP_CELLS = 32
HEAP_SIZE = HEAP_CELLS * CELL_SIZE
HEAP_PTR  = $80

; ----------------------------------
; variables

  SEG.U variables

    ORG $80

; 32 cell heap
heap               ds HEAP_SIZE 
; heap pointers to user defined symbols
flookup            ds FLKU_SIZE
; pointer to free part of the heap
free               ds 1
; repl var
; 00xxxxx0 = read  
; 10xxxxx0 = eval 
repl               ds 1
; output number
output             ds CELL_SIZE
; scratchpad for all kernel routines and stack
workspace          ds 24

; ----------------------------------
; code

  SEG
    ORG $F000

Reset
CleanStart
    ; do the clean start macro
            CLEAN_START

    ; bootstrap heap
            ldx #(HEAP_SIZE - 2)
        _bootstrap_heap_loop
            ldy #HEAP_PTR
            lda #HEAP_PTR + 2
            clc
            sty heap,x
            sta heap + 1,x
            adc #2
            dex
            dex
            bpl _bootstrap_heap_loop

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

            inc frame ; new frame

    ; check reset switches
            lda #$01
            bit SWCHB
            bne _end_switches
            jmp CleanStart
_end_switches


;---------------------
; end vblank

            jsr waitOnVBlank ; SL 34
            sta WSYNC ; SL 35
            lda #1
            sta CTRLPF ; reflect playfield
            lda #LOGO_COLOR
            sta COLUPF


            ; OK
            ldx #HEADER_HEIGHT
header_loop
            sta WSYNC
            dex
            bpl header_loop

            ; PROMPT
            ; draw cell graph
            ; highlight cursor
            lda repl
            pha
            lda #0
            pha
prompt_loop
            sta WSYNC
            pla
            tax 
            sec
._prompt_hpos_loop
            sbc #15
            bcs ._prompt_hpos_loop
            ; BUGBUG: fine pos
            sta RESP0
            sta RESP1
            sta WSYNC
            pla 
            

            ; FREEBAR
            lda free

            ; OUTPUT / MENU

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

;-----------------------------------------------------------------------------------
; the CPU reset vectors

    ORG $FFFA

    .word Reset          ; NMI
    .word Reset          ; RESET
    .word Reset          ; IRQ

    END
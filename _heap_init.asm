; dummy program
heap_init
            ldx #0
_heap_loop
            lda HEAP_ROM,x
            sta #heap,x
            inx
            cpx #HEAP_ROM_END
            bmi _heap_loop

            ; set free cell list
            txa
            clc
            adc #heap
            sta free
            lda #%10000000
            sta repl
            rts

HEAP_ROM
            byte %11000010,%10000010 ;0
            byte %11100001,%10000100 ;2
            byte %11100010,%00000000 ;4
HEAP_ROM_END = . - HEAP_ROM

;   ; dummy program
; heap_init
;             ldx #0
; _heap_loop
;             lda HEAP_ROM,x
;             sta #heap,x
;             inx
;             cpx #HEAP_ROM_END
;             bmi _heap_loop
;
;             ; set free cell list
;             txa
;             clc
;             lda #%10000000
;             sta repl
;             lda #%10000110
;             sta f0
;             lda #%10001100
;             sta f1
;             lda #%10010100
;             sta f2
;             rts
;
; HEAP_ROM
;             byte %11000010,%10000010 ;0
;             byte %11100001,%10000100 ;2
;             byte %11100010,%00000000 ;4
;             byte %11000001,%10001000 ;6
;             byte %11101010,%10001010 ;8
;             byte %11101010,%00000000 ;10
;             byte %11010010,%10001110 ;12
;             byte %11100001,%10010000 ;14
;             byte %11100000,%10010010 ;16
;             byte %11101010,%00000000 ;18
;             byte %11001100,%10010110 ;20
;             byte %10011000,%10011110 ;22
;             byte %11000110,%10011010 ;24
;             byte %11101100,%10011100 ;26
;             byte %11100000,%00000000 ;28
;             byte %11101011,%10100000 ;30
;             byte %10100010,%00000000 ;32
;             byte %11010010,%10100100 ;34
;             byte %10100110,%10101100 ;36
;             byte %11000010,%10101000 ;38
;             byte %11101010,%10101010 ;40
;             byte %11101011,%00000000 ;42
;             byte %11101010,%10101110 ;44
;             byte %10110000,%00000000 ;46
;             byte %11000011,%10110010 ;48
;             byte %11101100,%10110100 ;50
;             byte %11100001,%00000000 ;52
; HEAP_ROM_END = . - HEAP_ROM
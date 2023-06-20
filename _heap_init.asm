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
            lda #%10000100
            sta f0
            lda #%10001100
            sta f1
            rts

HEAP_ROM
            byte %11001100,%10000010 ;0
            byte %11010110,%00000000 ;2
            byte %11001101,%10000110 ;4
            byte %11010101,%10001000 ;6
            byte %11010100,%10001010 ;8
            byte %11010000,%00000000 ;10
            byte %11001011,%10001110 ;12
            byte %10010000,%10010110 ;14
            byte %11000101,%10010010 ;16
            byte %11010010,%10010100 ;18
            byte %11010100,%00000000 ;20
            byte %11010001,%10011000 ;22
            byte %10011010,%00000000 ;24
            byte %11001101,%10011100 ;26
            byte %10011110,%10100100 ;28
            byte %11000010,%10100000 ;30
            byte %11010000,%10100010 ;32
            byte %11010001,%00000000 ;34
            byte %11010000,%10100110 ;36
            byte %10101000,%00000000 ;38
            byte %11000011,%10101010 ;40
            byte %11010010,%10101100 ;42
            byte %11010101,%00000000 ;44
HEAP_ROM_END = . - HEAP_ROM
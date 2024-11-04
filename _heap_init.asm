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
  ; dummy program
            ldx #0
            ;
            ;(simple)
            ;
            ;0
            lda #%11000001
            sta heap,x
            inx
            lda #%10000010
            sta heap,x
            inx
            ;2
            lda #%11010100
            sta heap,x
            inx
            lda #%10000100
            sta heap,x
            inx
            ;4
            lda #%11010101
            sta heap,x
            inx
            lda #%00000000
            sta heap,x
            inx


            ; ;
            ; ;(average x y)
            ; ;
            ; lda #%11000011
            ; sta heap,x
            ; inx
            ; lda #%10000010
            ; sta heap,x
            ; inx
            ; lda #%10000100
            ; sta heap,x
            ; inx
            ; lda #%10001010
            ; sta heap,x
            ; inx
            ; lda #%11000001
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
            ; lda #%11010000
            ; sta heap,x
            ; inx
            ; lda #%00000000
            ; sta heap,x
            ; inx
            ; lda #%11010101
            ; sta heap,x
            ; inx
            ; lda #%00000000
            ; sta heap,x
            ; inx


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
  ; dummy program
            ldx #0

            ; ;
            ; ;(+ 1 2)
            ; ;
            ; ;0
            ; lda #%11000001
            ; sta heap,x
            ; inx
            ; lda #%10000010
            ; sta heap,x
            ; inx
            ; ;2
            ; lda #%11010100
            ; sta heap,x
            ; inx
            ; lda #%10000100
            ; sta heap,x
            ; inx
            ; ;4
            ; lda #%11010101
            ; sta heap,x
            ; inx
            ; lda #%00000000
            ; sta heap,x
            ; inx

            ; (+ 1 (+ 1 (+ (+ 2 2) (+ 2 1))))
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
            lda #%10000110
            sta heap,x
            inx
            lda #%00000000
            sta heap,x
            inx
            ;6
            lda #%11000001
            sta heap,x
            inx
            lda #%10001000
            sta heap,x
            inx
            ;8
            lda #%11010100
            sta heap,x
            inx
            lda #%10001010
            sta heap,x
            inx
            ;10
            lda #%10001100
            sta heap,x
            inx
            lda #%00000000
            sta heap,x
            inx
            ;12
            lda #%11000001
            sta heap,x
            inx
            lda #%10001110
            sta heap,x
            inx
            ;14
            lda #%10010000
            sta heap,x
            inx
            lda #%10010110
            sta heap,x
            inx
            ;16
            lda #%11000001
            sta heap,x
            inx
            lda #%10010010
            sta heap,x
            inx
            ;18
            lda #%11010101
            sta heap,x
            inx
            lda #%10010100
            sta heap,x
            inx
            ;20
            lda #%11010101
            sta heap,x
            inx
            lda #%00000000
            sta heap,x
            inx
            ;22
            lda #%10011000
            sta heap,x
            inx
            lda #%00000000
            sta heap,x
            inx
            ;24
            lda #%11000001
            sta heap,x
            inx
            lda #%10011010
            sta heap,x
            inx
            ;26
            lda #%11010101
            sta heap,x
            inx
            lda #%10011100
            sta heap,x
            inx
            ;28
            lda #%11010100
            sta heap,x
            inx
            lda #%00000000
            sta heap,x
            inx

            ; ; (/ (+ 1 2) 2)
            ; ;0
            ; lda #%11000011
            ; sta heap,x
            ; inx
            ; lda #%10000010
            ; sta heap,x
            ; inx
            ; ;2
            ; lda #%10000100
            ; sta heap,x
            ; inx
            ; lda #%10001010
            ; sta heap,x
            ; inx
            ; ;4
            ; lda #%11000001
            ; sta heap,x
            ; inx
            ; lda #%10000110
            ; sta heap,x
            ; inx
            ; ;6
            ; lda #%11010100
            ; sta heap,x
            ; inx
            ; lda #%10001000
            ; sta heap,x
            ; inx
            ; ;8
            ; lda #%11010101
            ; sta heap,x
            ; inx
            ; lda #%00000000
            ; sta heap,x
            ; inx
            ; ;10
            ; lda #%11010101
            ; sta heap,x
            ; inx
            ; lda #%00000000
            ; sta heap,x
            ; inx

    ; set free cell list
            lda #%10010010            
            sta free
            lda #%10000000            
            sta repl

    
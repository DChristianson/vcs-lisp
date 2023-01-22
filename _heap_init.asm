  ; dummy program
            ldx #heap

            ;
            ;(fib-iter a b count)
            ;
            ;0
            lda #%11001010
            sta #0,x
            inx
            lda #%10000010
            sta #0,x
            inx
            ;2
            lda #%10000100
            sta #0,x
            inx
            lda #%10001010
            sta #0,x
            inx
            ;4
            lda #%11000100
            sta #0,x
            inx
            lda #%10000110
            sta #0,x
            inx
            ;6
            lda #%11010001
            sta #0,x
            inx
            lda #%10001000
            sta #0,x
            inx
            ;8
            lda #%11010011
            sta #0,x
            inx
            lda #%00000000
            sta #0,x
            inx
            ;10
            lda #%11010000
            sta #0,x
            inx
            lda #%10001100
            sta #0,x
            inx
            ;12
            lda #%10001110
            sta #0,x
            inx
            lda #%00000000
            sta #0,x
            inx
            ;14
            lda #%11001011
            sta #0,x
            inx
            lda #%10010000
            sta #0,x
            inx
            ;16
            lda #%10010010
            sta #0,x
            inx
            lda #%10011000
            sta #0,x
            inx
            ;18
            lda #%11000001
            sta #0,x
            inx
            lda #%10010100
            sta #0,x
            inx
            ;20
            lda #%11001111
            sta #0,x
            inx
            lda #%10010110
            sta #0,x
            inx
            ;22
            lda #%11010000
            sta #0,x
            inx
            lda #%00000000
            sta #0,x
            inx
            ;24
            lda #%11001111
            sta #0,x
            inx
            lda #%10011010
            sta #0,x
            inx
            ;26
            lda #%10011100
            sta #0,x
            inx
            lda #%00000000
            sta #0,x
            inx
            ;28
            lda #%11000010
            sta #0,x
            inx
            lda #%10011110
            sta #0,x
            inx
            ;30
            lda #%11010001
            sta #0,x
            inx
            lda #%10100000
            sta #0,x
            inx
            ;32
            lda #%11010100
            sta #0,x
            inx
            lda #%00000000
            sta #0,x
            inx


            ;
            ;(fib-iter 1 0 (+ 2 2))
            ;
            ;34
            lda #%11001011
            sta #0,x
            inx
            lda #%10100100
            sta #0,x
            inx
            ;36
            lda #%11010100
            sta #0,x
            inx
            lda #%10100110
            sta #0,x
            inx
            ;38
            lda #%11010011
            sta #0,x
            inx
            lda #%10101000
            sta #0,x
            inx
            ;40
            lda #%10101010
            sta #0,x
            inx
            lda #%00000000
            sta #0,x
            inx
            ;42
            lda #%11000001
            sta #0,x
            inx
            lda #%10101100
            sta #0,x
            inx
            ;44
            lda #%11010101
            sta #0,x
            inx
            lda #%10101110
            sta #0,x
            inx
            ;46
            lda #%11010101
            sta #0,x
            inx
            lda #%00000000
            sta #0,x
            inx

            ; ;
            ; ;(define (square x) (* x x))
            ; ;
            ; ;0
            ; lda #%11000000
            ; sta #0,x
            ; inx
            ; lda #%10000010
            ; sta #0,x
            ; inx
            ; ;2
            ; lda #%11001111
            ; sta #0,x
            ; inx
            ; lda #%10000100
            ; sta #0,x
            ; inx
            ; ;4
            ; lda #%11001111
            ; sta #0,x
            ; inx
            ; lda #%00000000
            ; sta #0,x
            ; inx

            ; ;
            ; ;(square x)
            ; ;
            ; ;6
            ; lda #%11001011
            ; sta #0,x
            ; inx
            ; lda #%10001000
            ; sta #0,x
            ; inx
            ; ;8
            ; lda #%11010101
            ; sta #0,x
            ; inx
            ; lda #%00000000
            ; sta #0,x
            ; inx

            ; ;
            ; ;(+ 1 2)
            ; ;
            ; ;0
            ; lda #%11000001
            ; sta #0,x
            ; inx
            ; lda #%10000010
            ; sta #0,x
            ; inx
            ; ;2
            ; lda #%11010100
            ; sta #0,x
            ; inx
            ; lda #%10000100
            ; sta #0,x
            ; inx
            ; ;4
            ; lda #%11010101
            ; sta #0,x
            ; inx
            ; lda #%00000000
            ; sta #0,x
            ; inx

            ; ; (+ 1 (+ 1 (+ (+ 2 2) (+ 2 1))))
            ; ;0
            ; lda #%11000001
            ; sta #0,x
            ; inx
            ; lda #%10000010
            ; sta #0,x
            ; inx
            ; ;2
            ; lda #%11010100
            ; sta #0,x
            ; inx
            ; lda #%10000100
            ; sta #0,x
            ; inx
            ; ;4
            ; lda #%10000110
            ; sta #0,x
            ; inx
            ; lda #%00000000
            ; sta #0,x
            ; inx
            ; ;6
            ; lda #%11000001
            ; sta #0,x
            ; inx
            ; lda #%10001000
            ; sta #0,x
            ; inx
            ; ;8
            ; lda #%11010100
            ; sta #0,x
            ; inx
            ; lda #%10001010
            ; sta #0,x
            ; inx
            ; ;10
            ; lda #%10001100
            ; sta #0,x
            ; inx
            ; lda #%00000000
            ; sta #0,x
            ; inx
            ; ;12
            ; lda #%11000001
            ; sta #0,x
            ; inx
            ; lda #%10001110
            ; sta #0,x
            ; inx
            ; ;14
            ; lda #%10010000
            ; sta #0,x
            ; inx
            ; lda #%10010110
            ; sta #0,x
            ; inx
            ; ;16
            ; lda #%11000001
            ; sta #0,x
            ; inx
            ; lda #%10010010
            ; sta #0,x
            ; inx
            ; ;18
            ; lda #%11010101
            ; sta #0,x
            ; inx
            ; lda #%10010100
            ; sta #0,x
            ; inx
            ; ;20
            ; lda #%11010101
            ; sta #0,x
            ; inx
            ; lda #%00000000
            ; sta #0,x
            ; inx
            ; ;22
            ; lda #%10011000
            ; sta #0,x
            ; inx
            ; lda #%00000000
            ; sta #0,x
            ; inx
            ; ;24
            ; lda #%11000001
            ; sta #0,x
            ; inx
            ; lda #%10011010
            ; sta #0,x
            ; inx
            ; ;26
            ; lda #%11010101
            ; sta #0,x
            ; inx
            ; lda #%10011100
            ; sta #0,x
            ; inx
            ; ;28
            ; lda #%11010100
            ; sta #0,x
            ; inx
            ; lda #%00000000
            ; sta #0,x
            ; inx

            ; ; (/ (+ 1 2) 2)
            ; ;0
            ; lda #%11000011
            ; sta #0,x
            ; inx
            ; lda #%10000010
            ; sta #0,x
            ; inx
            ; ;2
            ; lda #%10000100
            ; sta #0,x
            ; inx
            ; lda #%10001010
            ; sta #0,x
            ; inx
            ; ;4
            ; lda #%11000001
            ; sta #0,x
            ; inx
            ; lda #%10000110
            ; sta #0,x
            ; inx
            ; ;6
            ; lda #%11010100
            ; sta #0,x
            ; inx
            ; lda #%10001000
            ; sta #0,x
            ; inx
            ; ;8
            ; lda #%11010101
            ; sta #0,x
            ; inx
            ; lda #%00000000
            ; sta #0,x
            ; inx
            ; ;10
            ; lda #%11010101
            ; sta #0,x
            ; inx
            ; lda #%00000000
            ; sta #0,x
            ; inx

    ; set free cell list
            stx free
            lda #%10000000            
            sta f0
            lda #%10100010
            sta repl

    
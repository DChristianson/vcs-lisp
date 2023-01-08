
;
; 
; 8 byte machine states
; 8 byte kernel work space
; 16 byte repl
; 64 byte heap
; 32 byte stack
; static symbol table
; static numeric constants table
; 
; Borrowing from PicoLisp
; a cell is 2 bytes wide 
; each cell is either a pair or a number
; each pair half is a reference
; a reference can address 
;    a heap cell (there are 32 heap cells)
;    a rom cell (there are 32 rom cells)
;    an embedded small number
; a number is a 15 bit precision float
;    
; there are 32 heap cells
; there are 64 symbols
; pair representation:
;   1rxxxxxs 1rxxxxxs
;   10xxxxx0 - heap reference
;   11xxxxxx - symbol
;   0_______ - nil
;
; number representation: 
;   0smmmmxx xxxxxxxx - fp number 

; car 
;   1 bit ref marker
;   2 bits type 00 = stack ptr
;   2 bits type 01 = constant
;   2 bits type 10 = ram ptr
;   2 bits type 11 = rom ptr
;   5 bits address (0-32)
; cdr
;   1 bit ref marker
;   2 bits type 10 = ptr
;   5 bits address (0-32)
;   6 bits address (0-)
; heap 64 bytes / 32 cells
;
;
; fixed symbol table
;  function vars
;   l0 l1 l2 l3 
;  numeric vars
;   n x y a b 
;  if
;  =
;  + 
;  -
;  *
;  /
;  >
;  <


(define (square x)
 (* x x))

(define (fib n)
  (fib-iter 1 0 n))
  (define (fib-iter a b count)
  (if (= count 0)
       b
      (fib-iter (+ a b) a (- count 1))))

(define (sqrt-iter guess x)
   (if (good-enough? guess x)
       guess
        (sqrt-iter (improve guess x) x)))
(define (improve guess x)
        (average guess (/ x guess)))
(define (average x y)
         (/ (+ x y) 2))
(define (good-enough? guess x)
        (< (abs (- (square guess) x)) 0.001))
(define (sqrt x)
    (sqrt-iter 1.0 x))

(define (factorial n)
        (fact-iter 1 1 n))

(define (fact-iter product counter max-count)
        (if (> counter max-count)
            product
            (fact-iter (* counter product)
                       (+ counter 1)
                        max-count)))
square
*    1
  x  2 
  x  3
          
11000001 10000010
11000010 10000100
11000010 00000000

average
/      1  
  +    2
    x  3
    y  4
  2    5

11000001 10000010
10000110 10000100
11000010 00000000
11001000 10001000
11000010 10001010
11000011 00000000


improve
average  1
   x     2
   /     3
     y   4
     x   5

[?]              0
   [>]           1
      [b][c]     23
   [a]           4
   [iter]        5
       [*]       6
          [b c]  78
       [+]       9
          [b 1]  10 11
       a         12
          

Goals
 Joystick compatible
 Repl Fib(n) from SICP
 Repl Sqrt(x) from SICP
 Play Music 
 Change bkfg colors
 Change sprite
 Be able to ~play the pong game from AB
 See https://huguesjohnson.com/programming/atari-2600-basic/ 
 See sample programs in Atari Basic manual

DONE
  - basic eval
  - stubbed out math functions
  - bcd conversion function
  - tail recursion optimization
  - display tester 1 (all positions indent with separators)
  - display tester 2 (symmetric indent)
    - create display plan in vblank to allow closer spacing of cells
    - encode indent level + display type
  - tester 3 (cursor movement dynamics)
    - bracket current line
    - scrolling
    - joystick to move cursor around
    - line highlight
  - tester 4 (editor)
    - display cursor to point at current cell
    - display cursor stays in bounds of cells
    - display cursor can be at end of a list
  - virtual keyboard 1
    - button press opens keyboard
    - with open keyboard movement selects new value
    - keyboard opens on curr cell value 
    - scrolls through appropriate values
    - with press display cursor locates curr cell and replaces
    - add new cell 
    - delete cell
  - game modes 1
      - scratch
ALPHA
  - demo 1
      - start with blank program, make + 1 2
  - menu 1
      - function menu displayed on screen
  - controls 1
      - moving past last line goes to menu
      - moving above first line goes to menu
      - eval when button push in menu
  - demo 2
      - eval demo program + 1 2
  - controls 2
      - function assignment when push in menu
      - game mode switch when push in menu
  - library 1
      - beeps
      - actual float math
  - demo 3
      - fib program
      - play beep
BETA
  - game modes 2
      - silly goose (number sequence)
      - towers of hanoi
      - paddle pong
  - library 2
      - modulo function
      - music functions
  - virtual keyboard 2
      - number edit
  - virtual keyboard 3
      - cancel move undoes changes
      - other gestures move through list
  - dev support
     - some way to do unit tests?
  - eval graphics kernel
     - graphics zone
     - stack / heap / free accumulator
     - song that plays during eval
SPRINKLES
  - interpreter
     - safeties against stack overflow
  - font
     - tune font / symbols
  - title screen
     - logo 
     - shoutouts
  - help / attract mode 1 
      - occasional blinkyness of controls
  - virtual keyboard 3
      - empty at first
      - blinky cursor when in repl
  - display 4 
      - show numbers
BONUS 
  - bonus game mode
     - matching shapes (boolean logic)
     - mouse maze
     - tictactoe?
     - mastermind?
     - ant


Shoutouts
  sicp authors, basic author, source contribs, atari age forums, picolisp, scheme
Fundamentals
  Memory divides into cells of 2 bytes
  Cells are either reference pairs or numbers
  References can refer to heap or to symtab

References
https://dwheeler.com/6502/
https://huguesjohnson.com/programming/atari-2600-basic/ 
http://web.archive.org/web/20100131151915/http://www.ip9.org/munro/skimp/
https://www.cs.unm.edu/~williams/cs491/three-imp.pdf

Implementation

= Data structures

```
       Cell
        |
     --------
    |        | 
  Pair     Number
```
Borrowing from PicoLisp 
The fundamental data structure is the cell. A cell can represent
either a number or a pair. Pairs have a head and a tail, with the
head containing either a symbol, a reference to a number, or a 
reference to another pair. The tail can either be a reference to 
another pair or the null reference.

a number can be a 15 bit precision float or a 3 digit binary coded decimal

cell pair representation:
  1rxxxxxs 1rxxxxxs
  10xxxxx0 - heap reference (5 bits - 32 cells in total)
  11xxxxxx - symbol (6 bits - 64 symbols in total)
  00000000 - null pointer

number representation: 
  0smmmmxx xxxxxxxx  - 15 bit binary floating point  
  0smmdddd dddd dddd - float decimal


= Memory organization

== The heap

64 byte heap

== Program registers

f0...f3 - there are four user assignable references
        - each one points to a location in the heap containing a
        - pair expression or possibly a number reference
repl    - this points to the head of the expression that the user is actively editing in repl mode
        - in eval mode this points to the expression that is being executed
current_cell - this points to the cell that the user is actively editing in repl mode
prev_cell - prev_cell points to first "upstream" pair from the one the user is actively editing in repl mode

== The symbol table

fixed symbol table
 function vars
  f0 f1 f2 f3 
 arg vars
  a0 a1 a2 a3
 if
 =
 + 
 -
 *
 /
 >
 <

 30/27
 33/30
 35/32
 49/46
 46/43

== The stack

to eval
 - pull from the stack 
   - this is where to write
   - push to address register
 - pull from stack
   - this is what to write
   - symbol: mask, shift, a->x, get value, write, get value + 1, write + 1
   - 

Heap based model
a: the accumulator,
x: the next expression,
e: the current environment,
r: the current value rib, and
s: the current stack


(halt) halts the virtual machine. The value in the accumulator is the result of
the computation.
(refer var x ) finds the value of the variable var in the current environment, and
places this value into the accumulator and sets the next expression to x.
(constant obj x ) places obj into the the accumulator and sets the next expression
to x.
(close vars body x ) creates a closure from body, vars and the current environment,
places the closure into the accumulator, and sets the next expression to x.
(test then else) tests the accumulator and if the accumulator is nonnull (that is,
the test returned true), sets the next expression to then. Otherwise test sets the
next expression to else.
(assign var x) changes the current environment binding for the variable var to
the value in the accumulator and sets the next expression to x.
(conti x) creates a continuation from the current stack, places this continuation
in the accumulator, and sets the next expression to x.
(nuate s var) restores s to be the current stack, sets the accumulator to the value
of var in the current environment, and sets the next expression to (return) (see
below).
(frame x ret) creates a new frame from the current environment, the current rib,
and ret as the next expression, adds this frame to the current stack, sets the current
rib to the empty list, and sets the next expression to x.
(argument x) adds the value in the accumulator to the current rib and sets the
next expression to x.
(apply) applies the closure in the accumulator to the list of values in the current
rib. Precisely, this instruction extends the closure’s environment with the closure’s
variable list and the current rib, sets the current environment to this new environment, sets the current rib to the empty list, and sets the next expression to the
closure’s body.
(return) removes the first frame from the stack and resets the current environment, the current rib, the next expression, and the current stack.


Stack based model

a: the accumulator,
x: the next expression,
e: the current environment
s: the current stack

next_outer_scope = static link (pushed last) (register e)
first argument
.
.
.
last argument
next_x           = Dybvig's next expression to evaluate (register x)
prev_frame       = top of stack of caller, Dybvig's dynamic link (pushed first)

stack mofe 


(halt) behaves the same.
(refer var x) follows static links on the stack instead of links in a heap-allocated
environment. (It also uses an index operation in place of a loop once it finds the
appropriate frame.)
(constant obj x) behaves the same.
(closure vars body x) creates a functional rather than a closure.
(test then else) behaves the same.
(assign var x ) follows static links on the stack instead of links in a heap-allocated
environment.
(conti x ) not supported.
(nuate s var) not supported.
(frame x ret) starts a new frame by pushing the dynamic link (the current frame
pointer) and next expression ret. The virtual machine of the preceding chapter
built a call frame in the heap.
(argument x ) pushes the argument on the stack instead of adding an element to
the current rib.
(apply) behaves similarly, but pushes the static link from the functional onto the
stack rather than building onto it by adding a rib.
(return n) takes an additional argument, n, that determines the number of elements it removes from the stack in addition to the saved dynamic link and next
expression.


registers
a: the accumulator
x: expression           - car of current cell
t: tail expression      - cdr of current cell
e: env                  - environment (args)

stack registers
h: head expression      - on stack, head of the current list
f: frame pointer        - previous frame
p: previous tail        - f(n-1).t


s: the current stack

frame structure:
  
        x
f(n+1): f(n)
        t
        a30 a31
        a20 a21
        a10 a11
        a00 a01
f(n):   h
        f(n-1)

eval `(+ 1 2)
  x <- '+' ; t <- (1 2) ; f <- 0
    --> call '+' -->
  s <- ('+') ; x <- '1' ; t <- (2) ; f <- -1
    --> lookup '1' -->
  s <- (#1 '+')  ; x <- '2' ; t <- () ; f <- -1
    --> lookup '2' -->
  s <- (#2 #1 '+') ; x <- () ; f <- -1
    --> apply -1 -->
  s <- () ; a <- #3 ; f <- 0
    --> return 

eval `(/ (+ 1 2) 2)
  x <- '/'; t <- ((+ 1 2) 2) ; f <- 0
    --> call '/' -->
  s <- ('/') ; x <- '(+ 1 2) ; t <- (2) ; f <- -1
    --> eval '(+ 1 2) -->
  s <- (-1 (2) '/') ; x <- '+' ; t <- (1 2) ; f <- -1
    --> call '+' -->
  s <- ('+' -1 (2) '/') ; x <- '1' ; f <- -4
   --> lookup '1' -->
  s <- (#1 '+' -1 (2) '/')  ; x <- '2' ; t <- () ; f <- -4
    --> lookup '2' -->
  s <- (#2 #1 '+' -1 (2) '/') ; x <- () ; f <- -4
    --> apply -4 -->
  s <- ('/') ; a <- #3 ; x <- '2'; t <- () ; f <- -1
    --> argument -->
  s <- (#3 '/') ; x <- '2'; t <- () ; f <- -1
    --> lookup '2' -->
  s <- (#2 #3 '/') ; x <- (); f <- -1
    --> apply -1 -->
  s <- () ; a <- #1.5; f <- 0
    --> return 

eval `(- 2 (+ 1 2))
eval `(- 2 (+ 1 (* 3 4))))


eval `(square 2)
  x <- 'square' ; t <- (2) ; f <- 0
    --> call 'square' -->
  s <- ('square') ; x <- '2' ; t <- () ; f <- -1
    --> lookup '2' -->
  s <- (#2 'square')  ; x <- () ; t <- () ; f <- -1
    --> apply 'square' -->
  s <- (-1 () #2 'square') ; x <- '*'; t <- (x  x) ; f <- -5
    --> call '*' -->
  s <- ('*' -1 () #2 'square') ; x <- 'x', ; t <- (x) ; f <- -5 ; e <- -2
    --> lookup 'x' -->
  s <- (#2 '*' -1 'r' #2 'square') ; x <- 'x', ; t <- () ; f <- -5 ; e <- -2
    --> lookup 'x' -->
  s <- (#2 #2 '*' -1 'r' #2 'square') ; x <- (), ; t <- () ; f <- -5 ; e <- -2
    --> apply -5 -->
  s <- (-1 () #2 'return') ; a <- #4 ; x <- (), ; t <- () ; f <- -5 ; e <- -2



= Sample programs

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
          

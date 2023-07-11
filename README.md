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
  - demo 1
      - start with blank program, make + 1 2
  - game modes 1
      - scratch
  - controls 1
      - moving past last line goes to menu
      - moving above first line goes to menu
      - eval when button push in menu
  - demo 2
      - eval demo program + 1 2
  - menu 1
      - function menu displayed on screen
  - menu 2
      - function assignment when push in menu
  - demo 3
      - fib program
      - eval demo program + 1 99
  - bugs
      - blank program is weird
      - binary to decimal conversion is slow, blows out display
      - adding removing numbers at end messes up program (probably free memory issues)
      - beep goes too fast (need to take a beat after we eval)
      - suspect if the repl begins with an if, we don't evaluate the test properly
      - in general a const in an if hasn't been tested
      - if try to delete and recreate fib, crashes (probably free memory issue)
  - display 4 
      - show numbers
  - virtual keyboard 2
      - number edit
      - up to go back
      - number edit shouldn't return right away
      - number cursor is at digit being edited
  - library 1
      - beep (as continuation)
      - multiply (as continuation)
  - demo 5
      - play beep
ALPHA
  - library 1
      - all functions working
  - virtual keyboard 3
      - can only see symbols you can use
  - display 4 
      - screen layout is sloppy
      - menus are messed up
BUGS
  - code
    - complex program takes too long to analyze in vblank
BETA
  - controls 2
      - game mode switch when push in menu
  - game modes 2
      - towers of hanoi
      - paddle pong
  - code 2
      - reduce need for extra lookups
      - no / limited numbers constants
      - bigger symbol table? 
      - compact numbers?
  - library 2
      - modulo function
      - music functions (map... or progn?)
  - dev support
     - some way to do unit tests?
  - eval graphics kernel
     - graphics zone
     - stack / heap / free accumulator
     - song that plays during eval
  - interpreter
     - show free mem
     - safeties against stack overflow
     - safety against no free mem left
SPRINKLES
  - font
     - tune font / symbols
     - null display on complex lines no box
  - title screen
     - logo 
     - shoutouts
  - help / attract mode 1 
      - occasional blinkyness of controls
  - virtual keyboard 4
      - empty at first
      - blinky cursor when in repl
      - no cell boxes on numbers 
      - cancel move undoes changes
      - too slow to scroll through keys

BONUS 
  - bonus game mode
     - silly goose (number sequence)
     - maze
     - matching shapes (boolean logic)
     - mouse maze
     - tictactoe?
     - mastermind?
     - ant
     - sqry using .. rational math?

IBM 704
40 kips 12 kiloflops
0.00635 MIPS?
12000 fp addition / subtraction per second
4000 integer multiplication / divisions per second
36 bit word
737 magnetic core unit
12 us core memory
4,096 36-bit words, the equivalent of 18,432 bytes.
733 magnetic drum reader / recorder
8192 36-bit words (36,864 8-bit bytes).
floating point
19,466 pound
MTBF - 8 hours
Sales #
$2MM


Atari 2600
September 1977
MOS 6507 @ 1.19 Mhz
0.430 MIPS at 1.000 MHz
4kb addressible ROM
128 bytes RAM
4.6 lbs
MTBF
Sales #30MM
$199

Mac IIcx
Macbook Pro
Nintendo NES
Symbolics Lisp
PiZero
Workstation
Cloud Compute





Shoutouts
  sicp authors, basic author, source contribs, atari age forums, picolisp, scheme
Fundamentals
  Memory divides into cells of 2 bytes
  Cells are either reference pairs or numbers
  References can refer to heap or to symtab
Credits
  AtariAge
  6502.org
  Atari Background Builder
  Atari Label Maker https://www.labelmaker2600.com/

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

The fundamental data structure in vcs-lisp is the cell. This concept borrows directly from PicoLisp although with a few differences.

 - A cell is 2 bytes wide and represents either a number or a pair. 
 - Pairs have a head (car) and tail (cdr). 
  - The head can contain either a symbol or a reference to another cell
  - The tail must be a reference to another pair or the null reference
 - Numbers are 3 digit binary coded decimals. 

Using 2 bytes for the cell is a natural choice. There are only 128 bytes of RAM available onboard the Atari 2600.At 2 bytes per cell we have a theoretical maximum of 64 addressible cells. 
 
Using BCD for numbers saves a lot of code when it comes to editing and displaying numbers. 
- Displaying character graphics on the Atari 2600 requires specialized code, so having to deal with only three digits allows us to simplify the display kernel dramatically. 
- Avoiding expensive conversions that have to be done to convert to/from binary formats further simplifies the code and saves significant time and space

== Cell and Symbol References

```
  10xxxxx0 - cell reference (5 significant bits - 32 cells in total)
  110xxxxx - symbol reference (5 significant bits - 32 symbols in total)
  00000000 - null pointer
```

Cell references start at hex value $80. Coincidentally, we locate the cell heap at address $80 - so that the zeropage address of a cell on the heap *is* its cell reference. 

Symbol references start at hex value $C0. Similar to how cell references line up with heap addresses, we try to manipulate the start address of data tables for symbol lookups to start at $C0.

There are some unused bits in these schemes (very wasteful...)
- We reserve the 6th bit of a cell reference to perform operations on off-heap zeropage data as if it were on heap.
- We manipulate the 0th bit of a cell reference to perform operations that reference the car of a cell as if it were the cdr (and vice versa).
- The 6th bit of symbol references is completely unused at this time.


== Numbers

```
  0000dddd dddd dddd - binary coded decimal
```


== Off-Heap Registers

The following memory locations hold the contents of the Lisp program

```
heap             ds 64 ; the heap contains all program memory, organized into 32 2-byte cells
free             ds 1  ; this points to the linked list of free cells on the heap
repl             ds 1  ; this points to an expression that we want the evaluator to execute
                       ; repl mode allows the user to edit this expression
f0...f2          ds 1  ; there are three user assignable expressions
                       ; each one points to a cell in the heap
                       ; repl mode allows the user to edit these expressions
accumulator      ds 2  ; a cell holding the result of the last expression
```


= Expression evaluation


There are a considerations here:
- Because 
Cells can either be a byte pair consisting of a head (car) and tail (There are two kinds of cells

== Evaluator  

Evaluation 

```
accumulator      ds 2 ; the result accumulator
eval_next        ds 1 ; the next action to take
                      ; if negative, it is a reference to the next expression to evaluate
                      ; if 1, then return from the current frame
                      ; if 2, then execute as a conditional test
eval_env         ds 1 ; pointer to beginning of stack for calling frame
eval_frame       ds 1 ; pointer to beginning of stack for current frame
```

accumulator a: the accumulator,
eval_next   x: the next expression,
eval_env    e: the current environment
eval_frame  s: the current stack


```
eval_next  = ...(arg2 arg3)
eval_env   = +2/+3 previous eval_next
             +1/+2 previous eval_frame
             +1    previous eval_env (optional)
eval_frame = +0    function symbol
             -1    arg0 lsb / cdr
             -2    arg0 msb / car
             -3    arg1 lsb / cdr
             -4    arg1 msb / car
SP         = ...
```

```
eval_next  = #1
eval_env   = +2  previous eval_next
             +1  previous eval_frame
eval_frame = +0  function symbol
             -1  arg0 lsb / cdr
             -2  arg0 msb / car
SP         = ...
```

```
eval_next  = #2 
eval_env   = +2  previous eval_next
             +1  previous eval_frame
eval_frame = +0  ...(arg1 arg2)
             -1  arg0 lsb / cdr
             -2  arg0 msb / car
SP         = ...
```


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
          

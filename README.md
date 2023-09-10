# LISP Programming 
Play the game on [Javatari.org](https://javatari.org/?ROM=https://github.com/DChristianson/vcs-lisp/releases/download/alpha/lisp_NTSC_20230714.bin)!

This is an Atari 2600 game from an alternate reality...

- where a [computer language](https://en.wikipedia.org/wiki/Lisp_(programming_language)) from 1960 
- has been hastily crammed onto a VCS ROM cartridge in 1977
- so you can learn to write programs of the type you find in the first chapter of a [textbook](https://en.wikipedia.org/wiki/Structure_and_Interpretation_of_Computer_Programs) first published in 1984.

<img src="https://github.com/DChristianson/vcs-lisp/blob/main/assets/lisp_NTSC_2.png" height=180></img><img src="https://github.com/DChristianson/vcs-lisp/blob/main/assets/lisp_NTSC_20230714.png" height=180></img><img src="https://github.com/DChristianson/vcs-lisp/blob/main/assets/lisp_NTSC_5.png" height=180></img>

It is *not* a competitor to [Basic Programming](https://en.wikipedia.org/wiki/BASIC_Programming) but I am definitely trying to think in terms of the feature set and capture the spirit of a "programming game"...

<img src="https://github.com/DChristianson/vcs-lisp/blob/main/assets/lisp-programming1.png" width=180></img>

## Instructions

Some explanations are in order...

The basics:

The main screen is the REPL (read-eval-print-loop). It is preloaded with an expression (+ 1 2) represented as a boxy array of cells.

- Moving the joystick up to EVAL and pressing the fire button will evaluate the expression and you will see the result
- Pressing the fire button on the +, 1, or 2 cells lets you change the function and the arguments being applied.
- Pressing the fire button on the ∴ lets you extend the expression.
- Pressing the fire button to select the +, -, *, / ... symbols will start a subexpression
- Note when you create a subexpression (or make a list longer than 5 entries)  the display will shift to display the containing expression vertically
- The 0...9 symbols can be used for small numbers, if you press the # symbol you can input any number up to 999
 
The fun (as in functional) part:

If you move up to "EVAL" and press right you will cycle through various function definitions that can be called from EVAL...

- Functions can be named anything you want! As long as the name is one character long and is either a λ,Lamedh, or this funky looking f
- I hope you get the picture: there are no strings and there are 3 bytes reserved for pointers to functions. You want more? Source code forthcoming, feel free...
- Arguments to functions can be anything you want! As long as the first argument is a, the second is b...
vFor maximum fun I've loaded a few predefined functions 
vλ: starts as (* a a) - if you EVAL (λ 5) you will get 25
- Lamedh: takes one argument (a) and calls the funky f...
- funky f: this is the fibonacci function, which is a recursively defined function f(n) = f(n-1) + f(n - 2)...
--... to be specific this is the tail recursive variant - and - if you've read this far and see where we're going ---- yes this LISP has some super simple tail recursion optimization (otherwise we'd blow up the stack very quickly)

## Some Implementation Details

### Data structures

```
       Cell
        |
     --------
    |        | 
  Pair     Number
```

The fundamental data structure in vcs-lisp is the cell. 

 - A cell is 2 bytes wide and represents either a number or a pair. 
 - Pairs have a head (car) and tail (cdr). 
  - The head can contain either a symbol or a reference to another cell
  - The tail must be a reference to another pair or the null reference
 - Numbers are 3 digit binary coded decimals. 

The cell concept is borrowed directly from [PicoLisp](https://picolisp.com) but resized to live in the world of Atari 2600:

- There are only 128 bytes of RAM available onboard the Atari 2600, so using 1 byte for references is more than adequate to address every possible RAM location.
- Using BCD for numbers, and then limiting them to 3 digits saves a lot of time and space as well
 - Displaying character graphics on the Atari 2600 requires specialized code, so having to deal with only three digits allows us to simplify the display kernel dramatically. 
 - Avoiding expensive conversions that have to be done to convert to/from binary formats further simplifies the code and saves significant time and space.

### Cell and Symbol References

Each byte of a pair can contain a reference to another cell, a reference to a symbol, or the null reference.

```
  10xxxxx0 - cell reference (5 significant bits - 32 cells in total)
  11xxxxxx - symbol reference (6 significant bits - 64 symbols in total)
  00000000 - null pointer (when seen in the cell cdr, if seen in the car implies the cell is a number)
```

Cell references start at hex value $80. Coincidentally, we locate the cell heap at address $80 - so that the zeropage address of a cell on the heap *is* its cell reference. 

Symbol references start at hex value $C0. Similar to how cell references line up with heap addresses, we try to manipulate the start address of data tables for symbol lookups to start at $C0.

There are some unused bits in these schemes (very wasteful...)
- We reserve the 6th bit of a cell reference to perform operations on off-heap zeropage data as if it were on heap.
- We manipulate the 0th bit of a cell reference to perform operations that reference the car of a cell as if it were the cdr (and vice versa).

### Off-Heap Registers

The following memory locations hold the contents of the Lisp program

```
heap             ds 64 ; the heap contains all program memory, organized into 32 2-byte cells
free             ds 1  ; this points to the linked list of free cells on the heap
repl             ds 1  ; this points to an expression that we want the evaluator to execute
                       ; repl mode allows the user to edit this expression
f0...f2          ds 3  ; there are three user assignable expressions
                       ; each one points to a cell in the heap
                       ; repl mode allows the user to edit these expressions
accumulator      ds 2  ; a cell holding the result of the last expression
```

### Stack Execution 
Expression evaluation relies entirely on the stack, using the following memory locations:

```

accumulator      ds 2 ; the result accumulator
eval_next        ds 1 ; the next action to take
                      ; if negative, it is a reference to the next expression to evaluate
                      ; if 1, then return from the current frame
                      ; if 2, then execute as a conditional test
eval_env         ds 1 ; pointer to beginning of stack for calling frame
eval_frame       ds 1 ; pointer to beginning of stack for current frame```


Example: evaluating function call arguments
--------------------------------------------------
eval_next  = pointer to args that haven't been evaluated ...(arg2 arg3)
eval_env   = FP+2/+3 previous eval_next
             FP+1/+2 previous eval_frame
             FP+1    previous eval_env (optional)
eval_frame = FP+0    function symbol
             FP-1    arg0 lsb / cdr
             FP-2    arg0 msb / car
             FP-3    arg1 lsb / cdr
             FP-4    arg1 msb / car
        SP = FP-5    ... top of stack

Example: evaluating a function call
--------------------------------------------------
eval_next  = #1 (return - when done, return value to calling frame)
eval_env   = FP+2  previous eval_next
             FP+1  previous eval_frame
eval_frame = FP+0  function symbol
             FP-1  arg0 lsb / cdr
             FP-2  arg0 msb / car
        SP = FP-3    ... top of stack

Example: evaluating a test (if) statement 
--------------------------------------------------
eval_next  = #2 (test - use value of first arg to choose the next arg to evaluate)
eval_env   = FP+2  previous eval_next
             FP+1  previous eval_frame
eval_frame = FP+0  ...(arg1 arg2)
             FP-1  arg0 lsb / cdr
             FP-2  arg0 msb / car
        SP = FP-3    ... top of stack

```

## References, Credits and Inspirations

This work would not be possible without the [AtariAge forums](https://www.atariage.com/forums) and all
 the tools and resources developed by the Atari 2600 homebrew community.

The original concept box art was produced with the help of [DALL-E mini](https://www.craiyon.com/), and the [Atari Label Maker](https://www.labelmaker2600.com/)

### Lisp
 - [Structure and Interpretation of Computer Programs](https://en.wikipedia.org/wiki/Structure_and_Interpretation_of_Computer_Programs) 
 - [PicoLisp](https://picolisp.com/) 
 - R. Kent Dybvig's [Three Implementation Models for Scheme](https://www.cs.unm.edu/~williams/cs491/three-imp.pdf) 
 - [uLisp](http://www.ulisp.com/)

### Atari 2600 Basic
 - [Atari 2600 Basic Programming](https://huguesjohnson.com/programming/atari-2600-basic/)
 - [Basic Programming](https://en.wikipedia.org/wiki/BASIC_Programming)

### 6502  
 - David A. Wheeler's [6502 Language Implementation Approaches](https://dwheeler.com/6502/)
 - [Skimp](http://web.archive.org/web/20100131151915/http://www.ip9.org/munro/skimp/)
 - [6502.org](https6502.org)


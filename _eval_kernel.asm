;-------------------
; Eval kernel
;

eval_wait
            lda game_state
            and #$f0
            ora #GAME_STATE_EVAL_CONTINUE
            sta game_state
            jmp update_return

eval_update
            lda game_state
            and #$0f
            beq eval_start
            lsr
            bcs eval_apply
            ; continue
            rts
eval_apply
            ; BUGBUG: PROTECT: we need at least 3 bytes of stack
            jsr alloc_stack
            lda #1 ; 1 = return
            pha
            lda eval_frame
            pha
            tax
            lda eval_env
            and #$7f    ; READABILITY: notation
            pha
            stx eval_env
            lda 0,x     ; READABILITY: notation
            and #$0f    ; READABILITY: notation - this is the function #
            tax
            lda function_table,x ; deref function
            jmp eval_iter
eval_start
            ; initial entry
            lda repl
eval_iter
            ; push a new frame onto the stack
            tsx                   ; save current stack pointer to eval_frame
            stx eval_frame        ;
            tax                   ; read head of cell reference in accumulator 
            beq _eval_null
            lda HEAP_CAR_ADDR,x   ; .
            bpl _eval_number      ; branch if it's a number
            and #SYMBOL_IF + $c0
            eor #SYMBOL_IF + $c0  ; special case if we are applying test, loop, progn
            bne _eval_funcall       ; otherwise eval as funcall
_eval_test_loop_progn
            lda HEAP_CAR_ADDR,x   ; .
            lsr
            bcc _eval_no_loop
            ; BUGBUG: push criteria for repeat
            lda #$03              ; signal progn
_eval_no_loop
            and #$03
            sta eval_next         ; store 2/3 to eval_next (KLUDGE: 2= test, 3=progn ; READABILITY: notation
            ; BUGBUG: need 1 stack
            ; x references a test/progn expression
            lda HEAP_CDR_ADDR,x   ; follow cdr of test ; BUGBUG: what if empty
            tax                   ; .
            lda HEAP_CDR_ADDR,x   ; push cddr of test to be rest of args ; BUGBUG: what if empty
            pha                   ; . 
            jmp _eval_funcall_arg ;  
_eval_number
            ; BUGBUG: need 0 stack
            ; x references a number cell, a is the car
            sta accumulator_car   ; push number cell into accumulator and return
            lda HEAP_CDR_ADDR,x   ; .
            sta accumulator_cdr   ; .
_eval_null  ; BUGBUG: just returning from null
            jmp exec_frame_return ; .
_eval_funcall
            ; BUGBUG: need 1 stack
            ; x references a function call
            lda HEAP_CAR_ADDR,x   ; .
            pha                   ; push head to stack
_eval_funcall_push_args
            ; push all args to stack
            lda HEAP_CDR_ADDR,x   ; start following tail
            beq _eval_funcall_exec; if null we have a unary expression
_eval_funcall_args_loop
            tax                   ; .
            lda HEAP_CDR_ADDR,x   ; remember reference to next arg
            sta eval_next         ; . 
_eval_funcall_arg
            lda HEAP_CAR_ADDR,x   ; check head of arg cell
            cmp #$40              ; .
            bpl _eval_funcall_args_expression ; if a funcall we recurse
            ; arg is a symbol (constant or variable) reference
            and #$01f                  ; strip significant bits
            cmp #$0A                   ; check if it's a local variable BUGBUG: magic number
            bpl _eval_funcall_args_env ; read
            ; arg is a numeric constant, push to accumulator and return
            sta accumulator_lsb
            pha
            lda #0
            sta accumulator_msb
            pha
            jmp _eval_funcall_args_next
_eval_funcall_args_env
            ; evaluate a local variable (a, b, c, d...)
            ; compute relative argument offset, then load accumulator and push to stack
            sec
            sbc #SYMBOL_A0
            asl
            eor #$ff
            clc
            adc #1
            clc
            adc eval_env                ; eval_env is the parent frame in stack 
            tax
            ; BUGBUG: need 2 stack
            ; this is a short circuit from doing a frame eval
            lda #FRAME_ARG_OFFSET_LSB,x
            sta accumulator_lsb        ; BUGBUG: may not be needed?
            pha
            lda #FRAME_ARG_OFFSET_MSB,x 
            sta accumulator_msb
            pha
            jmp _eval_funcall_args_next
_eval_funcall_args_expression
            ; BUGBUG: need 2 stack
            ; a is a reference to a function call, x is the parent frame
            tay
            lda eval_next  ; push next arg to stack
            pha
            lda eval_frame ; push current frame to stack
            pha
            tya
            jmp eval_iter ; recurse
_eval_funcall_args_next
            ; proceed to next arg
            lda eval_next
            bmi _eval_funcall_args_loop ; if next is a cell ref, continue
            bne exec_frame_return       ; otherwise special form, go to return sub
_eval_funcall_exec
            ; exec frame
            ldx eval_frame
            lda 0,x
            and #$3f
            asl
            tax
            lda LOOKUP_SYMBOL_FUNCTION+1,x ; reverse jump
            pha
            lda LOOKUP_SYMBOL_FUNCTION,x
            pha
            rts

exec_frame_return
            ; called when we've made a funcall or evaluated an expression
            ; clear stack back to current frame
            ldx eval_frame
            txs 
            inx
            bne _eval_pop_frame
            ; done with eval - go back to repl
            lda #0
            sta repl_scroll
            sta repl_edit_line
            sta repl_edit_col
            lda game_state
            and #GAME_TYPE_MASK; #GAME_STATE_EDIT
            sta game_state
            jmp update_return
_eval_pop_frame
            ; pop up from recursion
            pla ; will get previous env or frame
            bmi _eval_old_env
            ora #$80 ; kludge: if val is positive, it's a saved env
            sta eval_env
            pla ; will get previous frame
_eval_old_env
            sta eval_frame
            pla ; pull next action from frame
            bmi _eval_continue_args ; if negative, eval next arg cell
            beq _eval_continue_args ; if zero, eval next arg cell (will be nil)
            ; args is 1 = return, 2 = test, 3 = progn
            lsr
            beq _eval_return
            ; evaluate test/progn expression
            ; BUGBUG: potentially we can optimize the stack here
            sta eval_next ; a should be = 1 after the lsr
            ldx eval_frame ; pull 
            txs
            lda #0,x ; get the next arg READABILITY: notation
            tax
            bcs _eval_progn
            lda accumulator_lsb
            ora accumulator_msb
            bne _eval_test_true ; assume 0 is false
_eval_test_false
            lda HEAP_CDR_ADDR,x
            tax
_eval_test_true
            jmp _eval_funcall_arg
_eval_progn
            lda HEAP_CDR_ADDR,x   ; get cddr to rest of args 
            beq _eval_test_true ; if null, we will return 
            pha                   ; else push cddr back 
            lda #3                ; we will continue
            sta eval_next
            jmp _eval_funcall_arg ;  
_eval_return
            sta eval_next ; BUGBUG may not be needed?
            jmp exec_frame_return
_eval_continue_args
            sta eval_next
            ; BUGBUG: need 2 stack
            lda accumulator_lsb
            pha
            lda accumulator_msb 
            pha
            jmp _eval_funcall_args_next

alloc_stack
            ; BUGBUG: very crude protection against stack overflow
            tsx
            cpx #STACK_DANGER_ZONE
            bmi stack_overflow
            rts

stack_overflow
            ; BUGBUG: need some kind of error display
            ; for now will pull address we were at from stack and drop in accumulator
            pla
            sta accumulator_car
            pla
            sta accumulator_cdr
            ldx #$ff ; reset stack
            txs
            stx eval_frame
            jmp exec_frame_return

FUNC_F0
FUNC_F1
FUNC_F2
            ; check for tail call when we call an user defined function
            ; we will immediately collapse the stack
            ; the function expression will be evaluated on the next vblank
            ldx eval_frame
_apply_tail_call_loop
            cpx #$ff
            beq _apply_tail_call_end_search; top of stack
            ; we need to look at the frame above us on the stack
            ; if it's marked for return we are a tail call
            ; if we are a tail call we can shrink the stack
            ; BUGBUG: if we reorder frame ... or always push static ref we can simplify this logic
            lda #1,x ; check next frame ; READABILITY: notation
            bmi _apply_tail_call_bare_frame
            lda #3,x ; get eval_next skipping env and frame; READABILITY: notation
            cmp #1; READABILITY: notation
            bne _apply_tail_call_end_search
            lda #2,x; READABILITY: notation
            jmp _apply_tail_call_found
_apply_tail_call_bare_frame
            lda #2,x ; get_eval_next skipping frame; READABILITY: notation
            cmp #1
            bne _apply_tail_call_end_search
            lda #1,x ; loop stack; READABILITY: notation
_apply_tail_call_found
            tax
            jmp _apply_tail_call_loop
_apply_tail_call_end_search
            ; shift eval_frame to x
            cpx eval_frame
            beq _apply
            stx eval_next ; use eval_next as scratch
            tsx ; get stack pointer
            txa ; move stack pointer to a
            eor #$ff ; invert (we need  -sp - 1)
            clc
            ; optimization - no adc #1 
            adc eval_frame
            tay
            ldx eval_next
            txs
            ldx eval_frame
_apply_shift_loop
            lda #0,x
            pha
            dex
            dey
            bpl _apply_shift_loop
            ldx eval_next
            stx eval_frame
_apply
            lda game_state
            and #$f0
            ora #GAME_STATE_EVAL_APPLY
            sta game_state
            jmp update_return
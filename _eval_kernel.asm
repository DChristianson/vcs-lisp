;-------------------
; Eval kernel
;

eval_wait
            lda game_state
            and #$f0
            ora #GAME_STATE_EVAL_CONTINUE
            sta game_state
            jmp update_return

stack_overflow
            ; we hit a stack overflow
            ; for now will pull address we were at from stack and drop in accumulator
            pla
            sta accumulator_car
            pla
            sta accumulator_cdr
            ldx #$ff ; reset stack
            txs
            stx eval_frame
            jmp exec_frame_return

eval_apply
            ; PROTECT: we need at least 3 bytes of stack
            ; very crude protection against stack overflow
            tsx
            cpx #STACK_DANGER_ZONE
            bmi stack_overflow
            lda #1 ; 1 = return
            pha
            lda eval_frame
            pha
            tax
            lda eval_env
            and #$7f    ; READABILITY: notation
            pha
            stx eval_env
            lda 0,x     ; READABILITY: notation - this gets the head of the expression
            cmp #$40    ; check if we are applying a cell reference
            bpl eval_iter
            and #$0f    ; READABILITY: notation - else get function # offset
            tax
            lda function_table,x ; deref function
            jmp eval_iter

eval_start
            lda #0
            sta player_input_latch
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
            cmp #SYMBOL_QUOTE + $c0
            beq _eval_quote
            bmi _eval_funcall     ; eval as funcall if less than quote
_eval_test_loop_progn
            lda HEAP_CAR_ADDR,x   ; special case if we are applying test, loop, progn
            sbc #1                ; SPACE: expect carry set here
            and #$07              ; mask out eval_next
            sta eval_next
            lsr                   ; test/loop/progn : 100/101/110 -> 00/01/11
            bcc _eval_no_loop
_eval_loop_init
            ; SAFETY: need 1 stack
            lda HEAP_CDR_ADDR,x   ; push cdr of loop 
            pha                   ; . 
            tsx                   ; push stack up
            stx eval_frame        ;
_eval_no_loop
            ; SAFETY: need 1 more stack
            ; x references a test/progn expression
            lda HEAP_CDR_ADDR,x   ; follow cddr of test ; BUGBUG: what if empty
            tax                   ; .
_eval_test_loop_progn_next
            lda HEAP_CDR_ADDR,x   ; push cddr of test to be rest of args ; BUGBUG: what if empty
            pha                   ; . 
            jmp _eval_funcall_arg ;

eval_update
            lsr SWCHB ; test game reset
            bcc exec_exit_eval
            lda game_state
            and #$0f
            beq eval_start
            lsr
            bcs eval_apply
            ; continue
            rts

_eval_quote 
_eval_number
            ; SAFETY: need 0 stack
            ; x references a number or quote cell, a is the car
            sta accumulator_car   ; push number cell into accumulator and return
            lda HEAP_CDR_ADDR,x   ; .
            sta accumulator_cdr   ; .
_eval_null  ; SAFETY: just returning from null
            jmp exec_frame_return ; .
_eval_funcall
            ; SAFETY: need 1 stack
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
            ; evaluate a local variable (a, b, c, d)
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
            ; SAFETY: need 2 stack
            ; this is a short circuit from doing a frame eval
            lda #FRAME_ARG_OFFSET_LSB,x
            sta accumulator_lsb        ; BUGBUG: may not be needed?
            pha
            lda #FRAME_ARG_OFFSET_MSB,x 
            sta accumulator_msb
            pha
            jmp _eval_funcall_args_next
_eval_funcall_args_expression
            ; SAFETY: need 2 stack
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
            bne _eval_funcall_args_end
_eval_funcall_exec
            ; exec frame
            ldx eval_frame
            lda #0,x
            and #$3f
            asl
            tax
            lda LOOKUP_SYMBOL_FUNCTION+1,x ; reverse jump
            pha
            lda LOOKUP_SYMBOL_FUNCTION,x
            pha
            rts

_eval_funcall_args_end
            lsr ; 001/100/101/110 -> 00/00/01/10                     
            bne _eval_test_loop_continue ; otherwise special form, go to return sub
exec_frame_return
            ; called when we've made a funcall or evaluated an expression
            ; clear stack back to current frame
            ldx eval_frame
            txs 
            inx
            bne _eval_pop_frame
            ; done with eval - go back to repl
exec_exit_eval
            lda #0
            sta AUDV0
            ldx #(repl_edit_col - gx_s1_addr)
_exec_exit_clean_stack_top
            sta gx_s1_addr,x
            dex
            bpl _exec_exit_clean_stack_top
            txs 
_exec_exit_gc
            ; do a major gc
            lda #(heap + HEAP_SIZE)
_exec_exit_gc_iter
            sec
            sbc #2
            bpl _exec_exit_gc_exit
            pha
            jsr eval_wait
_exec_exit_gc_return
            pla 
            ldx #(f2 - heap) ; walk back from f2
_exec_exit_gc_loop
            cmp heap,x
            beq _exec_exit_gc_iter ; found a ref
            dex
            bne _exec_exit_gc_loop
            ; no refs found, free cell
            tax
            lda #0
            sta HEAP_CAR_ADDR,x
            lda free
            sta HEAP_CDR_ADDR,x
            stx free
            jmp _exec_exit_gc ; brute force: have to start over
_exec_exit_gc_exit
            lda game_state
            and #GAME_TYPE_MASK; #GAME_STATE_EDIT
            sta game_state
            jmp repl_update ; we should exit to repl update so it can reclaim the stack

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
            ; args is 1 = return, 4 = test, 5 = loop test, 6 = progn,  7 = loop eval
            lsr
            beq _eval_return
_eval_test_loop_continue
            ldx eval_frame ; pull 
            txs
            bcs _eval_loop_continue ; carry is set if we were looped
            ; evaluate test/progn expression
            ; SPACE: potentially we can optimize the stack here
            lsr ; 10/11 -> 1
            sta eval_next ; should be 1 after the lsr
            lda #0,x ; READABILITY: notation ; get pointer at FRAME+0
            beq _eval_return      ; if null we will return 
            tax
            bcs _eval_progn
            lda accumulator_lsb
            ora accumulator_msb
            bne _eval_test_true ; assume 0 is false
_eval_test_false
            lda HEAP_CDR_ADDR,x
            beq _eval_return      ; if null we will return 
            tax
_eval_test_true
            jmp _eval_funcall_arg
_eval_loop_continue
            lsr
            bcs _eval_loop_iter ; looped : BUGBUG: need?
            lda accumulator_lsb   ; check results of loop test
            ora accumulator_msb   ; .
            beq _eval_loop_return ; assume 0 is false
_eval_loop_iter
            lda #0,x ; READABILITY: notation ; get pointer at FRAME+0
            beq _eval_loop_end_iter
            tax
            lda #7                ; we will continue READABILITY: meaning 
            jmp _eval_loop_next
_eval_loop_end_iter
            jsr eval_wait         ; we need to start the loop over but first, wait 1 frame
            ldx eval_frame
            lda #1,x ; READABILITY: notation
            tax
            lda #5                ; we will re-test READABILITY: meaning 
_eval_loop_next
            sta eval_next
            jmp _eval_test_loop_progn_next
_eval_progn
            lda HEAP_CDR_ADDR,x   ; get cddr to rest of args 
            beq _eval_progn_next  ; if eq we will return, eval_next should be 1
            pha                   ; push cddr back 
            lda #6                ; we will continue READABILITY: meaning 
            sta eval_next
_eval_progn_next
            jmp _eval_funcall_arg ;  
_eval_loop_return
            inx
            stx eval_frame
_eval_return
            sta eval_next ; SPACE: REDUNDANT? may not be needed?
            jmp exec_frame_return
_eval_continue_args
            sta eval_next ; SPACE: REDUNDANT? could consolidate?
            ; SAFETY: need 2 stack
            lda accumulator_lsb
            pha
            lda accumulator_msb 
            pha
            jmp _eval_funcall_args_next

FUNC_APPLY
            ; collapse stack
            tsx
            inx
            txa ; move stack pointer to a            
            eor #$ff ; invert (we need  -sp - 2)
            clc
            adc eval_frame
            tay
            ldx eval_frame
            txs
            lda FRAME_ARG_OFFSET_LSB,x ; get funcall ref
            pha
            dex ; advance to rest of args
            dex ;
            dex ;
_apply_collapse_loop
            lda #0,x ; READABILITY: notation
            pha
            dex
            dey
            bpl _apply_collapse_loop
            ; intentional fallthrough
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
            lda #0,x ; READABILITY: notation
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

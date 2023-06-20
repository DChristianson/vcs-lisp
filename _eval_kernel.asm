;-------------------
; Eval kernel
;


eval_update
            lda game_state
            and #$0f
            beq eval_start
eval_apply
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
            and #$3f    ; READABILITY: notation
            sec
            sbc #FUNCTION_SYMBOL_F0
            tax
            lda function_table,x
            jmp eval_iter
eval_start
            lda repl
eval_iter
            tsx
            stx eval_frame
            tax
            lda HEAP_CAR_ADDR,x ; read car            
            bpl _eval_number
            cmp #FUNCTION_REF_IF
            bne _eval_funcall
_eval_test
            lda HEAP_CDR_ADDR,x ; read cdr
            tax
            lda HEAP_CDR_ADDR,x
            pha
            lda #2 ; KLUDGE: signals test ; READABILITY: notation
            sta eval_next
            jmp _eval_funcall_arg  
_eval_number
            sta accumulator + 1
            lda HEAP_CDR_ADDR,x
            sta accumulator
            jmp exec_frame_return
_eval_funcall
            pha
_eval_funcall_push_args
            ; iterate through all the args
            ; args should either be a cell ref or symbol
            lda HEAP_CDR_ADDR,x ; read cdr
            beq _eval_funcall_exec
_eval_funcall_args_loop
            tax
            lda HEAP_CDR_ADDR,x
            sta eval_next
_eval_funcall_arg
            lda HEAP_CAR_ADDR,x
            cmp #$40
            bpl _eval_funcall_args_expression
            and #$03f
            cmp #NUMERIC_SYMBOL_ZERO
            bmi _eval_funcall_args_env
            asl
            tax
            lda LOOKUP_SYMBOL_VALUE+1,x
            sta accumulator + 1
            pha
            lda LOOKUP_SYMBOL_VALUE,x
            sta accumulator
            pha
            jmp _eval_funcall_args_next
_eval_funcall_args_env
            sec
            sbc #ARGUMENT_SYMBOL_A0
            asl
            eor #$ff
            clc
            adc #1
            clc
            adc eval_env ; find arg 
            tax
            lda #-1,x                 ; READABILITY: notation
            sta accumulator + 1
            pha
            lda #-2,x                ; READABILITY: notation
            sta accumulator
            pha
            jmp _eval_funcall_args_next
_eval_funcall_args_expression
            tay
            lda eval_next
            pha
            lda eval_frame
            pha
            tya
            jmp eval_iter ; recurse
_eval_funcall_args_next
            lda eval_next
            bmi _eval_funcall_args_loop
            bne exec_frame_return
_eval_funcall_exec
            ; exec frame
            ldx eval_frame
            lda 0,x
            and #$3f
            asl
            tax
            lda LOOKUP_SYMBOL_FUNCTION,x
            sta eval_func_ptr
            lda LOOKUP_SYMBOL_FUNCTION+1,x
            sta eval_func_ptr+1
            jmp (eval_func_ptr)
exec_frame_return
            ; clear frame
            ldx eval_frame
            txs 
            inx
            bne _eval_pop_frame
            ; done with eval - go back to repl
            lda #0
            sta repl_scroll
            sta repl_edit_line
            sta repl_edit_col
            lda #GAME_STATE_EDIT
            sta game_state
            jmp update_return
_eval_pop_frame
            ; pop up from recursion
            pla 
            bmi _eval_old_env
            ora #$80 ; kludge: if val is positive, it's a saved env
            sta eval_env
            pla
_eval_old_env
            sta eval_frame
            pla ; pull args from frame
            bmi _eval_continue_args ; if negative, eval next arg cell
            beq _eval_continue_args ; if zero, eval next arg cell (will be nil)
            ; args is 1 = return or 2 = test
            lsr
            beq _eval_return
            ; evaluate test expression
            ; BUGBUG: potentially we can optimize the stack here
            sta eval_next ; a should be = 1
            ldx eval_frame ; pull 
            txs
            lda #0,x
            tax
            lda accumulator+1
            ora accumulator
            beq _eval_test_true
_eval_test_false
            lda HEAP_CDR_ADDR,x
            tax
_eval_test_true
            jmp _eval_funcall_arg
_eval_return
            sta eval_next ; BUGBUG may not be needed?
            jmp exec_frame_return
_eval_continue_args
            sta eval_next
            lda accumulator+1
            pha
            lda accumulator
            pha
            jmp _eval_funcall_args_next


FUNC_S0C_F0
FUNC_S0D_F1
FUNC_S0E_F2
FUNC_S0F_F3
            ; check for tail call here
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
            lda #GAME_STATE_EVAL_APPLY
            sta game_state
            jmp update_return

eval_draw
            ldx #58
_eval_draw_loop
            sta WSYNC
            dex
            bne _eval_draw_loop
            jmp logo_draw
logo_draw_return
            jmp waitOnOverscan
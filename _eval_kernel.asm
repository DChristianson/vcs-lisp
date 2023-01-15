;-------------------
; Eval kernel
;
sub_eval_update
            lda repl
eval_iter
            tsx
            stx tmp_prev_stack
            tax
            lda HEAP_CAR_ADDR,x ; read car            
            bpl _eval_number 
            cmp #$40
            bpl _eval_lambda
_eval_funcall
            pha
_eval_funcall_push_args
            ; iterate through all the args
            ; args should either be a cell ref or symbol
            lda HEAP_CDR_ADDR,x ; read cdr
            beq _eval_funcall_exec
            tax
            lda HEAP_CAR_ADDR,x
            pha
            pha
            jmp _eval_funcall_push_args
_eval_funcall_exec
            lda tmp_prev_stack
            ; exec frame
            tax
            lda #0,x
            and #$3f
            asl
            tax
            lda SYMBOL_FUNCTION_LOOKUP_TABLE,x
            sta tmp_func_ptr
            lda SYMBOL_FUNCTION_LOOKUP_TABLE+1,x
            sta tmp_func_ptr+1
            jmp (tmp_func_ptr)
exec_frame_return
            ldx tmp_prev_stack
            ; get return value off stack
            lda #0,x
            sta accumulator
            lda #1,x
            sta accumulator + 1
            txs ; clear frame
_eval_number
_eval_lambda
            rts



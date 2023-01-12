;-------------------
; Eval kernel
;
; Each frame contains 1 - n + 1 bytes
;
;  arg n
;   ...
;  arg 0
;  function ref (pushed first)
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
            lda HEAP_CDR_ADDR,x ; read cdr
            beq _eval_funcall_exec
            tax
            lda HEAP_CAR_ADDR,x 
            pha
            jmp _eval_funcall_push_args
_eval_funcall_exec
            lda tmp_prev_stack
            ; exec frame
            tax
            lda #0,x
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
            sta return_value
            lda #1,x
            sta return_value + 1
            txs ; clear frame
_eval_number
_eval_lambda
            rts
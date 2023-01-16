;-------------------
; Eval kernel
;

sub_eval_update
            lda repl
eval_iter
            tsx
            stx eval_frame
            tax
            lda HEAP_CAR_ADDR,x ; read car            
            bpl _eval_number 
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
            sta eval_args
            lda HEAP_CAR_ADDR,x
            bpl _eval_funcall_args_number
            cmp #$40
            bpl _eval_funcall_args_expression
            and #$03f
            asl
            tax
            lda LOOKUP_SYMBOL_VALUE+1,x
            pha
            lda LOOKUP_SYMBOL_VALUE,x
            pha
_eval_funcall_args_number
_eval_funcall_args_expression
            lda eval_args
            bne _eval_funcall_args_loop
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
_eval_number
            rts



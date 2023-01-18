;-------------------
; Eval kernel
;

eval_update
            lda repl
eval_iter
            tsx
            stx eval_frame
            tax
            lda HEAP_CAR_ADDR,x ; read car            
            bmi _eval_funcall
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
            sta eval_args
            lda HEAP_CAR_ADDR,x
            cmp #$40
            bpl _eval_funcall_args_expression
            and #$03f
            cmp #NUMERIC_SYMBOL_ZERO
            bmi _eval_funcall_args_env
            asl
            tax
            lda LOOKUP_SYMBOL_VALUE+1,x
            pha
            lda LOOKUP_SYMBOL_VALUE,x
            pha
            jmp _eval_funcall_args_next
_eval_funcall_args_env
            sec
            sbc #ARGUMENT_SYMBOL_A0
            asl
            clc
            adc eval_env ; find arg 
            tax
            lda #-1,x
            pha
            lda #-2,x
            pha
            jmp _eval_funcall_args_next
_eval_funcall_args_expression
            tay
            lda eval_args
            pha
            lda eval_frame
            pha
            tya
            jmp eval_iter ; recurse
_eval_funcall_args_next
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
            inx
            beq _eval_return
            ; pop up from recursion
            pla 
            bmi _eval_old_env
            ora #$80 ; kludge: if val is positive, it's a saved env
            sta eval_env
            pla
_eval_old_env
            sta eval_frame
            pla 
            bmi _eval_continue_args
            beq _eval_continue_args
            lda #0
            sta eval_args ; BUGBUG may not be needed?
            jmp exec_frame_return
_eval_continue_args
            sta eval_args
            lda accumulator+1
            pha
            lda accumulator
            pha
            jmp _eval_funcall_args_next
_eval_return
            jmp eval_update_return


FUNC_S0B_F0
FUNC_S0C_F1
FUNC_S0D_F2
FUNC_S0E_F3
            lda #1 ; KLUDGE in place of args
            pha
            lda eval_frame
            pha
            tax
            lda eval_env
            and #$7f
            pha
            stx eval_env
            lda 0,x
            and #$3f
            sec
            sbc #FUNCTION_SYMBOL_F0
            tax
            lda function_table,x
            jmp eval_iter
;;
;; REPL kernel
;; code editor
;;

repl_kernel_start

repl_update_splice_cell
            ; insert cell between current and prev
            ; do not allow at head 
            ldx repl_prev_cell 
            cpx #$c0
            bpl _repl_update_splice_root
            lda HEAP_CDR_ADDR,x
            cmp repl_curr_cell
            bne _repl_update_prevent_splice_head
_repl_update_splice_cdr
            jsr alloc_cdr
            lda repl_curr_cell
            sta HEAP_CDR_ADDR,x
            stx repl_curr_cell
            rts
_repl_update_splice_root
            ; make sure curr cell is null if at root
            lda repl_curr_cell
            beq _repl_update_splice_cdr
_repl_update_prevent_splice_head
            ; exit update if we try to splice head
            pla
            pla
            jmp _repl_update_skip_move

repl_update_insert_number
            ldy #0
            jmp _repl_update_insert_cell
repl_update_insert_subexp
            ldy #$c0
_repl_update_insert_cell
            jsr repl_update_splice_cell
            dex
            jsr alloc_cdr
            sty HEAP_CAR_ADDR,x
            ;advance cursor
            jmp _repl_update_skip_move

repl_update_edit_delete
            ; delete what's at the cursor
            ldx repl_prev_cell 
            cpx #$c0
            bpl _repl_update_delete_root
            lda HEAP_CDR_ADDR,x
            cmp repl_curr_cell
            beq _repl_update_edit_delete_cdr
            ldx repl_curr_cell
            lda HEAP_CAR_ADDR,x
            bmi _repl_update_edit_delete_end  ; do not allow at head ref
            ldy #3
_repl_update_delete_digit_loop
            lsr HEAP_CAR_ADDR,x
            ror HEAP_CDR_ADDR,x
            dey
            bpl _repl_update_delete_digit_loop
            bmi _repl_update_edit_delete_end
_repl_update_delete_root
            lda repl_edit_col
            lsr
            bne _repl_update_edit_delete_end ; curr cell is second
            lda repl_curr_cell
            beq _repl_update_edit_delete_end ; curr cell is empty
            ldy #0
            beq _repl_update_edit_delete_cdr_root
_repl_update_edit_delete_cdr
            tax             ; 
            beq _repl_update_edit_delete_end ; curr cell is empty
            ldy HEAP_CDR_ADDR,x
            lda #0
            sta HEAP_CDR_ADDR,x
_repl_update_edit_delete_cdr_root
            ldx repl_prev_cell 
            jsr set_cdr_y                  ;
_repl_update_edit_delete_end
            jmp _repl_update_skip_move

repl_update_eval
            ; eval
            lda game_state
            and #$f0
            ora #GAME_STATE_EVAL
_repl_update_save_state
            sta game_state
            jmp _repl_update_skip_move 

repl_menu_select_game
            lda game_state
            ora #GAME_STATE_EDIT_SELECT
            bpl _repl_update_save_state ; SPACE: take advantage of saving state
            ; will not fall through (state always positive)
            
repl_menu_update_game
            ; inc game
            lda game_state
            clc
            adc #$10
            and #$30
            sta game_state
repl_menu_reset_game
            lda game_state
            lsr
            lsr
            lsr
            tax
            lda GAME_STATE_INIT_JMP_HI,x
            pha
            lda GAME_STATE_INIT_JMP_LO,x
            pha
            rts    

repl_update_edit_digit
            ldy #3
_repl_update_edit_digit_loop
            asl HEAP_CDR_ADDR,x
            rol HEAP_CAR_ADDR,x
            dey
            bpl _repl_update_edit_digit_loop
            lda player_input_latch + 1
            cmp #$0b
            bne _repl_update_edit_digit_zero_skip
            lda #0
_repl_update_edit_digit_zero_skip
            ora HEAP_CDR_ADDR,x
            sta HEAP_CDR_ADDR,x
            lda #$0f
            and HEAP_CAR_ADDR,x
            sta HEAP_CAR_ADDR,x
_repl_update_edit_digit_end
            bpl _repl_update_skip_move ; don't exit editor

repl_update_shift_context
            lda game_state
            clc
            adc #$02
            and #$f6
            sta game_state
            jmp _repl_update_skip_move

repl_update
            lda SWCHB
            lsr
            bcc repl_menu_reset_game ; game reset
            lsr
            bcc repl_menu_select_game; game reset
            ; disambiguate editor state
            lda game_state
            and #$0f
            lsr ; test if #GAME_STATE_EDIT_SELECT== 1
            bcs repl_menu_update_game
            tay ; move state into 
            lda player_input_latch
            beq _repl_update_check_key_1
_repl_update_edit_move 
            tax
            dex
            ; moving cursor
            lda REPL_EDIT_K0_TABLE_HI,x
            pha
            lda REPL_EDIT_K0_TABLE_LO,x
            pha
            rts ; jump away
_repl_update_check_key_1
            ldy player_input_latch + 1
            beq _repl_update_skip_move
            ldx repl_curr_cell
            bne repl_update_edit_cell
            jsr repl_update_splice_cell
            lda #$c0
            sta HEAP_CAR_ADDR,x
repl_update_edit_cell
            lda HEAP_CAR_ADDR,x
            bpl repl_update_edit_digit
            cmp #$40 ; check for symbol vs ref
            bpl _repl_update_skip_move ; if ref skip
            ; intentional fallthrough
repl_update_edit_symbol
            lda #7 ; READABILITY: MAGIC NUMBER - key 7 on keypad 0 is held down
            cmp player_input
            bne _repl_update_replace_symbol
            jsr repl_update_splice_cell
_repl_update_replace_symbol
            ; lookup
            lda game_state
            and #$0f
            asl
            adc REPL_KEY_ROW-1,y
            tay
            lda player_input_latch + 1
            adc REPL_KEY_SHIFT,y
            ora #$c0
            sta HEAP_CAR_ADDR,x
            ; fallthrough to advance cursor
_repl_update_advance_cursor
            inc repl_edit_col
            ; end of moves
_repl_update_skip_move
game_state_init_return
            ; calculate visible program
            ldy #(EDITOR_LINES - 1)
            lda repl_scroll
            sta repl_tmp_scroll
            ldx repl_edit_line      ; 
            stx repl_tmp_cell_count ; will count down to zero
            lda #REPL_DISPLAY_MARGIN; initial indent level
            sta repl_display_indent,y
            ; get active editor (eval, def0, def1, def2)
            lda repl_menu_tab
            clc
            adc #REPL_CELL_ADDR     ; precursor cell
            sta repl_prev_cell
            tax
            lda HEAP_CDR_ADDR,x
            beq _prep_repl_line_start_terminal
            ; start scanning the current list for complex data
            sta repl_display_list,y ; ^ a is the current, if this line is simple we don't need to do more
_prep_repl_line_scan
            ldx #$00
            stx repl_tmp_width
_prep_repl_line_scan_loop
            tax
            lda HEAP_CAR_ADDR,x ; read car
            bpl _prep_repl_line_number               ; found a number
            cmp #$40 ; READABILITY: constant
            bpl _prep_repl_line_complex_from_scan    ; found a sublist, need to write in complex way
            lda repl_tmp_width
            clc
            adc #1
            cmp #4 ; BUGBUG: check for too long
            bcs _prep_repl_line_complex_from_scan
            sta repl_tmp_width
            lda HEAP_CDR_ADDR,x ; read cdr
            bne _prep_repl_line_scan_loop
            jmp _prep_repl_line_next
_prep_repl_line_complex_from_scan
            lda repl_display_list,y       ; recover start of line address and recurse
            ldx repl_display_indent,y     ; mark head with additional width
            inx
            stx repl_display_indent,y
_prep_repl_line_complex_next
            tax ; ^ a is the current
_prep_repl_line_complex
            lda #0               
            sta repl_tmp_width
            lda HEAP_CDR_ADDR,x           ; read cdr
            pha                           ; push next addr to stack
            txa                           ; next
            pha                           ; push current addr to stack
            lda HEAP_CAR_ADDR,x           ; read car 
            sta repl_display_list,y       ; store in dl
            bpl _prep_repl_line_next      ; isa constant, draw next line
            cmp #$40                      ; check for symbol or list
            bmi _prep_repl_line_next      ; if symbol next line
            ; ^ car is pointing at a list, we need to pop down
            jmp _prep_repl_line_scan      ; go back to scan
_prep_repl_line_start_terminal
            lda #$c0 ; BUGBUG: magic number
            sta repl_display_list+3 ; SPACE: should always be top line
            inc repl_display_indent+3; SPACE: should always be top line
            bpl _prep_repl_line_next_dey ; SPACE: should always be positive
_prep_repl_line_number
            ; numbers are three wide
            lda #3
            sta repl_tmp_width            
_prep_repl_line_next
            ; merge width into indent level
            lda repl_display_indent,y
            clc
            adc repl_tmp_width
            sta repl_display_indent,y
_prep_repl_line_next_dey
            dec repl_tmp_scroll
            bpl _prep_repl_line_next_skip_dey
            dey
            bmi _prep_repl_line_end
_prep_repl_line_next_skip_dey
            ; start next line
            tsx ; read stack to see how indented we need to be
            txa
            eor #$ff ; invert to get size (at size 0 will be #$ff)
            beq _prep_repl_line_clear
            asl ; shift left x 4
            asl
            clc
            adc #REPL_DISPLAY_MARGIN
            sta repl_display_indent,y ; columns to indent (from prev line)
            pla ; get prev cell from stack
            dec repl_tmp_cell_count ; check if we are on the cursor line
            bne _prep_repl_line_next_skip_prev
            sta repl_prev_cell
_prep_repl_line_next_skip_prev
            pla ; pull next cell from stack
            bmi _prep_repl_line_complex_next ; not null
            lda #$c0; SYMBOL_GRAPHICS_S00_TERM BUGBUG: magic number
            sta repl_display_list,y
            jmp _prep_repl_line_next_dey
_prep_repl_line_clear
            lda #0
_prep_repl_line_clear_loop
            sta repl_display_indent,y
            sta repl_display_list,y
            dex
            dey
            bpl _prep_repl_line_clear_loop
_prep_repl_line_end

            ; check cursor location to make sure it's in bounds
            lda #0 
            sta repl_display_cursor      ; use to increment col pos
            lda repl_tmp_scroll
            eor #$ff
            clc
            adc repl_scroll
            sta repl_last_line ; last cleared line
            ; adjust cursor to stay within line bounds
            lda #$ff
            sta repl_edit_y 
_prep_repl_line_adjust 
            lda repl_scroll              ; get edit line y index
            sec                          ; .
            sbc repl_edit_line           ; .
            clc                          ; .
            adc #(EDITOR_LINES - 1)      ; .
            tay                          ; .
            lda repl_display_indent,y    ; read indent
            lsr                          ; . divide by 8
            lsr                          ; .
            lsr                          ; .
            sta repl_tmp_indent
            lda repl_display_indent,y    ; read line width level
            and #$07                     ; mask out indent
            tax
            lda repl_display_list,y      ; check if we have a list or a symbol
            cmp #$40                     ;
            bmi _prep_repl_line_check_sw
            txs
            tax
            lda HEAP_CAR_ADDR,x
            bpl _prep_repl_line_number_adjust
            tsx
            inx ; allow 1 extra
            jmp _prep_repl_line_check_sw
_prep_repl_line_number_adjust
            lda repl_tmp_indent
            cmp repl_edit_col
            bpl _prep_repl_line_set_col
            lda #2
            sta repl_display_cursor
            ldx #1
_prep_repl_line_check_sw
            stx repl_tmp_width           ; save indent level to tmp
            lda repl_tmp_indent
            sec
            sbc repl_edit_col
            bmi _prep_repl_line_check_wide
_prep_repl_line_check_left
            lda repl_tmp_indent
            jmp _prep_repl_line_set_col
_prep_repl_line_check_wide                         
            clc
            adc repl_tmp_width
            bpl _prep_repl_line_adjust_end
            adc repl_edit_col
_prep_repl_line_set_col
            sta repl_edit_col
_prep_repl_line_adjust_end
            lda repl_edit_col
            clc
            adc repl_display_cursor
            sta repl_display_cursor
            sty repl_edit_y
_prep_repl_key_end

            ; find curr cell based on editor position
            lda repl_edit_col     ;
            sec                   ; subtract indent level from col
            sbc repl_tmp_indent   ; .
            tay                   ; .
            ldx repl_prev_cell  ; deref prev cell
            cpx #$c0
            bmi _prep_repl_line_skip_root
            dey
_prep_repl_line_skip_root            
            lda HEAP_CDR_ADDR,x
            tax
            beq _prep_repl_line_found_curr_cell
            dey
            bmi _prep_repl_line_found_curr_cell
            ; check head
            lda HEAP_CAR_ADDR,x
            cmp #$40
            bmi _prep_repl_line_find_curr_cell
            stx repl_prev_cell
            tax ; pop down
            dey
            bmi _prep_repl_line_found_curr_cell
_prep_repl_line_find_curr_cell
            lda HEAP_CAR_ADDR,x
            bpl _prep_repl_line_found_curr_cell ; check for number
            lda HEAP_CDR_ADDR,x
            stx repl_prev_cell
            tax ; pop down
            beq _prep_repl_line_found_curr_cell
            dey
            bpl _prep_repl_line_find_curr_cell
_prep_repl_line_found_curr_cell
            stx repl_curr_cell

            ; done
_prep_repl_end
            ldx #$ff ; clean stack
            txs      ;
            jmp update_return

;----------------------
; Repl display
;

            ; PROMPT
            ; BUGBUG: change name from prompt
            ; draw repl cell tree
sfd_draw_prompt ; stack 1 level deep
            lda #(PROMPT_HEIGHT * 76 / 64) 
            sta TIM64T
            ldy #(EDITOR_LINES - 1)
            sty repl_editor_line

            ; position cursor
            sta WSYNC               ; --
            lda repl_display_cursor ;3    3
            asl                     ;2    5
            asl                     ;2    7
            asl                     ;2    9
            sec                     ;2   11; BUGBUG: space: use generic object position?
_prompt_repos_col
            sbc #15                 ;2   13
            sbcs _prompt_repos_col  ;2/3 15
            tax                     ;2   17
            lda LOOKUP_STD_HMOVE,x  ;5   22
            sta HMBL                ;3   25
            sta RESBL               ;3   28 RESBL shifted -1 cycle compared to cells
            ; no HMOVE - first cell line will do HMOVE for us, then set HMBL to zero

prompt_next_line
            ; lock missiles to players
            lda #2
            sta RESMP0
            sta RESMP1     
            ; load indent level
            lda repl_display_indent,y ;4  4
            and #$f8                ;2    6
            sec                     ;2    8
            ; get ready to strobe player position
            sta WSYNC               ; --
_prompt_repos_loop
            sbc #15                 ;2    2
            sbcs _prompt_repos_loop ;2/3  4
            tax                     ;2    6
            lda LOOKUP_STD_HMOVE,x  ;5   11
            sta HMP0                ;3   14
            sta HMP1                ;3   17
            lda repl_display_indent,y ;4 21 ; check display list for who goes first
            lsr                     ;2   23 : SPACE: use lsr to check order bit
            sbcs _prompt_repos_swap ;2/3 25 ; .
            sta.w RESP0             ;3   29 shim to 29
            sta RESP1               ;3   32
            jmp _prompt_repos_swap_end ; 3 35
_prompt_repos_swap
            sta RESP1               ;3   29
            sta RESP0               ;3   32
_prompt_repos_swap_end
            sta WSYNC               ;--
            ; background color
            tya                     ;2    2
            lsr                     ;2    4
            lda repl_menu_tab       ;3    7
            rol                     ;2    9
            tax                     ;2   11
            lda DISPLAY_REPL_COLOR_SCHEME,x ;4 15
            sta COLUBK              ;3   18
            sta COLUPF              ;3   21
            ; game cursor
            lda game_state          ;3   24
            and #$0f                ;2   26
            lsr                     ;2   28
            tax                     ;2   30
            lda CURSOR_COLORS,x     ;4   34
            cpy repl_edit_y         ;3   37
            sbne _prompt_cursor_skip ;2* 39
            sta COLUPF              ;3   42
            jmp _prompt_cursor_bk_1 ;3   45
_prompt_cursor_skip
            SLEEP 5                 ;5   45            
_prompt_cursor_bk_1
            lda #$30                ;2   47
            sta CTRLPF              ;3   50
            lda repl_display_indent,y ;4 54
            and #$01                ;2   56
            tax                     ;2   58
            ldy POW_2_4,x           ;4   62
            SLEEP 8                 ;8   70
            sta HMOVE             ;3   73 ; BUGBUG: can move back? or go to one HMOVE?
            ldx #4                  ;2   75
_prompt_hmove_loop
            dey                     ;2    1  6
            lda PROMPT_HMP_OFFSETS,y;4    5  4
            dex                     ;2    7  8
            sta HMP0,x              ;4   11 12
            sbne _prompt_hmove_loop  ;2/3 14 15 * 3 + 14 = 59 - 2 = 57
            sta RESMP0              ;3   60
            sta RESMP1              ;3   63
            lda #$80                ;2   65
            sta HMBL                ;3   68 ; no move
            sta.w HMOVE             ;4   73
            
prompt_encode
            ldy repl_editor_line
            lda repl_display_list,y
            beq _prompt_encode_blank
            tax
            cmp #$40
            bpl _prompt_encode_ref
_prompt_encode_symbol
            lda repl_display_indent,y 
            lsr
            bcc _prompt_encode_symbol_alone
            ldy #2
            lda #SYMBOL_CELL
            jsr sub_fmt_symbol
_prompt_encode_symbol_alone
            txa
            ldy #0
            jsr sub_fmt_symbol
            jmp prompt_display
_prompt_encode_ref
            ; add ref marker
            lda HEAP_CAR_ADDR,x
            bpl _prompt_encode_number
            ; load width and find offset to write graphics
            lda repl_display_indent,y 
            and #$07
            asl ; multiply by 2
            tay ; load offset into y
            lda #SYMBOL_CELL
            jsr sub_fmt_symbol
            dey
            dey
            ;  encoding loop
_prompt_encode_loop
            lda HEAP_CAR_ADDR,x ; read car
            jsr sub_fmt_symbol
            lda HEAP_CDR_ADDR,x
            dey
            dey
            bmi _prompt_encode_end
            tax
            bne _prompt_encode_loop
_prompt_encode_end
            jmp prompt_display
_prompt_encode_blank
            ldx #CHAR_HEIGHT + 4
            jsr sub_wsync_loop
            jmp prompt_end_line
_prompt_encode_number
            lda #<SYMBOL_GRAPHICS_HASH
            sta gx_s1_addr
            lda #>SYMBOL_GRAPHICS_HASH
            sta gx_s1_addr + 1
            jsr sub_fmt_number
            ; SPACE: intentional fallthrough

prompt_display
            ; ------------------------------------
            ; cell display kernel
            ;
            ;   - cells are displayed using player / missile graphics
            ;     - missiles are used to draw cell walls
            ;     - players are used to draw cell contents
            ;  - limits
            ;     - we can display 1-3 copies of each player / missile for a total of 6 elements
            ;     - the last missile draws the rightmost cell wall
            ;     - this gives us max 5 cells (using 6 walls)
            ;     - so #copies p0 / p1 = # cells + 1
            ;   - kernel timing 
            ;     - player 1 / missile 1 are always last
            ;     - example: to draw top of cell
            ;       - on first line set missile width to 8
            ;       - while last m0 / p0 is being drawn set m1 width to 1
            ;       - leave width 1 until last line
            ;       - draw cell contents with a stock 48 pixel kernel
            ;       - on last line repeat the top line logic 
            ;
            ; cells - copies - NUSIZ -  0  1  0  1  0  1  0
            ; 1     - 1 / 1  - 30 00 -             30 00 00 
            ; 2     - 1 / 2  - 30 31 -          31 30 01 00 
            ; 3     - 2 / 2  - 31 31 -       31 31 31 01 01
            ; 4     - 2 / 3  - 31 33 -    33 31 33 31 03 01 
            ; 5     - 3 / 3  - 33 33 - 33 33 33 33 33 03 03
            ;

            lda #1                       ;2  -15
            sta VDELP0                   ;3  -13
            sta VDELP1                   ;3  -10
            ldy repl_editor_line         ;3   -7
            lda repl_display_indent,y    ;4   -4
            sta WSYNC                    ;------
            and #$07                     ;2    2
            tax                          ;2    4
            lda repl_display_indent,y    ;4    8
            and #$f8                     ;2   10
            clc                          ;2   12
            adc DISPLAY_COLS_INDENT,x    ;4   16
            sec                          ;2   18
_prompt_delay_loop                       ; A=80 at first position
            sbc #24                      ;2   44
            SLEEP 3                      ;3   47
            sbcs _prompt_delay_loop      ;2/3 49
            adc #16                      ;2   51
            bmi _prompt_draw_entry_0     ;2/3 53 ; -24, transition at +0  BUGBUG: DASM is weird about sbmi here
            SLEEP 4                      ;4   57
            bne _prompt_draw_entry_2     ;2   59 ; -16, transition at +5 BUGBUG: DASM is weird about sbmi here
            jmp _prompt_draw_entry_1     ;3   62 ;  -8, transition at +3
_prompt_draw_entry_0 ; 54          
_prompt_draw_entry_2 ; 54/--/60
            SLEEP 5                      ;5   59/--/65
_prompt_draw_entry_1 ; 59/62/65
              
            SLEEP 5                      ;4   63/66/69
            lda DISPLAY_COLS_NUSIZ0_A,x  ;4   67/70/73
            sta NUSIZ0                   ;3   70/73/76
            lda DISPLAY_COLS_NUSIZ1_A,x  ;4   
            sta NUSIZ1                   ;3   
            lda #2                       ;2    
            sta ENAM0                    ;3   
            sta ENAM1                    ;3   
            sta ENABL                    ;3   
            ldy DISPLAY_COLS_NUSIZ1_B,x  ;4  
            lda DISPLAY_COLS_NUSIZ0_B,x  ;4   
            sty NUSIZ1                   ;3   
            sta NUSIZ0                   ;3  
            ldx #14                      ;2  
_prompt_draw_start_loop ; skip a line
            dex                          ;2   ..27
            sbpl _prompt_draw_start_loop  ;2/3 ..30
            ldy #CHAR_HEIGHT - 1         ;2   32

_prompt_draw_loop    ; 40/41 w page jump
            SLEEP 23                     ;23  55/58
            lda (gx_s0_addr),y           ;5   60/64
            sta GRP0                     ;3   63
            lda (gx_s1_addr),y           ;5   68
            sta GRP1                     ;3   71
            lda (gx_s2_addr),y           ;5   76
            sta GRP0                     ;3    3
            lax (gx_s3_addr),y           ;5    8
            lda (gx_s4_addr),y           ;5   13
            ; the next statement needs to fire as we start drawing the first GRP0
            stx GRP1                     ;3   16   0 -  9  !0!8 ** ++ 32 40
            ldx #0                       ;2   18   9 - 15   0!8!16 24 ++ 40
            sta GRP0                     ;3   21  15 - 24   0 8!16!** ++ 40
            stx GRP1                     ;3   24  24 - 33   0 8 16!24!** ++
            stx GRP0                     ;3   27  33 - 42   0 8 16 24!32!** 
            dey                          ;2   29  
            sbpl _prompt_draw_loop       ;2   31  

            ldx #$fd ; reset the stack   ;2   33
            txs                          ;2   35
            lda #0                       ;2   37
            sta VDELP0                   ;3   40
            sta VDELP1                   ;3   43
            sta GRP0                     ;3   46
            sta GRP1                     ;3   49

            ldy repl_editor_line         ;3   52
            lda repl_display_indent,y    ;4   56
            and #$07                     ;2   58
            tax                          ;2   60
            lda DISPLAY_COLS_NUSIZ0_A,x  ;4   64
            sta NUSIZ0                   ;3   67
            lda DISPLAY_COLS_NUSIZ1_A,x  ;4   71
            sta NUSIZ1                   ;3   74
            ldy DISPLAY_COLS_NUSIZ1_B,x  ;4    2
            lda DISPLAY_COLS_NUSIZ0_B,x  ;4    6
            SLEEP 18                     ;18  24
            sty NUSIZ1                   ;3   27
            sta NUSIZ0                   ;3   30

            sta WSYNC
            lda #0          
            sta ENAM0
            sta ENAM1
            sta ENABL
prompt_end_line
            dec repl_editor_line
            bmi prompt_done
            ldy repl_editor_line
            jmp prompt_next_line
prompt_done
            jsr waitOnTimer
            rts

repl_draw
            lda #5
            jsr sub_respxx
            ldx repl_menu_tab 
            txa
            bne _menu_fmt_fn
            jsr sub_fmt_word_no_mult
            jmp _menu_draw_start
_menu_fmt_fn
            ldy #2
            clc
            adc #SYMBOL_F0-1
            jsr sub_fmt_symbol
            lda #>SYMBOL_GRAPHICS_BLANK
            sta gx_s4_addr + 1
            lda #<SYMBOL_GRAPHICS_BLANK
            sta gx_s4_addr
_menu_draw_start
            lda DISPLAY_REPL_COLOR_MENU,x
        	sta WSYNC
            sta COLUBK
            lda #WHITE     
        	sta WSYNC
            sta COLUP0     
            sta COLUP1    
            jsr sub_draw_glyph_16px
            sta GRP0     
            lda #WHITE
            sta COLUP0
            sta COLUP1
            jsr sfd_draw_prompt

            sta WSYNC
            lda #BLACK
            sta COLUBK
            ldx #FOOTER_HEIGHT
            jsr sub_wsync_loop

            jmp waitOnOverscan

sub_draw_glyph_16px ; draw p0 and p1, using y and a registers
            ldy #CHAR_HEIGHT - 1
_glyph_loop
            sta WSYNC          
            lda (gx_s3_addr),y   
            sta GRP0                    
            lda (gx_s4_addr),y         
            sta GRP1                     
            dey
            sbpl _glyph_loop
            rts

; display

    ; line width X sprite arrangement
    ; we use the same display kernel for all 
    ; code, but manipulate respx and nusizex 
    ; to ensire p1/m1 are always written last
    ;         - S0 S1  0  1  0  1  0  1  0
    ; 1 - 0 0 - 30 00             30 00 00  
    ; 2 - 2 0 - 30 31          31 30 01 00 
    ; 3 - 2 2 - 31 31       31 31 31 01 01
    ; 4 - 3 2 - 31 33    33 31 33 31 03 01 
    ; 5 - 3 3 - 33 33 33 33 33 33 33 03 03  
  
DISPLAY_COLS_INDENT
    byte 80,88,96,104,112
DISPLAY_COLS_NUSIZ0_A
    byte $30,$30,$31,$31,$33
DISPLAY_COLS_NUSIZ1_A
    byte $00,$31,$31,$33,$33
DISPLAY_COLS_NUSIZ0_B
    byte $00,$00,$01,$01,$03
DISPLAY_COLS_NUSIZ1_B
    byte $00,$01,$01,$03,$03

PROMPT_HMP_OFFSETS
    byte $a0, $b0, $00, $10
    byte $b0, $a0, $10, $00

CURSOR_COLORS
    byte CURSOR_COLOR,$60,$B0,$50

DISPLAY_REPL_COLOR_SCHEME ; BUGBUG: make pal safe
    byte $6A,$6E,$BA,$BE,$5A,$5E,$3A,$3E
DISPLAY_REPL_COLOR_MENU
    byte $60,$B0,$50,$30 ; BUGBUG: make pal safe

; -- NON space-sensitive routines follow

repl_update_edit_up
            lda #-1
            byte $2c
repl_update_edit_down
            lda #1
_repl_update_set_cursor_line
            clc
            adc repl_edit_line
            bpl _repl_update_above_limit
            lda #0
_repl_update_above_limit
            ; check if we are past last line
            cmp repl_last_line
            bcc _repl_update_check_limit
            lda repl_last_line
_repl_update_check_limit
            sta repl_edit_line
            cmp repl_scroll
            bpl _repl_update_check_scroll_down
            sta repl_scroll
            jmp _repl_update_skip_move
_repl_update_check_scroll_down
            sec 
            sbc #(EDITOR_LINES-2)
            cmp repl_scroll
            bmi _repl_update_skip_save_scroll
            sta repl_scroll
_repl_update_skip_save_scroll
            jmp _repl_update_skip_move

repl_update_edit_left
            lda #-1
            byte $2c ; skip next 2 bytes
repl_update_edit_right
            lda #1
            clc
            adc repl_edit_col
            bpl _repl_update_check_col_limit
            lda #0
_repl_update_check_col_limit
            sta repl_edit_col
            jmp _repl_update_skip_move

repl_update_menu_tab
            ; inc tab
            lda repl_menu_tab
            clc 
            adc #1
            and #$03
            sta repl_menu_tab
            jmp _repl_update_skip_move    

sub_fmt_symbol
            ; a is a symbol value, y is location
            asl ; multiply by 8
            asl ; .
            asl ; .
            sta gx_addr,y
            lda #>SYMBOL_GRAPHICS_P0
            adc #0 ; will pick up carry bit if we have P1
            sta gx_addr+1,y
            rts

            ; a is a symbol value
sub_fmt_word_no_mult
            clc 
            adc #<SYMBOL_GRAPHICS_WORDS
            sta gx_s3_addr
            adc #$08
            sta gx_s4_addr
            lda #>SYMBOL_GRAPHICS_WORDS
            sta gx_s3_addr+1
            sta gx_s4_addr+1
            rts

sub_fmt_number
            WRITE_DIGIT_LO HEAP_CAR_ADDR, gx_s2_addr ;16 15
            WRITE_DIGIT_HI HEAP_CDR_ADDR, gx_s3_addr   ;14 29
            WRITE_DIGIT_LO HEAP_CDR_ADDR, gx_s4_addr   ;16 45
            rts

REPL_EDIT_K0_TABLE_LO
            byte <(repl_update_insert_number -1)
            byte <(repl_update_edit_up - 1)
            byte <(repl_update_edit_delete-1)
            byte <(repl_update_edit_left - 1)
            byte <(_repl_update_skip_move - 1)
            byte <(repl_update_edit_right - 1)
            byte <(_repl_update_skip_move-1)
            byte <(repl_update_edit_down - 1)
            byte <(repl_update_shift_context -1)
            byte <(repl_update_eval -1)
            byte <(repl_update_insert_subexp -1)
            byte <(repl_update_menu_tab -1)

REPL_EDIT_K0_TABLE_HI
            byte >(repl_update_insert_number -1)
            byte >(repl_update_edit_up - 1)
            byte >(repl_update_edit_delete-1)
            byte >(repl_update_edit_left - 1)
            byte >(_repl_update_skip_move - 1)
            byte >(repl_update_edit_right - 1)
            byte >(_repl_update_skip_move-1)
            byte >(repl_update_edit_down - 1)
            byte >(repl_update_shift_context -1)
            byte >(repl_update_eval -1)
            byte >(repl_update_insert_subexp -1)
            byte >(repl_update_menu_tab -1)

; set up symbol offsets for each keyboard shift
;  key + repl_key_shift[shift][repl_key_row[key]]
; the first three rows have to be three sequential digits
; the last row each key can be a different offset
; 

REPL_KEY_ROW
    byte 0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3

REPL_KEY_SHIFT
REPL_KEY_SHIFT_0
    byte $0, $0, $0, $0
REPL_KEY_SHIFT_1
    byte $20, $20, $20, ($20 - 11)
REPL_KEY_SHIFT_2
    byte $0f, $1d - 4, $13 - 7, ($2a - 10) 
REPL_KEY_SHIFT_3
    byte $15, $15, $0d - 7, ($2b - 10)

    MAC WRITE_DIGIT_HI 
            lda {1},x
            and #$f0
            lsr
            sta {2}
            lda #>SYMBOL_GRAPHICS_ZERO
            sta {2}+1
    ENDM

    MAC WRITE_DIGIT_LO
            lda {1},x
            and #$0f
            asl
            asl
            asl
            sta {2}
            lda #>SYMBOL_GRAPHICS_ZERO
            sta {2}+1
    ENDM

    MAC MAP_CAR
            lda HEAP_CAR_ADDR,x ; read car
            ldy #{1}
            jsr sub_fmt_symbol
            lda HEAP_CDR_ADDR,x
            tax
    ENDM




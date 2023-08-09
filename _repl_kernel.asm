;;
;; REPL kernel
;; code editor
;;

repl_kernel_start

_repl_update_edit_digit
            ldy #3
_repl_update_edit_digit_loop
            asl HEAP_CDR_ADDR,x
            rol HEAP_CAR_ADDR,x
            dey
            bpl _repl_update_edit_digit_loop
            lda repl_edit_sym
            sec
            sbc #$14
            ora HEAP_CDR_ADDR,x
            sta HEAP_CDR_ADDR,x
            lda #$0f
            and HEAP_CAR_ADDR,x
            sta HEAP_CAR_ADDR,x
            jmp _repl_update_skip_move ; don't exit editor
_repl_update_edit_head
            lda repl_edit_sym
            beq _repl_update_edit_delete ; edit function or . symbol
            cmp #$10 ; BUGBUG: magic number (var versus function)
            bcc _repl_update_edit_set_car
            jmp _repl_update_edit_done ; can't replace with symbol
_repl_update_keys_move_jmp
            jmp _repl_update_keys_move            
_repl_update_edit_set_funcar
            ; we are editing the head of a funcall
            ldy HEAP_CAR_ADDR,x
            bmi _repl_update_edit_set_car ; just change symbol
            ; otherwise it's a number
            ldy #0
            sty HEAP_CDR_ADDR,x
            jmp _repl_update_edit_set_car
_repl_update_edit_keys
            lda player_input_latch         ; check button push
            bmi _repl_update_keys_move_jmp  ; no push
            ldx repl_curr_cell
            beq _repl_update_edit_extend   ; curr cell is null
_repl_update_edit_apply
            ldy repl_prev_cell              ; check if we are at head
            cpy #REPL_CELL_ADDR             ; .
            bpl _repl_update_edit_head      ; .
            lda HEAP_CAR_ADDR,x
            bpl _repl_update_edit_digit     ; we are editing a number
            cmp #$40
            bpl _repl_update_edit_funcall  ; curr cell is a funcall
            ; curr cell is a symbol
            lda repl_edit_sym
            beq _repl_update_edit_delete   ; delete current cell
            cmp #$1e ; BUGBUG: hash
            bne _repl_update_edit_symbol ; BUGBUG could be simpler?
            dex
            jsr alloc_cdr
            jmp _repl_update_edit_set_number
_repl_update_edit_symbol
            cmp #$10 ; BUGBUG: magic number (var versus function)                
            bcs _repl_update_edit_set_car  ; edit symbol
            dex
            jsr alloc_cdr       
            lda repl_edit_sym
_repl_update_edit_set_car
            ora #$c0
            sta HEAP_CAR_ADDR,x
_repl_update_edit_done
            ldx #GAME_STATE_EDIT
            stx game_state
            jmp _repl_update_skip_move
_repl_update_edit_extend
            ldx repl_prev_cell
            lda repl_edit_sym
            beq _repl_update_edit_done     ; extending with null is noop
            jsr alloc_cdr       
            lda #$c0                       ; put in dummy term symbol 
            sta HEAP_CAR_ADDR,x            ; otherwise we will misinterpret
            jmp _repl_update_edit_apply    ; proceed to edit new extension
_repl_update_edit_delete
            ldx repl_prev_cell             ; 
            jsr set_cdr                    ;
            jmp _repl_update_edit_done
_repl_update_edit_funcall
            tax
            lda repl_edit_sym
            beq _repl_update_edit_delete   ; delete current cell
            cmp #$10 ; BUGBUG: magic number (var versus function)                        
            bcc _repl_update_edit_set_funcar   ; edit funcall operator
            cmp #$1e ; BUGBUG: hash
            beq _repl_update_edit_number
            ora #$c0
            ldx repl_curr_cell
            dex
            jsr set_cdr
            jmp _repl_update_edit_done
_repl_update_edit_number
            ; we've changed to a number using # symbol
            lda HEAP_CAR_ADDR,x
            bpl _repl_update_edit_number_skip ; already a number
_repl_update_edit_set_number
            ; clear car and free cdr
            lda #0
            sta HEAP_CAR_ADDR,x
            jsr set_cdr
_repl_update_edit_number_skip
            jmp _repl_update_edit_done

repl_update
            ; disambiguate editor state
            ldx game_state
            cpx #GAME_STATE_EDIT_KEYS
            beq _repl_update_edit_keys
            lda repl_edit_line
            bmi _repl_update_menu
            lda player_input_latch     ; check button push
            bmi _repl_update_edit_move ; BUGBUG: better name prefix - _repl_keys_...?
_repl_update_edit_keys_start
            ; button was pushed, so we need to display keyboard
            ldx #GAME_STATE_EDIT_KEYS
            stx game_state
            lda repl_curr_cell
            beq _repl_update_edit_save_sym ; curr cell is null
            tax
            lda HEAP_CAR_ADDR,x
            bpl _repl_update_edit_number_start
            cmp #$40
            bmi _repl_update_edit_save_sym
            tax
            lda HEAP_CAR_ADDR,x
            bmi _repl_update_edit_save_sym
            ; we are at the head of a number
            lda #$1e ; BUGBUG: HASH
            jmp _repl_update_edit_save_sym
_repl_update_edit_number_start
            ; current cell is a number
            lda #$14 ; BUGBUG: ZERO
_repl_update_edit_save_sym
            and #$1f
            sta repl_edit_sym
            jmp _repl_update_skip_move

_repl_update_keys_move
            ; check keyboard movement
            ;up
            ror 
            bcs _repl_update_keys_skip_up
            jmp _repl_update_edit_done
_repl_update_keys_skip_up
            ror ; skip down 
            ;left
            ror
            bcs _repl_update_keys_skip_left
            lda #-1
            jmp _repl_update_keys_set
_repl_update_keys_skip_left
            ;right
            ror
            bcs _repl_update_keys_skip_move
            lda #1
_repl_update_keys_set
            clc
            adc repl_edit_sym
_repl_update_check_keys_limit
            and #$1f
            sta repl_edit_sym
_repl_update_keys_skip_move
            jmp _repl_update_skip_move

_repl_update_menu
            ; check button push
            lda player_input_latch         
            bpl _repl_update_menu_select
            ; check cursor movement
            ror ; skip up
            ror ; down
            bcc _repl_update_down
            ror
            bcs _repl_update_menu_skip_left
            lda #-1
            jmp _repl_update_set_menu
_repl_update_menu_skip_left
            ror
            bcs _repl_update_skip_move
            lda #1
_repl_update_set_menu
            adc repl_menu_tab ; should be carry clear
            and #$07
            cmp #$05 ; BUGBUG magic number should be constant
            bcc _repl_update_save_menu_tab
            lda #0
_repl_update_save_menu_tab
            sta repl_menu_tab
            jmp _repl_update_skip_move
_repl_update_menu_select
            ldx repl_menu_tab
            lda REPL_MENU_JMP_HI,x
            pha
            lda REPL_MENU_JMP_LO,x
            pha
            rts       

_repl_update_edit_move
            ; check cursor movement
            ror
            bcs _repl_update_skip_up
            lda #-1
            jmp _repl_update_set_cursor_line
_repl_update_skip_up
            ror
            bcs _repl_update_skip_updown
_repl_update_down
            lda #1
_repl_update_set_cursor_line
            clc
            adc repl_edit_line
            bmi _repl_update_above_limit
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
_repl_update_above_limit            
            lda #-1 
            sta repl_edit_line
            lda #0
            sta repl_scroll
            jmp _repl_update_skip_move
_repl_update_check_scroll_down
            sec 
            sbc #(EDITOR_LINES-2)
            cmp repl_scroll
            bmi _repl_update_skip_move
            sta repl_scroll
            jmp _repl_update_skip_move
_repl_update_skip_updown
            ror
            bcs _repl_update_skip_left
            lda #-1
            jmp _repl_update_set_cursor_col
_repl_update_skip_left
            ror
            bcs _repl_update_skip_move
            lda #1
_repl_update_set_cursor_col
            clc
            adc repl_edit_col
            bpl _repl_update_check_col_limit
            lda #0
_repl_update_check_col_limit
            sta repl_edit_col
_repl_update_skip_move

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
            beq _prep_repl_line_next_terminal
            ; start scanning the current list for complex data
            sta repl_display_list,y ; ^ a is the current, if this line is simple we don't need to do more
_prep_repl_line_scan
            ldx #$ff
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
            cmp #5 ; BUGBUG: check for too long
            bcs _prep_repl_line_complex_from_scan
            sta repl_tmp_width
            lda HEAP_CDR_ADDR,x ; read cdr
            bne _prep_repl_line_scan_loop
            jmp _prep_repl_line_next
_prep_repl_line_complex_from_scan
            lda repl_display_list,y       ; recover start of line address and recurse
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
_prep_repl_line_next_terminal
            lda #$c0; SYMBOL_GRAPHICS_S00_TERM
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
            lda repl_edit_line           ; check if we are at -1
            bmi _prep_repl_key_end       ; if so, skip (that's the menu)
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
            ; show keyboard if we are in that game state
            ; keep y as edit line
            lda game_state
            beq _prep_repl_key_end
            lda repl_display_cursor
            sec
            sbc #2
            asl
            asl
            asl
            ora #4 ; keyboard is 5 cells wide
            dey
            sta repl_display_indent,y
            lda #$ff
            sta repl_display_list,y
_prep_repl_key_end

            ; find curr cell based on editor position
            lda repl_edit_col     ;
            sec                   ; subtract indent level from col
            sbc repl_tmp_indent   ; .
            tay                   ; .
            ldx repl_prev_cell  ; deref prev cell       
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

repl_draw

            lda #0
            sta COLUBK

            lda game_state
            lsr
            lsr
            lsr
            tax
            lda REPL_DRAW_JMP_HI,x
            pha
            lda REPL_DRAW_JMP_LO,x
            pha
            rts
repl_draw_return

            jsr sub_draw_menu
            jsr sfd_draw_prompt

            sta WSYNC
            lda #BLACK
            sta COLUBK
            ldx #FOOTER_HEIGHT
            jsr sub_wsync_loop

            jmp waitOnOverscan


            ; MENU
            ; 
sub_draw_menu
            sta WSYNC                    ;--  0
            lda #$c0                     ;2   2
            sta HMP0                     ;3   5
            lda #$d0                     ;2   7
            sta HMP1                     ;3  10
            SLEEP 9                      ;9  19
            sta RESP0                    ;3  22
            sta RESP1                    ;3  25

            sta WSYNC
            sta HMOVE                    ;3   3 - don't need early hmove since COLUBK is black
            lda #RED                     ;2   5
            ldx repl_edit_line           ;3   8
            bpl _menu_set_colubk         ;2  10
            lda #CURSOR_COLOR            ;2  12
_menu_set_colubk
            sta COLUBK
            lda repl_menu_tab
            asl
            asl
            adc #3 ; don't need to clc due to AND #$07 + ASL's
            tax
            jsr sub_draw_glyph_2
            rts

            ; PROMPT
            ; BUGBUG: change name from prompt
            ; draw repl cell tree
sfd_draw_prompt ; stack 1 level deep
            lda #(PROMPT_HEIGHT * 76 / 64) 
            sta TIM64T
            ldy #(EDITOR_LINES - 1)
            sty repl_editor_line
            jsr sub_prep_repl_graphics

            ; position cursor
            sta WSYNC               ; --
            lda repl_display_cursor ;3    3
            asl                     ;2    5
            asl                     ;2    7
            asl                     ;2    9
            sec                     ;2   11
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
            bcs _prompt_repos_swap  ;2/3 25 ; .
            sta.w RESP0             ;3   29 shim to 29
            sta RESP1               ;3   32
            jmp _prompt_repos_swap_end
_prompt_repos_swap
            sta RESP1               ;3   29
            sta RESP0               ;3   32
_prompt_repos_swap_end
            sta WSYNC               ;--
            lda #WHITE              ;2    2
            sta COLUP0              ;3    5
            sta COLUP1              ;3    8
            sta COLUPF              ;3   11
            lda #$30                ;2   13
            sta CTRLPF              ;3   16
            tya                     ;2   18 
            eor #$ff                ;2   20
            clc                     ;2   22
            adc #(EDITOR_LINES)     ;2   24
            clc                     ;2   26   
            adc repl_scroll         ;3   29
            cmp repl_edit_line      ;3   32
            bne _prompt_skip_cursor_bk ;2 34
_prompt_jmp_cursor_bk
            sec                     ;2   36
            sbc #1                  ;2   38
            and #$01                ;2   40
            tax                     ;2   42
            lda DISPLAY_REPL_COLORS,x ;4 46
            ldx #CURSOR_COLOR       ;2   48 
            SLEEP 6                 ;6   54
            jmp _prompt_cursor_bk_1 ;3   57
_prompt_skip_cursor_bk
            sec                     ;2   37
            sbc #1                  ;2   39
            cmp repl_edit_line      ;3   42
            beq _prompt_check_vk_bk ;2   44
            and #$01                ;2   46
            tax                     ;2   48
            lda DISPLAY_REPL_COLORS,x ;4 52
            tax                     ;2   54
            jmp _prompt_cursor_bk_1 ;3   57
_prompt_check_vk_bk
            ldx game_state          ;3   48
            bne _prompt_vk_bk       ;2   50
            and #$01                ;2   52
            tax                     ;2   54
            lda DISPLAY_REPL_COLORS,x ;4 58
            tax                     ;2   60   
            jmp _prompt_cursor_bk_2 ;3   63         
_prompt_vk_bk
            lda #0                  ;2   53
            ldx #CURSOR_COLOR + 1   ;2   55 ; KLUDGE (+ 1 indicator)
            SLEEP 2                 ;2   57
_prompt_cursor_bk_1
            SLEEP 6                 ;6   63
_prompt_cursor_bk_2            
            SLEEP 4                 ;4   67
            stx COLUPF              ;3   70
            sta HMOVE               ;3   73
            sta COLUBK              ;3   76
            SLEEP 14                ;14  14 ; sleep to protect HMX registers
            lda repl_display_indent,y ;4 18
            and #$01                ;2   10
            bne _prompt_swap_hpos   ;2/3 22
            lda #$a0                ;2   24
            sta HMP0                ;3   27
            lda #$b0                ;2   29
            sta HMP1                ;3   32
            lda #$00                ;2   34
            sta HMM0                ;3   37 
            lda #$10                ;2   39
            sta HMM1                ;3   42
            jmp _prompt_final_hpos  ;3   45
_prompt_swap_hpos
            lda #$a0                ;2   25
            sta HMP1                ;3   28
            lda #$b0                ;2   30
            sta HMP0                ;3   33
            lda #$00                ;2   35
            sta HMM1                ;3   38 
            lda #$10                ;2   40
            sta HMM0                ;3   43
            SLEEP 2                 ;2   45 ; -2  -3  -4  -5  -6  -7  -8  -9
_prompt_final_hpos
            lda #0                  ;2   47
            sta RESMP0              ;3   50
            sta RESMP1              ;3   53
            lda #$80                ;2   55
            sta HMBL                ;3   58 ; no move
            SLEEP 12                ;12  70
            sta HMOVE               ;3   73
            
prompt_encode
            cpx #CURSOR_COLOR + 1   ; still background; BUGBUG kludgy to use +1?
            beq _prompt_encode_keys
            lda repl_display_list,y
            beq _prompt_encode_blank
            cmp #$40
            bpl _prompt_encode_ref
_prompt_encode_symbol
            tax
            lda LOOKUP_SYMBOL_GRAPHICS,x
            sta gx_s4_addr
            lda #<SYMBOL_GRAPHICS_S1F_BLANK
            jmp _prompt_encode_end
_prompt_encode_ref
            tax
            lda HEAP_CAR_ADDR,x
            bpl _prompt_encode_number
            ; load indent level onto stack so we can jmp
            lda repl_display_indent,y 
            and #$07
            asl ; multiply by two
            tay
            lda PROMPT_ENCODE_JMP+1,y
            pha
            lda PROMPT_ENCODE_JMP,y
            pha
            rts
            ; unrolled encoding loop
_prompt_encode_s0
            MAP_CAR gx_s0_addr
_prompt_encode_s1
            MAP_CAR gx_s1_addr
_prompt_encode_s2
            MAP_CAR gx_s2_addr
_prompt_encode_s3
            MAP_CAR gx_s3_addr
_prompt_encode_s4
            MAP_CAR gx_s4_addr
_prompt_encode_end
            jmp prompt_display
_prompt_encode_number
            sta repl_fmt_arg + 1
            lda HEAP_CDR_ADDR,x
            sta repl_fmt_arg
            jsr sub_fmt
            jmp prompt_display

_prompt_encode_blank
            ldx #CHAR_HEIGHT + 4
_prompt_encode_blank_loop
            sta WSYNC
            dex
            bpl _prompt_encode_blank_loop
            jmp prompt_end_line

_prompt_encode_keys
            lda repl_edit_sym
            sec
            sbc #2
            and #$1f
            asl
            asl
            asl
            sta gx_s0_addr
            clc
            adc #8
            sta gx_s1_addr
            clc
            adc #8
            sta gx_s2_addr
            clc
            adc #8
            sta gx_s3_addr
            clc
            adc #8
            sta gx_s4_addr

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
            sbpl _prompt_draw_loop        ;2   31  

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
            lda #$80
            sta HMBL
            lda #0          
            sta ENAM0
            sta ENAM1
            sta ENABL
prompt_end_line
            ldy repl_editor_line
            dey 
            bmi prompt_done
            sty repl_editor_line
            jmp prompt_next_line
prompt_done
            jsr waitOnTimer
            rts

sub_fmt
            lda #<SYMBOL_GRAPHICS_S1E_HASH
            sta gx_s1_addr
            WRITE_DIGIT_LO repl_fmt_arg+1, gx_s2_addr ;16 15
            WRITE_DIGIT_HI repl_fmt_arg, gx_s3_addr   ;14 29
            WRITE_DIGIT_LO repl_fmt_arg, gx_s4_addr   ;16 45
            rts

repl_menu_press_game
            ; inc game
            lda game_state
            clc
            adc #$10
            sta game_state
            jmp _repl_update_skip_move            
repl_menu_press_eval
            ; eval
            ldx #GAME_STATE_EVAL
            stx game_state
repl_menu_press_noop
            jmp _repl_update_skip_move     

sub_wsync_loop
_header_loop
            sta WSYNC
            dex
            bpl _header_loop
            rts

; BUGBUG can probably ditch this for a loop
sub_prep_repl_graphics
            ; prep for symbol graphics
            lda #>SYMBOL_GRAPHICS_S00_TERM
            sta gx_s0_addr+1
            sta gx_s1_addr+1
            sta gx_s2_addr+1
            sta gx_s3_addr+1
            sta gx_s4_addr+1
            rts

; BUGBUG can probably ditch this for a loop
PROMPT_ENCODE_JMP
    word _prompt_encode_s4-1
    word _prompt_encode_s3-1
    word _prompt_encode_s2-1
    word _prompt_encode_s1-1
    word _prompt_encode_s0-1

REPL_MENU_JMP_LO
    byte <(repl_menu_press_eval-1),<(repl_menu_press_noop-1),<(repl_menu_press_noop-1),<(repl_menu_press_noop-1)
    byte <(repl_menu_press_game-1)
REPL_MENU_JMP_HI
    byte >(repl_menu_press_eval-1),>(repl_menu_press_noop-1),>(repl_menu_press_noop-1),>(repl_menu_press_noop-1)
    byte >(repl_menu_press_game-1)

; interleaved jump table
; BUGBUG: notation for this?
REPL_DRAW_JMP_LO
REPL_DRAW_JMP_HI = REPL_DRAW_JMP_LO + 1
    word (repl_draw_accumulator-1)
    word (repl_draw_music-1)
    word (repl_draw_game-1)
    word (repl_draw_steps-1)
    word (repl_draw_tower-1)

sub_respxx
            ; a has position
            sta WSYNC               ; --
_respxx_loop
            sbc #15                 ;2    2
            sbcs _respxx_loop       ;2/3  4
            tax                     ;2    6
            lda LOOKUP_STD_HMOVE,x  ;5   11
            sta HMP0                ;3   14
            sta HMP1                ;3   17
            NOP                     ;2   19
            sta.w RESP0             ;4   23
            sta RESP1               ;3   27
            rts

sub_draw_glyph_2
            ldy #3
_glyph_load_loop
            lda MENU_GRAPHICS,x
            sta gx_s1_addr,y
            dex
            dey
            bpl _glyph_load_loop
            ldy #CHAR_HEIGHT - 1
_glyph_loop
            sta WSYNC              ; BUGBUG: position
            lda (gx_s0_addr),y   ; BUGBUG: position   
            sta GRP0                    
            lda (gx_s1_addr),y         
            sta GRP1                     
            dey
            sbpl _glyph_loop
            sta GRP0 ; clear VDEL register
            rts

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
DISPLAY_REPL_COLORS
    byte #$7A,#$7E,#$86 ; BUGBUG: make pal safe

    MAC WRITE_DIGIT_HI 
            lda {1}                         ;3  3
            and #$f0                        ;2  5
            lsr                             ;2  7
            clc                             ;2  9
            adc #<SYMBOL_GRAPHICS_S14_ZERO  ;2 11
            sta {2}                         ;3 13
    ENDM

    MAC WRITE_DIGIT_LO
            lda {1}
            and #$0f
            asl
            asl
            asl
            clc
            adc #<SYMBOL_GRAPHICS_S14_ZERO
            sta {2}
    ENDM

    MAC MAP_CAR
            ldy HEAP_CAR_ADDR,x ; read car
            lda LOOKUP_SYMBOL_GRAPHICS,y
            sta {1}
            lda HEAP_CDR_ADDR,x
            tax
    ENDM

    MAC WRITE_ADDR
            lda #<{1}
            sta {2}
            lda #>{1}
            sta {2}+1
    ENDM


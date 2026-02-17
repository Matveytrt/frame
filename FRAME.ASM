;==========================Settings======================================
.model tiny
.code
LOCALS @@
org 100h
;=========================================================================
PUSH_ARG			macro arg
					mov ax, arg
					push ax
					endm
;=========================================================================
GET_ARGS			macro A, B, C, D
					PUSH_ARG A
					PUSH_ARG B
					PUSH_ARG C
					PUSH_ARG D
					endm
;=========================================================================
CALL_CDECL 			macro proc_name, A, B, C, D
					GET_ARGS D, C, B, A
					call proc_name
					add  sp, 8
    				endm
;=========================================================================
END_PROG		 	macro
					mov ax, 4c00h
					int 21h
					endm
;=========================================================================
pos_0 equ 700
st_offset equ 760
color_0 = 4ch or 80h
symbol_0 = 03h
len_0 = 3
wdth_0 = 10
hght_0 = 5
;=========================================================================
Sign_t	struc
		sign_pos		dw pos_0
		sign_addr		dw 81h
		len				dw 0
		sgn_clr   		db color_0
Sign_t 	ends
;=========================================================================
Frame_t	struc
		frame_pos		dw pos_0
		wdth			dw wdth_0
		hght			dw hght_0
		sym		  		db symbol_0
		frm_clr   		db color_0
Frame_t ends	
;=========================================================================

Start:
Frame Frame_t <, , , ,>
;================================Main=====================================
Main			proc
				
				mov si, 80h
				mov cl, [si] ;cmd_strlen

				test cl, cl ;no sign == default
				jz @@skip_par
				
				dec cl

				xor ax, ax
				mov si, 81h
				inc si

				call Get_Frm_Pos ;bx = pos
				mov word ptr [Frame.frame_pos], bx

				call Get_Wdth
				mov word ptr [Frame.wdth], dx

				call Get_Hght
				mov word ptr [Frame.hght], dx
			
@@skip_par:		mov ax, 0b800h
				mov es, ax ;vmem segment
				mov dh, [Frame.frm_clr]
				mov dl, [Frame.sym]

				CALL_CDECL Draw_Frame, [Frame.frame_pos], [Frame.wdth], [Frame.hght], dx
				
				END_PROG
				endp
;=========================================================================

;================================Scan_Str=================================
Scan_Str     	proc
				push bp

				call Skip_Spaces

				mov ah, dh
				jmp @@first_check

@@lp:			lodsb 

@@first_check:	cmp byte ptr al, '%'
				je @@exit

				stosw
				loop @@lp 

@@exit:			pop bp
				ret
				endp
;================================Scan_Str=================================
;Entry: 	DS:SI - read addr
;			ES:DI - write addr
;			CX - st_len (count)
;			DH = color
;Exit:		AL - cur_sym
;Expected: 	SI = 82h
;			ES = 0b800h
;			DS = default 
;Destroyed: DL, AX
;Comment: % is needed when need pos/ сначала считать в оперативку
;		потом считать в видеопамять
;ToDo:
;=========================================================================

;================================StrLen===================================
Strlen			proc
				push cx

				mov al, '%'

				cld
				xor cx, cx
				dec cx
				repne scasb

				xchg ax, cx
				not ax

				pop cx
				ret
				endp
;================================StrLen===================================
;Entry: 	ES:DI - read_adr 
;Exit:		AX - len
;			CL = '%'
;Expected:
;Destroyed: CX, AX
;Comment: return len of str to %
;ToDo:
;=========================================================================

;===============================Get_Frm_Pos===============================
Get_Frm_Pos		proc

				call Skip_Spaces

				lodsb
				cmp al, 'x'
				jne @@def_pos

				call Atoi ;BX = X
				shl bx, 1
				push bx ;save x

				lodsb
				cmp al, 'y'
				jne @@def_pos

				call Atoi ; BX = Y

				mov dx, bx
				shl dx, 5 ; DX = 32*BX
				shl bx, 7 ;BX *= 128
				add bx, dx ; 160*Y

				pop dx
				add bx, dx ; pos = 160 * y + x
				jmp @@exit

@@def_pos:		dec si
				mov bx, pos_0

@@exit:			ret
				endp
;===============================Get_Frm_Pos===============================
;Entry: 	DS:SI - read addr 
;			CX - len_str
;Exit:		BX - vmem_pos
;Expected: 	DS = default
;Destroyed: DX, AX, BX
;Comment: ret frame position
;ToDo:
;=========================================================================

;================================Get_Sign_Pos=============================
Get_Sign_Pos	proc
				
				lea ax, [bx + 162]

				ret
				endp
;================================Get_Sign_Pos=============================
;Entry: 	BX - frame pos
;Exit:		AX - sign pos
;Expected: -
;Destroyed: AX
;Comment: ret sign pos
;ToDo:
;=========================================================================

;================================Get_Wdth=================================
Get_Wdth		proc

				call Skip_Spaces

				lodsb
				cmp al, 'w'
				jne @@default

				call Atoi

				mov dx, bx
				jmp @@exit

@@default:		dec si
				mov dx, wdth_0

@@exit:			ret
				endp
;================================Get_Wdth=================================
;Entry: 	CX - len
;			DS:SI - read addr 
;Exit:		DX - wdth
;Expected: DS = def
;Destroyed: AX, DX, BX
;Comment: ret frame wdth
;ToDo:
;=========================================================================

;================================Get_Hght=================================
Get_Hght		proc

				call Skip_Spaces

				lodsb
				cmp al, 'h'
				jne @@default

				call Atoi

				mov dx, bx
				jmp @@exit

@@default:		dec si
				mov dx, hght_0

@@exit:			ret
				endp
;================================Get_Hght=================================
;Entry: 	DS:SI - read addr
;			CX - len
;Exit:		DX - hght
;Expected: 	DS = def
;Destroyed: AX, BX, DX
;Comment: ret frame hght
;ToDo:
;=========================================================================

;===============================Get_Frm_Style=============================
Get_Frm_Style		proc
				call Skip_Spaces

				; @@jump_table:
				; 	dw @@case_0
				; 	dw @@case_1
				; 	dw @@case_2
				; 	dw @@case_3

				; @@case_0:
					

				ret
				endp
;===============================Get_Frm_Style============================
;Entry: 	DS:SI - read addr
;			AL - cur_pos
;			CX - len_str
;Exit:		DX - 
;			
;Expected: 	DS = default
;Destroyed:
;Comment: define visualisatin of frame
;ToDo: 
;=========================================================================

;===============================Skip_Spaces===============================
Skip_Spaces		proc

@@lp:			lodsb
				cmp al, ' '
				jne @@exit
				loop @@lp

@@exit:			dec si
				ret
				endp
;===============================Skip_Spaces===============================
;Entry: 	DS:SI - read addr 
;			CX - len
;Exit:		SI += Nspaces 
;			CX -= Nspaces
;Expected: 	DS = default
;Destroyed: AL
;Comment: skips all spaces from cur_pos
;ToDo: 
;=========================================================================

;================================Draw_Frame===============================
Draw_Frame		proc
				push bp
				mov bp, sp

				mov bx, [bp + 4]
				mov cx, [bp + 6]
				mov dx, [bp + 10]

				GET_ARGS bx, cx, 2, dx
				call Print_Row ;upper line

				lea bx, [bx + 158]
				mov cx, [bp + 8]

				GET_ARGS bx, cx, 160, dx
				call Print_Row ;left vert

				mov cx, [bp + 6]

				GET_ARGS bx, cx, -2, dx
				call Print_Row ;lower line

				lea bx, [bx - 158]

				mov cx, [bp + 8]

				GET_ARGS bx, cx, -160, dx
				call Print_Row

				pop bp
				ret
				endp
;================================Draw_Frame===============================
;Entry: 	BX = [bp + 4] - vmem offset
;			CX = [bp + (8 | 6)] hght or wdth
;			DX = [bp + 10] - symbol
;Exit:		BX to start pos
;Expected: 	ES = 0b800h
;Destroyed: BX, CX, DX
;Comment: frame drawing / CDECL std
;ToDo: сверху вниз 9 / чисельный формат рисования
;=========================================================================

;================================Print_Row================================
Print_Row 		proc
				push bp
				mov bp, sp

				mov dx, [bp + 4]
				mov si, [bp + 6]
				mov cx, [bp + 8]

@@lp:			mov bx, [bp + 10]
				mov word ptr es:[bx], dx
				lea bx, [bx + si]
				mov word ptr [bp + 10], bx
				loop @@lp
				
				pop bp
				ret 8
				endp
;================================Print_Row================================
;Entry: 	BX = [BP + 10] - offset
;			ES:BX - addr / ES = vmem_segment_addr
;			CX = [BP + 8] - count
;			SI = [BP + 6] - step	
;			DX = [BP + 4] - color
;Exit:		BX = [BP + 10] - new_offset
;Expected:  -
;Destroyed: CX, DX, SI
;Comment: Printing line / Pascal std
;ToDo: .
;=========================================================================

;===============================Atoi======================================
Atoi			proc
				push bp

				call Skip_Spaces	

				xor bx, bx
				xor ax, ax

@@next_digit:	lodsb

				cmp al, '9'
				ja @@exit
				cmp al, '0'
				jb @@exit

				and al, 0fh
				
				mov dx, bx
				shl dx, 1 ; dx = 2bx

				shl bx, 3 ; bx *= 8
				add bx, dx ; 10bx

				add bx, ax
				
				loop @@next_digit

@@exit:			dec si
				pop bp
				ret
				endp
;===============================Atoi======================================
;Entry: 	DS:SI - read addr 
;			CX - len
;Exit:		BX - num, AL = -1
;Expected: 	DS = default
;Destroyed: DX
;Comment: convert str to num
;ToDo: 
;=========================================================================

;=========================================================================
end		Start
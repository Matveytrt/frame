;==========================Settings======================================
.model tiny
.code
LOCALS @@
org 100h
;=========================================================================
DEF_SYM				macro name, clr
					mov dl, name
					mov dh, clr
					endm
;=========================================================================
GET_SYM				macro pos
					mov dx, [di + pos]
					endm
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
color_0 = 4ch or 80h
symbol_0 = 03h
wdth_0 = 10
hght_0 = 5
;=========================================================================
Sign_t	struc
		sgn_pos 		dw pos_0
		sgn_addr		dw 0
		len				dw 0
		nlines			dw 1
		sgn_clr   		db color_0
Sign_t 	ends
;=========================================================================
Frame_t	struc
		frame_pos		dw pos_0
		wdth			dw wdth_0
		hght			dw hght_0
		sym		  		db symbol_0 ;style data
		frm_clr   		db color_0
Frame_t ends
;=========================================================================
DATASEG
Frame Frame_t <, , , ,>
Sign Sign_t <, , , ,>
Style_Data dw 9 dup(4c03h)  
; 0  1  2
; 3  4  5
; 6  7  8  - 9 pos symbols def frame style
;=========================================================================
CODESEG
Start:
;================================Main=====================================
Main			proc
				
				mov si, 80h
				mov cl, [si] ;cmd_strlen

				test cl, cl ;no params
				jz @@skip_par
				
				dec cl

				xor ax, ax
				mov si, 81h
				inc si

				call Get_Frm_Pos ;bx = pos
				mov word ptr [Frame.frame_pos], bx

				call Get_Wdth ;dx = wdth
				mov word ptr [Frame.wdth], dx

				call Get_Hght ;dx = hght
				mov word ptr [Frame.hght], dx

				call Get_Frm_Style ;dx
				mov byte ptr [Frame.frm_clr], dh
				mov byte ptr [Frame.sym], dl

				call Skip_Spaces

				mov ax, ds
				mov es, ax
				mov di, si
				call Strlen
				mov word ptr [Sign.len], ax

				test ax, ax
				jz @@skip_par ;no sign
				mov word ptr [Sign.sgn_addr], si

				mov dx, [Frame.wdth]
				mov di, [Frame.hght]
				mov cx, [Sign.len]
				call Get_Sign_Pos ;bx
				mov di, [Frame.frame_pos]
				lea bx, [bx + di]
				mov word ptr [Sign.sgn_pos], bx
							
@@skip_par:		mov ax, 0b800h
				mov es, ax ;vmem segment
				; mov dh, [Frame.frm_clr]
				; mov dl, [Frame.sym]
				mov dx, offset Style_Data

				CALL_CDECL Draw_Frame, [Frame.frame_pos], [Frame.wdth], [Frame.hght], dx

				mov cx, [Sign.len]
				test cx, cx
				jz @@no_sign
				mov si, [Sign.sgn_addr]
				mov di, [Sign.sgn_pos]
				mov dh, [Sign.sgn_clr]
				call Print_Str
				
@@no_sign:		END_PROG
				endp
;=========================================================================

;================================Print_Str================================
Print_Str     	proc
				push bp

				call Skip_Spaces
				mov ah, dh

@@lp:			lodsb 
				cmp byte ptr al, '%'
				je @@exit
				stosw
				loop @@lp 

@@exit:			pop bp
				ret
				endp
;================================Print_Str================================
;Entry: 	DS:SI - read addr
;			ES:DI - write addr
;			CX - len
;			DH = color
;Exit:		-
;Expected: 	DS = def
;			ES = 0b800h
;Destroyed: AX
;Comment: % is needed when need pos
;ToDo:
;=========================================================================

;================================StrLen===================================
Strlen			proc
				xor ah, ah
				mov al, 0dh

				cld
				xor cx, cx
				dec cx
				repne scasb
				dec di

				xchg ax, cx
				not ax
				dec ax

				ret
				endp
;================================StrLen===================================
;Entry: 	ES:DI - read_adr 
;Exit:		AX - len
;Expected: % is the end of str, or err
;Destroyed: CX, ES:DI
;Comment: return len of str from cur pos to 0dh
;ToDo:
;=========================================================================

;================================StrChr===================================
Strchr			proc
				mov dl, cl

				call Strlen ;ax - len
				mov cx, ax ;max len
				mov al, dl ;trgt sym

				cld
				repne scasb
				dec di
				cmp byte ptr al, es:[di]
				je @@exit ;search is ok

				xor di, di

@@exit:			ret
				endp
;================================StrChr===================================
;Entry: 	ES:DI - read_adr 
;			CL - target symbol != 0
;Exit:		ES:DI - found pos
;Expected:
;Destroyed: AX, CX, DX
;Comment: ret DI - pos of found sym 
;ret 0 (in DI) when end of cmd string (0dh) reached FAIL
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

				call Skip_Spaces

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
				push bp
				mov bp, sp

				xor ax, ax
				xor bx, bx

				sub dx, 2
				cmp cx, dx
				ja @@exit
				add dx, 2

				mov ax, di
				mov bl, 2
				div bl

				xor ah, ah
				mov di, ax ;save half h

				mov ax, dx
				sub ax, cx
				div bl

				xor ah, ah
				mov bx, ax ;save hor offset
				shl bx, 1 ;2x wdth

				mov dx, di
				shl dx, 7 ;128 di
				shl di, 5 ;32 di
				add di, dx ;160*di

				lea bx, [bx + di]	

@@exit:			pop bp
				ret
				endp
;================================Get_Sign_Pos=============================
;Entry: 	CX - sign len, 
;			DX - frame wdth
;			DI - frame hght
;Exit:		BX - rltv sign pos
;Expected: -
;Destroyed: CX, DX, DI, AX, BX
;Comment: ret relative sign pos or 0, when can't centring the sign
;ToDo:
;=========================================================================

;================================Get_Wdth=================================
Get_Wdth		proc
				push bp
				mov bp, sp

				call Skip_Spaces

				lodsb
				cmp al, 'w'
				jne @@default

				call Atoi

				mov dx, bx
				jmp @@exit

@@default:		dec si
				mov dx, wdth_0

@@exit:			pop bp
				ret
				endp
;================================Get_Wdth=================================
;Entry: 	DS:SI - read addr 
;Exit:		DX - wdth
;Expected: 	DS = def
;Destroyed: AX, BX
;Comment: ret frame wdth
;ToDo:
;=========================================================================

;================================Get_Hght=================================
Get_Hght		proc
				push bp
				mov bp, sp

				call Skip_Spaces

				lodsb
				cmp al, 'h'
				jne @@default

				call Atoi

				mov dx, bx
				jmp @@exit

@@default:		dec si
				mov dx, hght_0

@@exit:			pop bp
				ret
				endp
;================================Get_Hght=================================
;Entry: 	DS:SI - read addr
;Exit:		DX - hght
;Expected: 	DS = def
;Destroyed: AX, BX, DX
;Comment: ret frame hght
;ToDo:
;=========================================================================

;===============================Get_Frm_Style=============================
Get_Frm_Style	proc
				push bp
    			mov bp, sp

				call Skip_Spaces

				xor ax, ax

				lodsb
				cmp al, 's'
				jne @@default

				call Skip_Spaces
				lodsb ;err_check

				cmp al, '0'
				jb @@default
				cmp al, '3'
				ja @@default

				and al, 0fh
				shl al, 1 ;word_addresses
				mov bx, ax

				lea bx, [bx + @@jump_table]


				jmp [bx]

				@@jump_table:
					dw @@case_0
					dw @@case_1
					dw @@case_2
					dw @@case_3

				@@case_0:
					mov dl, 0b0h
					mov dh, 83h
					jmp @@exit

				@@case_1:
					mov dl, 03h
					mov dh, 95h
					jmp @@exit

				@@case_2:
					mov dl, 0fh
					mov dh, 0ach
					jmp @@exit

				@@case_3:
					mov dl, 06h
					mov dh, 0ceh
					jmp @@exit

				@@default:
					dec si
					mov dl, symbol_0
					mov dh, color_0
					jmp @@exit

@@exit:			pop bp
				ret
				endp
;===============================Get_Frm_Style============================
;Entry: 	DS:SI - read addr
;Exit:		DX - frm atribute
;			DH - color, DL - sym	
;Expected: 	DS = default
;Destroyed: AX, BX
;Comment: define visualisatin of frame
;ToDo: 
;=========================================================================

;===============================Get_Style=================================
Get_Style		proc
				push bp
    			mov bp, sp

				call Skip_Spaces

				xor ax, ax
				mov di, bx
				mov dl, symbol_0
				mov dh, color_0

				lodsb
				cmp al, '['
				jne @@far_jmp
				jmp @@lp

@@far_jmp:		jmp far ptr @@no_style

@@lp:			call Skip_Spaces
				lodsb

				cmp al, '0'
				jb @@default
				cmp al, '9'
				ja @@default

				and al, 0fh ;get num
				
				shl al, 1 ;word_addresses
				mov bx, ax

				lea bx, [bx + @@jump_table]
				jmp [bx] ;dx - symbol

@@next:			mov [di], dx
				lea di, [di + 2]
				loop @@lp

				call Skip_Spaces
				lodsb
				cmp al, ']'
				je @@exit

				dec si
				jmp @@exit

				@@jump_table:
					dw @@case_0
					dw @@case_1
					dw @@case_2
					dw @@case_3
					dw @@case_4
					dw @@case_5
					dw @@case_6
					dw @@case_7
					dw @@case_8
					dw @@case_9

				@@case_0:
					DEF_SYM 0b0h, 83h
					jmp @@next

				@@case_1:
					DEF_SYM 03h, 95h
					jmp @@next

				@@case_2:
					DEF_SYM 0fh, 0ach
					jmp @@next

				@@case_3:
					DEF_SYM 06h, 0ceh
					jmp @@next

				@@case_4:
					DEF_SYM 06h, 0ceh;c
					jmp @@next

				@@case_5:
					DEF_SYM 06h, 0ceh;c
					jmp @@next

				@@case_6:
					DEF_SYM 06h, 0ceh;c
					jmp @@next

				@@case_7:										
					DEF_SYM 06h, 0ceh;c
					jmp @@next

				@@case_8:
					DEF_SYM 06h, 0ceh;c
					jmp @@next

				@@case_9:
					DEF_SYM 06h, 0ceh;c
					jmp @@next

				@@default:
					cmp al, ']'
					jne @@no_style
					dec si
					jmp @@next ; jmp next

@@no_style:		dec si
@@exit:			pop bp
				ret
				endp
;===============================Get_Style=================================
;Entry: 	DS:SI - read addr
;			BX - data addr
;			CX - data len
;			DI - offset
;Exit:      - 
;Expected: 	DS = default
;Destroyed: BX, CX, DX, DI, AX
;Comment: [123456789] - style format
; not the best realisation, but that's special for show switch table and far jmps
;ToDo: 
;=========================================================================


;===============================Skip_Spaces===============================
Skip_Spaces		proc

@@next_sp:		lodsb
				cmp al, ' '
				jne @@exit
				jmp @@next_sp

@@exit:			dec si
				ret
				endp
;===============================Skip_Spaces===============================
;Entry: 	DS:SI - read addr 
;Exit:		SI += Nspaces 
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

				sub word ptr [bp + 8], 2

				sub word ptr [bp + 6], 2

				mov di, [bp + 10]

				GET_SYM 0 ;left up
				GET_ARGS bx, 1, 2, dx
				call Print_Row ;dot
				
				GET_SYM 2 ;up mid
				mov cx, [bp + 6]
				GET_ARGS bx, cx, 2, dx
				call Print_Row ;hor up

				GET_SYM 4 ;right up
				GET_ARGS bx, 1, 2, dx
				call Print_Row ;dot
				
				mov bx, [bp + 4]
				lea bx, [bx + 160]
				mov cx, [bp + 8];lp count

@@lp:			push bx
				push cx
				GET_SYM 6 ;left vert
				GET_ARGS bx, 1, 2, dx
				call Print_Row ;dot

				GET_SYM 8
				mov cx, [bp + 6]
				GET_ARGS bx, cx, 2, dx
				call Print_Row ;middle

				GET_SYM 10
				GET_ARGS bx, 1, 2, dx
				call Print_Row ;right vert

				pop cx
				pop bx
				lea bx, [bx + 160];next line
				loop @@lp

				GET_SYM 12 ;left dwn
				GET_ARGS bx, 1, 2, dx
				call Print_Row ;dot
				
				GET_SYM 14 ;dwn mid
				mov cx, [bp + 6]
				GET_ARGS bx, cx, 2, dx
				call Print_Row ;hor dwn

				GET_SYM 16 ;right dwn
				GET_ARGS bx, 1, 2, dx
				call Print_Row ;dot

				pop bp
				ret
				endp
;================================Draw_Frame===============================
;Entry: 	[BP+4]  - vmem offset (начальный адрес в видеопамяти)
;           [BP+6]  - width (ширина рамки в символах)
;           [BP+8]  - height (высота рамки в символах)
;			[BP+10] - style data addr (адрес структуры со стилями)
;Exit:		-
;Expected: 	ES = 0b800h (сегмент видеопамяти)
;Destroyed: AX, BX, CX, DX, SI
;Comment: Рисует рамку используя структуру стиля (18 слов)
;         Стили: 0-left_up, 2-up_mid, 4-right_up,
;                6-left_vert, 8-mid_vert, 10-right_vert,
;                12-left_down, 14-down_mid, 16-right_down
;ToDo: слева направо + заливка
;используя структуру стиля 
;левый верхний строка (wdth - 2)
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
;Entry: 	Стек: [BP+10] - vmem offset
;                 [BP+8]  - length (количество символов)
;                 [BP+6]  - step (шаг между символами в байтах)
;                 [BP+4]  - symbol (символ+атрибут)
;Exit:			  [BP+10] обновлен (новый offset после печати)
;Expected: 	ES = 0b800h
;Destroyed: CX, DX, SI (BX не портится!)
;Comment: Печатает строку символов с заданным шагом
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
				
				jmp @@next_digit

@@exit:			dec si
				pop bp
				ret
				endp
;===============================Atoi======================================
;Entry: 	DS:SI - read addr 
;Exit:		BX - num, AL = -1
;Expected: 	DS = default
;Destroyed: DX
;Comment: convert str to num
;ToDo: 
;=========================================================================

;=========================================================================
end		Start
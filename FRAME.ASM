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
color_0 = 4ch or 80h
symbol_0 = 03h
len_0 = 3
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

Start:
Frame Frame_t <, , , ,>
Sign Sign_t <, , , ,>
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
				lea bx, [bx + [Frame.frame_pos]]
				mov word ptr [Sign.sgn_pos], bx
							
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
				mov ax, '%'

				cld
				xor cx, cx
				dec cx
				repne scasb

				xchg ax, cx
				not ax

				ret
				endp
;================================StrLen===================================
;Entry: 	ES:DI - read_adr 
;Exit:		AX - len
;Expected: % is the end of str, or err
;Destroyed: CX, ES:DI
;Comment: return len of str
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
				inc al
				mov di, ax ;save half h

				mov ax, dx
				sub ax, cx
				div bl

				xor ah, ah
				mov bx, ax ;save hor offset
				shl bx, 1 ;x2

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
;Entry: 	DS:SI - read addr 
;Exit:		DX - wdth
;Expected: 	DS = def
;Destroyed: AX, BX
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
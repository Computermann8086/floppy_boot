;----------------------------------;
;        Floppy Boot Record        ;
;  Written by Christian Henrichsen ;
;            30.09.2024            ;
;           Copyright (C)          ;
;       Christian Henrichsen       ;
;               2024               ;
;                                  ;
;     Copyright Notice Must be     ;
; Included with All Copies of This ;
;              Program             ;
;----------------------------------;

org 7c00h               ; Program origin of 7c00h
bits 16                 ; 16-bit programing
cpu 8086                ; And assembling for the iAPX 8086 processor
jmp start
nop
;------------------------------
; BIOS PARAMETER BLOCK
BPB:
bps  dw 512             ; Bytes Per Sector
spc  db 2               ; Sectors Per Cluster
rs   dw 0               ; Reserved Sectors
nFAT db 2               ; Number of FAT's
MRDIR dw 224            ; Max Root Directory Entries
tSect dw 2880           ; Total Sectors
mdesc db 0f0h           ; Media Descriptor Byte
spfat dw 9              ; Sectors Per FAT
sptrk dw 18             ; Sectors Per Track
nhead dw 2              ; Number of heads
hsect dd 0              ; Hidden Sectors
tsect dd 0              ; Total Sectors
drvno db 0              ; Drive Number
flags db 0              ; Flags
ebsig db 29h            ; Extended Boot Signature
vsnum dd 12341234h      ; Volume Serial Number
vlabl db 'NO NAME    '  ; Volume Label
fstyp db 'FAT12   '     ; Filesystem Type

;-----------------
; Boot Loader

start:
jmp 0000:enforce_csip   ; Preforming a far jump to enforce CS:IP
enforce_csip:           ; Now that CS:IP is enforced
cli                     ; Clear the interrupt flag, only non-maskable interrupts will be enabled
xor ax, ax              ; Zero out accumulator
mov ss, ax              ; Set the stack segment register
mov sp, 7c00h           ; and the Stack Pointer
push ax                 ; Pushing AX 
push ax                 ; Pushing AX again
pop es                  ; And popping it into ES
pop ds                  ; and DS and setting them both to zero
sti                     ; Set the interrupts flag back on, now every single interrupt can interrupt my work

read_rootdir:
    mov byte [drvno], dl
    mov ax, 19
    call convert_LBA
    mov al, 14
    call read_sect
    mov cx, 224
check_root_dir:
    mov di, buffer
    mov si, filename
    push cx
    mov cx, 11
    rep cmpsb
    je found_file
    pop cx
    add di, 32
    loop check_root_dir

no_kernel:
    mov si, non_sys_disk
    jmp print_string
    

found_file:
    pop cx
    mov si, di
    mov al, [si+0bh]
    test al, 0d8h          ; Bit-mask for bits 11011000
    jnz no_kernel         ; The kernel is either invalid or not here
    xor ax, ax
    mov word ax, [si+1ah] ; AX = First cluster of kernel
    
    
    


;-----------------
; Loader Subroutines

get_fat:
    push bx
    push cx
    mov cx, ax
    shl ax, 1
    add ax, cx
    test ax, 1
    pushf
    shr ax, 1
    add bx, ax
    mov ax, [bx]
    popf
    jnz .getfat1
    and ax, 0fffh
    jmp .getfat2
.getfat1:
    mov cl, 4
    shr ax, cl
.getfat2:
    pop cx
    pop bx
    ret


print_string:
    mov ah, 0eh
.print_loop:
    lodsb
    cmp al, 0
    je .done
    int 10h
    jmp short .print_loop
.done:

reboot:
    xor ax, ax
    int 16h
    mov word [ds:472h], 1234h ; To simulate a ctrl+alt+del
    jmp 0ffffh:0000h    ; Reset the system

read_sect:              ; IN: call to convert_LBA, DL = Drive to read
    mov ah, 02h
    xor bx, bx
    mov es, bx
    mov bx, buffer
    int 13h
    ret



convert_LBA:           ; Converts LBA to CHS tuple ready for int 13h call
	push bx
	push ax

	mov bx, ax			; Save logical sector

	mov dx, 0			; First the sector
	div word [sptrk]
	add dl, 01h			; Physical sectors start at 1
	mov cl, dl			; Sectors belong in CL for int 13h
	mov ax, bx

	mov dx, 0			; Now calculate the head
	div word [sptrk]
	mov dx, 0
	div word [nhead]
	mov dh, dl			; Head/side
	mov ch, al			; Track

	pop ax
	pop bx

	ret


non_sys_disk db 'Non system disk or disk error!', 0
filename db 'AC-DOS  SYS'

buffer:

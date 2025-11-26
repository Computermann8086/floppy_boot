;----------------------------------;
;        Floppy Boot Record        ;
;  Written by Christian Henrichsen ;
;            26.11.2025            ;
;           Copyright (C)          ;
;       Christian Henrichsen       ;
;               2025               ;
;                                  ;
;     Copyright Notice Must be     ;
; Included with All Copies of This ;
;              Program             ;
;----------------------------------;

org 7c00h               ; Program origin of 7c00h
bits 16                 ; 16-bit programing
cpu 8086                ; And assembling for the iAPX 8086 processor
jmp short start
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
    jmp 0000:enforce_csip ; Preforming a far jump to enforce CS:IP
enforce_csip:             ; Now that CS:IP is enforced
    cli                   ; Clear the interrupt flag, only non-maskable interrupts will be enabled
    xor ax, ax            ; Zero out accumulator
    mov ss, ax            ; Set the stack segment register
    mov sp, 7bffh         ; and the Stack Pointer
    push ax               ; Pushing AX 
    push ax               ; Pushing AX again
    pop es                ; And popping it into ES
    pop ds                ; and DS and setting them both to zero
    sti                   ; Set the interrupts flag back on, now every single interrupt can interrupt my work

read_rootdir:
    mov byte [drvno], dl  ; What drive to read from
    mov ax, 19            ; Sector 19
    call convert_LBA      ; Convert it to CHS
    mov al, 14            ; Read 14 sectors
    call read_sect
    mov cx, 224           ; Ammount of entries in root directory
    mov di, buffer        ; The root directory is stored here
check_root_dir:
    mov si, filename      ; The name of our kernel here
    push cx               ; Save CX, since it contains the counter, so we don't start reading garbage data
    mov cx, 11            ; We need to read 11 bytes, cuz 8.3 filenames
    rep cmpsb             ; Does it match?
    je short found_file   ; Yes it does!
    pop cx                ; Nope, let's try again
    add di, 32            ; Add 32 to get to the next dir entry
    loop check_root_dir   ; Let's try again

no_kernel:
    mov si, non_sys_disk  ; No kernel, not good
    jmp short print_string
    

found_file:

    
    pop cx                ; Ok, we found the kernel, let's pop CX of the stack
    mov si, di            ; SI=The die entry for our kernel
    mov al, [si+0bh]      ; This is where the attributes are stored 
    test al, 0d8h         ; Bit-mask for bits 11011000
    jnz short no_kernel   ; The kernel is either invalid or not here
    xor ax, ax            ; Zero out AX
    mov word ax, [si+1ah] ; AX = First cluster of kernel
    mov bp, ax            ; Save AX, since it contains the kernel Cluster
    mov ax, 1             ; FAT starts at LBA 1
    call convert_LBA      ; Convert it to CHS
    mov al, [spfat]       ; Read all the FAT sectors
    call read_sect        ; READ IT
    mov ax, bp            ; Restore AX
    mov bx, 2000h         ; Segment where to load the kernel
    mov es, bx            ; Move segment value 
    xor bx, bx            ; Zero out bx
    jmp short $+4         ; Skip the first increase of bx
read_loop:
    add bx, 1024          ; Add to sectors worth to the adress
    mul [spc]             ; AX *= 2
    call convert_LBA      ; Convert it to LBA
    mov al, 2             ; Read two sectors
    call read_sect_k      ; Read the kernel sector
    mov ax, bp            ; Save AX = previous cluster
    push bx
    mov bx, buffer
    call get_fat          ; Get the next FAT field
    pop bx
    mov bp, ax            ; Save AX again
    cmp ax, 0FF8h         ; Now is this the end of the file??
    jl short read_loop    ; Nope, keep reading
    
jump_to_kernel:           ; Yes indeed, it is the end
    mov ax, 2000h         ; Lets set the main segments to 2000h
    mov es, ax            ; ES
    mov ds, ax            ; Then DS
    xor ax, ax            ; Then lets clear out the registers, starting with AX
    xor bx, bx            ; Then BX
    xor cx, cx            ; Then CX
    xor dx, dx            ; Then DX
    xor si, si            ; Then SI
    xor di, di            ; Then finally DI
    mov dl, [drvno]       ; Set DL to the drivenumber, to pass it to the OS
    jmp far 2000h:0000h   ; Jump to 2000h:0000h, the start of our kernel  

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
    jnz short .getfat1
    and ax, 0fffh
    jmp short .getfat2
.getfat1:
    mov cl, 4
    shr ax, cl
.getfat2:
    pop cx
    pop bx
    ret


print_string:
    mov ah, 0eh              ; Teletype output
.print_loop:
    lodsb                    ; AL = ES:SI
    cmp al, 0                ; Is it zero? If not then keep reading the string
    je .done                 ; Yes it is zero, we're done here
    int 10h                  ; Nope we're not done here, keep printin
    jmp short .print_loop    ; Jump back
.done:

reboot:                       ; Reboot procedure
    xor ax, ax                ; Zero out AX
    int 16h                   ; Wait for keypress
    mov word [ds:472h], 1234h ; To simulate a ctrl+alt+del
    jmp 0ffffh:0000h          ; Reset the system

read_sect:              ; IN: call to convert_LBA, DL = Drive to read
    mov ah, 02h         ; 
    xor bx, bx
    mov es, bx
    mov bx, buffer
    int 13h
    ret

read_sect_k:              ; IN: call to convert_LBA, DL = Drive to read
    push bx
    mov ah, 02h
    mov bx, 2000h
    mov es, bx
    pop bx
    int 13h
    ret

convert_LBA:            ; Converts LBA to CHS tuple ready for int 13h call
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
filename db 'KERNEL  BIN'

times 510 - ($-$$) db 00h

db 055h, 0AAh     ; Boot signature, MUST NOT BE ALTERED

buffer:
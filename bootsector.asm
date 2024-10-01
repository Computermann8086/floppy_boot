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
BPB:
bps  dw 512             ; Bytes Per Sector
spc  db 2               ; Sectors Per Cluster
rs   dw 0               ; Reserved Sectors
nFAT db 2               ; Number of FAT's
MRDIR dw 224            ; Max Root Directory Entries
tSect dw ?              ; Total Sectors
mdesc db 0f0h           ; Media Descriptor Byte
spfat dw 7              ; Sectors Per FAT
sptrk dw ?              ; Sectors Per Track
nhead dw ?              ; Number of heads
hsect dd ?              ; Hidden Sectors
tsect dd ?              ; Total Sectors


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




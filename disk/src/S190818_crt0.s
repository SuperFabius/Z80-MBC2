;--------------------------------------------------------------------------
;
;  S190818_crt0.s
;
;  S190818 - crt0.s for the Z80-MBC2 - HW ref: A040618 
;
;
;  To compile from dos:    sdasz80 -o S190818_crt0.s
;
;  then rename the generated file S190818_crt0.rel as crt0.rel and overwrite 
;  the previous one in "C:\Program Files\SDCC\lib\z80" 
;  (the actual directory may depend on the specific installation).
;
;  Suited for SDDC 3.6.0
;
;--------------------------------------------------------------------------
;
;  Copyright (C) 2000, Michael Hope
;
;  This library is free software; you can redistribute it and/or modify it
;  under the terms of the GNU General Public License as published by the
;  Free Software Foundation; either version 2, or (at your option) any
;  later version.
;
;  This library is distributed in the hope that it will be useful,
;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;  GNU General Public License for more details.
;
;  You should have received a copy of the GNU General Public License 
;  along with this library; see the file COPYING. If not, write to the
;  Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,
;   MA 02110-1301, USA.
;
;  As a special exception, if you link this library with other files,
;  some of which are compiled with SDCC, to produce an executable,
;  this library does not by itself cause the resulting executable to
;  be covered by the GNU General Public License. This exception does
;  not however invalidate any other reasons why the executable file
;   might be covered by the GNU General Public License.
;--------------------------------------------------------------------------

    .module crt0
    .globl  _main
    
;   
; Needed to compile
;
    .globl l__INITIALIZER
    .globl s__INITIALIZED
    .globl s__INITIALIZER   
    

    .area   _HEADER (ABS)
    ;; Reset vector
    .org    0
;
; No interrupt is used (up to now...)
;
    ;jp init

    ;.org   0x08
    ;reti
    ;.org   0x10
    ;reti
    ;.org   0x18
    ;reti
    ;.org   0x20
    ;reti
    ;.org   0x28
    ;reti
    ;.org   0x30
    ;reti
    ;.org   0x38
    ;reti

    ;.org   0x100
init:
;; Set stack pointer directly above top of memory.
;
;  SP is iLoad (S260117) compatible, just for a future warm boot mode...
;
    ld  sp,#0xfcf0

    ;; Initialise global variables
    call    gsinit
    call    _main
    jp  _exit

    ;; Ordering of segments for the linker.
    .area   _HOME
    .area   _CODE
    .area   _INITIALIZER
    .area   _GSINIT
    .area   _GSFINAL

    .area   _DATA
    .area   _INITIALIZED
    .area   _BSEG
    .area   _BSS
    .area   _HEAP

    .area   _CODE
__clock::
    ;ld a,#2
    ;rst    0x08
    ret

_exit::
    ;; Exit - special code to the emulator
    ;ld a,#0
    ;rst    0x08
1$:
    halt
    jr  1$

    .area   _GSINIT
gsinit::
    ld  bc, #l__INITIALIZER
    ld  a, b
    or  a, c
    jr  Z, gsinit_next
    ld  de, #s__INITIALIZED
    ld  hl, #s__INITIALIZER
    ldir
    
gsinit_next:
    .area   _GSFINAL
    ret
    
;--------------------------------------------------------------------------
;--------------------------------------------------------------------------
;
; Basic Z80-MBC2 I/O routines (Here just to make things easier...)
;
;--------------------------------------------------------------------------
;--------------------------------------------------------------------------
;
; VOID PUTCHAR(CHAR C)
;
;--------------------------------------------------------------------------   
        .area   _CODE
_putchar::
        ld      hl,#2
        add     hl,sp
        
        ld      a,(hl)      ; A = "c"
        cp      #0x0a       ; Is a LF?
        jr      nz, 00020$  ; No, just send it
        ld      a,#0x0d     ; Yes, send a CR
        call    00020$
        ld      a,#0x0a     ; Now send a LF

00020$:                     ; Send a single character to the serial line (A contains the character)
        push    af          ; Save A
        ld      a, #0x01    ; A = IOS Serial Tx operation opcode
        out     (#0x01), a  ; Send to IOS the Tx operation opcode
        pop     af          ; Restore the output char into A
        out     (#0x00), a  ; Write A to the serial
        ret

;--------------------------------------------------------------------------     
;
; CHAR GETCHAR()
;
;--------------------------------------------------------------------------  
        .area   _CODE
_getchar::      
00010$:
        in      a,(#0x01)
        ld      l,a         ; No, L = input char
        ret

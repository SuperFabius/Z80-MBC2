;==============================================================================
; Z80-MBC2 QP/M 2.71 Cold Loader - S160918.asm
;
; Required IOS S220718-R100918 (or following until otherwise stated)
;
; Z80-MBC2 - HW ref: A040618
;
;==============================================================================

; CP/M addresses
CCP     .equ    $D200        ; CBASE: (CP/M System)
BDOS    .equ    CCP + $806   ; BDOS entry
BIOS    .equ    CCP + $1600  ; BIOS entry (jumps to BOOT)

; Commons ASCII chars
eos     .equ   $00           ; End of string
cr      .equ   $0d           ; Carriage return
lf      .equ   $0a           ; Line feed

; Z80-MBC2 IOS equates
EXC_WR_OPCD .equ    $00      ; Address of the EXECUTE WRITE OPCODE write port
EXC_RD_OPCD .equ    $00      ; Address of the EXECUTE READ OPCODE read port
STO_OPCD    .equ    $01      ; Address of the STORE OPCODE write port
SERIAL_RX   .equ    $01      ; Address of the SERIAL RX read port
SERTX_OPC   .equ    $01      ; SERIAL TX opcode
SELDISK_OPC .equ    $09      ; SELDISK opcode
SELTRCK_OPC .equ    $0A      ; SELTRACK opcode
SELSECT_OPC .equ    $0B      ; SELSECT opcode
WRTSECT_OPC .equ    $0C      ; WRITESECT opcode
SYSFLAG_OPC .equ    $83      ; SYSFLAG opcode
ERRDSK_OPC  .equ    $85      ; ERRDISK opcode
RDSECT_OPC  .equ    $86      ; READSECT opcode
SDMOUNT_OPC .equ    $87      ; SDMOUNT opcode

; Definitions
LDSECT  .equ    14           ; Number of total host sectors (512 byte) to load (CCP+BDOS+BIOS).

; Starting address
        .org    $80

; ===========================================================================
;
; Load CCP+BDOS+BIOS from the system area of disk 0 (track 0).
; CCP+BDOS+BIOS is stored from sector 0 (total LDSECT sectors to load)
;
; ===========================================================================
    ;
    ; Initialization
    ld      sp, $80         ; Space for local stack 
    ld      hl, LoaderMsg1  ; Print a message
    call    puts
    ld      a, LDSECT       ; Initialize the sectors counter
    ld      e, 0            ; E = first sector = 0
    ld      hl, CCP         ; HL = DMA = CCP starting address
    ld      (SECTCNT), a    ; Save the sectors counter
    ld      (DMABUFF), hl   ; Save current DMA (Disk Memory Access) address
    ;
    ; Select host disk 0
    ld      a, SELDISK_OPC  ; Select SELDISK opcode (IOS)
    out     (STO_OPCD), a
    xor     a               ; disk = 0
    out     (EXC_WR_OPCD), a; Select it
    ;
    ; Select host track 0
    ld      a, SELTRCK_OPC  ; Select SELTRACK opcode (IOS)
    out     (STO_OPCD), a
    xor     a               ; track = 0
    out     (EXC_WR_OPCD), a; LSB track = 0
    out     (EXC_WR_OPCD), a; MSB track = 0
    ;
    ; Load QP/M
LDLOOP
    ld      c, e            ; Select sector
    call    SETSEC
    ld      bc, (DMABUFF)   ; BC = current DMA
    ld      hl, 512
    add     hl, bc          ; HL = DMA + 512
    ld      (DMABUFF), hl   ; Save next DMA
    ld      (DMAAD), bc     ; Set current DMA
    call    READ            ; Read one sector
    or      a               ; Set flags (A = error code)
    jr      nz, FATALERR    ; Jump to load read error
    ld      a, (SECTCNT)    ; A = sectors counter
    dec     a               ; A = A - 1
    jr      z, LOADEND      ; Jump if A = 0 (all done)
    ld      (SECTCNT), a    ; Save updated sectors counter
    inc     e               ; E = next sector
    jr      LDLOOP

FATALERR
    ld      hl, FatalMsg    ; Print a message
    call    puts
    halt

LOADEND
    ld      hl, LoaderMsg2  ; Print a message
    call    puts
    jp  BIOS                ; Jump to QP/M Cold Boot
    
; =========================================================================== ;

SETSEC
    ;
    ; Select current sector. Register C holds the sector number
    ;
    ld      a, SELSECT_OPC  ; Select SELSECT opcode (IOS)
    out     (STO_OPCD), a
    ld      a, c            ; A = current host sector number
    out     (EXC_WR_OPCD), a; Select it
    ret

; =========================================================================== ;

READ
    ;
    ; Assuming the disk, the track, the sector, the DMA address have been set, the READ 
    ; subroutine attempts to read one sector based upon these parameters and 
    ; returns the following error codes in register A:                                                                 ;
    ;
    ;     0 - no errors occurred
    ;     1 - non recoverable error condition occurred
    ;
    ld      hl, (DMAAD)     ; HL = DMA address
    ld      c, EXC_RD_OPCD  ; Set the EXECUTE READ OPCODE port into C
    ld      a, RDSECT_OPC   ; Select READSECT opcode (IOS)
    out     (STO_OPCD), a
    ld      b, 0            ; Byte counter = 256
    inir                    ; Read 256 byte
    inir                    ; Read 256 byte
    ;
    ; Check read errors
    ld      a, ERRDSK _OPC  ; Select ERRDISK opcode (IOS)
    out     (STO_OPCD), a
    in      a, (EXC_RD_OPCD); A = read error code
    or      a               ; Set flags
    ret     z               ; Return if no error (A = 0)
    ld      a, 1
    ret                     ; Return with error (A = 1)

; =========================================================================== ;
            
puts
    ;
    ; Send a string to the serial line, HL contains the pointer to the string
    ;
    ld      a, (hl)         ; A = current char to print
    cp      eos             ; End of string reached?
    jr      z, puts_end     ; Yes, jump
    ld      a, SERTX_OPC    ; A = SERIAL TX opcode
    out     (STO_OPCD), a   ; Write the opcode
    ld      a, (hl)         ; A = current char to print
    out     (EXC_WR_OPCD), a; Print A
    inc     hl              ; Increment character pointer
    jr      puts            ; Transmit next character

puts_end
    ret

; =========================================================================== ;

; MESSAGES

FatalMsg    .db     cr, lf, "FATAL DISK READ ERROR - SYSTEM HALTED", eos
LoaderMsg1  .db     cr, lf, lf, "Z80-MBC2 QP/M 2.71 Cold Loader - S160918"
            .db     cr, lf, "Loading...", eos
LoaderMsg2  .db     " done", cr, lf, eos

; =========================================================================== ;

; DATA AREA

SECTCNT     .block  1
DMABUFF     .block  2
DMAAD       .block  2

            .end
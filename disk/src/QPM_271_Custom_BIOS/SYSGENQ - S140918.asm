;==============================================================================
; Z80-MBC2 - SYSGENQ - S140918
;
; SYSGEN-like program to install QP/M 2.71 using QINSTALL
;
;             Z80-MBC - HW ref: A040618
;
; Required IOS S220718-R100918 (or newer until otherwise stated)
;
;==============================================================================

; CP/M addresses
CCP     .equ    $900         ; CP/M System load address
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
    .org    $100             ; CP/M programs starting address

; =========================================================================== ;
;                                                                             ;
; Load or write CCP+BDOS+BIOS from/to the system area of disk 0 (track 0)     ;
; to/from RAM. CCP+BDOS+BIOS are stored from sector 0 track 0.                ;
; (LDSECT is the total number of sectors to load/write)                       ; 
;                                                                             ;
; =========================================================================== ;
    ;
    ; Initialize and ask wich operation to do
    ld      (CPMSP),SP      ; Save CP/M SP
    ld      sp, (LOCSTK)    ; Set the local stack
    ld      hl, LoaderMsg1  ; Print a message
    call    puts
    ld      hl, askCommMsg  ; Ask the operation (R/W)
    call    puts
waitComm
    call    getc            ; Wait the choice
    call    to_upper        ; Convert it to uppercase
    ld      (COMMAND), a    ; Save it
    cp      'R'             ; READ?
    jr      z, SYSRDWR      ; Yes, jump to read/write function
    cp      'W'             ; WRITE?
    jr      nz, waitComm    ; No, wait for a valid char
SYSRDWR
    call    putc            ; Send echo
    ld      a, (COMMAND)    ; A = 'R' or 'W'
    cp      'W'             ; A = 'W' ?
    jr      z, INITWR       ; Yes, jump
    ld      hl, ReadMsg     ; No, print a message
    call    puts
    jr      INIT            ; Jump to do the rerquested operation
INITWR
    ld      hl, WriteMsg    ; No, print a message
    call    puts
    ;
INIT        ; initialize the read or write operation
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
    ; Initialize counters
    ld      a, LDSECT       ; Initialize the sectors counter
    ld      e, 0            ; E = fisrt sector = 0
    ld      hl, CCP         ; HL = DMA = CCP starting address
    ld      (SECTCNT), a    ; Save the sectors counter
    ld      (DMABUFF), hl   ; Save current DMA (Disk Memory Access) address
    ;
LDLOOP      ; Do the read or write operation
    ld      c, e            ; Select sector
    call    SETSEC
    ld      bc, (DMABUFF)   ; BC = current DMA
    ld      hl, 512
    add     hl, bc          ; HL = DMA + 512
    ld      (DMABUFF), hl   ; Save next DMA
    ld      (DMAAD), bc     ; Set current DMA

    ld      a, (COMMAND)    ; A = 'R' or 'W'
    cp      'W'             ; A = 'W' ?
    jr      z, WRITESEC     ; Yes, jump to write a sector
    call    READ            ; No, Read one sector
    jr      CHECKFLG        ; Jump to check the result flag
WRITESEC
    call    WRITE           ; Write one sector
CHECKFLG
    or      a               ; Set flags (A = error code)
    jr      nz, FATALERR    ; Jump on CP/M load read error
    ld      a, (SECTCNT)    ; A = sectors counter
    dec     a               ; A = A - 1
    jr      z, LOADEND      ; Jump if A = 0 (all done)
    ld      (SECTCNT), a    ; Save updated sectors counter
    inc     e               ; E = next sector
    ld      a, 33
    cp      e               ; Next sector = 33?
    jr      nz, LDLOOP      ; No, jump
    ld      e, 1            ; Set next sector = 1
    ld      d, e            ; Set next track = 1
    jr      LDLOOP
    
FATALERR
    ld      hl, FatalMsg    ; Print a message
    call    puts
    halt
    
LOADEND
    ld      hl, DoneMsg     ; Print a message
    call    puts
    ld      sp, (CPMSP)     ; Restore the CP/M SP
    ret                     ; Return to CP/M
    
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

WRITE
    ;
    ; Assuming the disk, the track, the sector, the DMA address have been set, the WRITE 
    ; subroutine attempts to write one sector based upon these parameters and 
    ; returns the following error codes in register A:                                                                 ;
    ;
    ;     0 - no errors occurred
    ;     1 - non recoverable error condition occurred
    ;
    ld      hl, (DMAAD)     ; HL = DMA address
    ld      c, EXC_WR_OPCD  ; Set the EXECUTE WRITE OPCODE port into C
    ld      a, WRTSECT_OPC  ; Select WRITESECT opcode (IOS)
    out     (STO_OPCD), a
    ld      b, 0            ; Byte counter = 256
    otir                    ; Write 256 byte
    otir                    ; Write 256 byte
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
    ; Send a string to the serial port, HL holds the pointer to the string
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

putc
    ;
    ; Send the char in A to serial port
    ;
    push    af
    ld      a, SERTX_OPC    ; A = SERIAL TX opcode
    out     (STO_OPCD), a   ; Write the opcode
    pop     af
    out     (EXC_WR_OPCD), a; Send A to serial Tx
    ret
    
; =========================================================================== ; 

getc
    ;
    ; Wait for a single incoming character on the serial port
    ; and read it, result is in A:
    ;
    in      a, (SERIAL_RX)  ; read a char from uart
    cp      $ff             ; is = $FF?
    jp      z, getc         ; if yes jump until a valid char is received
    ret

; =========================================================================== ;

to_upper
    ; Convert a single character contained in A to upper case:
    cp      'a'             ; Nothing to do if not lower case
    ret     c
    cp      'z' + 1         ; > 'z'?
    ret     nc              ; Nothing to do, either
    and     $5f             ; Convert to upper case
    ret

; =========================================================================== ;

    ; Print a single byte in hexadecimal notation to the serial port.
    ; The byte to be printed is expected to be in A.
print_byte      
    push    af              ; Save the contents of the registers
    push    bc
    ld      b, a
    rrca
    rrca
    rrca
    rrca
    call    print_nibble    ; Print high nibble
    ld      a, b
    call    print_nibble    ; Print low nibble
    pop     bc              ; Restore original register contents
    pop     af
    ret
 
; =========================================================================== ; 

    ; Prints a single hex nibble which is contained in the lower 
    ; four bits of A:
print_nibble    
    push    af              ; We won't destroy the contents of A
    and     $f              ; Just in case...
    add     a, '0'          ; If we have a digit we are done here.
    cp      '9' + 1         ; Is the result > 9?
    jr      c, print_nibble_1
    add     a, 'A' - '0' - $a ; Take care of A-F
print_nibble_1  
    call    putc            ; rint the nibble and
    pop     af              ; restore the original value of A
    ret

; =========================================================================== ;
;
; MESSAGES
;
FatalMsg    .db     cr, lf, "FATAL DISK ERROR - SYSTEM HALTED", eos
LoaderMsg1  .db     cr, lf, "SYSGENQ - S140918 - Z80-MBC2", cr, lf
            .db     "CP/M 2.2 SYSGEN-like Utility", cr, lf, lf
            .db     "Use only to install QP/M 2.71 using QINSTALL.COM", cr, lf
            .db     "WARNING: W command will overwrite system track!", cr, lf, eos
ReadMsg     .db     cr, lf, "Reading...", eos
WriteMsg    .db     cr, lf, "Writing...", eos
DoneMsg     .db     " done", cr, lf, eos
askCommMsg  .db     cr, lf, "Read system tracks and load to RAM or write them back to disk? [R/W] >", eos
CRLF        .db     cr, lf, eos

; =========================================================================== ;
;
; DATA AREA
;
COMMAND     .block  1
SECTCNT     .block  1
DMABUFF     .block  2
DMAAD       .block  2
CPMSP       .block  2
STKAREA     .block  64
LOCSTK      .equ    $

            .end
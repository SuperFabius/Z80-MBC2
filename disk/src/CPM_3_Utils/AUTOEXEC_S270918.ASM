;********************************************************************************************
;
; AUTOEXEC.ASM - S270918
; CP/M 3.0 IOS AUTOEXEC flag check utility for the Z80-MBC2 (HW ref. A040618)
;
; Required IOS S220718-R190918 (or newer revisions until otherwise stated)
;
; NOTE: Use the RMAC.COM relocatable assembler and link with LINK.COM to 
;       create AUTOEXEC.COM
;
;
;
;********************************************************************************************

;
; INCLUDE MACRO LIBRARY:
;

            MACLIB	Z80

;
; Z80-MBC2 IOS equates
;

EXC$WR$OPCD EQU    000H     ; Address of the EXECUTE WRITE OPCODE write port
EXC$RD$OPCD EQU    000H     ; Address of the EXECUTE READ OPCODE read port
STO$OPCD    EQU    001H     ; Address of the STORE OPCODE write port
SERIAL$RX   EQU    001H     ; Address of the SERIAL RX read port
SERTX$OPC   EQU    001H     ; SERIAL TX opcode
SELDISK$OPC EQU    009H     ; SELDISK opcode
SELTRCK$OPC EQU    00AH     ; SELTRACK opcode
SELSECT$OPC EQU    00BH     ; SELSECT opcode
WRTSECT$OPC EQU    00CH     ; WRITESECT opcode
SYSFLAG$OPC EQU    083H     ; SYSFLAG opcode
DATETIM$OPC EQU    084H     ; DATETIME opcode
ERRDSK$OPC  EQU    085H     ; ERRDISK opcode
RDSECT$OPC  EQU    086H     ; READSECT opcode
SDMOUNT$OPC EQU    087H     ; SDMOUNT opcode

;
; Others equates
;

EOS         EQU    00H      ; End of string
CR		    EQU	   0DH
LF		    EQU	   0AH
BDOS:       EQU    5        ; Address of BDOS entry

;********************************************************************************************
;
; Program start
;
;********************************************************************************************

            ORG    100h     ; CP/M programs start address.

START:  
    SSPD    CpmStack        ; Save CP/M stack
    lxi     sp, LocStack    ; Set local stack
    lxi     h, MsgStr1      ; Print a message
    call    puts
    ;
    ; Read the IOS AUTOEXEC flag
    mvi     a, SYSFLAG$OPC  ; Select SYSFLAG opcode
    out     STO$OPCD    
    in      EXC$RD$OPCD     ; A = SYSFLAG
    ani     01h             ; Isolate the AUTUEXEC flag bit
    sta     Autoexec        ; Save it
    ;
    ; Print the AUTOEXEC flag status
    lxi     h, MsgStr2
    call    puts
    lda     Autoexec        ; A = AUTOEXEC flag
    ora     a               ; AUTOEXEC flag is OFF?
    jrz     AutoOff         ; Yes, jump
    lxi     h, MsgStr4      ; No, print ON
    call    puts
    jr      retCode
AutoOff:
    lxi     h, MsgStr3      ; No, print OFF
    call    puts
    ;
    ; Set the program return code using BDOS function 108
retCode:
    lda     Autoexec        ; A = AUTOEXEC flag
    ora     a               ; AUTOEXEC flag is ON?
    jrnz    exit            ; Yes, jump
    mvi     d, 0ffh         ; No, set return code as unsuccessful (DE = FF00H)
    mvi     e, 0
    mvi     c, 6ch          ; C = BDOS func. 108
    call    BDOS
    ;
    ; Program exit
exit:
    lspd    CpmStack        ; Restore CP/M stack
    ret

;********************************************************************************************
;
; Subroutines
;
;********************************************************************************************

puts:
    ;
    ; Subroutine to print a message using BDOS function 2.
    ; HL holds the pointer to the string
    mvi      c, 02h         ; C = BDOS function 2
    mov      a, m           ; A = (HL) = current char to print
    cpi      eos            ; End of string reached?
    rz                      ; Yes, return
    mov      e, a           ; No, print current char
    push     h
    call     BDOS           ; Print char into E
    pop      h
    inx      h              ; Increment character pointer
    jr       puts           ; Next character

;********************************************************************************************
;        
; Storage
;
;********************************************************************************************

MsgStr1:    DB     CR, LF, 'Z80-MBC2 AUTOEXEC - S270918', eos
MsgStr2:    DB     CR, LF, 'AUTOEXEC is ', eos
MsgStr3:    DB     'OFF', CR, LF, eos
MsgStr4:    DB     'ON', CR, LF, eos 
Autoexec:   DS     1        ; AUTOEXEC flag status
CpmStack:   DS     2        ; Saved CP/M stack
            DS     64       ; Local stack
LocStack:   EQU    $

            END
;********************************************************************************************
;
; VDISK.ASM - S200918
; CP/M 3.0 VIRTUAL DISK ON SD BIOS MODULE FOR THE Z80-MBC2 (HW ref. A040618)
;
; Required IOS S220718-R190918 (or newer revisions until otherwise stated)
;
; NOTE: Use the RMAC.COM relocatable assembler
;
;
;
;********************************************************************************************

TITLE   'CP/M 3 MODULE FOR VIRTUAL DISKS ON SD - Z80-MBC2 (A040618)'

    ;  DEFINE LOGICAL VALUES:
TRUE:       EQU -1
FALSE       EQU NOT TRUE

    ;  DETERMINE IF BANKED SELECT OR NOT
BANKED      EQU TRUE          ; <------ BANKED/NON-BANKED SWITCH

BELL        EQU 07H
CR          EQU 0DH
LF          EQU 0AH

; --------------------------------------------------------------------------------
;
; Z80-MBC2 IOS equates
;
; --------------------------------------------------------------------------------

EXC$WR$OPCD  EQU    000H      ; Address of the EXECUTE WRITE OPCODE write port
EXC$RD$OPCD  EQU    000H      ; Address of the EXECUTE READ OPCODE read port
STO$OPCD     EQU    001H      ; Address of the STORE OPCODE write port
SERIAL$RX    EQU    001H      ; Address of the SERIAL RX read port
SERTX$OPC    EQU    001H      ; SERIAL TX opcode
SELDISK$OPC  EQU    009H      ; SELDISK opcode
SELTRCK$OPC  EQU    00AH      ; SELTRACK opcode
SELSECT$OPC  EQU    00BH      ; SELSECT opcode
WRTSECT$OPC  EQU    00CH      ; WRITESECT opcode
SYSFLAG$OPC  EQU    083H      ; SYSFLAG opcode
DATETIM$OPC  EQU    084H      ; DATETIME opcode
ERRDSK$OPC   EQU    085H      ; ERRDISK opcode
RDSECT$OPC   EQU    086H      ; READSECT opcode
SDMOUNT$OPC  EQU    087H      ; SDMOUNT opcode

    
        PUBLIC  @DTBL

    ; DEFINE EXTERNAL LABELS:
        EXTRN   @ADRV,@RDRV
        EXTRN   @DMA,@TRK,@SECT
        EXTRN   @CBNK
        EXTRN   @DBNK           ;BANK FOR DMA OPERATION
        EXTRN   @ERMDE          ;BDOS ERROR MODE
        EXTRN   ?WBOOT          ;WARM BOOT VECTOR
        EXTRN   ?PMSG           ;PRINT MESSAGE @<HL> UP TO 00, SAVES
                                ; [BC] AND [DE]
        EXTRN   ?PDERR          ;PRINT BIOS DISK ERROR HEADER
        EXTRN   ?CONIN,?CONO    ;CONSOLE IN AND OUT
        EXTRN   ?CONST          ;CONSOLE STATUS
    
    IF      BANKED
        EXTRN   ?BNKSL          ;SELECT PROCESSOR MEMORY BANK
    ENDIF

    ; INCLUDE CP/M 3.0 DISK DEFINITION MACROS:
        MACLIB  CPM3

    ; INCLUDE Z-80 MACRO LIBRARY:
        MACLIB  Z80

    IF  BANKED
        ; --------------------------
        DSEG                    ;PUT IN OP SYS BANK IF BANKING
        ; --------------------------
    ENDIF

; --------------------------------------------------------------------------------  
;
; EXTENDED DISK PARAMETER HEADER FOR 16 VIRTUAL DISKS (Z80-MBC2)
;
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 0:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      0               ;RELATIVE DRIVE 0 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE

DPH0:   DPH     0,IDEHD$DPB0

; --------------------------------------------------------------------------------  

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 1:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      1               ;RELATIVE DRIVE 1 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH1:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------  

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 2:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      2               ;RELATIVE DRIVE 2 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH2:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------  

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 3:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      3               ;RELATIVE DRIVE 3 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH3:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 4:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      4               ;RELATIVE DRIVE 4 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH4:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 5:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      5               ;RELATIVE DRIVE 5 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH5:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 6:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      6               ;RELATIVE DRIVE 6 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH6:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 7:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      7               ;RELATIVE DRIVE 7 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH7:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 8:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      8               ;RELATIVE DRIVE 8 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH8:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 9:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      9               ;RELATIVE DRIVE 9 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH9:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 10:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      10              ;RELATIVE DRIVE 10 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH10:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 11:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      11              ;RELATIVE DRIVE 11 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH11:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 12:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      12              ;RELATIVE DRIVE 12 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH12:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 13:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      13              ;RELATIVE DRIVE 13 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH13:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 14:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      14              ;RELATIVE DRIVE 14 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH14:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------

    ; EXTENDED DISK PARAMETER HEADER FOR DRIVE 15:
    ;
        DW      HDWRT           ;HARD DISK WRITE ROUTINE
        DW      HDRD            ;HARD DISK READ ROUTINE
        DW      HDLOGIN         ;HARD DISK LOGIN PROCEDURE
        DW      HDINIT          ;HARD DISK DRIVE INITIALIZATION ROUTINE
        DB      15              ;RELATIVE DRIVE 15 ON THIS CONTROLLER
        DB      0               ;MEDIA TYPE
  
DPH15:   DPH     0,IDEHD$DPB0
    
; --------------------------------------------------------------------------------
;
; Disk Drive Table or DTBL (So the file DRVTBL.ASM is not needed)
;
; --------------------------------------------------------------------------------

    IF  BANKED
        ; --------------------------
        DSEG            ;BANKED SYSTEMS CAN HAVE DRIVE TABLE IN THE OP SYS BANK
        ; --------------------------
    ELSE
        ; --------------------------
        CSEG            ;NON-BANKED SYSTEMS HAVE NO CHOICE BUT TO PUT IN THE COMMON AREA
        ; --------------------------
    ENDIF

@dtbl:  
        dw  dph0        ; A:
        dw  dph1        ; B:
        dw  dph2        ; C:
        dw  dph3        ; D:
        dw  dph4        ; E:
        dw  dph5        ; F:
        dw  dph6        ; G:
        dw  dph7        ; H:
        dw  dph8        ; I:
        dw  dph9        ; J:
        dw  dph10       ; K:
        dw  dph11       ; L:
        dw  dph12       ; M:
        dw  dph13       ; N:
        dw  dph14       ; O:
        dw  dph15       ; P:
    
; --------------------------------------------------------------------------------
;    
; Disk Parameter Block  table (DPB)
;
; DBP macro parameters:
; Bytes per sector, num sec, num trk, block size, dir entries, reserved trk, HD flag
;
; --------------------------------------------------------------------------------

    ; --------------------------
    CSEG                ; MAKE SURE DPB'S ARE IN COMMON MEMORY
    ; --------------------------
    
IDEHD$DPB0:
        DPB 512,32,512,4096,512,1,8000H

; --------------------------------------------------------------------------------  
;
;                     >>>>>>> READ CAREFULLY <<<<<<<<
;
; NOTE: the disk capacity *MUST* be *LESS* than 8MBytes with DPB macro!!!
; (See CP/M 3 System Guide par. 3.3.5)
; But Z80-MBC2 virtual disks are exactly 8Mbytes (512 * 512 * 32),
; so I've used a little trick to keep things simple and avoid to do the table
; by hand... I've used for all disk an 1 reserved track, so the available 
; disk capacity is less that 8MB (and the DPB macro works...)
; Yeahhh... I'm lazy... :-)
; --------------------------------------------------------------------------------  
    
    IF BANKED
        ; --------------------------
        DSEG                        ;CAN SET BACK TO BANKED SEGMENT IF BANKING
        ; --------------------------
    ENDIF

;----------------------- INITIALIZE THE HARD DISK  -------------------------------
    
HDINIT:     
        RET                     ; Nothing to initialize


HDLOGIN:
        ; This entry is called when a logical drive is about to
        ; be logged into for the purpose of density determination.
        ;
        ; It may adjust the parameters contained in the disk
        ; parameter header pointed at by <DE>
        ret                     ; We have nothing to do


;--------------------------------------------------------------------------------
;      HARD DISK WRITE/READ A SECTOR AT @TRK, @SECT of disk @ADRV TO Address at @DMA
;      Return A=00H if no Error, A=01H if Non-recov Err
;
;
;      >>>> WARNING <<<<: In a banked system @ADRV, @RDRV, @DBNK, @TRK, @SECT, @DMA are 
;                         all in bank 0
;
;--------------------------------------------------------------------------------

            ; relative drive number in @rdrv (8 bits)
            ; absolute drive number in @adrv (8 bits)
            ; disk transfer address in @dma (16 bits)
            ; disk transfer bank    in @dbnk (8 bits)
            ; disk track address    in @trk (16 bits)
            ; disk sector address   in @sect (16 bits)
            ; pointer to XDPH in <DE>

;--------------------------------------------------------------------------------        

lastDsk:
        DB      0ffH                ; Last disk number (= ff after cold boot)

HDWRT:  ; Write a sector (512 bytes)
        push    b
        push    h
        call    setDTS              ; Set disk, track, sector (after return HL = DMA)
    IF  BANKED  ; Banked system handling
        JMP	    BHDWRT
        ; --------------------------
        CSEG                        ; This I/O part must be in the common bank
        ; --------------------------
BHDWRT:    
        LDA     @CBNK               ; Save current bank in the stack
        PUSH    PSW
        LDA     @DBNK               ; Select the bank for disk I/O
        CALL    ?BNKSL
	ENDIF   
        ;
        ; Write current host sector (512 byte) to DMA (HL = DMA)
        mvi     c, EXC$WR$OPCD      ; Set the EXECUTE WRITE OPCODE port into C
        mvi     a, WRTSECT$OPC      ; Select WRITESECT opcode (IOS)
        out     STO$OPCD
        mvi     b, 0                ; Byte counter = 256
        outir                       ; Write 256 byte
        outir                       ; Write 256 byte
    IF	BANKED
        POP	    PSW                 ; Restore previous bank
        CALL	?BNKSL
        JMP	    CHECKWR
        ; --------------------------
        DSEG
        ; --------------------------
	ENDIF
        ;
        ; Check for errors
CHECKWR:
        mvi     a, ERRDSK$OPC       ; Select ERRDISK opcode (IOS)
        out     STO$OPCD
        in      EXC$RD$OPCD         ; Read error code into A
        ora     a                   ; Set Z flag
        pop     h
        pop     b
        rz                          ; Return with A = 0 (no error)
        mvi     a, 1                ; Set error code
        ret                         ; Return with A = 1 (read error)


;--------------------------------------------------------------------------------


HDRD:   ; Read a sector (512 bytes)
        push    b
        push    h
        call    setDTS             ; Set disk, track, sector (after return HL = DMA)
    IF  BANKED  ; Banked system handling
        JMP	    BHDRD
        ; --------------------------
        CSEG                        ; This I/O part must be in the common bank
        ; --------------------------
BHDRD:    
        LDA     @CBNK               ; Save current bank in the stack
        PUSH    PSW
        LDA     @DBNK               ; Select the bank for disk I/O
        CALL    ?BNKSL
	ENDIF
        ;
        ; Read current host sector (512 byte) to DMA (HL = DMA)
        mvi     c, EXC$RD$OPCD      ; Set the EXECUTE READ OPCODE port into C
        mvi     a, RDSECT$OPC       ; Select READSECT opcode (IOS)
        out     STO$OPCD
        mvi     b, 0                ; Byte counter = 256
        inir                        ; Read 256 byte
        inir                        ; Read 256 byte
    IF	BANKED
        POP	    PSW                 ; Restore previous bank
        CALL	?BNKSL
        JMP	    CHECKRD
        ; --------------------------
        DSEG
        ; --------------------------
	ENDIF    
        ;
        ; Check for errors
CHECKRD:
        mvi     a, ERRDSK$OPC       ; Select ERRDISK opcode (IOS)
        out     STO$OPCD
        in      EXC$RD$OPCD         ; Read error code into A
        ora     a                   ; Set Z flag
        pop     h
        pop     b
        rz                          ; Return with A = 0 (no error)
        mvi     a, 1                ; Set error code
        ret                         ; Return with A = 1 (read error)

;--------------------------------------------------------------------------------
        
; Set disk, track and sector routine for a read or write operation and load into
; HL the address in @DMA (used for the read/write operaton)

setDTS: ; Select the disk, track and sector
        ;
        ; Select @ADRV host disk
        lda      @ADRV              ; A = new disk
        mov      b, a               ; B = new disk
        lda      lastDsk            ; A = last disk number
        cmp      b                  ; Previous disk = new disk?
        jrz      setTrack           ; Yes, jump to track selection
        mvi      a, SELDISK$OPC     ; No, select SELDISK opcode (IOS)
        out      STO$OPCD
        mov      a, b               ; A = new disk
        out      EXC$WR$OPCD
        sta      lastDsk            ; Update last disk number 
        ;
        ; Select @TRK host track
setTrack:
        mvi      a, SELTRCK$OPC     ; Select SELTRACK opcode (IOS)
        out      STO$OPCD
        lda      @TRK               ; Select the track number LSB
        out      EXC$WR$OPCD
        lda      @TRK + 1           ; Select the track number MSB
        out      EXC$WR$OPCD
        ;
        ; Select @SECT host sector
        mvi      a, SELSECT$OPC     ; Select SELSECT opcode (IOS)
        out      STO$OPCD
        lda      @SECT              ; Select the sector number (LSB only)
        out      EXC$WR$OPCD
        ;
        ; Load into HL the address in @DMA
        LHLD     @DMA
        ret

        END
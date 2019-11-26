;********************************************************************************************
;
; LRDBIOS.ASM - S180918
; CP/M 3.0 CPMLDR BIOS FOR THE Z80-MBC2 (HW ref. A040618)
;
; Required IOS S220718-R190918 (or newer revisions until otherwise stated)
;
; NOTE: Use the RMAC.COM relocatable assembler
;
;
;
;********************************************************************************************


TRUE		EQU	-1		    ; DEFINE LOGICAL VALUES:
FALSE		EQU	NOT TRUE

BELL		EQU	07H
eos         EQU 00H         ; End of string
CR		    EQU	0DH
LF		    EQU	0AH

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

; INCLUDE CP/M 3.0 MACRO LIBRARY:

	MACLIB CPM3
	MACLIB	Z80

;--------------------------------------------------------------------------
;	                    CODE BEGINS HERE:
;--------------------------------------------------------------------------	

		JMP	BOOT		;<----- INITIAL ENTRY ON COLD START
		JMP	WBOOT		;REENTRY ON PROGRAM EXIT, WARM START
		JMP	CONST		;RETURN CONSOLE INPUT STATUS
		JMP	CONIN		;RETURN CONSOLE INPUT CHARACTER
		JMP	CONOUT		;<------------ SEND CONSOLE OUTPUT CHARACTER
		JMP	LIST		;SEND LIST OUTPUT CHARACTER
		JMP	AUXOUT		;SEND AUXILLIARY OUTPUT CHARACTER
		JMP	AUXIN		;RETURN AUXILLIARY INPUT CHARACTER
		JMP	HOME		;SET DISKS TO LOGICAL HOME
		JMP	SELDSK		;SELECT DISK DRIVE RETURN DISK PARAMETER INFO
		JMP	SETTRK		;SET DISK TRACK
		JMP	SETSEC		;SET DISK SECTOR
		JMP	SETDMA		;SET DISK I/O MEMORY ADDRESS
		JMP	READ		;<----------- READ PHYSICAL BLOCK(S)
		JMP	WRITE		;WRITE PHYSICAL BLOCK(S)
		JMP	LISTST		;RETURN LIST DEVICE STATUS
		JMP	SECTRN		;TRANSLATE LOGICAL TO PHYSICAL SECTOR
		JMP	CONOST		;RETURN CONSOLE OUTPUT STATUS
		JMP	AUXIST		;RETURN AUXILLIARY INPUT STATUS
		JMP	AUXOST		;RETURN AUXILLIARY OUTPUT STATUS
		JMP	DEVTBL		;RETURN ADDRESS OF DEVICE DEFINITION TABLE
		JMP	?CINIT		;CHANGE BAUD RATE OF DEVICE
		JMP	GETDRV		;RETURN ADDRESS OF DISK DRIVE TABLE
		JMP	MULTIO		;SET MULTIPLE RECORD COUNT FOR DISK I/O
		JMP	FLUSH		;FLUSH BIOS MAINTAINED DISK CACHING
		JMP	?MOVE		;BLOCK MOVE MEMORY TO MEMORY
		JMP	?TIME		;SIGNAL TIME AND DATE OPERATION
		JMP	BNKSEL		;SEL BANK FOR CODE EXECUTION AND DEFAULT DMA
		JMP	SETBNK		;SELECT DIFFERENT BANK FOR DISK I/O DMA OPS.
		JMP	?XMOVE		;SET SOURCE AND DEST. BANKS FOR ONE OPERATION
		JMP	0		    ;RESERVED FOR FUTURE EXPANSION
		JMP	0		    ;     DITTO
		JMP	0		    ;     DITTO


CONST:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

LISTST:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

AUXIST:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

AUXOST:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

FLUSH:		
        XRA	A		; ROUTINE HAS NO FUNCTION IN LOADER BIOS:
		RET			; RETURN A FALSE STATUS

LIST:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

AUXOUT:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

DEVTBL:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

?CINIT:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

MULTIO:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

?TIME:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

BNKSEL:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

SETBNK:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

?XMOVE:		
        RET			; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

CONIN:		
        MVI   A,'Z'-40H		; ROUTINE HAS NO FUNCTION IN LOADER BIOS:
		RET

AUXIN:		
        MVI   A,'Z'-40H		; ROUTINE HAS NO FUNCTION IN LOADER BIOS:
		RET

CONOUT:
        ; Write Console Character out. Output char is in C
        mvi     a, SERTX$OPC    ; A = SERIAL TX opcode
        out     STO$OPCD        ; Write the opcode
        mov     a, c
        out     EXC$WR$OPCD     ; Send A to serial Tx
        ret

CONOST:
        ; Return Output Status of Console. Return A=00H if not ready, A=0FFH if ready
        mvi     a, 0FFH         ; Always ready
        ret

?MOVE:		
        XCHG
		LDIR
		XCHG
		RET

SELDSK:		
        LXI	H,DPH0		    ; RETURN DPH ADDRESS FOR DRIVE A:
		RET

HOME:		
        LXI	B,0		        ; HOME SELECTED DRIVE -- TREAT AS SETTRK(0):

SETTRK:		
        SBCD	@TRK		; ROUTINE SETS TRACK TO ACCESS ON NEXT READ
		RET
	
SETSEC:		
        SBCD	@SECT		; ROUTINE SETS SECTOR TO ACCESS ON NEXT READ
		RET

SETDMA:		
        SBCD	@DMA		; ROUTINE SETS DISK MEMORY ADDRESS FOR READ
		RET

SECTRN:		
        MOV	L,C		        ; NO TRANSLATION FOR HDISK
		MOV	H,B
		RET

GETDRV:		
        LXI	H,@DTBL		    ; RETURN ADDRESS OF DISK DRIVE TABLE:
		RET

DCBINIT:	
        RET			        ; ROUTINE HAS NO FUNCTION IN LOADER BIOS:

WRITE:		
        XRA	A		        ; RETURN GOOD RESULT CODE
		RET

WBOOT:		
        RET			        ; WARM BOOT IS NOT USED IN LOADER BIOS

;--------------------------------------------------------------------------
;                                  BOOT
;                   ROUTINE DOES COLD BOOT INITIALIZATION:
;--------------------------------------------------------------------------


BOOT:
        lxi     h, BiosMsg      ; Print a message
        call    puts
		RET

;--------------------------------------------------------------------------------
;	   HARD DISK READ A SECTOR AT @TRK, @SECT TO Address at @DMA
;      Return A=00H if no Error, A=01H if Non-recov Err
;-------------------------------------------------------------------------------- 

READ:
        push     b
        push     h
        ;
        ; Select host disk 0
        lda      lastDsk            ; A = last disk number
        ora      a                  ; Set Z flag. Last disk = 0?
        jrz      setTrack           ; Yes, jump to track selection
        mvi      a, SELDISK$OPC     ; No, select SELDISK opcode (IOS)
        out      STO$OPCD
        xra      a                  ; Select the disk 0
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
        ; Read current host sector (512 byte) to DMA
        mvi     c, EXC$RD$OPCD      ; Set the EXECUTE READ OPCODE port into C
        lhld    @DMA                ; HL = DMA address
        mvi     a, RDSECT$OPC       ; Select READSECT opcode (IOS)
        out     STO$OPCD
        mvi     b, 0                ; Byte counter = 256
        inir                        ; Read 256 byte to hstbuf
        inir                        ; Read 256 byte to hstbuf
        ;
        ; Check for errors
        mvi     a, ERRDSK$OPC      ; Select ERRDISK opcode (IOS)
        out     STO$OPCD
        in      EXC$RD$OPCD         ; Read error code into A
        ora     a                   ; Set Z flag
        pop     h
        pop     b
        rz                          ; Return with A = 0 (no error)
        mvi     a, 1                ; Set error code
        ret                         ; Return with A = 1 (read error)
    
lastDsk:     DB   0ffH              ; Last disk number (= ff after cold boot)


;=============================================================================
;                          Z80-MBC2 SUPPORT ROUTINES
;============================================================================= 

; ---------------------------------------------------------------------------- ;
;
; Send a string to the serial line, HL holds the pointer to the string.
; NOTE: Only A and HL are used
;
; ---------------------------------------------------------------------------- ;

puts
        mov      a, m           ; A = (HL) = current char to print
        cpi      eos            ; End of string reached?
        rz                      ; Yes, return
        mvi      a, SERTX$OPC   ; A = SERIAL TX opcode
        out      STO$OPCD       ; Write the opcode
        mov      a, m           ; A = (HL) = current char to print
        out      EXC$WR$OPCD    ; Print A
        inx      h              ; Increment character pointer
        jr       puts           ; Transmit next character


; --------------------------------------------------------------------------- ;
;
; MESSAGES
;
; --------------------------------------------------------------------------- ;

BiosMsg     db     CR, LF, LF, 'Z80-MBC2 CPMLDR BIOS - S180918', CR, LF, eos

@TRK:		DS	2		;2 BYTES FOR NEXT TRACK TO READ OR WRITE
@DMA:		DS	2		;2 BYTES FOR NEXT DMA ADDRESS
@SECT		DS	2		;2 BYTES FOR SECTOR


;--------------------------------------------------------
; BUILD CPM3 DPH'S ETC USING MACROS FOR HDISK AND BY HAND
;--------------------------------------------------------
	
	; DISK DRIVE TABLE:
@DTBL:	DW	DPH0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0

	; DRIVE A DISK PARAMETER HEADER:
	DW	WRITE			;WRITE ROUTINE
	DW	READ			;READ ROUTINE
	DW	SELDSK			;LOGIN PROCEDURE
	DW	DCBINIT			;DRIVE INITIALIZATION ROUTINE
	DB	0			    ;RELATIVE DRIVE 0 ON THIS CONTROLLER
	DB	0			    ;MEDIA TYPE ALWAYS KNOWN FOR HARD DISK
DPH0:	DW	0			;TRANSLATION VECTOR
	DB	0,0,0,0,0,0,0,0,0
	DB	0			    ;MEDIA FLAG
	DW	HD$DPB			;ADDRESS OF DISK PARAMETER BLOCK
	DW	CSV			    ;CHECKSUM VECTOR
	DW	ALV			    ;ALLOCATION VECTOR
	DW	DIRBCB			;DIRECTORY BUFFER CONTROL BLOCK
	DW	DATABCB			;DATA BUFFER CONTROL BLOCK
	DW	0FFFFH			;NO HASHING
	DB	0			    ;HASH BANK

	; HARD DISK PARAMETER BLOCK:
    ; Bytes per sector, num sec, num trk, block size, dir entries, res trk, HD flag
     
HD$DPB:	    DPB	    512,32,512,4096,512,1,8000H

	; DIRECTORY BUFFER CONTROL BLOCK:
DIRBCB:
	DB	0FFH			;DRIVE 0
	DS	3
	DS	1
	DS	1
	DS	2
	DS	2
	DW	DIRBUF			;POINTER TO DIRECTORY BUFFER

	; DATA BUFFER CONTROL BLOCK:
DATABCB:
	DB	0FFH			;DRIVE 0
	DS	3
	DS	1
	DS	1
	DS	2
	DS	2
	DW	DATABUF			;POINTER TO DATA BUFFER


	; DIRECTORY BUFFER
DIRBUF:	DS	512			;1 PHYSICAL SECTOR

	; DATA BUFFER:
DATABUF:DS	512			;1 PHYSICAL SECTOR

	; DRIVE ALLOCATION VECTOR:
ALV:	 DS	1000		;SPACE FOR DOUBLE BIT ALLOCATION VECTORS
CSV:					;NO CHECKSUM VECTOR REQUIRED FOR A HDISK

	END
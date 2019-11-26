;********************************************************************************************
;
; MOVE.ASM - S290918
; CP/M 3.0 BANK & MOVE BIOS MODULE FOR THE Z80-MBC2 (HW ref. A040618)
;
; Required IOS S220718-R190918 (or newer revisions until otherwise stated)
;
; NOTE: Use the RMAC.COM relocatable assembler
;
;
;********************************************************************************************

	title 'bank & move module for CP/M3 linked BIOS'
    
	; DEFINE LOGICAL VALUES
TRUE		EQU	-1
FALSE		EQU	NOT TRUE

	; DETERMINE IF FOR BANK SELECT OR NOT
BANKED		EQU	TRUE	        ; <------ BANKED/NON-BANKED SWITCH

	; LOCATE CODE IN THE COMMON SEGMENT:
    ; --------------------------
	CSEG
    ; --------------------------

	; DEFINE PUBLIC LABELS
	public ?move,?xmove,?bank
    
    ; EXTERNALLY DEFINED ENTRY POINTS AND LABELS
	extrn @cbnk

	; INCLUDE Z-80 MACROS
	maclib z80
	;maclib ports
    
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
SETBANK$OPC  EQU    00DH      ; SETBANK opcode
SYSFLAG$OPC  EQU    083H      ; SYSFLAG opcode
DATETIM$OPC  EQU    084H      ; DATETIME opcode
ERRDSK$OPC   EQU    085H      ; ERRDISK opcode
RDSECT$OPC   EQU    086H      ; READSECT opcode
SDMOUNT$OPC  EQU    087H      ; SDMOUNT opcode


	; ROUTINE SETS UP AN INTER-BANK MOVE OF 128 BYTES ON THE NEXT CALL
	;  TO ?MOVE
?xmove:		            ; Interbank moves not implemented
	ret

    
	; ROUTINE PERFORMS INTRA-BANK MOVES IF ?XMOVE WAS NOT CALLED PRIOR TO
	;  THIS CALL TO ?MOVE ELSE A 128 BYTE TRANSFER IS CONDUCTED BETWEEN
	;  DIFFERENT BANKS
?move:
	xchg		        ; we are passed source in DE and dest in HL
	ldir		        ; use Z80 block move instruction
	xchg		        ; need next addresses in same regs
	ret

    
	; ROUTINE SWITCHES IN PHYSICAL BANK.
    ; ?BANK is called with the bank address in register A. This bank address has already been 
    ; stored in @CBNK for future reference. All registers except A must be maintained upon return.
?bank:
	IF	BANKED
    push    psw                 ; Save requested bank
    mvi     a, SETBANK$OPC      ; Select the SETBANK opcode
    out     STO$OPCD
    pop     psw                 ; A = bank number [0..2]
    out     EXC$WR$OPCD         ; Select it
	ENDIF
	ret

	end
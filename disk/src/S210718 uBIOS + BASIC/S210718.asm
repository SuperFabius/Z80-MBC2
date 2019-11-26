;**********************************************************************************
;
; Z80-MBC2 uBIOS for Basic - S210718 - HW ref: A040618
;
; Adapted from Grant Searle great work!
;
;
; NOTE: all changes in the following code are marked with this string "Z80-MBC2:" in the comment
;       (the basic.asm file is not modified)
;
;**********************************************************************************
;==================================================================================
; Contents of this file are copyright Grant Searle
;
; You have permission to use this for NON COMMERCIAL USE ONLY
; If you wish to use it elsewhere, please include an acknowledgement to myself.
;
; http://searle.hostei.com/grant/index.html
;
; eMail: home.micros01@btinternet.com
;
; If the above don't work, please perform an Internet search to see if I have
; updated the web page hosting service.
;
;==================================================================================

; Minimum 6850 ACIA interrupt driven serial I/O to run modified NASCOM Basic 4.7
; Full input buffering with incoming data hardware handshaking
; Handshake shows full before the buffer is totally filled to allow run-on from the sender

SER_BUFSIZE     .EQU     3FH
SER_FULLSIZE    .EQU     30H
SER_EMPTYSIZE   .EQU     5

RTS_HIGH        .EQU     0D6H
RTS_LOW         .EQU     096H

serBuf          .EQU     $2000
serInPtr        .EQU     serBuf+SER_BUFSIZE
serRdPtr        .EQU     serInPtr+2
serBufUsed      .EQU     serRdPtr+2
basicStarted    .EQU     serBufUsed+1
TEMPSTACK       .EQU     $20ED ; Top of BASIC line input buffer so is "free ram" when BASIC resets

CR              .EQU     0DH
LF              .EQU     0AH
CS              .EQU     0CH             ; Clear screen

                .ORG $0000
;------------------------------------------------------------------------------
; Reset

RST00           DI                       ;Disable interrupts
                JP       INIT            ;Initialize Hardware and go

;------------------------------------------------------------------------------
; TX a character over RS232 

                .ORG     0008H
RST08            JP      TXA

;------------------------------------------------------------------------------
; RX a character over RS232 Channel A [Console], hold here until char ready.

                .ORG 0010H
RST10            JP      RXA

;------------------------------------------------------------------------------
; Check serial status

                .ORG 0018H
RST18            JP      CKINCHAR

;------------------------------------------------------------------------------
; RST 38 - INTERRUPT VECTOR [ for IM 1 ]

                .ORG     0038H
RST38            JR      serialInt       

;------------------------------------------------------------------------------
serialInt:      PUSH     AF
                PUSH     HL

                ;IN       A,($80)         ; Z80-MBC2: No buffer full to check here
                ;AND      $01             ; Check if interupt due to read buffer full
                ;JR       Z,rts0          ; if not, ignore

                IN       A,($01)         ; Z80-MBC2: Changed port addr from $81 to $01
                PUSH     AF
                LD       A,(serBufUsed)
                CP       SER_BUFSIZE     ; If full then ignore
                JR       NZ,notFull
                POP      AF
                JR       rts0

notFull:        LD       HL,(serInPtr)
                INC      HL
                LD       A,L             ; Only need to check low byte becasuse buffer<256 bytes
                CP       (serBuf+SER_BUFSIZE) & $FF
                JR       NZ, notWrap
                LD       HL,serBuf
notWrap:        LD       (serInPtr),HL
                POP      AF
                LD       (HL),A
                LD       A,(serBufUsed)
                INC      A
                LD       (serBufUsed),A
                CP       SER_FULLSIZE
                JR       C,rts0
                ;LD       A,RTS_HIGH     ; Z80-MBC2: No RTS HW handshackig here
                ;OUT      ($80),A
rts0:           POP      HL
                POP      AF
                EI
                RETI

;------------------------------------------------------------------------------
RXA:
waitForChar:    LD       A,(serBufUsed)
                CP       $00
                JR       Z, waitForChar
                PUSH     HL
                LD       HL,(serRdPtr)
                INC      HL
                LD       A,L             ; Only need to check low byte becasuse buffer<256 bytes
                CP       (serBuf+SER_BUFSIZE) & $FF
                JR       NZ, notRdWrap
                LD       HL,serBuf
notRdWrap:      DI
                LD       (serRdPtr),HL
                LD       A,(serBufUsed)
                DEC      A
                LD       (serBufUsed),A
                CP       SER_EMPTYSIZE
                JR       NC,rts1
                ;LD       A,RTS_LOW       ; Z80-MBC2: No RTS HW handshackig here
                ;OUT      ($80),A
rts1:
                LD       A,(HL)
                EI
                POP      HL
                RET                      ; Char ready in A

;------------------------------------------------------------------------------
TXA:            
conout1:        PUSH     AF              ; Store character
				;IN       A,($80)         ; Z80-MBC2: No TX status needed here ;Status byte       
                ;BIT      1,A             ; Set Zero flag if still transmitting character       
                ;JR       Z,conout1       ; Loop until flag signals ready
                LD       A,$01           ; Z80-MBC2: (Added) A = Serial TX Operation Code
                OUT      ($01),A         ; Z80-MBC2: (Added) Write the Serial TX Opcode to IOS
                POP      AF              ; Retrieve character
                OUT      ($00),A         ; Z80-MBC2: Changed port addr from $81 to $01 ; Output the character
                RET

;------------------------------------------------------------------------------
CKINCHAR        LD       A,(serBufUsed)
                CP       $0
                RET

PRINT:          LD       A,(HL)          ; Get character
                OR       A               ; Is it $00 ?
                RET      Z               ; Then RETurn on terminator
                RST      08H             ; Print it
                INC      HL              ; Next Character
                JR       PRINT           ; Continue until $00
                RET
;------------------------------------------------------------------------------
INIT:
               LD        HL,TEMPSTACK    ; Temp stack
               LD        SP,HL           ; Set up a temporary stack
               LD        HL,serBuf
               LD        (serInPtr),HL
               LD        (serRdPtr),HL
               XOR       A               ;0 to accumulator
               LD        (serBufUsed),A
               ;LD        A,RTS_LOW       ; Z80-MBC2: Nothing to initialize 
               ;OUT       ($80),A         ; Initialise ACIA
               IM        1
               EI
               LD        HL,SIGNON1      ; Sign-on message
               CALL      PRINT           ; Output string
               LD        A,(basicStarted); Check the BASIC STARTED flag
               CP        'Y'             ; to see if this is power-up
               JR        NZ,COLDSTART    ; If not BASIC started then always do cold start
               LD        HL,SIGNON2      ; Cold/warm message
               CALL      PRINT           ; Output string
CORW:
               CALL      RXA
               AND       %11011111       ; lower to uppercase
               CP        'C'
               JR        NZ, CHECKWARM
               RST       08H
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
COLDSTART:     LD        A,'Y'           ; Set the BASIC STARTED flag
               LD        (basicStarted),A
               JP        $0150           ; Start BASIC COLD
CHECKWARM:
               CP        'W'
               JR        NZ, CORW
               RST       08H
               LD        A,$0D
               RST       08H
               LD        A,$0A
               RST       08H
               JP        $0153           ; Start BASIC WARM
              
SIGNON1:       ;.BYTE     CS              ; Z80-MBC2: Changed SIGNON1 string
               .BYTE     "uBIOS - S210718 (Adapted from Z80 SBC by G. Searle)",CR,LF,0
SIGNON2:       .BYTE     CR,LF            ; Z80-MBC2: Changed SIGNON2 string
               .BYTE     "uBIOS: Cold or warm start (C/W)?",0
               
               .org      $14f            ; Z80-MBC2: Last byte for this uBIOS (BASIC starts next one)!
LastByte:      .byte     $00
  
               .END

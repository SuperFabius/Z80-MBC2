;**********************************************************************************
;
; Z80-MBC2 - HW ref: A040618
;
; Systick and Serial Rx IRQ test. The user led blinks using the Systick IRQ while
; any char enterd on the serial port is echoed to the serial port itself.
; The Serial Rx IRQ is used to read a char from the serial port.
;
; REQUIRED: IOS S220718-R120519_DEVEL4 (or following revisions until stated otherwise).
;
; Assemble with: tasm -h -c -g0 -80  file_source.asm  file_output.hex
;
; TASM assembler can be found here: https://www.ticalc.org/archives/files/fileinfo/250/25051.html
; TASM manual can be found here: http://www.cpcalive.com/docs/TASMMAN.HTM
;
;
; *********************************************************************************
; *********************************************************************************
; THIS TEST IS INTENDED ONLY TO SHOW THE USE OF THE SHARED IRQ SCHEME OF 
; IOS S220718-R120519_DEVEL4 AND THE USE OF SETIRQ, SYSIRQ AND SETTICK OPCODES.
; *********************************************************************************
; *********************************************************************************
; 
;
;**********************************************************************************

CR              .EQU     0DH
LF              .EQU     0AH
eos             .EQU     0               ; End of string
prompt          .EQU     '>'             ; Prompt char

;
; IOS ports and Opcodes definitions (IOS S220718-R120519_DEVEL4)
;

;.........................................................................................................
;
;         Currently defined Opcodes for I/O write operations (IOS S220718-R120519_DEVEL4):
;
;           Opcode     Name            Exchanged bytes
;         -------------------------------------------------
;         Opcode 0x00  USER LED        1
;         Opcode 0x01  SERIAL TX       1
;         Opcode 0x03  GPIOA Write     1
;         Opcode 0x04  GPIOB Write     1
;         Opcode 0x05  IODIRA Write    1
;         Opcode 0x06  IODIRB Write    1
;         Opcode 0x07  GPPUA Write     1
;         Opcode 0x08  GPPUB Write     1
;         Opcode 0x09  SELDISK         1
;         Opcode 0x0A  SELTRACK        2
;         Opcode 0x0B  SELSECT         1  
;         Opcode 0x0C  WRITESECT       512
;         Opcode 0x0D  SETBANK         1
;         Opcode 0x0E  SETIRQ          1   
;         Opcode 0x0F  SETTICK         1   
;         Opcode 0xFF  No operation    1
;
;
;         Currently defined Opcodes for I/O read operations (IOS S220718-R120519_DEVEL4):
;
;           Opcode     Name            Exchanged bytes
;         -------------------------------------------------
;         Opcode 0x80  USER KEY        1
;         Opcode 0x81  GPIOA Read      1
;         Opcode 0x82  GPIOB Read      1
;         Opcode 0x83  SYSFLAGS        1
;         Opcode 0x84  DATETIME        7
;         Opcode 0x85  ERRDISK         1
;         Opcode 0x86  READSECT        512
;         Opcode 0x87  SDMOUNT         1
;         Opcode 0x88  ATXBUFF         1   
;         Opcode 0x89  SYSIRQ          1   
;         Opcode 0xFF  No operation    1
;
;.........................................................................................................

ExecRd_port     .EQU    00H              ; IOS Execute Read Opcode read port
ExecWr_port     .EQU    00H              ; IOS Execute Write Opcode write port
Rx_port         .EQU    01H              ; IOS Serial Rx read port
StorOpc_port    .EQU    01H              ; IOS Store Opcode write port
;
UsrLed_opc      .EQU    00H              ; IOS User Led Opcode
Tx_opc          .EQU    01H              ; IOS Serial Tx Opcode
SETIRQ_opc      .EQU    0EH              ; IOS SETIRQ Opcode
SETTICK_opc     .EQU    0FH              ; IOS SETTICK Opcode
SYSIRQ_opc      .EQU    89H              ; IOS SYSIRQ Opcode

;
; IOS S220718-R120519_DEVEL4: Set Systick values
;
TICKLED         .EQU     200             ; How many Systick events to toggle the User led [1..255]
TICKTIME        .EQU     1               ; Sysytick IRQ time in milliseconds [1..255]

;------------------------------------------------------------------------------

                .ORG     0

Start:          DI                       ;Disable interrupts
                JP       INIT

;------------------------------------------------------------------------------
; RST 38 - INTERRUPT VECTOR (for IM 1)
;
; ISR for the shared IRQ
;

                .ORG     0038H

                PUSH     AF
                PUSH     HL
                ;
                ; Check which SisTick IRQ flag is set
                ;
                LD       A,SYSIRQ_opc    ; A = SYSIRQ Opcode
                OUT      (StorOpc_port),A; Write the Opcode to IOS
                IN       A,(ExecRd_port) ; Read the SYSIRQ status byte in A
                LD       H,A             ; Save the SYSIRQ status byte in H
                AND      $02             ; Systick IRQ mask
                JR       Z, RxIRQCK      ; Jump to serial Rx IRQ check if Systick IRQ bit is not set
                ;
                ; Systick ISR (User led blink)
                ;
                LD       A,(TickCount)   ; Decrement TickCount
                DEC      A
                LD       (TickCount),A
                JR       NZ,RxIRQCK      ; Jump if TickCount not zero
                LD       a,TICKLED       ; Reload TickCount
                LD       (TickCount),A
                LD       A,(UserLedStat) ; Change the User Led status
                XOR      1
                LD       (UserLedStat),A
                LD       L,A
                LD       A,UsrLed_opc    ; A = USERLED Opcode
                OUT      (StorOpc_port),A; Write the Opcode to IOS
                LD       A,L
                OUT      (ExecWr_port),A ; Write the value
                ;
                ; Check if serial Rx IRQ flag is set
                ;
RxIRQCK:        LD       A,H             ; A = SYSIRQ status byte
                AND      $01             ; Serial Rx IRQ mask
                JR       Z,RxISREnd      ; Jump if serial Rx IRQ bit is not set
                ;
                ; Serial Rx ISR
                ;
                IN       A,(Rx_port)     ; Read a char from serial port
                LD       (RxChar), A     ; Save it
                XOR      A               ; Clear A
                SET      0, A            ; Set the Rx char ready flag
                LD       (RxCharFlg), A  ; Save it
RxISREnd:       POP      HL
                POP      AF
                EI
                RETI

;------------------------------------------------------------------------------
;
; Read a char in A from the serial port, or wait for  char.
; NOTE: There is a read rx buffer on the Atmega side, so no buffer here.
;

GetChar:    
                LD       A,(RxCharFlg)
                CP       0
                JR       Z, GetChar      ; Wait for a char
                XOR      A
                DI                       ; Must be an atomic events, so IRQ disbled
                LD       (RxCharFlg), A  ; Clear the Rx char ready flag
                LD       A, (RxChar)
                EI                       ; Now IRQ can be enabled again
                RET                      ; Rx char ready in A

;------------------------------------------------------------------------------
;
; Send to the serial port a char in A.
;

PutChar:            
                PUSH     AF              ; Store character
                LD       A,Tx_opc        ; A = Serial TX Opcode
                ;
                DI                       ; WARNING!: Opcodes must be an atomic event
                OUT      (StorOpc_port),A; Write the Serial TX Opcode to IOS
                POP      AF              ; Retrieve character
                OUT      (ExecWr_port),A ; Output the character
                EI                       ; Opcode executed, so re-enable IRQ
                ;
                RET

;------------------------------------------------------------------------------
;
; Send a string to the serial line, HL contains the pointer to the string.
; NOTE: Only A and HL are used.
;

PutStr:
                LD      A, (HL)         ; A = current char to print
                CP      eos             ; End of string reached?
                JR      Z, puts_end     ; Yes, jump
                CALL    PutChar         ; No, print it
                INC     HL              ; Increment character pointer
                JR      PutStr          ; Transmit next character

puts_end:       RET

;------------------------------------------------------------------------------

INIT:
               LD        HL,Stack
               LD        SP,HL           ; Set up a stack
               ;
               ; IOS S220718-R120519_DEVEL4: Set Systick time
               ;
               LD       A,SETTICK_opc   ; A = SETTICK Opcode
               OUT      (StorOpc_port),A; Write the Opcode to IOS
               LD       A, TICKTIME     ; Set the Sysytick time
               OUT      (ExecWr_port),A ; Write it to the IOS EXECUTE_WRITE_OPCODE port
               ;
               ; IOS S220718-R120519_DEVEL4: Enable both Systick IRQ and Serial Rx IRQ
               ;
               LD       A,SETIRQ_opc    ; A = SETIRQ Opcode
               OUT      (StorOpc_port),A; Write the Opcode to IOS
               LD       A, 3            ; Set the all IRQ enabled
               OUT      (ExecWr_port),A ; Write it to the IOS EXECUTE_WRITE_OPCODE port
               ;
               IM        1              ; Enable Z80 IRQ mode 1
               EI
               LD        HL, Msg1       ; Print a message
               CALL      PutStr
               LD        A, prompt      ; Print the prompt
               CALL      PutChar
               ;
               ; Echo test
               ;
EchoLoop:      CALL      GetChar
               CALL      PutChar
               JR        EchoLoop        ; For ever
               
;------------------------------------------------------------------------------
              
TickCount      .DB       TICKLED
UserLedStat    .DB       0
RxChar         .DB       0
RxCharFlg      .DB       0
Msg1           .DB       CR, LF, "Z80-MBC2 - HW ref: A040618", CR , LF, LF
               .DB       "Echo test using the serial port (while User led is blinking using Systick IRQ).", CR , LF
               .DB       "Required IOS S220718-R120519_DEVEL4.",  CR , LF
               .DB       "Systick timer set at 1ms.", CR , LF
               .DB       "Any entered char on the serial port is echoed on the serial port itself.", CR , LF, LF, eos
               .ORG      $+64            ; Stack area
Stack:

               .END

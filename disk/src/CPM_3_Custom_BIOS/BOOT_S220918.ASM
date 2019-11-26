;********************************************************************************************
;
; BOOT.ASM - S220918
; CP/M 3.0 BOOT LOADER BIOS MODULE FOR THE Z80-MBC2 (HW ref. A040618)
;
; Required IOS S220718-R190918 (or newer revisions until otherwise stated)
;
; NOTE: Use the RMAC.COM relocatable assembler
;
;
;
;********************************************************************************************

    TITLE   'BOOT LOADER MODULE FOR CP/M 3.0 - Z80-MBC2 (A040618)'

    ; DEFINE LOGICAL VALUES:
TRUE        EQU -1
FALSE       EQU NOT TRUE

    ; DETERMINE IF FOR BANK SELECT OR NOT:
BANKED      EQU TRUE               ; <------ BANKED/NON-BANKED SWITCH

    ; DEFINE PUBLIC LABELS:
    PUBLIC  ?INIT,?LDCCP,?RLCCP,?TIME
    ;PUBLIC  OUT$BLOCKS

    ; EXTERNALLY DEFINED ENTRY POINTS AND LABELS:
    EXTRN   ?PMSG,?CONIN
    EXTRN   @CIVEC,@COVEC,@AIVEC,@AOVEC,@LOVEC
    EXTRN   @CBNK,?BNKSL
    EXTRN   @SEC,@MIN,@HOUR,@DATE   ;FIELDS HOLDING CURRENT TIME AND DATE

    ; INCLUDE Z-80 MACROS:
    MACLIB  Z80

    ; SOME MISCELLANEOUS EQUATES:
BDOS    EQU 5
CR      EQU 13          ; ASCII CARRIAGE RETURN
LF      EQU 10          ; ASCII LINEFEED

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


    ; WE CAN DO INITIALIZATION FROM BANKED MEMORY (IF WE HAVE IT):
    IF  BANKED
    ; --------------------------
    DSEG                ; INIT DONE FROM BANKED MEMORY
    ; --------------------------
    ELSE
    ; --------------------------
    CSEG                ; INIT TO BE DONE FROM COMMON MEMORY
    ; --------------------------
    ENDIF

    ; HARDWARE INITIALIZATION OTHER THAN CHARACTER AND DISK I/O
    
?INIT:
    ; ASSIGN CONSOLE INPUT AND OUTPUT TO CRT:
    LXI H,8000H         ;SIGNIFIES DEVICE 0
    SHLD    @CIVEC      ;CONSOLE INPUT VECTOR
    SHLD    @COVEC      ;CONSOLE OUTPUT VECTOR
    
    ; PRINT THE SIGN-ON MESSAGE:
    LXI H,SIGNON$MSG    ;POINT TO IT
    JMP ?PMSG           ;AND PRINT IT
    ; Note: "RET" here is not needed because we use the that one at the end of ?PMSG

    IF  BANKED
    ; --------------------------
    CSEG
    ; --------------------------
    ENDIF

    ; THIS ROUTINE IS ENTERED TO LOAD THE CCP.COM FILE INTO THE TPA BANK
    ;  AT SYSTEM COLD START
    
?LDCCP:
    ; SET UP THE FCB FOR THE FILE OPERATION
    ; NOTE: If banked at this point bank 1 is alredy selected
    ; (see BIOSKRNL.ASM)
    XRA A               ;ZERO EXTENT
    STA CCP$FCB+15
    LXI H,0             ;START AT BEGINNING OF FILE
    SHLD    FCB$NR

    ; TRY TO OPEN THE CCP.COM FILE:
    LXI D,CCP$FCB       ;POINT TO FCB
    CALL    OPEN        ;ATTEMPT THE OPEN OPERATION
    INR A               ;WAS IT ON THE DISK ?
    JRNZ    CCP$FOUND   ;YES -- GO LOAD IT

    ; WE ARRIVE HERE WHEN CCP.COM FILE WASN'T FOUND:
    LXI H,CCP$MSG       ;REPORT THE ERROR
    CALL    ?PMSG
    CALL    ?CONIN      ;GET A RESPONSE
    JR  ?LDCCP          ;AND TRY AGAIN

    ; FILE WAS OPENED OK -- READ IT IN:
CCP$FOUND:
    LXI D,0100H         ;LOAD AT BOTTOM OF TPA
    CALL    SETDMA      ;BY SETTING THE NEXT DMA ADDRESS
    LXI D,128           ;SET MULTI SECTOR I/O COUNT
    CALL    SETMULTI    ; TO ALLOW UP TO 16K BYTES IN ONE OPERATION
    LXI D,CCP$FCB       ;POINT TO THE FCB
    CALL    READ        ;AND READ THE CCP IN
    RET

    ; ROUTINE RELOADS CCP IMAGE FROM BANK 2 IF BANKED SYSTEM OR FROM THE
    ;  DISK IF NON-BANKED VERSION
    
?RLCCP:
    JMP ?LDCCP          ;JUST DO LOAD AS THOUGH COLD BOOT

; --------------------------------------------------------------------------------
;    
; SETS/GETS TIME (Z80-MBC2)
;
; The time of day is kept as four fields. 
; @DATE is a binary word containing the number of days since 31 December 1977. 
; The bytes @HOUR, @MIN, and @SEC in the System Control Block contain the 
; hour, minute, and second in Binary Coded Decimal (BCD) format.
;
; C = Get/Set Flag
; C=000H if get, C=0FFH if set
; (see Appendix J, Table J-1 of CP/M 3 System Guide)
;
; NOTE1: Only the Get function is implemented. 
;        To change RTC date/time use the IOS "SELECT BOOT MODE OR SYSTEM PARAMETERS" menu.
; NOTE2: Because the IOS RTC year is from 00 to 99 only date from 1-1-2000 to 31-12-2099
;        are valid for this algorithm (I think that it's enough...)
;
; --------------------------------------------------------------------------------

?TIME:
    ;
    ; Check if it is a get time operation
    mov     a, c
    ora     a                   ; Get/Set Flag = 0?
    rnz                         ; Return if it is a Set Time request
    ;
    ; Check if the RTC module is present
    mvi     a, SYSFLAG$OPC      ; Select SYSFLAG opcode
    out     STO$OPCD    
    in      EXC$RD$OPCD         ; A = SYSFLAG
    ani     02h                 ; Isolate the RTC flag bit
    rz                          ; Return if the RTC is not present
    push    b
    push    d
    push    h
    ;
    ; Load date/time from the RTC to RTCBUFF
    mvi     a, DATETIM$OPC      ; Select DATETIME opcode
    out     STO$OPCD    
    mvi     c, EXC$RD$OPCD      ; C = EXECUTE READ opcode
    lxi     h, RTCBUFF          ; HL -> RTC Buffer
    mvi     b, 6                ; Byte counter = 6
    inir                        ; Read date/time to RTCBUFF
    ;
    ; Update @SEC (BCD)
    lxi     b, RTCBUFF          ; BC -> RTC seconds
    ldax    b                   ; A = RTC seconds (binary)
    call    bin2bcd             ; Binary to BCD
    sta     @SEC                ; Store it into @SEC
    ;
    ; Update @MIN (BCD)
    inx     b                   ; BC -> RTC minutes
    ldax    b                   ; A = RTC minutes (binary)
    call    bin2bcd             ; Binary to BCD
    sta     @MIN                ; Store it into @MIN
    ;
    ; Update @HOUR (BCD)
    inx     b                   ; BC -> RTC hours
    ldax    b                   ; A = RTC hours (binary)
    call    bin2bcd             ; Binary to BCD
    sta     @HOUR               ; Store it into @HOUR
    ;
    ; Calculate how many whole years elapsed from 31-12-1977 to now
    lda     RTCYEAR
    adi     22
    mov     c, a                ; C = elapsed_years = (RTCYEAR) + 22
    ;
    ; Convert it in days into HL (16 bit)
    xra     a                   ; A = 0
    mov     b, a                ; B = 0. BC = elapsed_years (16bit)
    lxi     d, 365              ; DE = 365
    call    Mult16              ; HL = elapsed_years * 365 = elapsed_years_days
    ;
    ; Calculate how many whole leap years elapsed from 31-12-1977 to now
    ;  (current year excluded) and add it to elapsed_years_days
    lda     RTCYEAR
    ora     a
    jrz     addleapyrs          ; If RTCYEAR = 00 -> A = 0
    dcr     a                   ; If RTCYEAR > 00 -> A = (RTRYEAR) - 1
    srlr    a                   ; / 2S
    srlr    a                   ; / 4
    inr     a                   ; If RTCYEAR > 00 -> A = (((RTCYEAR) - 1) / 4) + 1 =
                                ;  leap years from 31-12-1999 to now (current year excluded)
addleapyrs:
    adi     5                   ; Add leap years from 31-12-1977 to 31-12-1999
    mov     c, a                ; C = elapsed_leap_years = (((RTCYEAR) - 1) / 4) + 1 + 5
    xra     a                   ; A = 0
    mov     d, a                ; D = 0
    mov     b ,a                ; B = 0. BC = elapsed_leap_years (16bit)
    dad     b                   ; HL = elapsed_years_days + elapsed_leap_years
    ;
    ; Add days of current month
    lda     RTCDAY
    mov     c, a                ; BC = days_of_current_month (16bit)
    dad     b                   ; Add to HL days_of_current_month (BC)
    lda     RTCMONTH            ; A = current_month
    dcr     a                   ; A = Number_of_months_before_current
    jrz     checkCurrYear       ; Jump if Number_of_months_before_current = 0
    ;
    ; Add days of all previous months of current year, starting with January
    lxi     b, MONTHTAB         ; BC -> days_of_month (starting from Jan)
addDays:
    push    a                   ; Save A = Number_of_months_before_current
    ldax    b                   ; A = days_of_month (month pointed by BC)
    mov     e, a                ; DE = days of month (16bit)
    dad     d                   ; Add it to HL
    inx     b                   ; BC -> next month
    pop     a
    dcr     a                   ; There is an other month?
    jrnz    addDays             ; Jump if there is an other month to compute
    ;
    ; If current year is a leap year and current month is > February add one day
    ; to HL
checkCurrYear:
    lda     RTCMONTH
    cpi     3                   ; Current month < March?
    jrc     TIMEend             ; Jump if yes
    lda     RTCYEAR             ; No, check if current year is leap
    mov     b, a                ; A = B = current year
    srlr    a                   ; / 2
    srlr    a                   ; / 4
    slar    a                   ; * 2
    slar    a                   ; * 4
    cmp     b                   ; A = B if A is leap
    jrnz    TIMEend             ; Jump if not leap
    inx     h                   ; Add 1 to HL
TIMEend:
    ;
    ; All done, store days from 31-12-1977 to now into @DATE
    shld    @DATE               ; Store the date in days from CP/M epoch
    pop     h
    pop     d
    pop     b
    ret
    
MONTHTAB:
    DB      31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30  ; Only Jan-Nov needed
    
; Multiply 16-bit values (with 16-bit result)
; In: Multiply BC with DE
; Out: HL = result
;
Mult16: 
    mov     a,  b
    mvi     b, 16
Mult16Loop:
    dad     h
    slar    c
    ral
    jrnc    Mult16NoAdd
    dad     d
Mult16NoAdd:
    djnz    Mult16Loop
    ret    
    
; BIN to BCD conversion
;    a(BIN) =>  a(BCD) 
;   [0..99] => [00h..99h]
;
bin2bcd:
    push    b
    mvi     b,10
    mvi     c,-1
div10:  
    inr     c
    sub     b
    jrnc    div10
    add     b
    mov     b, a
    mov     a, c
    add     a
    add     a
    add     a
    add     a
    ora     b
    pop     b
    ret
    
RTCBUFF:                        ; Buffer for the RTC data (binary)
    DB  1                       ; Seconds [0..59]
    DB  1                       ; Minutes [0..59]
    DB  1                       ; Hours [0..23]
RTCDAY;
    DB  1                       ; Day [1..31]
RTCMONTH:
    DB  1                       ; Month [1..12]
RTCYEAR:
    DB  1                       ; Year [0..99]
    
; --------------------------------------------------------------------------------

    IF  BANKED
    ; --------------------------
    CSEG
    ; --------------------------
    ENDIF

    ; CP/M BDOS FUNCTION INTERFACES

    ; OPEN FILE:
OPEN:
    MVI C,15 ! JMP BDOS     ; OPEN FILE CONTROL BLOCK

    ; SET DMA ADDRESS:
SETDMA:
    MVI C,26 ! JMP BDOS     ; SET DATA TRANSFER ADDRESS

    ; SET MULTI SECTOR I/O COUNT:
SETMULTI:
    MVI C,44 ! JMP BDOS     ; SET RECORD COUNT

    ; READ FILE RECORD:
READ:
    MVI C,20 ! JMP BDOS     ; READ RECORDS

    ; CCP NOT FOUND ERROR MESSAGE:
CCP$MSG:
    DB  CR,LF,'BIOS ERR ON A: NO CCP.COM FILE',0


    ; FCB FOR CCP.COM FILE LOADING:
CCP$FCB:
    DB  1                   ;AUTO-SELECT DRIVE A
    DB  'CCP     COM'       ;FILE NAME AND TYPE
    DB  0,0,0,0
    DS  16
FCB$NR: DB  0,0,0

    ; SYSTEM SIGN-ON MESSAGE:
SIGNON$MSG:
    DB  CR,LF,'Z80-MBC2 128KB '
    DB  '(Banked) CP/M V3.0'
    DB  CR,LF,'Z80-MBC2 BIOS Modules: S200918, S210918, S220918, S290918'
    DB  CR,LF,LF,0

    END
;==============================================================================
;
; Z80-MBC2 (HW ref: A040618) CP/M 2.2 Custom BIOS - S030818-R040218
;
;
; NOTE: This CBIOS requires IOS S220718-R260119 (or following revisions until otherwise stated)
;
;
; CHANGELOG:
;
; S030818           First release
; S030818-R040219   Changed CONST_ and CONIN_ to allow full 8 bit data I/O
;
;==============================================================================

; CP/M addresses
CCP         = CBASE          ; CP/M System entry
BDOS        = CCP + $806     ; BDOS entry
BIOS        = CCP + $1600    ; BIOS entry
IOBYT       = $0003          ; IOBYTE address
CDISK       = $0004          ; Address of Current drive name and user number
CCPLEN      = CBASE + 7      ; Address of current number of chars into the CCP input buffer
CCPFIRS     = CBASE + 8      ; Address of the first charater of the CCP input buffer

; BIOS equates
NDISKS      .equ    16       ; Number of Disk Drives

; Commons ASCII chars
eos         .equ    $00      ; End of string
cr          .equ    $0d      ; Carriage return
lf          .equ    $0a      ; Line feed

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

; Blocking and deblocking algorithm equates
; (see CP/M 2.2 Alteration Guide p.34 and APPENDIX G)
blksiz      .equ    4096            ;CP/M allocation size
hstsiz      .equ    512             ;host disk sector size
hstspt      .equ    32              ;host disk sectors/trk
hstblk      .equ    hstsiz/128      ;CP/M sects/host buff
cpmspt      .equ    hstblk * hstspt ;CP/M sectors/track
secmsk      .equ    hstblk-1        ;sector mask
wrall       .equ    0               ;write to allocated
wrdir       .equ    1               ;write to directory
wrual       .equ    2               ;write to unallocated


    .org BIOS

; =========================================================================== ;
;                                                                             ;
; BIOS jump table                                                             ;
;                                                                             ;
; =========================================================================== ;

BOOT
    jp BOOT_    ; COLD START
WBOOT
WBOOTE
    jp WBOOT_   ; WARM START
CONST
    jp CONST_   ; CONSOLE STATUS
CONIN
    jp CONIN_   ; CONSOLE CHARACTER IN
CONOUT
    jp CONOUT_  ; CONSOLE CHARACTER OUT
LIST
    jp LIST_    ; LIST CHARACTER OUT
PUNCH
    jp PUNCH_   ; PUNCH CHARACTER OUT
READER
    jp READER_  ; READER CHARACTER OUT
HOME
    jp HOME_    ; MOVE HEAD TO HOME POSITION
SELDSK
    jp SELDSK_  ; SELECT DISK
SETTRK
    jp SETTRK_  ; SET TRACK NUMBER
SETSEC
    jp SETSEC_  ; SET SECTOR NUMBER
SETDMA
    jp SETDMA_  ; SET DMA ADDRESS
READ
    jp READ_    ; READ DISK
WRITE
    jp WRITE_   ; WRITE DISK
PRSTAT
    jp LISTST_  ; RETURN LIST STATUS
SECTRN
    jp SECTRN_  ; SECTOR TRANSLATE
    

; =========================================================================== ;
;                                                                             ;
; Disk parameter headers for disk 0 to 15                                     ;
;                                                                             ;
; =========================================================================== ;


dpbase
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb0,0000h,alv00
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv01
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv02
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv03
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv04
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv05
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv06
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv07
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv08
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv09
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv10
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv11
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv12
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv13
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv14
        .DW 0000h,0000h,0000h,0000h,dirbuf,dpb,0000h,alv15

; First drive has one reserved track for CP/M
dpb0
        .DW 128 ;SPT - 128 bytes sectors per track (= 32 sectors of 512 bytes)
        .DB 5   ;BSH - block shift factor
        .DB 31  ;BLM - block mask
        .DB 1   ;EXM - Extent mask
        .DW 2043 ; (2047-4) DSM - Storage size (blocks - 1)
        .DW 511 ;DRM - Number of directory entries - 1
        .DB 240 ;AL0 - 1 bit set per directory block
        .DB 0   ;AL1 -            "
        .DW 0   ;CKS - DIR check vector size (DRM+1)/4 (0=fixed disk)
        .DW 1   ;OFF - Reserved tracks

dpb
        .DW 128 ;SPT - 128 bytes sectors per track (= 32 sectors of 512 bytes)
        .DB 5   ;BSH - block shift factor
        .DB 31  ;BLM - block mask
        .DB 1   ;EXM - Extent mask
        .DW 2047 ;DSM - Storage size (blocks - 1)
        .DW 511 ;DRM - Number of directory entries - 1
        .DB 240 ;AL0 - 1 bit set per directory block
        .DB 0   ;AL1 -            "
        .DW 0   ;CKS - DIR check vector size (DRM+1)/4 (0=fixed disk)
        .DW 0   ;OFF - Reserved tracks


; =========================================================================== ;
; BOOT                                                                        ;
; =========================================================================== ;
; The BOOT entry point gets control from the cold start loader and is         ;
; responsible for basic system initialization, including sending a sign-on    ;
; message, which can be omitted in the first version.                         ;
; If the IOBYTE function is implemented, it must be set at this point.        ;
; The various system parameters that are set by the WBOOT entry point must be ;
; initialized, and control is transferred to the CCP at 3400 + b for further  ;
; processing. Note that register C must be set to zero to select drive A.     ;
; =========================================================================== ;
BOOT_
    xor     a
    ld      (IOBYT),a       ; Clear IOBYTE
    ld      (CDISK),a       ; Select Disk 0 & User 0
    ld      hl,BiosMsg      ; Print a message
    call    puts
    ;
    ; Set up the execution of AUTOEXEC.SUB if required
    ;
    ld      a, SYSFLAG_OPC  ; A = SYSFLAG opcode
    out     (STO_OPCD), a   ; Write the opcode
    in      a, (EXC_RD_OPCD); Check if AUTOEXEC execution is requierd
    and     $01             ; Isolate AUTOEXEC flag
    jr      z, GOCPM        ; Jump if flag = 0 (nothing to set up)
    ld      bc, CCPAuto     ; Flag = 1, BC = address of AUTOEXEC command string
    ld      hl, CCPFIRS     ; HL = address of the first char of CCP input string
bufCopy     ; Copy the AUTOEXEC command string into the CCP input buffer
    ld      a, (bc)         ; A = current command string char
    cp      eos             ; End of string reached?
    jr      z, bufCopyEnd   ; Yes, jump
    ld      (hl), a         ; No, load it the CCP input buffer
    inc     bc              ; Increment command string character pointer
    inc     hl              ; Increment CCP input buffer character pointer
    jr      bufCopy         ; Copy  next character
bufCopyEnd  ; Calculate command string lenght and store it to CCP input buffer lenght variable
    ld      bc, CCPFIRS     ; BC = address of the first char of CCP input string
    xor     a               ; Carry = 0
    sbc     hl, bc          ; L = command string lenght (H = 0 always)
    ld      a, l            ; A = command string lenght
    ld      (CCPLEN), a     ; Store it into CCP buffer lenght variable
    jr      GOCPM

; =========================================================================== ;
; WBOOT                                                                       ;
; =========================================================================== ;
; The WBOOT entry point gets control when a warm start occurs.                ;
; A warm start is performed whenever a user program branches to location      ;
; 0000H, or when the CPU is reset from the front panel. The CP/M system must  ;
; be loaded from the first two tracks of drive A up to, but not including,    ;
; the BIOS, or CBIOS, if the user has completed the patch. System parameters  ;
; must be initialized as follows:                                             ;
;                                                                             ;
; location 0,1,2                                                              ;
;     Set to JMP WBOOT for warm starts (000H: JMP 4A03H + b)                  ;
;                                                                             ;
; location 3                                                                  ;
;     Set initial value of IOBYTE, if implemented in the CBIOS                ;
;                                                                             ;
; location 4                                                                  ;
;     High nibble = current user number, low nibble = current drive           ;
;                                                                             ;
; location 5,6,7                                                              ;
;     Set to JMP BDOS, which is the primary entry point to CP/M for transient ;
;     programs. (0005H: JMP 3C06H + b)                                        ;
;                                                                             ;
; Refer to Section 6.9 for complete details of page zero use. Upon completion ;
; of the initialization, the WBOOT program must branch to the CCP at 3400H+b  ;
; to restart the system.                                                      ;
; Upon entry to the CCP, register C is set to the drive to select after system;
; initialization. The WBOOT routine should read location 4 in memory, verify  ;
; that is a legal drive, and pass it to the CCP in register C.                ;
; =========================================================================== ;

WBOOT_
    ;
    ; Load CCP+BDOS from the system area of disk 0 (track 0).
    ; CCP+BDOS are stored from host sector 0 to 10. Total 11 host sectors (each 512 bytes large) to load
    ;
    ld      sp, $80         ; Use space below buffer for stack 
    ld      hl, WbootMSG    ; Print a message
    call    puts
    ; Select host disk 0
    ld      a, SELDISK_OPC  ; Select SELDISK opcode (IOS)
    out     (STO_OPCD), a
    xor     a               ; disk = 0
    out     (EXC_WR_OPCD), a; Select it
    ; Select host track 0
    ld      a, SELTRCK_OPC  ; Select SELTRACK opcode (IOS)
    out     (STO_OPCD), a
    xor     a               ; track = 0
    out     (EXC_WR_OPCD), a; LSB track = 0
    out     (EXC_WR_OPCD), a; MSB track = 0
    ; Setup load 
    ld      d, 0            ; D = first host sector to load
    ld      e, 11           ; E = host sectors to load (= 11 * 512 bytes)
    ld      hl, CCP         ; HL = CCP starting address (destination)
WBTLOOP
    ; Select current host sector
    ld      a, SELSECT_OPC  ; Select SELSECT opcode (IOS)
    out     (STO_OPCD), a
    ld      a, d            ; A = current host sector number
    out     (EXC_WR_OPCD), a; Select it
    ; Read current host sector (512 bytes) into (HL)
    ld      c, EXC_RD_OPCD  ; Set the EXECUTE READ OPCODE port into C
    ld      a, RDSECT_OPC   ; Select READSECT opcode (IOS)
    out     (STO_OPCD), a
    ld      b, 0            ; Byte counter = 256
    inir                    ; Read 256 byte to hstbuf
    inir                    ; Read 256 byte to hstbuf
    ; Check read errors
    ld      a, ERRDSK _OPC  ; Select ERRDISK opcode (IOS)
    out     (STO_OPCD), a
    in      a, (EXC_RD_OPCD); A = read error code
    or      a               ; Set flags
    jr      nz, FATALERR    ; Ia A > 0 jump to error print
    ; All done?
    inc     d               ; Increment for next sector
    dec     e               ; Decrement counter E
    jr      nz, WBTLOOP     ; Jump if E > 0
    jr      WBTEND          ; All done (E = 0), jump to the CCP

FATALERR
    ld      hl, FatalMsg    ; Print an error message
    call    puts
    halt

WBTEND
    ld      hl, CRLFLF      ; Print a CR with two LF
    call    puts

GOCPM
    ; Init code for blocking and deblocking algorithm
    ; (see CP/M 2.2 Alteration Guide p.34 and APPENDIX G)
    xor a                   ; 0 to accumulator
    ld  (hstact),a          ; Host buffer inactive
    ld  (unacnt),a          ; Clear unalloc count
    ; CP/M init
    ld      hl, CPMMsg      ; Print a message
    call    puts
    ld      a, $C3          ; C3 IS A JMP INSTRUCTION
    ld      ($0000), a      ; FOR JMP TO WBOOT
    ld      hl,WBOOTE       ; WBOOT ENTRY POINT
    ld      ($0001), hl     ; SET ADDRESS FIELD FOR JMP AT 0
    ld      ($0005), a      ; FOR JMP TO BDOS
    ld      hl, BDOS        ; BDOS ENTRY POINT
    ld      ($0006), hl     ; ADDRESS FIELD OF JUMP AT 5 TO BDOS
    ld      bc, $0080       ; DEFAULT DMA ADDRESS IS 80H
    call    SETDMA_
    ;ei                     ; DO NOT ENABLE THE INTERRUPT SYSTEM
    ; Check if current disk is valid
    ld      a, (CDISK)      ; GET CURRENT USER/DISK NUMBER (UUUUDDDD)
    and     $0f             ; Isolate the disk number.
    cp      NDISKS          ; Drive number ok?
    jr      c, WBTDSKOK     ; Yes, jump (Carry set if A < NDISKS)
    ld      a, (CDISK)      ; No, set disk 0 (previous user)
    and     $f0
    ld      (CDISK), a      ; Save User/Disk    
WBTDSKOK    
    ld      a, (CDISK)
    ld      c, a            ; C = current User/Disk for CCP jump (UUUUDDDD)
    jp      CCP             ; GO TO CCP FOR FURTHER PROCESSING

; =========================================================================== ;
; CONST                                                                       ;
; =========================================================================== ;
; You should sample the status of the currently assigned console device and   ;
; return 0FFH in register A if a character is ready to read and 00H in        ;
; register A if no console characters are ready.                              ;
; =========================================================================== ;
CONST_
    ld      a, SYSFLAG_OPC  ; A = SYSFLAG opcode
    out     (STO_OPCD), a   ; Write the opcode
    in      a, (EXC_RD_OPCD); Read SYSFLAG data into A
    and     $04             ; Rx serial buffer empty (D2 = 0)?
    jr      z, NoInChr      ; Yes, jump
    ld      a, $ff          ; No, set char ready flag
    ret                     ; Return CP/M char ready flag ($FF)

NoInChr
    xor     a               ; Set no char flag
    ret                     ; Return CP/M no char flag ($00)

; =========================================================================== ;
; CONIN                                                                       ;
; =========================================================================== ;
; The next console character is read into register A, and the parity bit is   ;
; set, high-order bit, to zero. If no console character is ready, wait until  ;
; a character is typed before returning.                                      ;
; =========================================================================== ;
CONIN_
    in      a, (SERIAL_RX)  ; Read a char from serial port
    cp      $ff             ; Is = $FF?
    jr      z, ChkFF        ; Yes, jump
    ret                     ; No, return the read char in A
    
ChkFF
    ld      a, SYSFLAG_OPC  ; A = SYSFLAG opcode
    out     (STO_OPCD), a   ; Write the opcode
    in      a, (EXC_RD_OPCD); Read SYSFLAG data into A
    and     $08             ; It was a "serial buffer empty" flag (D3 = 1)?
    jr      nz, CONIN_      ; Yes, jump and wait for a char
    ld      a, $ff          ; No, it is a valid char
    ret                     ; Retun with it in A

; =========================================================================== ;
; CONOUT                                                                      ;
; =========================================================================== ;
; The character is sent from register C to the console output device.         ;
; The character is in ASCII, with high-order parity bit set to zero. You      ;
; might want to include a time-out on a line-feed or carriage return, if the  ;
; console device requires some time interval at the end of the line (such as  ;
; a TI Silent 700 terminal). You can filter out control characters that cause ;
; the console device to react in a strange way (CTRL-Z causes the Lear-       ;
; Siegler terminal to clear the screen, for example).                         ;
; =========================================================================== ;
CONOUT_
    ld      a, SERTX_OPC    ; A = SERIAL TX opcode
    out     (STO_OPCD), a   ; Write the opcode
    ld      a, c
    out     (EXC_WR_OPCD), a; Send A to serial Tx
    ret

; =========================================================================== ;
; LIST                                                                        ;
; =========================================================================== ;
; The character is sent from register C to the currently assigned listing     ;
; device. The character is in ASCII with zero parity bit.                     ;
; =========================================================================== ;
LIST_
    ret                     ; Not implemented

; =========================================================================== ;
; PUNCH                                                                       ;
; =========================================================================== ;
; The character is sent from register C to the currently assigned punch       ;
; device. The character is in ASCII with zero parity.                         ;
; =========================================================================== ;
PUNCH_
    ret                     ; Not implemented

; =========================================================================== ;
; READER                                                                      ;
; =========================================================================== ;
; The next character is read from the currently assigned reader device into   ;
; register A with zero parity (high-order bit must be zero); an end-of-file   ;
; condition is reported by returning an ASCII CTRL-Z(1AH).                    ;
; =========================================================================== ;
READER_
    ld      a, $1a          ; Enter an EOF for now (READER not implemented)
    ret

; =========================================================================== ;
; HOME                                                                        ;
; =========================================================================== ;
; The disk head of the currently selected disk (initially disk A) is moved to ;
; the track 00 position. If the controller allows access to the track 0 flag  ;
; from the drive, the head is stepped until the track 0 flag is detected. If  ;
; the controller does not support this feature, the HOME call is translated   ;
; into a call to SETTRK with a parameter of 0.                                ;
; =========================================================================== ;
HOME_
    ld      bc, 0
    jp      SETTRK_

; =========================================================================== ;
; SELDSK                                                                      ;
; =========================================================================== ;
; The disk drive given by register C is selected for further operations,      ;
; where register C contains 0 for drive A, 1 for drive B, and so on up to 15  ;
; for drive P (the standard CP/M distribution version supports four drives).  ;
; On each disk select, SELDSK must return in HL the base address of a 16-byte ;
; area, called the Disk Parameter Header, described in Section 6.10.          ;
; For standard floppy disk drives, the contents of the header and associated  ;
; tables do not change; thus, the program segment included in the sample      ;
; CBIOS performs this operation automatically.                                ;
;                                                                             ;
; If there is an attempt to select a nonexistent drive, SELDSK returns        ;
; HL = 0000H as an error indicator. Although SELDSK must return the header    ;
; address on each call, it is advisable to postpone the physical disk select  ;
; operation until an I/O function (seek, read, or write) is actually          ;
; performed, because disk selects often occur without ultimately performing   ;
; any disk I/O, and many controllers unload the head of the current disk      ;
; before selecting the new drive. This causes an excessive amount of noise    ;
; and disk wear. The least significant bit of register E is zero if this is   ;
; the first occurrence of the drive select since the last cold or warm start. ;
; =========================================================================== ;
SELDSK_
    ld      hl, $0000       ; HL = error code
    ld      a, c            ; A = disk number
    cp      NDISKS          ; Drive number ok?
    jr      c, calcHL       ; Yes, jump
    xor a                   ; No, set disk 0 as current disk
    ld      (CDISK), a      ; Save disk 0, user 0
    ret
    
calcHL
    ; Code for blocking and deblocking algorithm
    ; (see CP/M 2.2 Alteration Guide p.34 and APPENDIX G)
    LD      (sekdsk),A
    RLC     a               ; *2
    RLC     a               ; *4
    RLC     a               ; *8
    RLC     a               ; *16
    LD      HL,dpbase
    LD      b,0
    LD      c,A 
    ADD     HL,BC
    ret

; =========================================================================== ;
; SETTRK                                                                      ;
; =========================================================================== ;
; Register BC contains the track number for subsequent disk accesses on the   ;
; currently selected drive. The sector number in BC is the same as the number ;
; returned from the SECTRN entry point. You can choose to seek the selected   ;
; track at this time or delay the seek until the next read or write actually  ;
; occurs. Register BC can take on values in the range 0-76 corresponding to   ;
; valid track numbers for standard floppy disk drives and 0-65535 for         ;
; nonstandard disk subsystems.                                                ;
; =========================================================================== ;
SETTRK_  
    ld      (sektrk), bc    ; Set track passed from BDOS in register BC.
    ret

; =========================================================================== ;
; SETSEC                                                                      ;
; =========================================================================== ;
; Register BC contains the sector number, 1 through 26, for subsequent disk   ;
; accesses on the currently selected drive. The sector number in BC is the    ;
; same as the number returned from the SECTRAN entry point. You can choose to ;
; send this information to the controller at this point or delay sector       ;
; selection until a read or write operation occurs.                           ;
; =========================================================================== ;
SETSEC_
    ld      (seksec), bc    ; Set sector passed from BDOS in register BC.
    ret

; =========================================================================== ;
; SETDMA                                                                      ;
; =========================================================================== ;
; Register BC contains the DMA (Disk Memory Access) address for subsequent    ;
; read or write operations. For example, if B = 00H and C = 80H when SETDMA   ;
; is called, all subsequent read operations read their data into 80H through  ;
; 0FFH and all subsequent write operations get their data from 80H through    ;
; 0FFH, until the next call to SETDMA occurs. The initial DMA address is      ;
; assumed to be 80H. The controller need not actually support Direct Memory   ;
; Access. If, for example, all data transfers are through I/O ports, the      ;
; CBIOS that is constructed uses the 128 byte area starting at the selected   ;
; DMA address for the memory buffer during the subsequent read or write       ;
; operations.                                                                 ;
; =========================================================================== ;
SETDMA_
    ld      (dmaAddr), bc   ; Save the DMA (Disk Memory Access) address
    ret

; =========================================================================== ;
; READ                                                                        ;
; =========================================================================== ;
; Assuming the drive has been selected, the track has been set, and the DMA   ;
; address has been specified, the READ subroutine attempts to read one sector ;
; based upon these parameters and returns the following error codes in        ;
; register A:                                                                 ;
;                                                                             ;
;     0 - no errors occurred                                                  ;
;     1 - non recoverable error condition occurred                            ;
;                                                                             ;
; Currently, CP/M responds only to a zero or nonzero value as the return      ;
; code. That is, if the value in register A is 0, CP/M assumes that the disk  ;
; operation was completed properly. If an error occurs the CBIOS should       ;
; attempt at least 10 retries to see if the error is recoverable. When an     ;
; error is reported the BDOS prints the message BDOS ERR ON x: BAD SECTOR.    ;
; The operator then has the option of pressing a carriage return to ignore    ;
; the error, or CTRL-C to abort.                                              ;
; =========================================================================== ;
READ_
    ;
    ; Code for blocking and deblocking algorithm
    ; (see CP/M 2.2 Alteration Guide p.34 and APPENDIX G)
    ;
    xor a
    ld      (unacnt), a
    ld      a, 1
    ld      (readop), a     ; read operation
    ld      (rsflag), a     ; must read data
    ld      a, wrual
    ld      (wrtype), a     ; treat as unalloc
    jp      rwoper          ; to perform the read

; =========================================================================== ;
; WRITE                                                                       ;
; =========================================================================== ;
; Data is written from the currently selected DMA address to the currently    ;
; selected drive, track, and sector. For floppy disks, the data should be     ;
; marked as nondeleted data to maintain compatibility with other CP/M         ;
; systems. The error codes given in the READ command are returned in register ;
; A, with error recovery attempts as described above.                         ;
; =========================================================================== ;
WRITE_
    ;
    ; Code for blocking and deblocking algorithm
    ; (see CP/M 2.2 Alteration Guide p.34 and APPENDIX G)
    ;
    xor     a               ; 0 to accumulator
    ld      (readop), a     ; not a read operation
    ld      a, c            ; write type in c
    ld      (wrtype), a
    cp      wrual           ; write unallocated?
    jr      nz, chkuna      ; check for unalloc
    ; write to unallocated, set parameters
    ld      a, blksiz/128   ; next unalloc recs
    ld      (unacnt), a
    ld      a, (sekdsk)     ; disk to seek
    ld      (unadsk), a     ; unadsk = sekdsk
    ld      hl, (sektrk)
    ld      (unatrk), hl    ; unatrk = sectrk
    ld      a, (seksec)
    ld      (unasec), a     ; unasec = seksec
chkuna:
    ; check for write to unallocated sector
    ld      a,(unacnt)      ; any unalloc remain?
    or      a   
    jr  z   ,alloc          ; skip if not
    ; more unallocated records remain
    dec     a               ; unacnt = unacnt-1
    ld      (unacnt), a
    ld      a, (sekdsk)     ; same disk?
    ld      hl, unadsk
    cp      (hl)            ; sekdsk = unadsk?
    jp      nz, alloc       ; skip if not
    ; disks are the same
    ld      hl, unatrk
    call    sektrkcmp       ; sektrk = unatrk?
    jp      nz, alloc       ; skip if not
    ;   tracks are the same
    ld      a, (seksec)     ; same sector?
    ld      hl, unasec
    cp      (hl)            ; seksec = unasec?
    jp      nz, alloc       ; skip if not
    ; match, move to next sector for future ref
    inc     (hl)            ; unasec = unasec+1
    ld      a, (hl)         ; end of track?
    cp      cpmspt          ; count CP/M sectors
    jr      c, noovf        ; skip if no overflow
    ; overflow to next track
    ld      (hl), 0         ; unasec = 0
    ld      hl, (unatrk)
    inc     hl
    ld      (unatrk), hl    ; unatrk = unatrk+1
noovf:
    ; match found, mark as unnecessary read
    xor     a               ; 0 to accumulator
    ld      (rsflag), a     ; rsflag = 0
    jr      rwoper          ; to perform the write
alloc:
    ; not an unallocated record, requires pre-read
    xor     a               ; 0 to accum
    ld      (unacnt), a     ; unacnt = 0
    inc     a               ; 1 to accum
    ld      (rsflag), a     ; rsflag = 1
rwoper:
    ; enter here to perform the read/write
    xor     a               ; zero to accum
    ld      (erflag), a     ; no errors (yet)
    ld      a, (seksec)     ; compute host sector
    or      a               ; carry = 0
    rra                     ; shift right
    or      a               ; carry = 0
    rra                     ; shift right
    ld      (sekhst), a     ; host sector to seek
    ; active host sector?
    ld      hl, hstact      ; host active flag
    ld      a, (hl)
    ld      (hl), 1         ; always becomes 1
    or      a               ; was it already?
    jr      z, filhst       ; fill host if not
    ; host buffer active, same as seek buffer?
    ld      a, (sekdsk)
    ld      hl, hstdsk      ; same disk?
    cp      (hl)            ; sekdsk = hstdsk?
    jr      nz, nomatch
    ; same disk, same track?
    ld      hl, hsttrk
    call    sektrkcmp       ; sektrk = hsttrk?
    jr      nz, nomatch
    ; same disk, same track, same buffer?
    ld      a, (sekhst)
    ld      hl, hstsec      ; sekhst = hstsec?
    cp      (hl)
    jr      z, match        ; skip if match
nomatch:
    ; proper disk, but not correct sector
    ld      a, (hstwrt)     ; host written?
    or      a
    call    nz, writehst    ; clear host buff
filhst:
    ; may have to fill the host buffer
    ld      a, (sekdsk)
    ld      (hstdsk), a
    ld      hl, (sektrk)
    ld      (hsttrk), hl
    ld      a, (sekhst)
    ld      (hstsec), a
    ld      a, (rsflag)     ; need to read?
    or      a
    call    nz, readhst     ; yes, if 1
    xor     a               ; 0 to accum
    ld      (hstwrt), a     ; no pending write
match:
    ; copy data to or from buffer
    ld      a,  (seksec)    ; mask buffer number
    and     secmsk          ; least signif bits
    ld      l,  a           ; ready to shift
    ld      h,  0           ; double count
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    add     hl, hl
    ; hl has relative host buffer address
    ld      de, hstbuf
    add     hl, de          ; hl = host address
    ex      de, hl          ; now in DE
    ld      hl, (dmaAddr)   ; get/put CP/M data
    ld      c, 128          ; length of move
    ld      a, (readop)     ; which way?
    or      a
    jr      nz, rwmove      ; skip if read
    ; write operation, mark and switch direction
    ld      a, 1
    ld      (hstwrt), a     ; hstwrt = 1
    ex      de, hl          ; source/dest swap
rwmove:
    ; C initially 128, DE is source, HL is dest
    ld      a, (de)         ; source character
    inc     de
    ld      (hl), a         ; to dest
    inc     hl
    dec     c               ; loop 128 times
    jr      nz, rwmove
    ; data has been moved to/from host buffer
    ld      a, (wrtype)     ; write type
    cp      wrdir           ; to directory?
    ld      a, (erflag)     ; in case of errors
    ret     nz              ; no further processing
    ; clear host buffer for directory write
    or      a               ; errors?
    ret     nz              ; skip if so
    xor     a               ; 0 to accum
    ld      (hstwrt), a     ; buffer written
    call    writehst
    ld      a, (erflag)
    ret

; Utility subroutine for 16-bit compare
sektrkcmp:
    ; HL = .unatrk or .hsttrk, compare with sektrk
    ex      de, hl
    ld      hl, sektrk
    ld      a, (de)         ; low byte compare
    cp      (HL)            ; same?
    ret     nz              ; return if not
    ; low bytes equal, test high 1s
    inc     de
    inc     hl
    ld      a, (de)
    cp      (hl)            ; sets flags
    ret

;------------------------------------------------------------------------------------------------
; Read physical sector from host
;------------------------------------------------------------------------------------------------

readhst:
    push    bc
    push    hl
    call    setDTS          ; Select disk, track, sector
    ; Read current host sector (512 byte) to hstbuf
    ld      c, EXC_RD_OPCD  ; Set the EXECUTE READ OPCODE port into C
    ld      hl, hstbuf      ; HL points to buffer hstbuf
    ld      a, RDSECT_OPC   ; Select READSECT opcode (IOS)
    out     (STO_OPCD), a
    ld      b, 0            ; Byte counter = 256
    inir                    ; Read 256 byte to hstbuf
    inir                    ; Read 256 byte to hstbuf
    ; Check for errors
    ld      a, ERRDSK _OPC  ; Select ERRDISK opcode (IOS)
    out     (STO_OPCD), a
    in      a, (EXC_RD_OPCD); Read error code into A...
    ld     (erflag), a      ; ... and store it into erflag
    pop     hl
    pop     bc
    ret

; Set disk, track and sector routine for a read or write operation
setDTS
    ; Select hstdsk host disk
    ld      a, (lastDsk)
    ld      b, a            ; B = last disk number
    ld      a, (hstdsk)     ; A = new disk number
    cp      b               ; previous disk = new disk?
    jr      z, setTrack     ; Yes, jump ahead
    ld      a, SELDISK_OPC  ; No, Select SELDISK opcode (IOS)
    out     (STO_OPCD), a
    ld      a, (hstdsk)     ; Select the disk number (hstdsk)
    out     (EXC_WR_OPCD), a
    ld      (lastDsk), a    ; Update last disk number
    ; Select hsttrk host track
setTrack
    ld      a, SELTRCK_OPC  ; Select SELTRACK opcode (IOS)
    out     (STO_OPCD), a
    ld      a, (hsttrk)     ; Select the track number (hsttrk) LSB
    out     (EXC_WR_OPCD), a
    ld      a, (hsttrk+1)   ; Select the track number (hsttrk) MSB
    out     (EXC_WR_OPCD), a
    ; Select hstsec host sector
    ld      a, SELSECT_OPC  ; Select SELSECT opcode (IOS)
    out     (STO_OPCD), a
    ld      a, (hstsec)     ; Select the sector number (hstsec)
    out     (EXC_WR_OPCD), a
    ret
    
lastDsk     .fill   1       ; Last disk number (= $ff after cold boot)

;------------------------------------------------------------------------------------------------
; Write physical sector to host
;------------------------------------------------------------------------------------------------

writehst
    push    bc
    push    hl
    call    setDTS          ; Select disk, track, sector
    ; Write current host sector (512 byte) to hstbuf
    ld      c, EXC_WR_OPCD  ; Set the EXECUTE WRITE OPCODE port into C
    ld      hl, hstbuf      ; HL points to buffer hstbuf
    ld      a, WRTSECT_OPC  ; Select WRITESECT opcode (IOS)
    out     (STO_OPCD), a
    ld      b, 0            ; Byte counter = 256
    otir                    ; Write 256 byte to hstbuf
    otir                    ; Write 256 byte to hstbuf
    ; Check for errors
    ld      a, ERRDSK _OPC  ; Select ERRDISK opcode (IOS)
    out     (STO_OPCD), a
    in      a, (EXC_RD_OPCD); Read error code into A...
    ld  (erflag),a          ; ... and store it into erflag
    pop     hl
    pop     bc
    ret

; =========================================================================== ;
; LISTST                                                                      ;
; =========================================================================== ;
; You return the ready status of the list device used by the DESPOOL program  ;
; to improve console response during its operation. The value 00 is returned  ;
; in A if the list device is not ready to accept a character and 0FFH if a    ;
; character can be sent to the printer. A 00 value should be returned if LIST ;
; status is not implemented.                                                  ;
; =========================================================================== ;
LISTST_
    xor     a               ; A = 0 (not implemented)
    ret

; =========================================================================== ;
; SECTRAN                                                                     ;
; =========================================================================== ;
; Logical-to-physical sector translation is performed to improve the overall  ;
; response of CP/M. Standard CP/M systems are shipped with a skew factor of   ;
; 6, where six physical sectors are skipped between each logical read         ;
; operation. This skew factor allows enough time between sectors for most     ;
; programs to load their buffers without missing the next sector. In          ;
; particular computer systems that use fast processors, memory, and disk      ;
; subsystems, the skew factor might be changed to improve overall response.   ;
; However, the user should maintain a single-density IBM-compatible version   ;
; of CP/M for information transfer into and out of the computer system, using ;
; a skew factor of 6.                                                         ;
;                                                                             ;
; In general, SECTRAN receives a logical sector number relative to zero in BC ;
; and a translate table address in DE. The sector number is used as an index  ;
; into the translate table, with the resulting physical sector number in HL.  ;
; For standard systems, the table and indexing code is provided in the CBIOS  ;
; and need not be changed.                                                    ;
; =========================================================================== ;
SECTRN_
    ld      h, b            ; HL = BC
    ld      l, c
    ret

; =========================================================================== ;
;
; Send a string to the serial line, HL contains the pointer to the string.
; NOTE: Only A and HL are used
;
; =========================================================================== ;
puts
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
;
; MESSAGES
;
; =========================================================================== ;

BiosMsg     .db     cr, lf, lf, "Z80-MBC2 CP/M 2.2 BIOS - S030818-R040219", cr, lf, eos
CRLFLF      .db     cr, lf, lf, eos
CPMMsg      .db     "CP/M 2.2 Copyright 1979 (c) by Digital Research", cr, lf, eos
FatalMsg    .db     cr, lf, "FATAL DISK READ ERROR - SYSTEM HALTED", eos
WbootMSG    .db     cr, lf, "CP/M WARM BOOT...", cr, lf, eos
CCPAuto     .db     "SUBMIT AUTOEXEC", eos

; =========================================================================== ;
; THE REMAINDER OF THE CBIOS IS RESERVED UNINITIALIZED DATA AREA, AND DOES    ;
; NOT NEED TO BE A PART OF THE SYSTEM MEMORY IMAGE (THE SPACE MUST BE         ;
; AVAILABLE, HOWEVER).                                                        ;
; =========================================================================== ;

dirbuf:     .ds 128         ; scratch directory area
alv00:      .ds 257         ; allocation vector 0
alv01:      .ds 257         ; allocation vector 1
alv02:      .ds 257         ; allocation vector 2
alv03:      .ds 257         ; allocation vector 3
alv04:      .ds 257         ; allocation vector 4
alv05:      .ds 257         ; allocation vector 5
alv06:      .ds 257         ; allocation vector 6
alv07:      .ds 257         ; allocation vector 7
alv08:      .ds 257         ; allocation vector 8
alv09:      .ds 257         ; allocation vector 9
alv10:      .ds 257         ; allocation vector 10
alv11:      .ds 257         ; allocation vector 11
alv12:      .ds 257         ; allocation vector 12
alv13:      .ds 257         ; allocation vector 13
alv14:      .ds 257         ; allocation vector 14
alv15:      .ds 257         ; allocation vector 15

;
; Blocking and deblocking algorithm variables
; (see CP/M 2.2 Alteration Guide p.34 and APPENDIX G)
;

sekdsk:     .ds 1           ; seek disk number
sektrk:     .ds 2           ; seek track number
seksec:     .ds 2           ; seek sector number
;
hstdsk:     .ds 1           ; host disk number
hsttrk:     .ds 2           ; host track number
hstsec:     .ds 1           ; host sector number
;
sekhst:     .ds 1           ; seek shr secshf
hstact:     .ds 1           ; host active flag
hstwrt:     .ds 1           ; host written flag
;
unacnt:     .ds 1           ; unalloc rec cnt
unadsk:     .ds 1           ; last unalloc disk
unatrk:     .ds 2           ; last unalloc track
unasec:     .ds 1           ; last unalloc sector
;
erflag:     .ds 1           ; error reporting
rsflag:     .ds 1           ; read sector flag
readop:     .ds 1           ; 1 if read operation
wrtype:     .ds 1           ; write operation type
dmaAddr:    .ds 2           ; last dma address
hstbuf:     .ds 512         ; host buffer

    .end

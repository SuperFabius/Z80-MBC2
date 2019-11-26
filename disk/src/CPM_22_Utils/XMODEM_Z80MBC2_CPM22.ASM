;==============================================================
;               CP/M XMODEM by Martin Eberhard 
;==============================================================
;A command line and/or configuration file-driven program for
;transferring files to and from a CP/M 1.4 or 2.2 system using
;the XMODEM protocol, supporting both the original XMODEM
;checksum protocol and the newer XMODEM-CRC protocol.
;
;This program has been tested at 115.2 K Baud, running on a
;4 MHz Z80 with 0-wait state memory, and performing direct I/O
;via a CCS 2719A serial board (which is based on the Z80-DART).
;Calculations show that a 2 MHz 8080 ought to be able to send
;and receive up to 76.8K baud (with for example a Cromemco
;TU-ART), so long as there are not too many wait states.
;
; To use XMODEM, type:
;   XMODEM <filename> {option list}
;
; A file name is madatory, and can be any legal CP/M file
; name. If you are receiving with XMODEM and the file already
; exists, then you will be asked if it should be overwritten.
; If you are sending, then the file must exist, obviously.
;
; XMODEM first looks for a file called XMODEM.CFG on CP/M's
; default drive. If found, then this file is parsed for
; options, the same as the command line. XMODEM.CFG is parsed
; first, so that options that are set on the command line will
; override those set in XMOODEM.CFG.
;
; XMODEM.CFG and the command line both support the following
; options (though some are less useful on the command line.)
;
;  /R Specifies Receive mode
;
;  /S Specifies Send mode
;
;     If neither /R nor /S is specified then you will be asked.
;
;  /C Selects checksum error checking when receiving;
;     otherwise receiving uses CRC error checking. When
;     sending, the error-checking mode is set by the receiver.
;
;  /E Specifies an enhanced RDR routine that returns with the
;     Z flag set if no character is waiting. Note that this
;     option does not actually select the RDR device as the
;     transfer port. (/X2 does.)
;
;  /In h0 h1 h2... (max h7) Defines assembly code for the
;      custom I/O port (used by the /X3 option), using Intel
;      8080 machine language.
;
;        n = 0 specifies initialization code, to be run when
;              command line and config file parsing are done.
;              All registers may be trashed. This is useful
;              for setting the baud rate, etc.
;
;        n = 1 installs a transmit byte routine.
;              on entry to this routine, the character to send
;              is in c. do not trash de or hl. Sample custom
;              transmit routine (for SOLOS):
;              48        mov   b,c    ;SOLOS wants chr in b
;              3e 01     mvi   a,1    ;serial pseudoport
;              cd 1c c0  call  AOUT   ;output character
;            Encode as follows:
;              /I1 48 3E 01 CD 1C C0
;
;        n = 2 installs a receive status subroutine, which
;              should return with the Z flag set if no
;              character is waiting. Do not trash any registers
;              except psw. Sample routine:
;              3e 01     mvi   a,1    ;serial pseudoport
;              cd 22 c0  call  AINP   ;input character,
;                                     ;Z set if none
;            Encode as follows:
;              /I2 3E 01 CD 22 C0
;
;        n = 3 installs a receive character routine, assuming a
;              character is waiting. Returns the character in
;              a. Trashes no registers except psw. If no
;              routine is required (e.g.  for SOLOS), then no
;              /I3 option is required.
;
;  /M Print message on console. This lets you tell the user
;     e.g. what port is set up for direct I/O in XMODEM.CFG
;
;  /O Specifies an output sequence for an I/O port, intended to
;     initialize the direct I/O port. The form of this
;     option is:
;       /O pp h1 h2 ... hn
;     where pp is the port address, and all the subsequent
;     bytes are sent to that port. You can have more than
;     one /O option, allowing you e.g. to initialize the
;     UART and also to set the baud rate.
;
;  /P Defines the direct I/O transfer port (used by the /X2
;     option). The form of this command is:
;       /P ss dd qq rr tt
;       where:
;          ss is the status port (for Rx and Tx)
;          dd is the data port (for both Rx and tx)
;          qq is 00 if the ready bits are true when low
;            and 01 if the ready bits are true when high
;          rr is the receive-ready bit mask
;          tt is the transmit-ready bit mask
;
;     XMODEM assumes that the receive port works like this:
;       RXWAIT: in       <status port>
;               ani      <Rx Mask>
;               jz/jnz   RXWAIT
;               nop
;               in       <data port>
;
;     ..and the transmit port works like this:
;               push     psw
;       TXWAIT: in       <status port>
;               ani      <Tx Mask>
;               jz/jnz   TXWAIT
;               pop      psw
;               out      <data port>
;
;     Any port that can work with these templates will work
;     with XMODEM's /X2 option.
;
;  All variables for the /O and /P commands are in hexidecimal,
;  and must be exactly two characters long. Legal characters
;  are: {0,1,2,3,4,5,6,7,8,9,A,B,C,D,E,F}
;
;  /Q Specifies quiet mode, preventing messages and pacifiers
;     from being printed on the console during transfer. This
;     is particularly useful if the port you are using is also
;     the port used for CP/M's console. Otherwise, a '+' will
;     be printed on CON for every succesful block, and a '-'
;     will be printed for every block retry.
;
;  /Xn Specifies the transfer port:
;      n=0 uses CP/M's CON device. Contrary to CP/M specs,
;          the CON input port must not strip parity.
;
;      n=1 uses CP/M'd RDR and PUN devices. Contrary to CP/M
;          specs, the RDR input port must not strip parity.
;          Also use /E if the RDR driver has been enhanced
;          to return with the Z flag set when no character is
;          waiting. (Otherwise, no timeout is possible when
;          waiting for a RDR character.)
;
;      n=2 uses direct I/O, which can be set up using the /P
;          option. If no /P option is entered, then /X2 will
;          select a MITS 88-SIO port.
;
;      n=3 uses custom-patched I/O routines, set with the
;          /I option. If no /I option is entered then
;          transfers with /X3 will just cause errors.
;
;  /Zn Specifies CPU speed in MHz - n is between 1 and 9.
;      The default is 2 MHz. This is used for timeouts while
;      sending or receiving. The default is 2 MHz for an 8080,
;      and 4 MHz for a Z80. (Xmodem can tell the difference.)
;
;   A semicolon begins a comment on a new line. All characters
;   from the ';' until the end of the line will be ignored.
;
; Here is a sample XMODEM.CFG file:
;
;    /MDirect I/O is configured for 88-2SIO port B
;    /P 12 13 01 01 02	;set up for an 88-2SIO Port B
;    /O 12 03 15	;8 bits, 1 stop, no parity
;    /X2		;use direct I/O
;
; You can usually abort a transfer with ^C on the console.
;
; The /P option modifies code in the direct I/O transmit and
; receive routines. This is because the 8080 has no command to
; IN or OUT to a port that is specified by a register value -
; so self-modifying code is the only way.
;
; Code that is only used during initialization is at the end,
; and gets overwritten by the block buffer. XMODEM uses all
; available RAM (past its 2K runtime code, up through CP/M's
; CCP) for buffering received and transmitted data, to speed up
; transfers by minimizing disk accesses. This allows XMODEM to
; run comfortably in (for example) a 16K-byte CP/M system
; (with 10K of user memory), and still have a decent 8K data
; buffer and reasonably robust options and messages.
;
; This program will display correctly on screens that are 16X64
; or larger.
;
; Assemble with Digital Research's ASM Assembler
;
;==============================================================
; Thanks to Ward Christensen for inventing XMODEM and keeping
;   it simple.
; Thanks to John Byrns for the XMODEM-CRC extension, which was
;   adopted in Windows Hyperterm.
; Thanks to Keith Petersen, W8SDZ, for a few ideas I borrowed
;   from his XMODEM.ASM V3.2
;==============================================================
;Revision History:
;
; 1.0x  06 APR 2013 through 27 SEP 2014 M. Eberhard
;  Command-line driven versions Based on XMODEM for CDOS
;  (Z-80), version 1.03 by M. Eberhard
;
; 2.0  1 OCT 2014   M. Eberhard
;  New major release:
;   + Supports a configuration file (XMODEM.CFG), with same
;     options as on the command line
;   + combine features of all 1.0x assembly options
;   + Define direct I/O port in XMODEM.CFG (or on command line)
;   + User-set CPU speed (/Z), overrides 8080/Z80 defaults
;   + Option to delete file on /R, if it already exists
;   + Include which port we are using in announcement prior to
;     Xmodem file transfer
;   + A few new timeouts, to prevent hanging in odd situations
;   + Several other minor enhancements
;
; 2.1  3 Oct 2014  M. Eberhard
;  Fix bug in reporting the source of an error
;  Speed up RDR/PUN
;  require CR after "Y" on overwrite question
;
; 2.2  7 Oct 2014  M. Eberhard
;  fix error-reporting bug, increase stack size for BDOS
;
; 2.3  9 Oct 2014 M. Eberhard
;  Eliminate intermediate data buffer. Support CP/M 1.4
;
; 2.4  4 August 2016  M. Eberhard
;  Fix bug in TXLOOP that would cause sending with checksums
;  to fail. Fix bug causing a spurious block after the 1st
;  buffer-full of received data. (Thanks to Bob Bell for
;  helping find and fix these bugs.) Add /I cmd, and add /X3
;  option for custom port routine patching. (This makes it
;  possible to call external I/O routines, such as SOLOS or
;  POLEX.) Also cleaned up comments.
;
; 2.5  9 May 2017  M. Eberhard
;  Clean up file name in FCB if a command option was crammed
;  against the file name (no spaces) on the command line.
;
; 2.6  10 September 2017
;  Significant speed up by using table-driven CRC algorithm.
;  Make the initialization code modify the jump addresses in
;  RXBYTE and TXBYTE based on the type of transfer port
;  selected, eliminated some subroutine calls, and a few other
;  speed optimizations. Ask user for direction if no /R or /S
;  was specified. Use all RAM (even more than 32K) for the
;  buffer. perform initial buffer fill on Sends (before
;  determining error checking mode), while the disk is still
;  spinning. Flush a byte from the receiver port at the
;  beginning, if possible. Squeeze a bit to keep disk file
;  smaller than 4K-bytes. Tidy up comments and labels.
;
; 2.7 9 October 2017  M. Eberhard
;  Fix stack bug when switching stacks
;
; ==========================================================
;
; Z80-MBC2 patch by J4F
; Can run only with CP/M 2.2!!!
;
; (Search the string 'Z80-MBC2' to find changes)
;
; ==========================================================
;
;To Do (maybe in some future version):
;  Support Y-Modem (file name in block 0, 1K blocks, etc.)
;  Terminal mode for port testing/modem setup
;  Support for S-100 internal modem
; (If any of these would be useful to you, let me know...)
;==============================================================
;---------------------------
;This code's revision number
;---------------------------
VERSION	equ	0207h	;high byte = major revision number
			;low byte = minor version

FALSE	equ	0
TRUE	equ	not FALSE

ERRLIM	equ	10	;Max error-retries. 10 is standard.

;Timeout values in seconds. Values in parenthesis are
;XMODEM standard values.

SOHTO	equ	10	;(10)sender to send SOH 
NAKTO	equ	90	;(90)receiver to send init NAK
ACKTO	equ	60	;(60)receiver to ACK (or NAK)
			;(time to write to disk)

BLKSIZ	equ	128	;bytes per XMODEM block
			;DO NOT CHANGE. BLKSIZ must be 128

SECSIZ	equ	128	;CP/M logical-sector size must be 128

;Progress pacifiers printed on the console

PACACK	equ	'+'	;Sent/Received a good block
PACNAK	equ	'-'	;Sent/Received a NAK
PACLIN	equ	60	;pacifiers per line

;The following cycle values are used in the timing loops for
;timeouts when transferring via the CON or the RDR and PUN.
;It is ok if they are imperfect - the XMODEM protocol is quite
;tolerant of timing variations. The example BIOS Code below was
;used to estimate these cycle counts for CSTIME and CRTIME.

CSTIME	equ	85	;number of CPU cycles that BIOS uses to
			;..return CON status
CRTIME	equ	95	;number of cpu cycles that BIOS uses to
			;..return with no chr ready for custom
			;..RDR driver

EXTIME	equ	135	;Number of cycles an external receive
			;routine (e.g. SOLOS) will use for testing
			;status, when a chr is not ready.

;===Example BIOS Code==========================================
;Timing est. for getting reader status via custom RDR driver.
;Assume the IOBYTE is implemented, and assume RDR=UR1
;(the desired RDR port)
;This takes 95 8080 cycles.

;	jmp	RDRIN		;(10) BIOS jump vector

;	...

;RDRIN:	lda	IOBYTE		;(13) which reader port?
;	ani	0Ch		;(7)
;	jz	<not taken>	;(10) not RDR=TTY
;	cpi	8		;(7)
;	jc	<not taken>	;(10) not RDR=HSR
;	jz	UR1ST		;(10) RDR=UR1

;	...
	
;UR1ST:	in	<port>		;(10) get reader stat 
;	ani	<mask>		;(7) test, set Z
;	rz			;(11) return from BIOS

;===Example BIOS Code==========================================
;Timing estimate for getting console status.
;Assume the IOBYTE is implemented, and assume CON=CRT
;This takes 85 8080 cycles.

;	jmp	CONST		;(10) BIOS jump vector

;	...

;RDRIN:	lda	IOBYTE		;(13) which CON port?
;	ani	03h		;(7)
;	jz	<not taken>	;(10) not CON=TTY
;	cpi	2		;(7)
;	jc	CRTST		;(10) CON=CRT

;	...
	
;CRTST:	in	<port>		;(10) get reader stat 
;	ani	<mask>		;(7) test, set Z
;	rz			;(11) return from BIOS
;==============================================================

;**************
; CP/M Equates
;**************
;------------------------------------------
;BDOS Entry Points and low-memory locations
;------------------------------------------
WBOOT	equ	0000H		;Jump to BIOS warm boot
WBOOTA	equ	WBOOT+1		;Address of Warm Boot
IOBYTE	equ	WBOOT+3
;CDISK	equ	WBOOT+4		;Login drive
BDOS	equ	WBOOT+5		;BDOS Entry Point
BDOSA	equ	WBOOT+6		; First address of BDOS
				;(can overlay up to here)

FCB	equ	WBOOT+5CH	;CP/M file control blk
FCBDR	equ	FCB		;Drive Descriptor
FCBFN	equ	FCB+1		;File name (8 chrs)
FCBFT	equ	FCB+9		;File Type (3 chrs)
FCBNL	equ	11		;File name length
FCBEXT	equ	FCB+12		;File extent within FCB
FCBCLR	equ	24		;# of bytes to clear,
				;starting at FCBEXT
COMBUF	equ	WBOOT+80H	;disk & cmd line buffer
USAREA	equ	WBOOT+100H	;User program area

;------------------------------------------
;BDOS Function Codes, passed in register C
;Note: CON, RDR, and PUN I/O is done via
;direct BIOS calls, not BDOS calls.
;------------------------------------------
;BRESET	equ	0	;System Reset
BCONIN	equ	1	;Read Console Chr
;BCONOT	equ	2	;Type Chr on Console
;BRDRIN	equ	3	;Read Reader Chr
;BPUNOT	equ	4	;Write Punch Chr
BPRINT	equ	9	;Print $-terminated String
BRDCON	equ	10	;Get Line from Console
;BCONST	equ	11	;Console Status (<>0 IF CHR)
;BDRST	equ	13	;Reset Disk
BSDISK	equ	14	;select disk
BOPEN	equ	15	;Disk File Open
BCLOSE	equ	16	;Close disk file, FCB at de
BSERCH	equ	17	;Search dir for file, FCB at de
BDELET	equ	19	;delete file, FCB at (de)
BREAD	equ	20	;Read from Disk, 0=OK, <>0=EOF
BWRITE	equ	21	;Write next record, 0=OK, <>0=ERR
BMAKE	equ	22	;Make new file, 0FFH=BAD
BCDISK	equ	25	;get current disk
BSTDMA	equ	26	;Set disk buffer to (de)

;--------------------------------------------
;BIOS Entry Points, relative to the base
;address in WBOOT. BIOS calls are used
;(instead of BDOS calls) where speed matters.
;--------------------------------------------
CONST	equ	06h	;Console Status
CONIN	equ	09h	;Console Input
CONOUT	equ	0Ch	;Console output
PUNCH	equ	12h	;punch output
READER	equ	15h	;reader input
CONSTMD	equ	33h	;Set CONST mode to 8 bit (Z80-MBC2)

;-----------------------------------
;Altair 88-SIO Registers and Equates
;(Used as a default direct port.)
;-----------------------------------
SIOSTA	equ	00h		;status port
SIODAT	equ	01h		;data port

SIORDF	equ	00000001b	;-RX Data register full
SIOTDE	equ	10000000b	;-TX Data register empty

;----------------
;ASCII Characters
;----------------
SOH	equ	1		;Start of 128-byte block
;STX	equ	2		;Start of 1K-byte block
CTRLC	equ	3		;Control-C for user-abort
EOT	equ	4		;End XMODEM session
ACK	equ	6		;XMODEM block acknowledge
TAB	equ	9		;horizontal tab
LF	equ	0AH		;Linefeed
CR	equ	0DH		;Carriage return
NAK	equ	15H		;XMODEM block negative ACK
EOF	equ	1Ah		;^Z end of XMODEM.CFG file
SELCRC	equ	'C'		;selects CRC mode at initiation

;*********************
;* Beginning of Code *
;*********************
	org	USAREA		;normal place for CP/M programs

;*******************************
;Run-time stack is in the COMBUF
;(which is just below USAREA)
;*******************************
RSTACK:

;---------------------------------------------------------
;Initialize, using code that gets wiped out by the BUFFER.
;INIT returns with a=0 for receive, 1 for send. During the
;transfer, the stack is located in the COMBUF. But until
;then, the COMBUF contains the command line options.
;---------------------------------------------------------
	lxi	SP,ISTACK	;initialization stack
	call	INIT

;---------------------------------
;Send or receive, based on a=XMODE
;---------------------------------
	dcr	a		;1 means transmit	
	jnz	RXFILE		;0 means receive

;Fall into TXFILE

;***Function**********************
;Send a CP/M file in XMODEM format
;On Entry:
;  FCB is valid
;  BUFCNT = 0
;  XBLOCK = 0
;*********************************
TXFILE:	call	FOPEN		;Open file specified in FCB
				;& print message on console

	lxi	SP,RSTACK	;run-time stack in COMBUF

;-------------------------------------------------------
;Do initial buffer fill while the disk is still spinning
;-------------------------------------------------------
	call	FILBUF		;Fill the buffer from disk

;Get the transfer error checking mode from the receiver

	call	GTMODE		;wait for NAK or SELCRC to
				;..determine cksum or CRC mode

	lxi	h,ACKERR	;Timeout return address
	shld	RTORET		;..for RXBYTE

;---------------------------------------------------------
;Transmit the entire file in 128-byte blocks. Whenever the
;buffer is empty, refill it from disk and test for EOF.
;---------------------------------------------------------
TXLOOP:	lhld	BUFCNT		;block count in buffer
	mov	a,h		;16-bit test for 0
	ora	l
	cz	FILBUF		;Empty? go read disk
				;Returns BLKPTR=BUFFER
				;..and hl=BUFCNT=blocks in buf
				;Exit directly if no more data

	dcx	h		;one fewer block in
	shld	BUFCNT		;..the buffer

	lhld	XBLOCK		;inc 16-bit XMODEM block #
	inx	h
	shld	XBLOCK

;---------------------------------------
;(Block send retry re-entry point)
;Send the block header: SOH, 8-bit Block
;number, Complimented 8-bit block number
;On Entry:
;  XBLOCK=16-bit XMODEM block number
;---------------------------------------
TXRTRY:	mvi	a,SOH		;SOH first
	call	TXBYTE

	lda	XBLOCK		;8-bit block number
	call	TXBYTE		;(preserves a)

	cma			;complimented block
	call	TXBYTE

;-------------------------------------------
;Send the next BLKSIZ-byte block from BUFFER
;On Entry:
;  BLKPTR=DMA address
;On Exit:
;  Data checksum is in c
;  16-bit data CRC is in de
;  hl=BLKPTR+128
;-------------------------------------------
	lxi	b,BLKSIZ*256+0	;b=bytes/block,
				;...clear checksum in c

	mov	d,c		;clear CRC for new block
	mov	e,c

	lhld	BLKPTR		;(hl) = data in BUFFER

TXBLUP:	mov	a,m		;Get a data byte
	call	TXBYTE		;Send it

;------------------------------------------------------
;(Inline for speed)
;Update the 16-bit CRC and 8-bit checksum with one more
;data byte. Speed matters here. For speed, this code
;assumes that the CRC table is on a page boundary, and
;that the table is split, with the high bytes in the
;first half and the low bytes in the second half.
;   a has the byte just transmitted
;   c has checksum so far
;   de has the CRC so far
;------------------------------------------------------
	push	h		;(11)

	mvi	h,CRCTAB/256	;(7)CRC table addr high byte

	xra	d		;(4)compute lookup address
	mov	l,a		;(5)low byte of lookup

	xra	d		;(4)recover original byte
	add	c		;(4)update checksum too
	mov	c,a		;(5)

	mov	a,m		;(7)compute new CRC high byte			
	xra	e		;(4)using the table
	mov	d,a		;(5)

	inr	h		;(5)low bytes are in the
	mov	e,m		;(5)..other half of the table

	pop	h		;(10)

;------------------------------------------------------------
;CRC is done. Next byte, unless we have transmitted them all.
;------------------------------------------------------------
	inx	h		;Next byte
	dcr	b
	jnz	TXBLUP		;loop through block

;--------------------------------------------
;Send checksum or 16-bit CRC, based on CRCFLG
;  c= 8-bit checksum
;  de = CRC16
;  CRCFLG <>0 if CRC mode enabled
;  hl=BLKPTR+128
;--------------------------------------------
	lda	CRCFLG		;Checksum or CRC?
	ora	a		;clear Z if CRCFLG
	jz	TXCKSM		;jump to send checksum

	mov	a,d
	call	TXBYTE		;send byte in a
	mov	c,e		;now the 2nd CRC byte

TXCKSM:	mov	a,c		;a=cksum or CRC 2nd byte 
	call	TXBYTE		;send byte in a

;-------------------------------------------
;Wait for the ACK. If none arrives by the
;end of the timeout, or if a NAK is received
;instead of an ACK, then resend the block.
;  hl=BLKPTR+128
;-------------------------------------------
	call	GETACK		;Wait for the ACK
				;a=0, Z set if ACK
	jnz	TXRTRY		;NZ: timeout or NAK

	sta	ERRCNT		;a=0: restart error count
	shld	BLKPTR		;next block in the buffer

;----------------------------------------------------
;Ack received. Print pacifier, and go send next block
;----------------------------------------------------
	lda	PACCNT		;pacifiers enabled?
	inr	a		;PACCNT=FFh means no
	cnz	PACOK		;pacifier if allowed

	jmp	TXLOOP

;***Function**************************
;Receive XMODEM file & save it to disk
;On Entry:
;  XBLOCK=0
;  FCB is valid
;*************************************
RXFILE:	lxi	h,RXSERR	;Timeout return address
	shld	RTORET		;..for RXBYT1 and RXBYTE

	call	CREATE		;create & open file on disk
				;..and Send initial ACK or C

	lxi	SP,RSTACK	;run-time stack in COMBUF

;-------------------------------------------------------
;Receive & validate a block, and see if we got an EOT
;  XBLOCK=16-bit block number of the last block received
;-------------------------------------------------------
RXLOOP:	xra	a
	sta	ERRCNT		;Clear error count

;---------------------------------------
;Wait for SOH from sender to start
;reception, go investigate anything else
;---------------------------------------

;Bad block retry re-entry point

RXRTRY:	mvi	a,SOHTO*2	;Timeout for SOH
	call	RXBYTE

	cpi	SOH		;Did we get an SOH?
	jnz	NOTSOH		;If not, see what we got

;------------------------------------------------
;Got an SOH at beginning of the block. Now get
;the rest of the block header: 8-bit Block number
;followed by the complemented 8-bit block number
;------------------------------------------------
	mvi	a,NAK		;we have received
	sta	NAKCHR		;..at least one SOH

	call	RXBYT1		;Get block number
	mov	d,a		;Save block number

	lda	XBLOCK		;8-bit previous block number
	mov	e,a		;..for later

	call	RXBYT1		;complimented block number
	cma			;(4)compliment to compare

	cmp	d		;(4)
	jnz	PURGE		;(10)No match: error

;---------------------------------------------------
;Calculate and remember the difference between this
;block number and the previous block's block number.
;(We calculate this here because we have the time.)
;---------------------------------------------------
	sub	e		;(4)calc the difference
				;0 means same block
				;1 means next block
	sta	RXBDIF		;(7)Save block number diff

;-----------------------------------------------------
;Loop to receive BLKSIZ bytes and store them in the
;next slot in the buffer, computing both the checksum
;and the CRC along the way. Throughout the RXCHR loop:
;  b is the byte counter
;  c accumulates the checksum
;  de accumulates the CRC
;  hl is the buffer memory pointer
;----------------------------------------------------
	lxi	b,BLKSIZ*256+0	;(10)b=bytes, c=0 checksum
	mov	d,c		;(5)Clear CRC too
	mov	e,c		;(5)

	lhld	BLKPTR		;(16)next block in the buffer


RXCHR:	call	RXBYT1		;(17+118)Get one byte of data

	mov	m,a		;(7)Store byte in buffer

;-------------------------------------------------------------
;(Inline for speed: this is the critical path when receiving.)
;Update the 16-bit CRC and 8-bit checksum with one more data
;byte. For speed, this code assumes that the CRC table is on
;a page boundary, and that the table is split, with the high
;bytes in the first half and the low bytes in the second half.
;   a has the newly received byte
;   c has checksum so far
;   de has the CRC so far
;(This loop uses 238 8080 cycles IN-to-IN for direct I/O. with
;a 4 MHz Z80, this will require about 60 uS per byte. 115.2K
;baud sends a byte every 86.8 uS, so we have enough headroom.)
;-------------------------------------------------------------
	push	h		;(11)

	mvi	h,CRCTAB/256	;(7)CRC table addr high byte

	xra	d		;(4)compute lookup address
	mov	l,a		;(5)low byte of lookup

	xra	d		;(4)recover original byte
	add	c		;(4)update checksum too
	mov	c,a		;(5)

	mov	a,m		;(7)compute new CRC high byte			
	xra	e		;(4)..using the table
	mov	d,a		;(5)

	inr	h		;(5)low bytes are in the
	mov	e,m		;(5)..other half of the table

	pop	h		;(10)

;--------------------------------------------------------------
;Next byte, unless we have received all the data for this block
;--------------------------------------------------------------
	inx	h		;(5)next byte
	dcr	b		;(5)
	jnz	RXCHR		;(10)

;-------------------------------------------------------
;We've received all the block's data bytes. Now verify
;either the checksum in c or CRC in de, based on CRCFLG.
;  hl=next buffer address
;-------------------------------------------------------
	lda	CRCFLG		;CRC mode?
	ora	a		;0 means cksum
	jz	RXCKSM

	call	RXBYT1		;Get 1st byte of CRC

	cmp	d		;test the 1st CRC byte
	jnz	RXCERR		;fail: try again, but
				;..first, purge 2nd CRC

	mov	c,e		;put 2nd CRC byte in c

RXCKSM:	call	RXBYT1		;2nd CRC byte or cksum

	cmp	c		;Does it match?
	jnz	RXSERR		;No: error

;---------------------------------------------------
;Got an error-free block. See if is the block number
;we expected, based on the prior block's number.
;  hl=next buffer address
;  RXBDIF = this block's block number minus the
;    previous block's block number.
;---------------------------------------------------
	lda	RXBDIF		;difference between this
				;block's number & the
				;prior block's number
	dcr	a
	jnz	BLKORD		;Not sequential?

;------------------------------------------------
;Correct block received. Bump pointers and see if
;the buffer is full, requiring a flush to disk.
;  hl=next buffer address
;------------------------------------------------
	shld	BLKPTR		;next slot in BUFFER
	lda	BDOSA+1		;high byte of BDOS
	cmp	h		;full buffer?

;Bump 16-bit buffer block count (doesn't affect Z)

	lhld	BUFCNT
	inx	h
	shld	BUFCNT

;Test for full buffer, and flush it if it's full

	cz	WFLUSH
		
	lhld	XBLOCK		;inc 16-bit XMODEM block #
	inx	h
	shld	XBLOCK

;Print good-block pacifier on the console, if enabled

	lda	PACCNT		;pacifiers enabled?
	inr	a		;PACCNT=FFh means no
	cnz	PACOK		;pacifier if allowed

;-------------------------------------------
;Send ACK and loop back to get another block
;-------------------------------------------
ACKBLK:	call	TXACK		;Send XMODEM ACK
	jmp	RXLOOP		;LOOP until EOF

;========================
;Receive Error Processing
;========================
;-------------------------------------------------------
;Non-sequential block received without a checksum or CRC
;error. a=FFh if this block has the same block number as
;the previous block (and should be ignored). Otherwise
;abort because a block has been irretrievably lost.
;-------------------------------------------------------
BLKORD:	inr	a		;was it FFh?
	jz	ACKBLK		;y: ignore repeated block

	lxi	d,LBMSG		;Lost block
	jmp	ABORT

;---------------------------------------
;Got something besides an SOH. If it
;was an EOT then quit directly to RXEOT.
;---------------------------------------
NOTSOH:	cpi	EOT
	jz	RXEOT		;done with reception

;-------------------------------------------------------
;No SOH or EOT - this was an invalid header. Eat the
;rest of this block (up to 256 received bytes) until
;the line is quiet for 1 second. (RXBYT1 timeout will
;jump to the address in RTORET, which should be RXSERR.)
;-------------------------------------------------------
PURGE:	mvi	b,0		;allow 256 babbling chrs

PRGLUP:	call	RXBYT1		;Receive w/ 1-sec timeout
	dcr	b
	jnz	PRGLUP		;RXBYT1 times out to RXSERR

;The transmitter is babbling, unable to synchronize
;with the incoming data stream. Abort with message.

	lxi	d,SYNMSG	;Sync error message
	jmp	ABORT		;too many bogus bytes

;--------------------------------
;Error on 1st CRC byte. Flush 2nd
;CRC byte, and indicate an error.
;--------------------------------
RXCERR:	call	RXBYT1		;get and chuck 2nd CRC byte

;-----------------------------------------------
;Send a NAK to indicate receive error. If we are
;waiting to start and we are in CRC mode (NAKCHR
;=SELCRC), then send SELCRC instead of NAK
;-----------------------------------------------
RXSERR:	call	PACERR		;opportunity to abort,
				;pacifier if allowed
				;trashes hl

	lda	NAKCHR		;current NAK chr
	call	TXBYTE

;Bump error count, and abort if too many errors.
;otherwise, retry the block.

	lxi	h,ERRCNT	;Clear error count
	inr	m		;bump error count

	mov	a,m		;Too many errors?
	cpi	ERRLIM
	jc	RXRTRY		;No: try again

	lxi	d,ELEMSG	;error limit exceeded
	jmp	ABORT

;***Subroutine*********************************
;Write all data in BUFFER to disk
;On Entry:
;  BUFCNT = count of blocks currently in BUFFER
;  FCB describes the open file
;On Exit:
;  BUFCNT=0
;  BLKPTR = BUFFER
;Trashes all registers
;**********************************************
WFLUSH:	lxi	h,BUFFER	;reset BLKPTR
	shld	BLKPTR

WFLOOP:	xchg			;de=start of block data

	lhld	BUFCNT		;blocks in buffer
	mov	a,h		;end of buffer already?
	ora	l
	rz			;Return if so

	dcx	h		;next block
	shld	BUFCNT

	mvi	c,BSTDMA	;CP/M SET DMA function
	call	GOBDOS		;de = DMA address

	xchg			;pointer to hl, free de

	lxi	d,FCB
	mvi	c,BWRITE	;Write from buf to disk
	call	GOBDOS

	lxi	d,EWFMSG
	ora	a		;BDOS returns 0 if okay
	jnz	ABORT		;Oops, write error

				;hl = address in BUFFER
	lxi	d,BLKSIZ	;de=block size
	dad	d		;(hl)=next block data

	jmp	WFLOOP		;until all blocks sent

;***Subroutine*****************************************
;Get an ACK from the receiver. If we get a NAK, then
;print the NAK pacifier on the console. Opportunity for
;user to abourt (with ^C) if timeout waiting for ACK.
;On Entry:
;  RTORET = ACKERR (RXBYTE eror return adress)
;On Exit:
;  a=0, Z set and Carry clear if ACK received
;  Z clear and Carry clear if NAK received
;  Z clear, Carry set and ERRCNT bumped if timeout
;    or too many bogus chrs received
;  If too many errors, abort
;Good ack: trashes a
;Bad ack: trashes a,bc,e,hl
;******************************************************
GETACK:	

;-----------------------------------------
;Get a received byte, or timeout. Return
;with Z set and carry clear if it's an ACK
;-----------------------------------------
	mvi	a,ACKTO*2	;ACK-wait timeout value
	call	RXBYTE		;go get a character
				;timeout will "return"
				;..to ACKERR

	xri	ACK		;Did we get an ACK?
	rz			;Y: return w/ a=0, Z set
				;..and carry cleared

;-----------------------------------------
;If NAK, print pacifier, and return with
;Carry & Z cleared, unless the user aborts
;-----------------------------------------
	cpi	NAK xor ACK	;NAK?
	jnz	ACKERR		;NZ: bad byte received

	call	PACERR		;opportunity to abort,
				;pacifier if allowed
				;trashes hl

	ori	0FFh		;NAK: Clear Z & carry
	ret	

;----------------------------------------------------------
;Timeout or bogus chr while waiting for ACK/NAK. Bump error
;count & check limit. Set carry and clear Z for return.
;----------------------------------------------------------
ACKERR:	call	CCTRLC		;user abort?

	lxi	h,ERRCNT	;bump error count
	inr	m

	mov	a,m		;too many errors?
	cpi	ERRLIM
	rc			;N: Return w/ carry set
				;..and Z cleared for timeout

;--------------------------------------
;Abort waiting for ACK: Too many errors
;--------------------------------------
	lxi	d,TAEMSG	;too many ack errors
	jmp	ABORT

;***Subroutine*****************************
;Close CP/M disk file 
;(This is required after writing to a file)
;On Exit:
;  de = FCB
;Trashes psw
;******************************************
FCLOSE:	lxi	d,FCB		;FCB describes the file
	mvi	c,BCLOSE	;CP/M CLOSE FILE function
	call	GOBDOS
	inr	a		;-1 meant close error
	rnz

;--------------------------------------
;Error closing file: abort with message
;--------------------------------------
	call	CMSGXT
	db	'FILE CLOSE ERROR! May be corrupt.$'

;***Subroutine**************************************
;Read more blocks from the disk and put them in the
;buffer until it is full or there are no more blocks
;On Entry at BUFCNT:
;  BUFCNT = 0
;  Buffer start address = BUFFER
;On Entry at FILBF1:
;  hl=buffer starting address
;  BUFCNT = 0
;On Exit:
;  BLKPTR = buffer start address
;  BUFCNT=number of 128-byte blocks in the buffer
;  hl=(BUFCNT)
;  EOFLAG set if EOF encountered
;  direct exit to TXEOF if no more data
;Trashes all registers
;***************************************************

;--------------------------------------------------------
;BUFFER is empty: read 128-byte logical disk sectors into
;the buffer until EOF or the buffer is full (up to BDOS)
;--------------------------------------------------------
FILBUF:	lda	EOFLAG		;already seen the EOF?
	ora	a
	jnz	TXEOF		;y: no more data.

	lxi	h,BUFFER

;--------------------
;Entry for first fill
;--------------------
FILBF1:	shld	BLKPTR		;reset pointer for exit

	xchg			;de=address in BUFFER

FBLOOP:	mvi	c,BSTDMA	;de=CP/M DMA address
	call	GOBDOS		;Trashes no registers

	xchg			;pointer to hl, free de

	lxi	d,FCB
	mvi	c,BREAD		;Logical sector into BUFFER
	call	GOBDOS		;Trashes no registers
	ora	a		;Read ok?
	jnz	FBEOF		;EOF from CP/M?: no more data


	lxi	d,SECSIZ 	;logical sector size
	dad	d		;next logical sector's address
	xchg			;..into de

	lhld	BUFCNT		;count blocks in buffer. Note:
	inx	h		;this assumes blocks are the
	shld	BUFCNT		;same size as logical sectors.

	lda	BDOSA+1		;High byte of BDOS address
	cmp	d		;All full?
	jnz	FBLOOP		;n: go until all space used

	ret			;with hl=BUFCNT

;-------------------------------------------
;We got an EOF from CP/M. If we received 0
;logical sectors, then send the EOF and end.
;On Entry:
;  a<>0
;  count-down on stack
;  BUFCNT = # of blocks read from disk
;On Exit:
;  hl=(BUFCNT)
;-------------------------------------------
FBEOF:	sta	EOFLAG		;Set EOF flag

	lhld	BUFCNT		;zero blocks?
	mov	a,h
	ora	l
	rnz			;n: ret with hl=BUFCNT

;Fall into TXEOF to end transmission

;***Exit************************************************
;File send completed. Send EOT'S until we get an ACK
;Then print happy message, report block count anbd exit.
;On Entry:
;  XBLOCK=16-bit block number of the last block sent
;*******************************************************
TXEOF:	mvi	a,EOT		;Send an EOT
	call	TXBYTE

	call	GETACK		;Wait for an ACK
	jnz	TXEOF		;Loop until we get an ACK

	call	CILPRT		;report success
	db	'OK',CR,LF
	db	'Sent',' '+80h

	jmp	REPCNT		;print block count, goto CP/M

;***Subroutine************************
;Receive a byte, with 1-second timeout
;On Entry:
;  RTORET = error return address
;On Exit:
;  exit to RTORET if timeout
;  a = received byte if no timeout
;*************************************
RXBYT1:	mvi	a,2		;1-second timeout

;Fall into RXBYTE

;***Subroutine***************************************
;Receive a byte from the transfer port - either the
;CON or RDR device or a direct I/O port
;
;This routine gets modified by /T,/E, and /P options.
;On Entry:
;  RXROUT has been patched by the initialization code
;  a = timeout value in half-seconds
;  RTORET = error return address
;On Exit:
;  exit to RTORET if timeout
;  a = received byte if no timeout
;(118 8080 cycles for direct I/O)
;****************************************************
RXBYTE:	sta	TIMRH		;(13)Timer high byte
	push	h		;(11)
	lhld	TIMRLD		;(16)start timeout timer

RXROUT:	jmp	EXIT		;(10)This gets modified with
				;..the routine address

;---RX Byte Routine--------------------------
;Receive a transfer byte from CON
;On Entry:
;  hl = timer low word
;  TIMRH = timer high byte
;  prior hl is on the stack
;RXBCON loop: 179+CRTIME cycles, and round up
;-->Entry is at RXBCON <---
;--------------------------------------------
CONTO:	equ	50000/((195+CRTIME+9)/10)
RXCLUP:	dcx	h		;(5)
	mov	a,l		;(5)
	ora	h		;(4)
	cz	RXTIMR		;(11) Timeout?

RXBCON:	mvi	a,CONST		;(7)get console status
	call	GOBIOS		;(116+17+CRTIME)
	ora	a		;(4)nz means chr ready
	jz	RXCLUP		;(10)Go get the chr

	mvi	a,CONIN		;get console chr
	jmp	CRDONE

;---RX Byte Routine--------------
;Receive a transfer byte from RDR
;On Entry:
;  hl = timer low word
;  TIMRH = timer high byte
;  prior hl is on the stack
;--------------------------------
RXRDR:	mvi	a,READER	;BIOS routine offset

;Fall into CRDONE

;----------------------------------
;Get character from BIOS and return
;On Entry:
;  a = BIOS routine offset
;  prior hl is on the stack
;----------------------------------
CRDONE:	pop	h		;chuck timer

;Fall into GOBIOS

;***Subroutine*********************
;Go call a BIOS driver directly
;On Entry:
;  c=value for BIOS routine, if any
;  a = BIOS call address offset
;On Return:
;  psw as BIOS left it
;  all other regs preserved
;(116 cycles + BIOS time)
;**********************************
GOBIOS:	push	h		;(11)
	push	d		;(11)
	push	b		;(11)

	call	DOBIOS		;(17+26+BIOS time)

	pop	b		;(10)
	pop	d		;(10)
	pop	h		;(10)
	ret			;(10)done

;***Subroutine*********************
;Go call a BIOS driver directly
;On Entry:
;  c=value for BIOS routine, if any
;  a = BIOS call address offset
;On Return:
;  all regs as BIOS left them
;(26 cycles + BIOS time)
;**********************************
DOBIOS:	lhld	WBOOTA		;(16)get BIOS base address
	mov	l,a		;(5)a has jump vector

	pchl			;(5) 'call' BIOS routine

;---RX Byte Routine---------------------------------------
;Receiver from enhanced RDR routine, which returns with Z
;set if no character is waiting - allowing a timeout here.
;On Entry:
;  hl = timer low word
;  TIMRH = timer high byte
;  prior hl is on the stack
;RXERDR loop: 175+CRTIME cycles, and round up
;--> Entry is at RXERDR <--
;---------------------------------------------------------
RDRTO:	equ	50000/((175+CRTIME+9)/10)
RXERLP:	dcx	h		;(5)
	mov	a,l		;(5)
	ora	h		;(4)
	cz	RXTIMR		;(11) Timeout?

RXERDR:	mvi	a,READER	;(7)BIOS routine offset
	call	GOBIOS		;(116+17+BIOS time)
	jz	RXERLP		;(10)nz means chr ready

	pop	h
	ret

;---RX Byte Routine-------------------------------
;Generic direct transfer port Input Routine - gets
;modified by INIT based on selected transfer port
;On Entry:
;  hl = timer low word
;  TIMRH = timer high byte
;  prior hl is on the stack
;--> Entry is it RXDRCT <--
; WAITRX loop = 53 cycles. 0.5S / 53 uS = 9434
;-------------------------------------------------
DIRTO	equ	9434
WAITRX:	dcx	h		;(5)
	mov	a,l		;(5)
	ora	h		;(4)
	cz	RXTIMR		;(11) Timeout?

RXDRCT:

;The relative position of the following instructions must not
;change because MODIO assumes the positions of the bytes it
;modifies.

IMODFY:	in	SIOSTA	;(10+1)status port (modified)
	ani	SIORDF	;(7)test ready (clear carry) (modified)
	jnz	WAITRX	;(10)high when chr ready (modified)

	pop	h	;(10)here for IMODFY
	in	SIODAT	;(10)data port (modified)
	ret		;(10)

;---RX Byte Routine--------------------------------
;Custom Receive Subroutine
;On Entry:
;  hl = timer low word
;  TIMRH = timer high byte
;  prior hl is on the stack
;--> Entry is at RXCUST <---
;Assume WATCRX loop time is 80 cycles, and round up
;--------------------------------------------------
CUSTO:	equ	50000/((80+EXTIME+9)/10)
WATCRX:	dcx	h		;(5)
	mov	a,l		;(5)
	ora	h		;(4)
	cz	RXTIMR		;(11) Timeout?

RXCUST:
;Wait for data to be ready
;(Up to 8 bytes will be written here by /I2)

CRSTAT:	lxi	d,UPMSG		;default causes error
	jmp	ABORT
	nop
	nop

	jz	WATCRX
	pop	h

;Get the received data byte
;(Up to 8 bytes will be written here by /I3)

CRDAT:	ret			;just make default faster
	ret
	ret
	ret
	ret
	ret
	ret
	ret

	ret

;---Local Subroutine-------------------------
;Bump timer, test for abort every 1/2 sec
;On Entry:
;  hl = 0
;  TIMRH = remaining timeout in 0.5 sec units
;  RTORET = error return address
;  top-of-stack = our return address
;  next-on-stack = hl save value
;  next-on-stack = RXBYTE return address
;On Exit:
;  hl reloaded
;On Timeout:
;   repair stack for call to RXBYTE
;   jump to address in RTORET
;Trashes psw
;--------------------------------------------
RXTIMR:	call	CCTRLC		;user abort?

	lxi	h,TIMRH
	dcr	m		;bump timer high byte
	lhld	TIMRLD		;reload timer
	rnz			;return unless timeout

;Timeout: fix stack, "return" from RXBYTE to address in RTORET

	pop	h		;chuck RXTIMR return address
	pop	h		;original hl
	xthl			;RXBYTE return address instead

	lhld	RTORET		;error return address
	xthl			;onto stack, restore hl
	ret			;go there

;***Subroutine********************************
;Send ACK
;On Exit:
;  a trashed
;  All flags and all other registers preserved
;*********************************************
TXACK:	mvi	a,ACK

;Fall into TXBYTE

;***Subroutine*******************************
;Send a to the transfer port, based on XPORT
;and the assembly options.
;This routine gets modified by /P option
;On Entry:
;  a = byte to send
;  TXROUT has been modified by initialization
;On Exit:
;  All registers preserved
;********************************************
TXBYTE:	push	b
	mov	c,a		;chr to c

TXROUT:	jmp	EXIT		;This gets modified with
				;the routine address
;---TX Byte Routine-------------------------
;Custom Output Subroutine
;(Up to 8 bytes will be written here by /I1)
;-------------------------------------------
TXCUST:
CWDAT:	lxi	d,UPMSG		;default causes error
	jmp	ABORT
	nop
	nop

	mov	a,c		;restore registers
	pop	b
	ret	

;---TX Byte Routine----------------------
;Transmit via direct I/O, with timeout
;the timeout value doesn't really matter:
;we just shouldn't hang forever here
;----------------------------------------
TXDRCT:	push	h
	lxi	h,0		;about 1.7 second timeout
				;..at 2 MHz

TXWAIT:	dcx	h		;(5)timeout?
	mov	a,h		;(5)
	ora	l		;(4)
	jz	TXBTO		;(10)y: abort

;The relative position of the following instructions must not
;change because MODIO assumes the positions of the bytes it
;modifies.

OMODFY:	in	SIOSTA		;(10+1)status port (modified)
	ani	SIOTDE		;(7)mask (modified)
	jnz	TXWAIT		;(10)may become jnz (modified)

;52 cycles = 26 uS per pass at 2 MHz

	mov	a,c		;recover chr
	out	SIODAT		;data port (modified)

	pop	h
	pop	b
	ret

;Transmitter timeout: the UART CTS signal is probably not true.
;Rudely abort program.

TXBTO:	lxi	d,UTOMSG	;exit message
	jmp	ABORT

;---TX Byte Routine-------
;Transmit via CP/M CON
;-------------------------
TXCON:	mvi	a,CONOUT	;BIOS send c to console
	jmp	TXCP

;---TX Byte Routine-------
;Transmit via CP/M PUN
;-------------------------
TXPUN:	mvi	a,PUNCH		;1:BIOS send c to punch

;Fall into TXCP

;----------------------------
;Transmit via CP/M CON or PUN
;----------------------------
TXCP:	call	GOBIOS		;chr in c, routine in a

	mov	a,c		;restore character
	pop	b
	ret

;***Subroutine*********************
;Print hl in decimal on the console
;with leading zeros suppressed
;Trashes all registers
;**********************************
PDEC16:	mvi	d,0		;Suppress leading 0's

	lxi	b,-10000
	call	DECDIG
	lxi	b,-1000
	call	DECDIG
	lxi	b,-100
	call	DECDIG
	lxi	b,-10
	call	DECDIG

	mov	a,l		;last digit is simple
	jmp	DECDG0		;with leading 0's

;---Local Subroutine--------------------------
;Divide hl by power of 10 in bc and print
;result, unless it's a leading 0.
;On Entry:
;  hl=Dividend
;  bc=divisor (a negative power of 10)
;  d=0 if all prior digits were 0
;On Exit:
;  Quotent is printed, unless it's a leading 0
;  hl=remainder
;  d=0 iff this and all prior digits are 0
;---------------------------------------------
DECDIG:	mvi	a,0FFh		;will go 1 too many times
	push	d		;leading zero state

DIGLP:	mov	d,h		;de gets prev value
	mov	e,l
	inr	a
	dad	b		;subtract power of 10
	jc	DIGLP

	xchg			;hl has remainder
	pop	d		;leading 0 state

	mov	e,a		;e has digit to print
	ora	d		;leading 0 to suppress?
	rz			;yes: digit is done

	mov	d,a		;don't suppress next digit
 
	mov	a,e	

DECDG0:	adi	'0'		;make digit ASCII

;Fall into PRINTA

;***Subroutine******************
;Print character in a on console
;Trashes psw,c
;*******************************
PRINTA:	mov	c,a		;value to c for PRINTC

;Fall into PRINTC

;***Subroutine******************
;Print character in c on console
;Trashes psw
;*******************************
PRINTC:	mvi	a,CONOUT
	jmp	GOBIOS

;***Subroutine********************************
;Print error pacifier on the console unless
;disabled, giving the user a chance to abort
;On Entry:
;  PACCNT =FFh to disable pacifier printing
;  otherwise, PACCNT = column position
;On Exit:
;  PACCNT incremented mod 64, unless it is FFh
;Trashes psw,c,hl
;*********************************************
PACERR:	call	CCTRLC		;user abort?

	lda	PACCNT		;pacifiers enabled?
	inr	a
	rz			;n: no pacifier printed

	mvi	c,PACNAK
	db	21h		;'LXI H' opcode skips 2 bytes

;Hop into PACIFY

;***Subroutine*************************************
;Print good pacifier on the console unless disabled
;On Entry:
;  a = PACCNT = column position
;On Exit:
;  PACCNT incremented mod PACLIN, unless it is FFh
;Trashes psw,c
;**************************************************
PACOK:	mvi	c,PACACK

;Fall into PACIFY

;***Subroutine************************************
;Print pacifier on the console unless disabled.
;Print a CR/LF at the end of every PACLIN columns.
;On Entry:
;  c=pacify character
;  a = PACCNT+1 = next column position
;On Exit:
;  PACCNT incremented mod PACLIN
;Trashes psw,c
;*************************************************
PACIFY:	sta	PACCNT
	sui	PACLIN+1	;line full?
	jnz	PRINTC

	sta	PACCNT		;zero
	push	b		;save pacifier chr in c
	call	PCRLF		;need a CR?
	pop	b
	jmp	PRINTC		;last one on the line

;***Subroutine*****
;Delete file at FCB
;On Exit:
;  de=FCB
;Trashes psw,c,hl
;******************
FDELET:	mvi	c,BDELET	;delete existing file
	lxi	d,FCB
	db	21h		;LXI H opcode skips 2 bytes

;Hop into GOBDOS

;***Subroutine******************
;Print $-terminated string at de
;Trashes psw,c
;*******************************
PRINTF:	mvi	c,BPRINT

;Fall into GOBDOS

;***Subroutine*********************************
;Call BDOS while preserving all regs except psw
;**********************************************
GOBDOS:	push	h
	push	d
	push	b
	call	BDOS
	pop	b
	pop	d
	pop	h
	ret

;***Subroutine***
;Print CR, LF
;Trashes psw,c
;****************
PCRLF:	call	ILPRNT
	db	CR,LF+80H
	ret

;***Subroutine**************************************
;Print CR, LF, then In-line Message
;The call to ILPRNT is followed by a message string.
;The last message chr has its msb set.
;Trashes psw,c
;***************************************************
CILPRT:	call	PCRLF

;Fall into ILPRNT

;***Subroutine**************************************
;Print In-line Message
;The call to ILPRNT is followed by a message string.
;The last message chr has its msb set.
;On Exit:
;  Z cleared
;Trashes psw,c
;***************************************************
ILPRNT:	xthl			;Save hl, get msg addr

IPLOOP:	mov	a,m
	ani	7Fh		;strip end marker
	call	PRINTA		;print byte
	mov	a,m		;end?
	inx	h		;Next byte
	ora	a		;msb set?
	jp	IPLOOP		;Do all bytes of msg

	xthl			;Restore hl,
				;..get return address
	ret

;***Subroutine*************************************
;Check for Control-C on the console, and quit if so
;On Exit:
;  Z set if no chr was waiting
;  Z clear if anything but ^C was waiting
;Trashes a
;**************************************************	
CCTRLC:	mvi	a,CONST		;anything on console?
	call	GOBIOS		;(about 200 cycles)
	ora	a		;Z means no chr waiting
	rz

;Chr waiting: fall into GETCON to take a look

;***Subroutine*********************************
;Get console character, abort if it's control-C
;On Exit:
;  chr in a
;  Z cleared
;Trashes a
;**********************************************	
GETCON:	mvi	a,CONIN		;read the typed chr
	call	GOBIOS
	cpi	CTRLC
	rnz			;ignore everything else

	lxi	d,CCMSG		;control C

;Fall into ABORT to close file and report

;***Exit***********************************
;Abort - close file if writing, delete it
;if no blocks received
;On Entry:
;  de = abort message to print
;  XMODE = 0 for receiving, <>0 for sending
;******************************************
ABORT:	call	CILPRT
	db	'ABORT:',' '+80h

	call	PRINTF		;print string at de

	lda	XMODE		;need to close the file?
	ora	a		;0 means receiving
	jnz	EXIT

	jmp	RXEND

;***Exit*****************************************************
;Received EOT during file reception. Flush buffer, Send happy
;termination message, report block count, and return to CP/M.
;On Entry:
;  EOF received, but not yet ACKed
;  XBLOCK = block count 
;************************************************************
RXEOT:	call	WFLUSH		;Write all blocks in BUFFER
	call	TXACK		;ACK EOF

	call	CILPRT
	db	'O','K'+80h

;Fall into RXEND

;***Exit*****************************************
;Close the file. If no blocks were received, then
;delete the empty file; otherwise, print the
;number of blocks received. Then return to CP/M.
;On Entry:
;  XBLOCK = block count 
;************************************************
RXEND:	call	FCLOSE		;Close CP/M file

	lhld	XBLOCK		;any disk blks written?
	mov	a,h
	ora	l		;check 16-bit blk count
	jnz	RRXCNT		;y: report blks written

	call	FDELET		;n: delete empty file

	inr	a		;successful delete?
	jz	RRXCNT		;n: print 0 byte file

	call	MSGXIT		;succesful deletion
	db	CR,LF,'Empty file deleted$'

RRXCNT:	call	CILPRT
	db	'Received',' '+80h

;Fall into REPCNT

;***Exit*******************************************
;Report 16-bit block count, and then return to CP/M
;On Entry:
;  XBLOCK = block count 
;  either 'sent' or 'received' already printed
;**************************************************
REPCNT:	lhld	XBLOCK
	call	PDEC16		;print block count in decimal

	call	MSGXIT		;print & return to CP/M
	db	' blocks$'

;***************************
;$-terminated abort messages
;***************************
ELEMSG:	db	(ERRLIM/10)+'0'		;too many block retries
	db	(ERRLIM-((ERRLIM/10)*10))+'0'
	db	' block errors$'
TAEMSG:	db	(ERRLIM/10)+'0'		;too many bad ACKs
	db	(ERRLIM-((ERRLIM/10)*10))+'0'
	db	' ACK errors$'

;***Table*******************************
;CRC Calculation Table
;strategically placed on a page boundary
;***************************************
;Force the CRTTAB table to be page-aligned

TPAGER	equ	$
	org	(TPAGER+255) and 0FF00h

CRCTAB:

;high bytes

db	000h,010h,020h,030h,040h,050h,060h,070h
db	081h,091h,0A1h,0B1h,0C1h,0D1h,0E1h,0F1h
db	012h,002h,032h,022h,052h,042h,072h,062h
db	093h,083h,0B3h,0A3h,0D3h,0C3h,0F3h,0E3h
db	024h,034h,004h,014h,064h,074h,044h,054h
db	0A5h,0B5h,085h,095h,0E5h,0F5h,0C5h,0D5h
db	036h,026h,016h,006h,076h,066h,056h,046h
db	0B7h,0A7h,097h,087h,0F7h,0E7h,0D7h,0C7h
db	048h,058h,068h,078h,008h,018h,028h,038h
db	0C9h,0D9h,0E9h,0F9h,089h,099h,0A9h,0B9h
db	05Ah,04Ah,07Ah,06Ah,01Ah,00Ah,03Ah,02Ah
db	0DBh,0CBh,0FBh,0EBh,09Bh,08Bh,0BBh,0ABh
db	06Ch,07Ch,04Ch,05Ch,02Ch,03Ch,00Ch,01Ch
db	0EDh,0FDh,0CDh,0DDh,0ADh,0BDh,08Dh,09Dh
db	07Eh,06Eh,05Eh,04Eh,03Eh,02Eh,01Eh,00Eh
db	0FFh,0EFh,0DFh,0CFh,0BFh,0AFh,09Fh,08Fh
db	091h,081h,0B1h,0A1h,0D1h,0C1h,0F1h,0E1h
db	010h,000h,030h,020h,050h,040h,070h,060h
db	083h,093h,0A3h,0B3h,0C3h,0D3h,0E3h,0F3h
db	002h,012h,022h,032h,042h,052h,062h,072h
db	0B5h,0A5h,095h,085h,0F5h,0E5h,0D5h,0C5h
db	034h,024h,014h,004h,074h,064h,054h,044h
db	0A7h,0B7h,087h,097h,0E7h,0F7h,0C7h,0D7h
db	026h,036h,006h,016h,066h,076h,046h,056h
db	0D9h,0C9h,0F9h,0E9h,099h,089h,0B9h,0A9h
db	058h,048h,078h,068h,018h,008h,038h,028h
db	0CBh,0DBh,0EBh,0FBh,08Bh,09Bh,0ABh,0BBh
db	04Ah,05Ah,06Ah,07Ah,00Ah,01Ah,02Ah,03Ah
db	0FDh,0EDh,0DDh,0CDh,0BDh,0ADh,09Dh,08Dh
db	07Ch,06Ch,05Ch,04Ch,03Ch,02Ch,01Ch,00Ch
db	0EFh,0FFh,0CFh,0DFh,0AFh,0BFh,08Fh,09Fh
db	06Eh,07Eh,04Eh,05Eh,02Eh,03Eh,00Eh,01Eh

;Low Bytes

db	000h,021h,042h,063h,084h,0A5h,0C6h,0E7h
db	008h,029h,04Ah,06Bh,08Ch,0ADh,0CEh,0EFh
db	031h,010h,073h,052h,0B5h,094h,0F7h,0D6h
db	039h,018h,07Bh,05Ah,0BDh,09Ch,0FFh,0DEh
db	062h,043h,020h,001h,0E6h,0C7h,0A4h,085h
db	06Ah,04Bh,028h,009h,0EEh,0CFh,0ACh,08Dh
db	053h,072h,011h,030h,0D7h,0F6h,095h,0B4h
db	05Bh,07Ah,019h,038h,0DFh,0FEh,09Dh,0BCh
db	0C4h,0E5h,086h,0A7h,040h,061h,002h,023h
db	0CCh,0EDh,08Eh,0AFh,048h,069h,00Ah,02Bh
db	0F5h,0D4h,0B7h,096h,071h,050h,033h,012h
db	0FDh,0DCh,0BFh,09Eh,079h,058h,03Bh,01Ah
db	0A6h,087h,0E4h,0C5h,022h,003h,060h,041h
db	0AEh,08Fh,0ECh,0CDh,02Ah,00Bh,068h,049h
db	097h,0B6h,0D5h,0F4h,013h,032h,051h,070h
db	09Fh,0BEh,0DDh,0FCh,01Bh,03Ah,059h,078h
db	088h,0A9h,0CAh,0EBh,00Ch,02Dh,04Eh,06Fh
db	080h,0A1h,0C2h,0E3h,004h,025h,046h,067h
db	0B9h,098h,0FBh,0DAh,03Dh,01Ch,07Fh,05Eh
db	0B1h,090h,0F3h,0D2h,035h,014h,077h,056h
db	0EAh,0CBh,0A8h,089h,06Eh,04Fh,02Ch,00Dh
db	0E2h,0C3h,0A0h,081h,066h,047h,024h,005h
db	0DBh,0FAh,099h,0B8h,05Fh,07Eh,01Dh,03Ch
db	0D3h,0F2h,091h,0B0h,057h,076h,015h,034h
db	04Ch,06Dh,00Eh,02Fh,0C8h,0E9h,08Ah,0ABh
db	044h,065h,006h,027h,0C0h,0E1h,082h,0A3h
db	07Dh,05Ch,03Fh,01Eh,0F9h,0D8h,0BBh,09Ah
db	075h,054h,037h,016h,0F1h,0D0h,0B3h,092h
db	02Eh,00Fh,06Ch,04Dh,0AAh,08Bh,0E8h,0C9h
db	026h,007h,064h,045h,0A2h,083h,0E0h,0C1h
db	01Fh,03Eh,05Dh,07Ch,09Bh,0BAh,0D9h,0F8h
db	017h,036h,055h,074h,093h,0B2h,0D1h,0F0h

;********************************
;More $-terminated abort messages
;********************************
CCMSG:	db	'^C$'			;User typed ^C
SYNMSG:	db	'Sync fail$'		;can't find SOH
LBMSG:	db	'Lost blocks$'		;out of sequence
EWFMSG:	db	'Disk write fail$'	;CP/M error
UTOMSG:	db	'UART '			;fall into TTOMSG
TTOMSG:	db	'Tx fail$'		;Tx not ready
UPMSG:	db	'Undefined Port$'	;custom IO port fail
NAMSG:	db     'No init from receiver$'	;timeout

;***Subroutine*********************************************
;Get the error-checking mode: Wait for the initial NAK or
;SELCRC from the receiver. (NAK means we use checksums, and
;SELCRC means we use CRC-16.) Ignore all other characters,
;with a long timeout. Abort if user types Control-C.
;On Entry:
;  XPORT=0 if using console for transfers
;   (so don't print messages on console)
;On Succesful Exit:
;  CRCFLG = 0 if NAK received
;  CRCFLG <> 0 if SELCRC received
;  Message printed if CRC mode
;  RTORET set to WAITNK
;Trashes all registers
;**********************************************************
GTMODE:	mvi	b,NAKTO		;Long timeout

	lxi	h,WAITNK	;timeout return address
	shld	RTORET		;..for RXBYT1

	lda	PACCNT		;for quiet mode test
	mov	c,a

WAITNK:	lxi	d,NAMSG
	dcr	b		;Timeout?
	jz	ABORT		;yes: abort

	call	RXBYT1
	xri	NAK		;NAK for checksum?

	sta	CRCFLG		;0 for cksum, NZ otherwise

	jz	PCSNT		;yes:message, done

	cpi	SELCRC xor NAK	;'C' for CRC?
	jnz	WAITNK		;No: Keep looking

	inr	c		;Quiet mode?
	rz			;y: no message

;Fall into PCRC

;***Subroutine****
;Print 'with CRCs'
;On Exit:
;  Z flag cleared
;Trashes a,c
;*****************
PCRC:	call	ILPRNT
	db	' with CRC','s'+80h
	ret

;***Subroutine**********************
;Print 'with checksums' unless quiet
;On Entry:
;  c= FFh if quiet mode
;On Exit:
;  Z flag cleared
;Trashes a,c
;***********************************
PCSNT:	inr	c		;quiet mode?
	rz			;y: no message

;Fall into PCKSUM

;***Subroutine*********
;Print 'with checksums'
;On Exit:
;  Z flag cleared
;Trashes a,c
;**********************
PCKSUM:	call	ILPRNT
	db	' with checksum','s'+80h
	ret

;***Exit*******************************************
;Print CRLF, then $-terminated string following the
;call. Fix everything for CP/M, and return to CP/M
;**************************************************
CMSGXT:	call	PCRLF

;Fall into MSGXIT

;***Exit******************************************
;Print $-terminated string following the call, fix
;everything for CP/M, and return to CP/M
;*************************************************
MSGXIT:	pop	d		;Get message address
	call	PRINTF

;Fall into EXIT

;***Exit***********************************
;Return to CP/M. All exits go through here.
;******************************************
EXIT:	jmp	WBOOT		;go to CP/M

;******************************************************
;RAM Variables and Storage, all initialized during load
;******************************************************
;------------------------------
;XMODEM file transfer variables
;------------------------------
RXBDIF:	db	0	;Received block number minus
			;..previous block's block number
XBLOCK:	dw	0	;16-bit Current block number 
ERRCNT:	db	0	;Error count
NAKCHR:	db	NAK	;current NAK chr
TIMRLD:	dw	0001h	;receive timeout value
			;initialized for receiver flush in INIT
TIMRH:	db	0	;high byte of timer
RTORET:	dw	PPTIMO	;Receive timeout error return address
			;initialized for receiver flush in INIT

;------------------------
;Disk buffering variables
;------------------------
BLKPTR:	dw	BUFFER	;Points to next block in BUFFER
BUFCNT:	dw	0	;Count of 128-byte blocks in BUFFER
CLFLAG:			;1 means reading .CFG,
			;..0 means command line
EOFLAG:	db	1	;EOF flag (<>0 means true)

;---------------------------
;Other initialized variables
;---------------------------
XMODE:	db	0FFh	;1 for send, 0 for receive
			;FFh for uninitialized
CRCFLG:	db	SELCRC	;0 for checksum, NZ for CRC
			;init to SELCRC for receiving

PACCNT:	db	PACLIN ;Current column position for
			;pacifiers. Init to start new line
			;FF disables pacifiers.

;************************************************
;Buffer for XMODEM blocks. This buffer overwrites
;the following initialization code, as well as
;CP/M's CCP. The buffer is forced to an even
;block boundary for faster compares.
;************************************************
BPAGER	equ	$
BUFFER:	equ	(BPAGER+BLKSIZ-1) and (0-BLKSIZ)

;===========================================================
;= The following subroutines and variables are used only   =
;= during the initial command line processing, and get     =
;= wiped out by the BUFFER, once we start transfering data.=
;===========================================================
;-----------------------------------------------------
;Defaulted variables needed only during initialization
;-----------------------------------------------------
BYTCNT:	db	0	;command buffer bytes
CPUMHZ:	db	2	;CPU speed in MHz (for timeouts)
XPORT:	db	1	;Transfer port defaults to RDR/PUN
ENHRDR:	db	0	;01 for RDR that returns with
			;..Z set if chr not ready

;***INIT-Only Subroutine*******************************
;Open CP/M disk file (for reading), and reports success
;or failure to console.
;On Entry:
;  FCB has file name
;On successful Exit:
;  de = FCB
;  File is open
;  File-open message has been printed on the console
;On failure:
;  Relevent error msg has been printed on the console
;  jump to CP/M
;Trashes psw,bc
;******************************************************
FOPEN:	lxi	d,FCB		;FCB describes file to open
	mvi	c,BOPEN		;CP/M FILE OPEN function
	call	GOBDOS
	inr	a		;-1 means open failure
	jz	FOFAIL

;Start announcing

	call	CILPRT
	db	'File open',CR,LF
	db	'Sen','d'+80h

;Fall into ANNCTP

;***INIT-Only Subroutine**********
;Announce transfer port. Disable
;pacifiers if transfer port is CON
;Trashes psw,c
;*********************************
ANNCTP:	call	ILPRNT
	db	'ing via',' '+80h

	lda	XPORT
	dcr	a
	jm	TVC

	dcr	a
	jm	TVR
	jz	TVD

	call	ILPRNT
	db	'external cod','e'+80h
	ret

TVD:	call	ILPRNT
	db	'direct I/','O'+80h
	ret

TVR:	call	ILPRNT
	db	'RDR/PU','N'+80h
	ret

TVC:	sta	PACCNT		;CON: turn off pacifiers
	call	ILPRNT
	db	'CO','N'+80h
	ret

;--------------------------------------
;Error opening file: Abort with message
;--------------------------------------
FOFAIL:	call	CMSGXT	;Exit w/ this message
	db	'File not found$'

;***INIT-Only Subroutine******************************
;Create file on disk (for writing) and report. If the
;file already exists, ask if it should be overwritten.
;On Entry:
;  FCB has file name
;On successful Exit:
;  File is created and open
;  File-created message has been printed on console
;  Initial NAK or C (cksum or CRC mode) has been sent
;On failure:
;  Relevent error msg has been printed on the console
;  jump to CP/M
;Trashes all registers
;*****************************************************
CREATE:
;------------------------------------------------------
;See if file already exists, and ask to overwrite if so
;------------------------------------------------------
	lxi	d,FCB

	mvi	c,BSERCH	;Search directory for file
	call	GOBDOS

	inr	a		;-1 means not there
	jz	FILNEX		;no file: ok

	call	CILPRT
	db	'File exists. Overwrite (Y/N)','?'+80h

	call	GETANS		;Get 1-chr response
	cpi	'Y'
	jnz	EXIT

	call	FDELET		;delete existing file
				;returns de=FCB

;------------------------
;Create file on CP/M disk
; de still points to FCB
;------------------------
FILNEX:	call	CILPRT		;either 'File created'
				;or 'File create error'
	db	'File creat','e'+80h

	mvi	c,BMAKE		;CP/M CREATE FILE func
	call	GOBDOS
	inr	a		;-1 means create error

	jz	FCERR

;---------------------------
;Tell user that we are ready
;---------------------------
	call	ILPRNT		;finish message

	db	'd'		;end of 'File created'
	db	CR,LF,'Recei','v'+80h

	call	ANNCTP		;announce port

;-----------------------------------------------
;Delay for a few seconds if receiving via the
;console, to give the user time to start sending
;-----------------------------------------------
	lda	XPORT		;console?
	ora	a
	jnz	RXIND

	lxi	b,26786		;delay loop time
	call	TSETUP		;adjust for CPU speed

RIDEL:	call	CCTRLC		;(about 200 cycles)
	dcx	h		;(5)timeout timer?
	mov	a,l		;(5)Test for 16-bit 0
	ora	h		;(4)
	jnz	RIDEL		;(10)

;224 cycles/pass
;3 seconds = 3,000,000 uS = 6,000,000 cycles
;6,000,000/224 = 26786

RXIND:

;--------------------------------------------
;Set initial character to NAK or SELCRC, and
;report error checking mode (checksum or CRC)
;--------------------------------------------
	lda	CRCFLG		;CRC or checksum?
	ora	a		;0 means checksum
				;NZ means CRC

	jz	RXCSM
	sta	NAKCHR		;set CRC initial ACK

	call	PCRC		;print ' with CRCs'
				;..returns with Z cleared
RXCSM:	cz	PCKSUM		;print ' with checksums'

;-----------------------------------------------
;Send initial NAK or SELCRC to initiate transfer
;-----------------------------------------------
	lda	NAKCHR		;send the initial ACK
	jmp	TXBYTE		;return via TXBYTE

;---------------------------------------
;Error: File create failed
; 'File create' has already been printed
;---------------------------------------
FCERR:	call	MSGXIT
	db	' fail. Write protect? Directory full?$'

;***INIT-Only Subroutine***********************
;Initialization: parse command line, set up FCB
; return with a=XMODE=0 for receive, 1 for send 
;**********************************************

;---------------------------------------------------
;Set default CPU speed to 4MHZ if a Z80 is detected.
;(The user can later change this with /Z option)
;---------------------------------------------------
INIT:	
	; -----------------------------------
	; Set the 8 bit CONST mode (Z80-MBC2)
	; -----------------------------------
	push psw
	mvi	a,CONSTMD
	call GOBIOS
	pop psw
	;
	; -----------------------------------
	;
	sub	a		;test for 8080 or Z80
	jpe	IS8080
	mvi	a,4		;Assume Z80s run 4 MHz
	sta	CPUMHZ
IS8080:

;----------------------------------------
;Copy the command buffer so that CP/M 1.4
;won't destroy it during the BDOS call
;----------------------------------------
	lxi	h,COMBUF
	lxi	d,ICOMBF
	mvi	b,80

LDIR:	mov	a,m
	stax	d
	inx	h
	inx	d
	dcr	b
	jnz	LDIR

;-----------------------------
;look for a configuration file
;and parse it, if it exists
;-----------------------------

	lxi	d,CFGFCB	;FCB describes file to open
	mvi	c,BOPEN		;CP/M FILE OPEN function
	call	GOBDOS
	inr	a		;-1 means open failure
	cnz	PARSE

;----------------------------------
;Parse commands on the command line
;----------------------------------
	xra	a		;command line next
	sta	CLFLAG		;also clears EOFLAG

	lxi	d,ICOMBF	;copy of CP/M cmd line
	ldax	d		;1st byte is the byte count
	sta	BYTCNT
	inx	d

	call	WSKIP		;skip initial whitespace
	jc	HLPEXT		;no parameters: help

;Skip past the file name, which CP/M
;already put in the FCB for us

SKPFIL:	call	CMDCHR
	jc	CMDONE		;end of command line?

	cpi	'/'		;option crammed
	jnz	SF1		;..against file name?	

	dcx	d		;y: back up
	inr	m		;hl=BYTCNT from CMDCHR
	mvi	a,' '		;..and pass the next test	

SF1:	cpi	' '		;hunt for a space
	jnz	SKPFIL

	call	PARSE
CMDONE:

;-------------------------------------------------
;Initialize File Control Block for disk transfers:
;Check for an option crammed against the file name
;in the FCB, and clean it up (by padding with
;spaces) if necessary. Fill the FCB Extent bytes
;with zeros, as required.
;-------------------------------------------------
	lxi	b,(FCBNL+1)*256+FCBCLR ;2 counters

	lxi	h,FCBFN-1	;file name in FCB
	mvi	a,'/'		;option marker

FC1:	inx	h
	dcr	b
	jz	FC3		;all bytes checked?

	cmp	m		;crammed option?
	jNz	FC1

;Clear the rest of the name

FC2:	mvi	m,' '		;cleanup file name
	inx	h
	dcr	b
	jnz	FC2
FC3:

;b=0
;c=FCBCLR
;hl=FCBEXT
;Clear the FCB Extent bytes

FC4:	mov	m,b
	inx	h
	dcr	c
	jnz	FC4

;--------------------------------------------------------
;Patch RXBYTE and TXBYTE for the specified transfer port.
;Also set TIMRLD to the correct value for 1/2 second
;receive timouts, based on XPORT and CPU speed. Flush the
;receiver unless it's RDR that's not modified to return
;with Z set when no chr is waiting.
;On Entry
;  XPORT    ENHRDR     Port
;   0         x      Console
;   1         0      PUN/Standard RDR
;   1         1      PUN/Enhanced RDR
;   2         x      Direct I/O
;   3         x      Custom I/O
;-------------------------------------------------------
PATCHP:	lxi	h,PORTAB
	lda	XPORT
	add	a		;*2
	mov	e,a
	add	a		;*4
	add	e		;*6
	mov	e,a
	mvi	d,0
	dad	d

	mov	c,m
	inx	h
	mov	b,m		;bc=timeout value

	inx	h
	mov	e,m
	inx	h
	mov	d,m		;de=RX byte routine addr
	xchg

;Check for enhanced RDR if RDR is selected, and
;flush the reader unless it's the unmodified RDR port
;(which would hang forever waiting for input)

	cpi	6		;RDR port?
	jnz	PP1		;n: hl has correct address

	lda	ENHRDR		;Enhanced RDR?
	ora	a
	jz	PP1		;n: hl has correct adress

	lxi	h,RXERDR	;y: update patch

PP1:	shld	RXROUT+1
	cnz	RXBYT1		;flush receiver unless it's
				;..unmodified RDR
PPTIMO:				;(timeout goes to PPTIMO)

	xchg
	inx	h
	mov	e,m
	inx	h
	mov	d,m		;de=TX byte routine addr
	xchg
	shld	TXROUT+1

	call	TSETUP		;set up the Rx timer
				;bc is set for selected port

;----------------------------------------
;Run any user-defined initialization code
;(This gets filled in by /I0 option)
;----------------------------------------
CINIT:	nop			;8 bytes space
	nop
	nop
	nop
	nop
	nop
	nop
	nop

;----------------------------------------
;Did we get a direction? Return from Init
;with a=XMODE if so
;----------------------------------------
	lda	XMODE		;did /R or /S get set?
	ora	a		;-1 meant uninitialized
	rp			;with result in a

;-------------------------------------
;No direction specified (by /R or /S),
;so ask the user which way
;-------------------------------------
ASKRS:	call	CILPRT
	db	'Send or receive (S/R)?',' '+80h

	call	GETANS

	sui	'R'		;'R' and 'S' are adjacent
	cpi	2		;'R' or 'S'?
	jnc	ASKRS		;n: try again

	sta	XMODE		;1 for send, 0 for receive
	ret			;with result in a

;***INIT-Only Subroutine**************************
;Get a 1-character response (with editing, CR, and
;potential control-C) from the user
;On Exit:
;  a=uppercase response, if 1 chr typed
;  a=ff for no characters typed
;  a=1-7 for 2-8 characters typed (definitely not
;   'Y','N','R', or 'S')
;Trashes c,de
;*************************************************
GETANS:	lxi	d,COMBUF
	mvi	a,8			;max chrs
	stax	d
	mvi	c,BRDCON
	call	GOBDOS			;returns chr count
	lda	COMBUF+1
	dcr	a			;just 1 chr?
	rnz				;n: error exit

	lda	COMBUF+2		;1st chr in the buffer
	ani	('a'-'A')xor 0FFh	;uppercase
	ret

;***INIT-Only Subroutine***************************
;Parse command line or CFG file options
;On Entry:
;  CLFLAG = 1 for config file
;           0 for command line
;  de = address of command string terminated by EOF
;**************************************************
PARSE:
;-----------------------------------------------------------
;Parse all command line options & set variables accordingly. 
;Each option must be preceeded by a '/' Options may be
;preceeded by any reasonable number of spaces, tabs,
;carriage returns and/or line feeds.
;-----------------------------------------------------------
OPTLUP:	call	WSKIP		;skip whitespace
	rc			;end of input input?

	lxi	b,OPTLUP	;create return address
	push	b

	cpi	';'		;comment?
	jz	COMMNT		;y: ignore until CR or LF

	cpi	'/'		;all start with /
	jnz	BADINP		;error:no slash

	call	CMDCHR		;Get an option chr
	jc	BADINP		;Error: nothing after /

;-----------------------------------------------------------
;Got a command line option in a. Loop through table of
;options, looking for a match. Update the appropriate option
;variable with the table value. Error exit if not in table.
;  a = option character
;Trashes c,hl
;-----------------------------------------------------------
	lxi	h,OPTTAB

CHKLUP:	cmp	m		;Match? (alpha order)
	inx	h
	mov	c,m		;get routine address offset
	inx	h

	jc	OPTERR		;illegal option
	jnz	CHKLUP		;No match: keep looking

;-----------------------------------------
;Option match. Go execute option routine
;On Entry:
;  c = option routine adress offset
;  de  points to next cmd byte
;  top-of-stack = return address to OPTLUP
;Command routines preserve/advance de
;-----------------------------------------
	xra	a
	mov	b,a		;high byte
	lxi	h,CMDBAS
	dad	b		;hl=address of routine

	pchl			;go to routine

;*****************
; Option Commands
;*****************
CMDBAS:

;******----------------------
;* /C * Set Rx Checksum Mode
;******
;On Entry:
;  a=0
;  (de)=next command line chr
;On Exit:
;  CRCFLG = 0
;----------------------------
CCKSUM:	sta	CRCFLG
	ret

;******----------------------------
;* /E * Specify Enhanced Reader
;****** (RDR returns Z when no chr)
;On Entry:
;  a=0
;  (de)=next command line chr
;On Exit:
;  ENHRDR = 1
;----------------------------------
CMODR:	inr	a
	sta	ENHRDR
	ret

;*****--------------------------------------------------
; /I * Patch Custom I/O Routine
;*****
; /I0 hh hh hh... defines init code
; /I1 hh hh hh... defines transmit port routine
; /I2 hh hh hh... defines receive status routine
; /I3 hh hh hh... defines receive data routine
;Max 8 hh digits. (The original intention is to use these
;patches to call some ROM I/O routines, perhaps with a
;couple of registers set up prior to the calls.)
;On Entry:
;  (de)=next command line chr
;On Exit:
;  A Custom Transfer port routine has been written
;  de incremented past /I data
;-------------------------------------------------------
CCIO:	call	CMDCHR		;get next command line chr

;Get the address of the routine to define, based on a

	lxi	h,CINIT
	sui	'0'		;un-ASCII, test 0
	jz	CIOGET		;Init code?

	lxi	h,CWDAT
	dcr	a		;Tx port code?
	jz	CIOGET

	lxi	h,CRSTAT
	dcr	a		;Rx stat code?
	jz	CIOGET

	lxi	h,CRDAT
	dcr	a		;Rx data code?
	jnz	BADVAL		;n: bogus

;Get & install all routine bytes, padding with nops at the end

CIOGET:	mvi	c,8		;max bytes for a routine

CIOG0:	push	h
	call	GETHEX
	pop	h
	jnc	GIOG1		;any character?
	xra	a		;n: install nop
GIOG1:	mov	m,a

	inx	h
	dcr	c
	jnz	CIOG0

	ret			;note: any more hex values
				;will cause an error in PARSE

;******-------------------------
;* /M * print message on console
;******
;On Entry:
;  (de)=next command line chr
;-------------------------------
CMESSG:	call	PCRLF		;initial new line

CMSGLP:	call	CMDCHR		;get next chr
	rc			;end of file?
	rz			;end of message string?
	call	PRINTA		;to console
	jmp	CMSGLP

;******-----------------------------------------
;* /O * Output to Port
;******
;On Entry:
;  (de)=next command line chr
;      subsequent bytes are init sequence
;On Exit:
;  Data sequence has been sent to specified port
;  de incremented past /O data
;-----------------------------------------------
COUTP:	call	GTHEXM		;get port number
	sta	IPORT+1

CILOOP:	call	GETHEX		;get an init value
	rc			;done?

IPORT:	out	0		;port address gets modified
	jmp	CILOOP

;******-------------------------------------
;* /P * Define Transfer Port
;******
;On Entry:
;  (de)=next command line chr
;On Exit:
;  Transfer port routines have been modified
;  de incremented past /P data
;-------------------------------------------
CPORT:	call	GTHEXM		;get status port
	mov	l,a
	call	GTHEXM		;get data port
	mov	h,a
	call	GTHEXM		;get jz/jnz flag
	mov	c,a
	call	GTHEXM		;get Rx ready mask

	push	psw		;save Rx ready on stack
	call	GTHEXM		;get Tx ready mask

	xchg			;ports to de,pointer to hl
	xthl			;save pointer on stack
	push	h		;put Rx Ready back on stack

	lxi	h,OMODFY+1	;a=Tx ready mask
	call	MODIO		;modify input routine

	pop	psw		;a=Rx ready mask
	lxi	h,IMODFY+1
	call	MODIO		;modify input routine

	pop	d		;restore cmd pointer

	ret

;******----------------------
;* /Q * Enables quiet mode
;******
;On Entry:
;  a=0
;  (de)=next command line chr
;On Exit:
;  PACCNT=FFh
;----------------------------
CQUIET:	dcr	a		;a=FFh
	sta	PACCNT
	ret

;******----------------------
;* /S * Select send mode
;******
;On Entry:
;  a=0
;  (de)=next command line chr
;On Exit:
;  XMODE = 1
;----------------------------
CSETS:	inr	a	;a=1

;Fall into CSETR tpo save XMODE

;******----------------------
;* /R * Select receive mode
;******
;On Entry:
;  a=0
;  (de)=next command line chr
;On Exit:
;  XMODE = 0
;----------------------------
CSETR:	sta	XMODE
	ret

;******----------------------
;* /X * Select transfer port
;******
;On Entry:
;  (de)=next command line chr
;On Exit:
;  XPORT set as specified
;----------------------------
CSETX:	call	CMDCHR

	sui	'0'		;un-ASCII
	cpi	4		;0-3 allowed
	jnc	BADVAL
	sta	XPORT
	ret

;******--------------------------------
;* /Z * Specify CPU speed, in MHz (1-6)
;******
;On Entry:
;  (de)=next command line chr
;On Exit:
;  CPUMHZ updated
;-------------------------------------
CMHZ:	call	CMDCHR

	sui	'1'		;un-ASCII
	cpi	6		;1-6 allowed
	jnc	BADVAL

	inr	a		;make it 1-6
	sta	CPUMHZ
	ret

;***INIT-Only Subroutine***
;Ignore a comment
;On Entry:
;  de=next command line chr
;**************************
COMMNT:	call	CMDCHR
	rc			;end of file?
	jnz	COMMNT		;Z means CR or LF
	ret
	
;***INIT-Only Exit*********************************
;Print help screen, and then exit. Break up the
;help screen so that it even fits on a 16x64 screen
;**************************************************
HLPEXT:	call	CILPRT		;print this message

;    123456789012345678901234567890123456789012345678901234567890123
 db '=========================',CR,LF
 db 'XMODEM '
 db ((VERSION AND 0F00h)/256)+'0','.',(VERSION AND 0Fh) +'0'
	db	' By M. Eberhard',CR,LF
 db '=========================',CR,LF ; Z80-MBC2
 db 'Z80-MBC2 (CP/M 2.2 only)',CR,LF
 db 'patched ver. by J4F',CR,LF
 db '=========================',CR,LF
 db 'Usage: XMODEM <filename> <option list>',CR,LF
 db '^C aborts',CR,LF,LF
 db 'Command line and XMODEM.CFG options:',CR,LF
 db ' /R to receive, /S to send',CR,LF
 db ' /C receive with checksums, otherwise CRC error checking',CR,LF
 db '    (Receiver sets error checking mode when sending)',CR,LF
 db ' /E if CP/M RDR returns with Z set when not ready',CR,LF,LF
 db '--More-','-'+80h

	call	GETCON		;wait for user input

	call	CILPRT

 db ' /I<n> patches I/O routines with 8080 code for /X3:',CR,LF
 db '   /I0 h0 h1 ...(up to h7) = initialization',CR,LF
 db '   /I1 h0 h1 ...(up to h7) = Tx data (chr is in reg c)',CR,LF
 db '   /I2 h0 h1 ...(up to h7) = Rx status (Z set if no chr)',CR,LF
 db '   /I3 h0 h1 ...(up to h7) = Rx data (chr in reg a)',CR,LF
 db ' /M console message',CR,LF
 db ' /O pp h0 h1 ... hn sends bytes h1-hn to port pp',CR,LF
 db ' /P ss dd qq rr tt defines direct I/O port:',CR,LF
 db '   ss = status port',CR,LF
 db '   dd = data port',CR,LF
 db '   qq = 00/01 for active low/active high ready bits',CR,LF
 db '   rr = Rx ready bit mask',CR,LF
 db '   tt = Tx ready bit mask',CR,LF,LF
 db '--More-','-'+80h

	call	GETCON		;wait for user input

	call	CMSGXT		;print message and exit to CP/M

 db ' /Q for Quiet; else + means good block, - means retry',CR,LF
 db ' /X selects the transfer port:',CR,LF
 db '   /X0 CP/M CON',CR,LF
 db '   /X1 CP/M RDR/PUN (default)',CR,LF
 db '   /X2 Direct I/O, defined by /P option',CR,LF
 db '   /X3 8080 I/O code, patched with /I options',CR,LF
 db ' /Zm for m MHz CPU. 0<m<7, default m=2',CR,LF,LF
 db 'CP/M CON and RDR must not strip parity.',CR,LF
 db 'Values for /I, /O and /P are 2-digit hex.',CR,LF
 db '$'
	
;***INIT-Only Exit*******************************
;Illegal option. Print message and return to CP/M
;On Entry:
;  a=illegal option found
;************************************************
OPTERR:	sta	PAR1		;put it in error msg

	call	CILPRT		;Exit with this message
	db	'/'
PAR1:	db	'&'		;parameter goes here
	db	' unrecognize','d'+80h

	jmp	ERRSRC		;command line or .CFG file

;***INIT-Only Exit**********************************
;Input error exits. Print message and return to CP/M
;***************************************************
BADINP:		call	CILPRT
	db	'Jun','k'+80h

;Fall into ERRSRC

;***INIT-Only Exit****************************
;Bad input of some sort. Print source of error
;and quit to CP/M
;On Entry:
;  CLFLAG = 1 if reading .CFG file
;           0 if command line
;*********************************************
ERRSRC:	lda	CLFLAG		;command line or XMODEM.CFG?
	ora	a
	jz	BADCLN

	call	MSGXIT
	db	' in XMODEM.CFG$'

BADCLN:	call	MSGXIT
	db	' in command line$'

;***INIT-Only Subroutine**************************
;Adjust hl based on CPU speed
;On Entry:
;  bc = CPU cycles for 0.5 sec loop
;     assuming 1 MHz CPU
;  CPUMHZ = CPU speed, in MHz
;On Exit:
;  hl=TIMRLD=CPU cycles in loop for this CPU speed
;Trashes psw,hl
;*************************************************
TSETUP:	lda	CPUMHZ
	lxi	h,0

ADJMHZ:	dad	b
	dcr	a
	jnz	ADJMHZ

	shld	TIMRLD		;timer reload value
	ret

;***INIT-Only Subroutine************************
;Modify either the transfer input port routine
;or output port routine. This assumes that both
;routines look like this:
;
; WAIT:	...
; IMODFY or OMODFY:
;	in	<status port>
;	ani	<port ready mask>
;	jnz	WAIT	(may get converted to jz)
;
;	pop psw (or other 1-byte cmd)
;	in/out	<data port>
;	...
;	ret
;
;On Entry:
;  a = port-ready mask byte
;  c = 0 if jnz needs to be installed
;  d = data port address
;  e = status port address
;  hl = IMODFY+1 or OMODFY+1
;On Exit:
;  z flag unchanged
;Trashes a,hl
;*********************************************
MODIO:	mov	m,e		;install status port

	inx	h		;point to mask location
	inx	h
	mov	m,a		;install mask

	inx	h		;point to jnz location
	mov	a,c
	ora	a
	jz	MODIO1		;need a jz instead?
	mvi	m,JZ		;y: install jz opcode
MODIO1:

	inx	h		;point to data port loc
	inx	h
	inx	h
	inx	h
	inx	h
	mov	m,d		;install data port
	ret

;***INIT-Only Subroutine***************************
;Get a mandatory 2-digit hex value from LINBUF
;On Entry:
;  de points to first hex digit
;On Exit:
;  a=value
;  de advanced 2
;  trashes b
;  Rude jump to BADVAL if no chr or bogus hex found
;**************************************************
GTHEXM:	push	h
	call	GETHEX
	pop	h
	rnc

;Fall into BADVAL

;***INIT-Only Exit**************************
;Bad Value, bad hex character
;Fix everything for CP/M, and return to CP/M
;*******************************************
BADVAL:	call	CILPRT
	db	'Bad valu','e'+80h

	jmp	ERRSRC		;command line or .CFG file

;***INIT-Only Subroutine***************************
;Get an exactly 2-digit hex value from LINBUF
;On Entry:
;  de points to first hex digit
;On Exit:
;  carry set if no value found, either due to
;    end of input or non-hex chr found on 1st digit
;  a=value
;  de advanced past hex if hex found
;  de pointing to non-hex chr if found on 1st digit
;  hl=BYTCNT
;Trashes b
;Rude jump to BADVAL if bogus hex found on 2nd digit
;***************************************************
GETHEX:	call	WSKIP		;skip whitespace, get a chr
				;also sets hl=BYTCNT
	rc			;eof?

	call	HEX2BN		;convert a=1st digit
	jc	GHBACK		;bogus?

	add	a		;shift into place
	add	a
	add	a
	add	a
	mov	b,a		;save digit

	call	GHNIB
	jc	BADVAL		;no digit found or bogus?

	add	b		;combine w/ high digit
	ret			;carry is clear for ret

;non-hex 1st chr found, so backup

GHBACK:	dcx	d		;back up
	inr	m		;(does not affect carry)
	ret			;with carry set
		
;---Local Subroutine-----------------
;convert (de) to binary
;On Exit:
;  a=chr
;  de advanced 1
;  carry set if bad hex chr or no chr
;------------------------------------
GHNIB:	call	CMDCHR		;get a character
	rc			;carry:no more chrs

;Fall into HEX2BN

;---Local Subroutine-------
;convert a to binary
;On Exit:
;  a=chr
;  carry set if bad hex chr
;--------------------------
HEX2BN:	cpi	'9'+1		;below ASCII 9?
	jc	HC1		;Yes: deal with digit

	cpi	'A'		;between 9 & A?
	rc			;yes: bogus

	sui	'A'-'9'-1	;no: subtract offset	

HC1:	sui	'0'
	cpi	10H		;above 0Fh?
	cmc			;so carry means error
	ret			;carry clear means ok

;***INIT-Only Subroutine*************************
;Skip over spaces, tabs, CRs, and LFs in command
;line buffer until any other character is found 
;On Entry:
;  BYTCNT has remaining byte count
;  hl points to the next chr in buffer
;On Exit:
;  a = chr from buffer
;  BYTCNT has been decremented
;  de has been advanced
;  Carry means end of buffer (and a is not valid)
;************************************************
WSKIP:	call	CMDCHR		;sets Z if CR or LF
	rc			;carry set if nothing left
	jz	WSKIP		;skip CR or LF
	cpi	' '
	jz	WSKIP		;skip space
	cpi	TAB
	jz	WSKIP		;skip tab
	ret			;chr in a, carry clear

;***INIT-Only Subroutine*****************************
;Get more command bytes
;If we are reading from ICOMBF then we are done
;Otherwise, try to get another XMODEM.CFG sector
;On Entry:
;  CLFLAG = 1 if reading from XMODEM.CFG
;           0 if reading from command line in ICOMBF
;  de points to the next chr
;  hl=BYTCNT
;On Exit:
;  a = chr from ICOMBF or XMODEM.CFG, parity stripped
;  de has been reset and advanced
;  BYTCNT has bee reset and decremented
;    unless at end
;  Carry means end of buffer
;  Z means CR or LF found
;hl trashed
;****************************************************
RDCMD:	lda	CLFLAG		;reading command buffer?
	sui	1
	rc			;y: ret w/carry: done	

	push	b
	lxi	d,CFGBUF
	push	d
	mvi	c,BSTDMA	;Set CP/M DMA address
	call	GOBDOS		;Trashes no registers
	lxi	d,CFGFCB
	mvi	c,BREAD		;read another sector
	call	GOBDOS		;a=0 if not eof
	pop	d		;buffer address
	pop	b		;d=CFGBUF

	ora	a		;end of input?
	stc			;nz if end if file found
	rnz

	mvi	m,BLKSIZ	;another XMODEM.CFG sector

;Fall into CMDCHR

;***INIT-Only Subroutine*****************************
;Get next character from command line buffer
;On Entry:
;  CLFLAG = 1 if reading from XMODEM.CFG
;           0 if reading from command line in ICOMBF
;  BYTCNT has remaining buffer byte count
;  de points to the next chr
;On Exit:
;  a = chr from ICOMBF or XMODEM.CFG, parity stripped
;  de has been advanced and BYTCNT decremented
;    unless at end
;  hl =BYTCNT
;  Carry means end of buffer
;  Z means CR or LF found
;****************************************************
CMDCHR:	lxi	h,BYTCNT
	mov	a,m
	ora	a		;any bytes left?
	jz	RDCMD		;n:try to get more
	
	ldax	d		;get buffer chr
	ani	7Fh		;Strip parity

	cpi	EOF		;file end?
	stc			;y: ret with carry set
	rz

	inx	d		;bump buffer pointer
	dcr	m		;dec BYTCNT

	cpi	CR
	rz
	cpi	LF
	stc
	cmc			;clear carry
	ret
	
;***INIT-Only Table************************
;Port configuration table
;Three words per entry:
; Word 0 = timer constant
; Word 1 = address of receive byte routine
; Word 3 = address of transmit byte routine
;******************************************
PORTAB:	dw	CONTO,RXBCON,TXCON
	dw	RDRTO,RXRDR,TXPUN
	dw	DIRTO,RXDRCT,TXDRCT
	dw	CUSTO,RXCUST,TXCUST

;***INIT-Only Table**************************
;Command Line Options Table
;Table entries must be in alphabetical order,
;and terminated with 0FFh
;
;2 bytes per entry:
; Byte 0 = Uppercase legal option letter
; Byte 1 = offset to address of parse routine
;********************************************
OPTTAB:	db	'C',CCKSUM-CMDBAS	;Select checksum mode
	db	'E',CMODR-CMDBAS	;Enhanced RDR port
	db	'I',CCIO-CMDBAS		;Custom I/O definition	
	db	'M',CMESSG-CMDBAS	;console message
	db	'O',COUTP-CMDBAS	;output to port
	db	'P',CPORT-CMDBAS	;define transfer port
	db	'Q',CQUIET-CMDBAS	;quiet mode
	db	'R',CSETR-CMDBAS	;select receive mode
	db	'S',CSETS-CMDBAS	;select receive mode
	db	'X',CSETX-CMDBAS	;select transfer port
	db	'Z',CMHZ-CMDBAS		;specify CPU MHz
	db	0FFh			;end of table

;***INIT-Only Table**************
;Configuration File Control Block
;********************************
CFGFCB:	db	0		;(dr) use default drive
	db	'XMODEM  '	;(f1-f8)
	db	'CFG'		;(t1-t3)
	db	0,0,0,0		;(ex,s1,s2,rc)
	dw	0,0,0,0,0,0,0,0	;(d0-d15)
	db	0,0,0,0		;(cr,r0,r1,r2)

;***INIT-Only Buffer******
;Configuration file buffer
;*************************
CFGBUF:	ds	BLKSIZ

;***INIT-Only Stack*************************
;Stack space used only during initialization
;*******************************************
	ds	64		;plenty of room
ISTACK:
;***INIT-Only Buffer*********************************
;Command line buffer, used only during initialization
;****************************************************
ICOMBF:	ds	80

	END

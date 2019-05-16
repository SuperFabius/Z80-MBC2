01 REM ****************************************
02 REM
03 REM Z80-MBC2 ATXBUFF demo:
04 REM
05 REM Shows the use of the ATXBUFF Opcode
06 REM
07 REM ****************************************
08 REM
09 PRINT
10 PRINT "NOTE: To see differeces in ATXBUFF values you must have the serial @ 9600 baud!"
11 ATXBUFF = 136 : REM ATXBUFF read Opcode (0x88)
12 PRINT "Waitng a while..."
13 GOSUB 505 : REM some delay to free the TX bufer
15 GOSUB 700 : REM Print ATXBUFF
20 PRINT
22 PRINT "Now printing some text just to put some bytes in the TX buffer..."
24 GOSUB 700 : REM Print ATXBUFF
25 PRINT
29 PRINT "Waitng a while..."
30 GOSUB 505 : REM some delay to free the TX bufer
40 GOSUB 700 : REM Print ATXBUFF
50 GOTO 900
490 REM
500 REM * * * * * DELAY SUB
501 REM
505 FOR J=0 TO 2000
510 NEXT J
520 RETURN
690 REM
691 REM * * * * * PRINT ATXBUFF SUB
692 REM
700 OUT 1,ATXBUFF : REM Write the ATXBUFF read Opcode
710 I = INP(0) : REM Read free bytes in the TX buffer
720 PRINT "ATXBUFF = ";
730 PRINT I
740 RETURN
900 REM

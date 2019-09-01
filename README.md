# Z80-MBC2

The Z80-MBC2 is an easy to build Z80 SBC (Single Board Computer). It is the "evolution" of the Z80-MBC (https://hackaday.io/project/19000-a-4-4ics-z80-homemade-computer-on-breadboard), with a SD as "disk emulator" and with a 128KB banked RAM for CP/M 3 (but it can run CP/M 2.2, QP/M 2.71 and UCSD Pascal too).

It has an optional on board 16x GPIO expander, and uses common cheap add-on modules for the SD and the RTC options. It has an "Arduino heart" using an Atmega32A as EEPROM and "universal" I/O emulator (so a "legacy" EPROM programmer is not needed).

It is a complete development "ecosystem", and using the iLoad boot mode it is possible cross-compile, load and execute on the target an Assembler or C program (using the SDCC compiler) with a single command (like in the Arduino IDE). 

Project page: https://hackaday.io/project/159973-z80-mbc2-4ics-homemade-z80-computer

UCSD Pascal porting was made by Michel Bernard

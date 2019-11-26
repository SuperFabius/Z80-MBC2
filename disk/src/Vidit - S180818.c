// ****************************************************************************************
/*

ViDiT - Virtual Disk Test - S180818

Virtual Disks Module test program for the Z80-MBC2 - HW ref: A040618



NOTE1: Required SD module installed

NOTE2: Required IOS S220718 (or newer revisions until otherwise stated) 



Compiled with SDDC 3.6.0 (with S190818_crt0.s)

*/
// ****************************************************************************************


// Libraries
#include <stdio.h>


// Z80-MBC2 I/O opcodes definition (IOS - S220718)
//
//
// Currently defined Opcodes for I/O write operations:
//
//   Opcode     Name            Exchanged bytes
// -------------------------------------------------
// Opcode 0x00  USER LED        1
// Opcode 0x01  SERIAL TX       1
// Opcode 0x03  GPIOA Write     1
// Opcode 0x04  GPIOB Write     1
// Opcode 0x05  IODIRA Write    1
// Opcode 0x06  IODIRB Write    1
// Opcode 0x07  GPPUA Write     1
// Opcode 0x08  GPPUB Write     1
// Opcode 0x09  SELDISK         1
// Opcode 0x0A  SELTRACK        2
// Opcode 0x0B  SELSECT         1  
// Opcode 0x0C  WRITESECT       512
// Opcode 0xFF  No operation    1
//
//
// Currently defined Opcodes for I/O read operations:
//
//   Opcode     Name            Exchanged bytes
// -------------------------------------------------
// Opcode 0x80  USER KEY        1
// Opcode 0x81  GPIOA Read      1
// Opcode 0x82  GPIOB Read      1
// Opcode 0x83  SYSFLAGS        1
// Opcode 0x84  DATETIME        7
// Opcode 0x85  ERRDISK         1
// Opcode 0x86  READSECT        512
// Opcode 0x87  SDMOUNT         1
// Opcode 0xFF  No operation    1
//
#define         SELDISK     0x09
#define         SELTRACK    0x0A
#define         SELSECT     0x0B
#define         WRITESECT   0x0C
#define         ERRDISK     0x85
#define         READSECT    0x86
#define         SDMOUNT     0x87


// Z80-MBC2 I/O ports definition
__sfr __at      0x00        EXEC_OPCODE;
__sfr __at      0x01        STORE_OPCODE;


// Definitios and costants
#define                 ESC_ASCII   27          // ESC key
#define                 BUFFSIZE    512         // Read/write file buffer size
#define                 MAXTRACK    511         // Max track number
#define                 MAXSECT     31          // Max sector number
#define                 MAXDISK     99          // Max disk number
const unsigned int      sectSize = 512;         // Sector size (bytes)
const unsigned char     trackSize = 32;         // Track size (sectors)
const unsigned int      diskSize = 512;         // Virtial disk size (tracks)


// Variables
enum opType {mount, seldisk, selsect, seltrack, readsect, writesect};
unsigned int            sectCount = 1, track = 0, maxSect, ii, jj;
unsigned char           disk = 0;               // Current disk number [0..99]
unsigned char           sector = 0;             // Current sector number [0..31]
unsigned int            currTrack, currSect, j, fillNum;
unsigned char           sectBuff[BUFFSIZE];     // Buffer used to store a sector (disk I/O operations)
unsigned char           i, k, inChar, verifyFlag;


// ****************************************************************************************

unsigned char readChar()
// Read a char from input serial port  waiting for it if required. If no char is present it will 
//  be returned a 0xFF flag (so an input 0xFF ASCII char can't be used because equal to 
//  the "no char" flag)
{
    do inChar = getchar();
    while (inChar == 0xff);
    return inChar;
}

unsigned char readCharNow()
// Read a char from input serial port flushing all the previous chars already pending in the input 
//  buffer (if any), waiting for it if required. If no char is present it will be returned a 0xFF 
//  flag (so an input 0xFF ASCII char can't be used because equal to the "no char" flag)
{
    do inChar = getchar();                          // Flush input buffer until is empty
    while (inChar != 0xff);
    while (inChar == 0xff) inChar = getchar();      // Wait a valid char from input port
    return inChar;
}

unsigned char mountSD()
// Mount a volume on SD. Return an error code (0 = no error)
{
    STORE_OPCODE = SDMOUNT;
    return EXEC_OPCODE;
}

void selDisk (unsigned char diskNum)
// Select current virtual disk number [0..99]
{
    STORE_OPCODE = SELDISK;
    EXEC_OPCODE = diskNum;
}

void selTrack(unsigned int trackNum)
// Select current virtual disk track number [0..511]
{
    STORE_OPCODE = SELTRACK;
    EXEC_OPCODE = (unsigned char) (trackNum & 0x00ff);
    EXEC_OPCODE = (unsigned char) ((trackNum >> 8) & 0x00ff);
}

void selSect(unsigned char sectNum)
// Select current virtual disk sector number [0..31]
{
    STORE_OPCODE = SELSECT;
    EXEC_OPCODE = sectNum;
}

unsigned char errDisk()
// Read the error code after a selDisk(), selTrack(), selSect(), writeSect() or readSect() call (0 = no errors)
{
    STORE_OPCODE = ERRDISK;
    return EXEC_OPCODE;
}

void readSect(unsigned char * buffer)
// Read the current sector (512 bytes long) and write it into the buffer
{
    unsigned int i;
    
    STORE_OPCODE = READSECT;
    for (i = 0; i < BUFFSIZE; i++) buffer[i] = EXEC_OPCODE;
}

void writeSect(unsigned char * buffer)
// Write the content of the buffer into the current sector (512 bytes long)
{
    unsigned int i;
    
    STORE_OPCODE = WRITESECT;
    for (i = 0; i < BUFFSIZE; i++) EXEC_OPCODE = buffer[i];
}
    
char getOneDigit()
// Read one numeric ASCII char [0..9] or a CR or a BACKSPACE from the input stream. Ignore others chars.
{
    unsigned char   inChar;
    
    do inChar = readChar();
    while (((inChar < 48) || (inChar > 57)) && (inChar != 13) && (inChar != 8));
    return inChar;
}

unsigned int readNum()
// Read a decimal 1-5 digit unsigned number in the [0..65535} range from the input stream ending with a CR, 
//  and echo it.
// The returnud number is an unsigned integer in the [0..65535} range.
// If only a CR is pressed, it is returned a flag value of 0xFFFF meaning "no number".
{
    unsigned char   i, j, inChar;
    unsigned long   num;

    do
    {
        do inChar = getOneDigit();                  // Read first numeric char [0..9] + CR + BS
        while (inChar == 8);
        if (inChar == 13) return 0xffff;            // Read a CR, so return a flag (0xFFFF)
        putchar(inChar);                            // Echo it
        num = inChar - 48;                          // Convert first num char into decimal
        for (i = 1; i <= 4; i++)
        // Read next 4 digits
        {
            inChar = getOneDigit();                 // Get a numeric char
            j = 0;
            if (inChar == 8)
            // Read a BACKSPACE, so erase all input
            {
                do
                {
                    putchar(8);
                    putchar(32);
                    putchar(8);
                    j++;
                }
                while (j < i);
                break;
            }
            else putchar(inChar);                   // Echo the current digit
            if (inChar == 13) 
            // Reached last digit
            {
                if (num >= 0xffff) num = 0xffff;    // Avoid value overflow
                return (unsigned int) num;          // Return the number
            }
            num = num * 10;                         // Do a decimal shift
            num = num + (inChar - 48);              // Convert a numeric char
        }
        if (inChar != 8)
        // Wait a CR or BS after the 5th digit
        {
            do inChar = getOneDigit();
            while ((inChar != 13) && (inChar != 8));
            if ((inChar == 8) ) for (j = 0; j < 5; j++)
            // Is a BACKSPACE, so erase all previous input
            {
                putchar(8);
                putchar(32);
                putchar(8);
            }
        }
    }
    while (inChar == 8);
    putchar(inChar);
    if (num >= 0xffff) num = 0xffff;                // Avoid value overflow
    return (unsigned int) num;                      // Return the number
}

char upperCase(unsigned char c)
// Change a charcter in upper case if it is in [a-z] range
{
    if ((c >96) && (c < 123)) c = c - 32;
    return c;
}

void printErr(unsigned char errCode, enum opType operCode)
// Print the meaning of an errDisk() or mountSD()error code;
// "errCode" is the error code from errDisk() or mountSD(), operCode is the offending operation 
//
// Error codes table:
//
//    error code    | description
// ---------------------------------------------------------------------------------------------------
//        0         |  No error
//        1         |  DISK_ERR: the function failed due to a hard error in the disk function, 
//                  |   a wrong FAT structure or an internal error
//        2         |  NOT_READY: the storage device could not be initialized due to a hard error or 
//                  |   no medium
//        3         |  NO_FILE: could not find the file
//        4         |  NOT_OPENED: the file has not been opened
//        5         |  NOT_ENABLED: the volume has not been mounted
//        6         |  NO_FILESYSTEM: there is no valid FAT partition on the drive
//       16         |  Illegal disk number
//       17         |  Illegal track number
//       18         |  Illegal sector number
//       19         |  Reached an unexpected EOF
//
{
    if (errCode != 0)
    {
        printf("\r\n\n* DISK ERROR *\r\n");
        switch (operCode)
        {
            case mount: printf("SDMOUNT "); break;
            case seldisk: printf("SELDISK "); break;
            case selsect: printf("SELSECT "); break;
            case seltrack: printf("SELTRACK "); break;
            case readsect: printf("READSECT "); break;
            case writesect: printf("WRITESECT "); break;
        }
        printf("disk error %u", errCode);
        switch (errCode)
        {
            case 1:     printf(" (DISK_ERR): hardware, wrong FAT or internal error"); break;
            case 2:     printf(" (NOT_READY): hardware or no medium error"); break;
            case 3:     printf(" (NO_FILE): 'disk file' not found"); break;
            case 4:     printf(" (NOT_OPENED): the file has not been opened"); break;
            case 5:     printf(" (NOT_ENABLED): the volume has not been mounted"); break;
            case 6:     printf(" (NO_FILESYSTEM): there is no valid FAT partition on the drive"); break;
            case 16:    printf(": illegal disk number"); break;
            case 17:    printf(": illegal track number"); break;
            case 18:    printf(": illegal sector number"); break;
            case 19:    printf(": reached an unexpected EOF"); break;
            default:    printf(": unknown error"); break;
        }
        printf("\n");
    }
}


// ****************************************************************************************


void main(void) 
{ 
    printf("\nViDiT for Z80-MBC2 - Virtual Disk Test - S180818\r\n");
    mountSD();
    do
    {
        i = mountSD();
        if (i > 0)
        {
            printErr(i, mount);
            printf("\r\nCheck the SD and press a key to retry or ESC to ignore >");
            inChar = readCharNow();
            i = mountSD();
        }
    }
    while ((i > 0) && (inChar != ESC_ASCII));
    printf("\n\n\n                             * * * WARNING! * * *\n\n\n");
    printf("* * Write command will overwrite all previous data on the selected sectors! * *\n");
    selDisk(disk);
    printErr(errDisk(), seldisk);
    do
    {
        printf("\n\nCurrent setting:\ndisk -> %02u", disk);
        printf(" : track -> %03u", track);
        printf(" : sector -> %02u", sector);
        maxSect = (diskSize * trackSize) - ((track * trackSize) + sector);  // Update current max number of sectors 
                                                                            //  that can be processed sequentially
                                                                            //  starting from current track/sector
        if (sectCount > maxSect) sectCount = maxSect;                       // If too high change it accordingly
        printf(" : sectors to process -> %u", sectCount);
        printf("\n\nCommands list:\n\n");
        printf(" M: Mount the SD volume\n");
        printf(" D: Set disk (open 'disk file')\n");
        printf(" T: Set starting track\n");
        printf(" S: Set starting sector\n");
        printf(" N: Set how many sectors read or write\n");
        printf(" R: Read sectors\n");
        printf(" W: Write sectors filling a value and verify\n");
        printf(" E: Exit\n\n");
        do
        {
            printf("\r                  ");
            printf("\rEnter a command [M,D,T,S,N,R,W,E] >");
            inChar = readCharNow();
            inChar = upperCase(inChar);
        }
        while ((inChar != 'M') && (inChar != 'D') && (inChar != 'T') && (inChar != 'S') && (inChar != 'N') 
               && (inChar != 'R') && (inChar != 'W') && (inChar != 'E'));
        putchar(inChar);
        printf("\n");
        switch  (inChar)
        {
            case 'M':
                mountSD();
                i = mountSD();
                if (!i) printf("\r\nSD volume mounted");
                else printErr(i, mount);
            break;
            
            case 'D':
                do
                {
                    printf("\r                                ");
                    printf("\rEnter disk number [0..");
                    printf("%u", MAXDISK);
                    printf("] >");
                    ii = readNum();
                    if (ii <= MAXDISK) 
                    {
                        disk = (unsigned char) ii;
                        selDisk(disk);
                        if (!errDisk()) 
                        {
                            printf("\r\n\n'Disk file' opened (disk ");
                            printf("%02u)", disk);
                        }
                        else printErr(errDisk(), seldisk);
                    }
                }
                while (ii > MAXDISK);
            break;
        
            case 'T':
                do
                {
                    printf("\r                                  ");
                    printf("\rEnter track number [0..");
                    printf("%u", MAXTRACK);
                    printf("] >");
                    ii = readNum();
                    if (ii <= MAXTRACK) 
                    {
                        track = ii;
                        selTrack(track);
                        printErr(errDisk(), seltrack);
                    }
                }
                while (ii > MAXTRACK);
            break;
            
            case 'S':
                do
                {
                    printf("\r                                   ");
                    printf("\rEnter sector number [0..");
                    printf("%u", MAXSECT);
                    printf("] >");
                    ii = readNum();
                    if (ii <= MAXSECT) 
                    {
                        sector = (unsigned char) ii;
                        selSect(sector);
                        printErr(errDisk(), selsect);
                    }
                }
                while (ii > MAXSECT);
            break;
            
            case 'N':
                do
                {
                    maxSect = (diskSize * trackSize) - ((track * trackSize) + sector);
                    printf("\r                                          ");
                    printf("\rEnter sectors to process [1..");
                    printf("%u", maxSect);
                    printf("] >");
                    ii = readNum();
                    if (ii <= maxSect) sectCount = ii;
                }
                while ((ii > maxSect) || sectCount == 0);
            break;
                
            case 'R':
                currTrack = track;
                currSect = sector;
                for (jj = 1; jj <= sectCount; jj++)
                {
                    selTrack(currTrack);
                    selSect(currSect);
                    readSect(sectBuff);             // Read a sector
                    printf("\n* disk -> %02u", disk);
                    printf(" : track -> %03u", currTrack);
                    printf(" : sector -> %02u *\n", currSect);
                    
                    // Print a sector
                    for (i = 0; i < 32; i++)
                    // Print 32 rows, 16 values each
                    {
                        for (k = 0; k < 16; k++)
                        // Print a row of 16 values
                        {   
                            ii = k + (16 * i);      // Compute the buffer index
                            printf("%02X ", sectBuff[ii]);
                        }
                        printf("    ");
                        for (k = 0; k < 16; k++)
                        {   
							ii = k + (16 * i);      // Compute the buffer index
                            if ((sectBuff[ii] > 32) && (sectBuff[ii] < 127)) putchar(sectBuff[ii]);
                            else putchar('.');
                        }
                        printf("\n");
                    }
                    printErr(errDisk(), readsect);
                    currSect++;
                    if (currSect > MAXSECT)
                    {
                        currSect = 0;
                        currTrack++;
                    }
                    if ((sectCount - jj) > 0)
                    // There is more than one sector to read. Check if user wants to abort the read command
                    {
                        if (getchar() != 0xff)
                        // A char was typed durung the read command
                        {
                            printf("\r\nPress any key to continue or ESC to abort read command >");
                            inChar = readCharNow();
                            printf("\r\n");
                            if (inChar == ESC_ASCII) break;
                        }
                    }
                }
            break;
            
            case 'W':
                verifyFlag = 1;
                do
                {
                    printf("\r                                      ");
                    printf("\rEnter the value to fill [0..255] >");
                    fillNum = readNum();
                }
                while (fillNum > 255);
                printf("\n\Are you sure to proceed [Y/N]? >");
                do inChar = upperCase(readCharNow());
                while ((inChar != 'Y') && (inChar != 'N'));
                putchar(inChar);
                printf("\n");
                if (inChar != 'Y') break;
                printf("\n");
                currTrack = track;
                currSect = sector;
                for (jj = 1; jj <= sectCount; jj++)
                {
                    printf("Writing  track -> %03u", currTrack);
                    printf(" : sector -> %02u\n", currSect);
                    selTrack(currTrack);
                    selSect(currSect);
                    for (ii = 0; ii < sectSize; ii++) sectBuff[ii] = fillNum;   // Fill the sector buffer
                    writeSect(sectBuff);            // Write the current sector on disk
                    printErr(errDisk(), writesect);
                    printf("Verifing track -> %03u", currTrack);
                    printf(" : sector -> %02u\n", currSect);
                    selSect(currSect);
                    readSect(sectBuff);             // Read current sector
                    for (ii = 0; ii < sectSize; ii++)                           // Verify the sector
                        if (sectBuff[ii] != (unsigned char) fillNum) verifyFlag = 0;
                    printErr(errDisk(), readsect);
                    if (!verifyFlag)
                    {
                        printf("* * * * VERIFY FAILED!!!! * * * *\n");
                        break;
                    }
                    currSect++;
                    if (currSect > MAXSECT)
                    {
                        currSect = 0;
                        currTrack++;
                    }
                    if ((sectCount - jj) > 0)
                    // There is more than one sector to write. Check if user wants to abort the write command
                    {
                        if (getchar() != 0xff)
                        // A char was typed durung the write command
                        {
                            printf("\r\nPress any key to continue or ESC to abort the write command >");
                            inChar = readCharNow();
                            printf("\r\n");
                            if (inChar == ESC_ASCII) break;
                        }
                    }
                }
                if (verifyFlag && !(errDisk())) printf("\r\n* * * * VERIFY OK!!! * * * *\n");
            break;
        
            case 'E':
                printf("\n\n* Program terminated - System halted *\n");
            break;
        }
    }
    while (inChar != 'E');
} 
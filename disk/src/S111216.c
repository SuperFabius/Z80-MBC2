// S111216.c
// S111216 - Conversion utility
//	     To convert output from TASM assembler .lst file to a .txt file suited
//	     for Arduino IDE
//
//	     Created for the S221116 IOS
//
//	     To compile (linux OS): gcc -o S111216 S111216.c
//
//	     To run (linux OS): ./S111216 <in.txt > out.txt
//	     where: in.txt is the rom image copied from the .lst ouput TASM file,
//		    out-txt is the converted output txt for the Arduino IDE


#include <stdio.h>
//#include <string.h>
//#include <stdint.h>

main()
{
  unsigned int hexdata, hexdata2;
  int retValue, col, counter = 0;

  printf("TASM Assembler output converter - S101216\n\n");
  
  retValue = scanf("%x", &hexdata);		// Read address at the first line beginning
  while (retValue > 0)
  {
    col = 1;
    retValue = scanf("%x", &hexdata);		// Read first data of the line
    while ((retValue > 0) & (col <= 16))
    {
      if (col == 1) printf("  ");
      printf("0x%02X", hexdata);
      col++;
      counter++;
      retValue = scanf("%x", &hexdata);		// Read next data or address at the next line beginning
      if (retValue > 0) printf(", ");
    };
    printf("\n");
  }
  printf("\nTotal bytes count = %d (dec), 0x%04X (hex)\n", counter, counter);
return 0;
}
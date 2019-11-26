In this folder there is the "diskdefs" file for the cpmtools or cpmtoolsGUI utilities to access 
to virtual disk files (.DSK) using a PC to add, extract or delete files inside a virtual disk.

I suggest to use the cpmtoolsGUI (only for Windows) because is very easy.
You can download it (english version) from:

http://star.gmobb.jp/koji/cgi/wiki.cgi?action=ATTACH&page=CpmtoolsGUI&file=CPMTG%5FENG%5F20180903%2Ezip

Then unzip it into a folder and put the diskdefs file in the same folder.


For CP/M 2.2 and QP/M 2.71:
select "z80mbc2-d0" only for disk 0, and "z80mbc2-d1" for the others (disk 1 - 15);

For CP/M 3:
select "z80mbc2-cpm3" for all disks. 


Remenber that virtual disks filenames are "DSyNxx.DSK", where "xx" is the disk number,
and "y" is the Disk Set.

NOTE: do not create new virtual disk files with cpmtools or cpmtoolsGUI 
because further processing is required for a valid virtual disk file.

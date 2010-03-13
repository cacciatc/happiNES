   This is a slightly modified version of Michael Martin's perl 6502 assembler.  Slightly modified in that I added a print statement in his intermediate record walker (check out the walk function).  This print outputs the line number of the instruction being processed, the current file, node type, and location of program counter.  All of this information is used by the happiNES debugger!
   
   If you want to rebuild the source you'll need to do the following (using the included tutor files as an example):

perl p65.pl tutor.p65 tutor.nes > tutor.sym

The usage for p65.pl can be determined by running it without any command line arguments.  The item you should note here is that to create the symbol file to be used by the debugger you need to redirect p65's output to a file that is named the same as your source file and that has a .sym extension.  

   Also note that if you use some of p65's more verbose modes when running the assembler (and thus populated the .sym file with more text) then things might break...or they might I don't know for sure.

-C
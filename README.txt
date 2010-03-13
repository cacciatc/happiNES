@@@happiNES is a NES emulator.  

  This is a prototype written in ruby.  Once things are working well enough and I like the design, we will start implementing components in c/c++ and then write ruby bindings.  Check out my old_happiNES folder to see my original start on the emulator using ragel and c.

  Currently most work is happening in the picture processing unit.

@@file structure
	/test - currently a simple ppu viewer
	/asm  - contains a perl assembler and some asm files for testing
	/lib  - happiNES source.

-C
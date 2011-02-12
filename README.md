happiNES: A NES Emulator  
===========================
---------------------------

This is a prototype written in ruby.  Once things are working well enough and I like the design, I will start implementing components in c/c++ and then write ruby bindings.  Check out my old_happiNES folder to see my original start on the emulator using ragel and c.  In my previous version I took a top-down approach and first implemented the full 6502 instructions set.  Then I tackled the iNES standard, etc...  However, once I got to the pseudo-audio processing unit (papu) things got sticky and I got stuck.  At that point I lost focus, in part because I couldn't even run a rom (I had been testing instructions via a special interface--which in the long run was more work and less satisfying).

There is something really cool about just being able to load a NES rom with your fledgling emulator.  Anyways, this time I took a bottom-up approach.  First, using ruby I can quickly get things out and change components if need be.  Second, I started with the Michael Martin's NES programming tutorial and using that source and rom worked my way through it: run the rom, watch it fail on an opcode, implement that instruction, rinse and repeat.  I also would hit bigger issues like, now I have to implement interrupts, memory mapped registers, etc.  I have found this approach much more satisfying for a project that is meant to be fun and something I do in my spare time.

file structure:
---------------
* /test - specs
* /assembler  - contains a perl assembler and some asm files for testing.
* /lib  - happiNES source.
* /examples - what do you think?

-C

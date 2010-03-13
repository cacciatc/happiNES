   main.rb is an example of running a happiNES instance and at the moment is probably not that interesting.  If I were you I would check out the debugger in debugger.rb.  Below is a list of commands currently supported by the debugger as well as some other items of note:

   When you start a debugger session it will create the NES hardware, load a rom, load any configuration files (more info. at the bottom of this page), and then sit on the prompt.  You can jump to the prompt at any time thus pausing execution, by sending an SIGINT to the debugger (Ctrl+C):

'g' -> "go":
   Runs the program till a break is reached, you signal it to pause, or something bad happens.

'q' -> "quit": 
   Exits the debugger.

'n' -> "next": 
   Steps through the next instuction.

'b' -> "list breaks": 
   Lists all active break points.
   
'b -a <filename> <line number>' -> "add break": 
   Adds a breakpoint to the filename at line number.

'b -d <index>' -> "remove break": 
   Removes the breakpoint at index (within the array of break points).

'd -c' -> "dump registers": 
   Outputs the contents of the accumulator, x, y, and status cpu registers.

'w' -> "list watches":
   Lists all active watches.

'w -a <conditional code>\n<callback code>' -> "add watch":
   Adds a watch that will fire when the conditional code (in ruby)evaluates to true.  You will need to know some of the debugger internals to use this one.  The callback code is also ruby code which fires upon the watch evaluating to true, use this to output results etc.

'w -d <index>' -> "delete watch":
   Deletes a watch at the index (within the array of watches).

'c' -> "current instruction":
  Outputs the current instruction.

'i' -> "interactive shell":
  The coolest debugger feature!  This command will drop you into an interactive ruby session using irb.  Moreover, this session is bound to the current debugger context and therefore you have complete access to the debugger as well as all the NES hardware!  I use this instruction often to look at blocks of ram or see things that would not be possible using just watches and break points.  To exit the irb Ctrl+C to get back to the debugger prompt.

'e' -> "echo":
   Echoes a line of text.

'#' -> "comment":
   Ignored by the debugger interpreter.

   A few notes on configuration files...The debugger looks for a file ending in .fig in the same directory.  If found this file is loaded and executed.  All of the instructions listed in this document can be used in a .fig file.  For example,

#for testing why nametables are not being populated properly...
b -a tutorprg.p65 127
b -a tutorprg.p65 136
#(0x2400..0x4000).each {|addr| print @cpu.ppu.vram.read(addr)}
g

I generally keep a few config files handy that I place near the debugger when I need to inspect a certain aspect of the emulator.


-C
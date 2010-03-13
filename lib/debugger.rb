#simple debugger
require 'cpu'
require 'ines'
require 'memory/main_memory'
require 'memory/nrom'
require 'ostruct'

class BreakPoint < OpenStruct; end
class Watch      < OpenStruct; end

require "irb"
 
IRB.setup(nil)
IRB.conf[:MAIN_CONTEXT] = IRB::Context.new(IRB::Irb.new)
require "irb/ext/multi-irb"
 
def run_irb(context=self)
  IRB.irb(nil,context)
end

class Debugger
  include IRB::ExtendCommandBundle # so that Marshal.dump works
  (INSTRUCTION_NODES = [
    'IMPLIED',
    'MEMORY',
    'IMMEDIATE',
    'MEMORY-X',
    'INDIRECT-Y',
    'ABSOLUTE-X',
    'RELATIVE',
    'ABSOLUTE',
    'ZERO-PAGE',
    'ZERO-PAGE-X',
    'ZERO-PAGE-Y'
  ]).freeze
  attr_accessor :break_points
  class ArrayWindow
    def initialize
      @a = []
    end
    def <<(item)
      @a.shift if @a.length > 5
      @a << item
    end
    def method_missing(sym,*args,&block)
      @a.send(sym,*args,&block)
    end
  end
  def initialize(path,rom_name)
    @path = path
    @rom_name = @path + rom_name
    @listing_name = @path + rom_name[0..rom_name.length-4]+'lis'
    @listings = {}
    @listing_index = 0
    create_hardware
    load_listing_file
    @break_points = []
    @watches = []
    @no_breaks = false
    @high_stepping = false
    Signal.trap("INT") do
      if not @no_breaks
        exit
      end
      @no_breaks = false
      @working = false
      print '>[DEBUG]<'
    end
    @code_window = ArrayWindow.new
    @working = true
  end
  def update_break_points(listing)
    @break_points.each do |b|
      if b.fname == listing[:fname] and b.line_no == listing[:line_no]
        puts "BREAK on line #{listing[:line_no]}"
        @no_breaks = false
      end
    end
  end
  def update_watches
    @watches.each do |w|
      if instance_eval(w.proc) == true
        puts "WATCH fired #{w.proc}"
        puts "#{instance_eval(w.call_back)}"
        @no_breaks = false
      end
    end
  end
  def proc_cmd(input)
    case input.chomp
      when /^g/i
        @no_breaks = true
        @high_stepping = false
        @working = false
      when /^q/i
        exit
      when /^n/i
        @high_stepping = true
        @no_breaks = true
        @working = false
      when /^b/i
        args = input.split
        if args[1] == '-a'
          @break_points << BreakPoint.new({:fname=>args[2],:line_no=>args[3].to_i})
        elsif args[1] == '-d'
          @break_points.delete_at(args[2].to_i)
        else
          @break_points.each {|b| puts b}
        end
      when /^d/i
        args = input.split
        #show regs
        if args[1] == '-c'
          puts "x: #{@cpu.x_reg}"
          puts "y: #{@cpu.y_reg}"
          puts "a: #{@cpu.a_reg}"
          puts "s: #{@cpu.status}"
        end
      when /^w/i
        args = input.split
        if args[1] == '-a'
          watch =  Watch.new({:proc=>args[2..args.length].join(" ")})
          watch.call_back = gets
          @watches << watch
        elsif args[1] == '-d'
          @watches.delete_at(args[2].to_i)
        else
          @watches.each {|w| puts w}
        end
      when /^c/i
        puts "[#{@listings[@cpu.pc][:line_no]}] #{@listings[@cpu.pc][:src]}"
      when /^i/i
        run_irb
      when /^e/i
        puts input[2..input.length]
      when /^#/i
      else
        puts 'Unknown command.'
    end if not input == nil
  end
  def run
    while true
      while @no_breaks
        step(silent=true)
        update_break_points(@listings[@listing_index])
        update_watches
        if @high_stepping
          @no_breaks = false
        end
      end
      @working = true
      if not @high_stepping
        display_code_window 
      else
        if @last_file != @code_window.last[:fname]
          puts "*****#{@code_window.last[:fname]}*****"
        end
        puts "[#{@listings[@cpu.pc][:line_no]}] #{@listings[@cpu.pc][:src]}"
      end

      while @working
        input = gets
        proc_cmd(input)
      end
    end
  end
  def display_code_window
    puts "\n**********************************************"
    @code_window.each do |line|
      puts "[#{line[:line_no]}] #{line[:src]}"
    end
  end
  def step(silent=false)
    @listing_index = @cpu.pc
    l = @listings[@listing_index]
    @code_window << l
    if @last_file != l[:fname]
      puts "*****#{l[:fname]}*****" if not silent
    end
    if @last_line != l[:line_no]
      puts "[#{l[:line_no]}] #{l[:src]}" if not silent
    end
    @last_file = l[:fname]
    @last_line = l[:line_no]
    @cpu.run(1,false)
  end
  def create_hardware
    @ines = Ines.new
    @mmc = @ines.load(@rom_name)
    @mem = MainMemory.new(@mmc)
    @cpu = Cpu.new(@mem,0xC000)
    @listing_index = @cpu.pc
  end
  def load_listing_file
    tmp_a = File.new(@listing_name).readlines.inject([]) do |a,i| 
      a << i.split(',')
    end
    src_files = {}
    tmp_a.each do |l|
      line_num,fname,node,pc = l[0].to_i,l[1],l[2].chomp,l[3].chomp.to_i
      src_files[fname] = File.new(@path+fname).readlines if not src_files.include?(fname)
      @listings[pc] = {
        :src=> src_files[fname][line_num-1].chomp,
        :type=> node,
        :fname=> fname,
        :line_no=> line_num
      } if INSTRUCTION_NODES.include?(node)
    end
  end
  def load_config(fname)
    puts "loading configs..."
    File.new(fname,'r').each do |line|
      puts line
      proc_cmd(line)
    end if File.exist?(fname)
  end
end

d = Debugger.new("..\\assembler\\","tutor.nes")
d.load_config('config.fig')
d.run

require 'memory/main_memory'
require 'ppu'
require 'memory/register'
require 'cpu/addressing_modes'

class Cpu
  (WORD_SIZE = 256).freeze
  #interrupt constants
  (NMI = 0xFFFA).freeze;(RES = 0xFFFC).freeze;(IRQ = 0xFFFE).freeze
  #address modes cycles and bytes
  (IMPLIED   = {:cycles=>2,:bytes=>1}).freeze
  (IMMEDIATE = {:cycles=>2,:bytes=>2}).freeze
  (ZERO_PAGE = {:cycles=>3,:bytes=>2}).freeze
  (ABSOLUTE  = {:cycles=>4,:bytes=>3}).freeze
  (RELATIVE  = {:cycles=>2,:bytes=>2}).freeze
  (ZERO_PAGE_INDEXED = {:cycles=>4,:bytes=>2}).freeze
  (ABSOLUTE_INDEXED  = {:cycles=>5,:bytes=>3}).freeze
  
  include AddressingModes

  attr_accessor :ppu,:m,:x_reg,:y_reg,:a_reg,:status
  attr_reader   :pc
  def initialize(memory,pc)
    #nes hardware variables
    @m = memory
    @ppu = Ppu.new(@m,self)
    
    @pc = pc
    @x_reg = 0x00 #Register.new(0x00)
    @y_reg = 0x00 #Register.new(0x00)
    @a_reg = 0x00 #Register.new(0x00)
    @status = 0x00

    #emulation variables
    reset!
  end

  def reset!
    @cycles_completed_this_pass = 0
    @interrupt_requested = false
    @interrupt_type = IRQ
    
    @paused = false

    @ppu.reset!
  end
  
  def pause!
    @paused = !@paused
    puts @paused
  end
  
  def paused?
    @paused
  end

  #interface for outside modules to request an interrupt (most likely the PPU or APU)
  def request_interrupt(type)
    if @interrupt_requested
      #ordering of importance RES,NMI,IRQ
      if @interrupt_type == IRQ and not type == IRQ
        @interrupt_type = type
      elsif @interrupt_type == NMI and type == RES
        @interrupt_type = type
      end
    elsif not interrupts_disabled?
      @interrupt_requested = true
      @interrupt_type = type
    end
  end

  def process_interrupt
    @m.push(@pc-0x8000)
    @m.push(@status)
    disable_interrupts!
    @pc = (@m.read(@interrupt_type+1)*256)+@m.read(@interrupt_type)
    @interrupt_requested = false
  end

  #wrapper around RAM read
  def load(address)
    @m.read(address)
  end
  
  #handles the housekeeping of counting cycles and updating the pc
  def update_cycles_n_bytes(address_type,extra=0)
    @cycles_completed_this_pass += address_type[:cycles]
    @cycles_completed_this_pass += extra
    @pc += address_type[:bytes] 
  end

  def run(this_many_cycles,log=false)
    @cycles_completed_this_pass = 0
    prev_cycles_this_pass = 0
    while (@cycles_completed_this_pass <= this_many_cycles) and !@paused
      #fetch,load,execute
      opcode = load(@pc)
      old_pc = @pc           if log
      execute(opcode)
      out_log(opcode,old_pc) if log
      #PPU update
      @ppu.update(@cycles_completed_this_pass-prev_cycles_this_pass)
      #APU update
      process_interrupt if @interrupt_requested
      prev_cycles_this_pass = @cycles_completed_this_pass
    end
  end

  #a somewhat incorrect log, sometimes it will not show the correct memory value!
  def out_log(opcode,old_pc)
    args = []
    if opcode == 0x10 or opcode == 0xD0
      args << sprintf("%02X",@m.read(old_pc+1))
    elsif opcode == 0x20
      args << sprintf("%02X",@m.read(old_pc+1))
      args << sprintf("%02X",@m.read(old_pc+2))
    elsif @pc-old_pc <= 3 and @pc-old_pc > 1
      (old_pc+1..@pc-1).each {|n| args << sprintf("%02X",@m.read(n))}
    end
    puts "(#{Time.new.strftime("%I:%M:%S%p")}) [#{sprintf("%04X",old_pc)}] opcode = #{sprintf("%02X",opcode)} : #{args.join(' ')}"
    $stdout.flush
  end

  def execute(opcode)
    case opcode
    when 0x10 #BPL
      cycles = RELATIVE[:cycles]
      if not negative_flag?
        cycles += 1
        new_pc = relative(@m.read(@pc+1))
        cycles +=2 if new_page?(@pc,new_pc)
        @pc = new_pc+RELATIVE[:bytes]
      else
        @pc+=RELATIVE[:bytes]
      end
      @cycles_completed_this_pass += cycles
    when 0x18 #CLC
      clear_carry_flag!
      update_cycles_n_bytes(IMPLIED)
    when 0x20 #JSR
      @m.push(@pc+ABSOLUTE[:bytes]-0x8000)
      @pc = absolute(@m.read(@pc+1),@m.read(@pc+2))
      @cycles_completed_this_pass += ABSOLUTE[:cycles]+2
    when 0x29 #AND immediate
      clear_zero_flag!
      clear_negative_flag!
      @a_reg &= @m.read(@pc+1) % WORD_SIZE
      set_zero_flag! if it_is_zero?(@a_reg)
      set_negative_flag! if it_is_negative?(@a_reg)
      update_cycles_n_bytes(IMMEDIATE)
    when 0x40 #RTI
      @status = @m.pop
      @pc = @m.pop+0x8000
      @cycles_completed_this_pass += 6
    when 0x48 #PHA
      @m.push(@a_reg)
      update_cycles_n_bytes(IMPLIED)
    when 0x4C #JMP absolute
      @pc = absolute(@m.read(@pc+1),@m.read(@pc+2))
      @cycles_completed_this_pass += ABSOLUTE[:cycles]
    when 0x58 #CLI
      enable_interrupts!
      update_cycles_n_bytes(IMPLIED)
    when 0x60 #RTS
      @pc = @m.pop+0x8000
      @cycles_completed_this_pass += ABSOLUTE[:cycles]+2
    when 0x65 #ADC zero page
      clear_zero_flag!
      clear_carry_flag!
      clear_negative_flag!
      tmp = @a_reg + @m.read(zero_page(@m.read(@pc+1))) + (carry_flag? ? 1 : 0)
      set_carry_flag! if @a_reg > tmp
      @a_reg = tmp % WORD_SIZE
      set_zero_flag! if it_is_zero?(@a_reg)
      set_negative_flag! if it_is_negative?(@a_reg)
      update_cycles_n_bytes(ZERO_PAGE)
    when 0x68 #PLA
      clear_zero_flag!
      clear_negative_flag!
      @a_reg = @m.pop % WORD_SIZE
      set_zero_flag! if it_is_zero?(@a_reg)
      set_negative_flag! if it_is_negative?(@a_reg)
      update_cycles_n_bytes(IMPLIED)
    when 0x78 #SEI
      disable_interrupts!
      update_cycles_n_bytes(IMPLIED)
    when 0x85 #STA zero page
      @m.write(zero_page(@m.read(@pc+1)),@a_reg)
      update_cycles_n_bytes(ZERO_PAGE)
    when 0x86 #STX zero page
      @m.write(zero_page(@m.read(@pc+1)),@x_reg)
      update_cycles_n_bytes(ZERO_PAGE)
    when 0x8D #STA absolute
      @m.write(absolute(@m.read(@pc+1),@m.read(@pc+2)),@a_reg)
      update_cycles_n_bytes(ABSOLUTE)
    when 0x8E #STX absolute
      @m.write(absolute(@m.read(@pc+1),@m.read(@pc+2)),@x_reg)
      update_cycles_n_bytes(ABSOLUTE)
    when 0x9A #TSX
      @m.set_stack_ptr(@x_reg)
      update_cycles_n_bytes(IMPLIED)
    when 0x95 #STA zero page x
      @m.write(indexed_zero_page(@m.read(@pc+1),@x_reg),@a_reg)
      update_cycles_n_bytes(ZERO_PAGE_INDEXED)
    when 0x9D #STA absolute x
      @m.write(indexed_absolute(@m.read(@pc+1),@m.read(@pc+2),@x_reg),@a_reg)
      update_cycles_n_bytes(ABSOLUTE_INDEXED)
    when 0xA0 #LDY immediate
      @y_reg = @m.read(@pc+1) %WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@y_reg)
      set_negative_flag! if it_is_negative?(@y_reg)
      update_cycles_n_bytes(IMMEDIATE)
    when 0xA2 #LDX immediate
      @x_reg = @m.read(@pc+1) % WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@x_reg)
      set_negative_flag! if it_is_negative?(@x_reg)
      update_cycles_n_bytes(IMMEDIATE)
    when 0xA5 #LDA zero page
      @a_reg = @m.read(zero_page(@m.read(@pc+1)))% WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@a_reg)
      set_negative_flag! if it_is_negative?(@a_reg)
      update_cycles_n_bytes(ZERO_PAGE)
    when 0xA6 #LDX zero page
      @x_reg = @m.read(zero_page(@m.read(@pc+1)))% WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@x_reg)
      set_negative_flag! if it_is_negative?(@x_reg)
      update_cycles_n_bytes(ZERO_PAGE)
    when 0xA9 #LDA immediate
      @a_reg = @m.read(@pc+1)% WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@a_reg)
      set_negative_flag! if it_is_negative?(@a_reg)
      update_cycles_n_bytes(IMMEDIATE)
    when 0xAD #LDA absolute
      @a_reg = @m.read(absolute(@m.read(@pc+1),@m.read(@pc+2)))% WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@a_reg)
      set_negative_flag! if it_is_negative?(@a_reg)
      update_cycles_n_bytes(ABSOLUTE)
    when 0xB1 #LDA indirect y
      @a_reg = @m.read(indirect_indexed(@m.read(@pc+1)))% WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@a_reg)
      set_negative_flag! if it_is_negative?(@a_reg)
      old_pc = @pc
      @cycles_completed_this_pass += 5;@pc+=2
      @cycles_completed_this_pass += new_page?(old_pc,@pc) ? 1 : 0
    when 0xB5 #LDA zero page x
      @a_reg = @m.read(zero_page_indexed(@m.read(@pc+1),@m.read(@x_reg)))% WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@a_reg)
      set_negative_flag! if it_is_negative?(@a_reg)
      update_cycles_n_bytes(ZERO_PAGE_INDEXED)
    when 0xBD #LDA absolute x
      @a_reg = @m.read(indexed_absolute(@m.read(@pc+1),@m.read(@pc+2),@x_reg))% WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@x_reg)
      set_negative_flag! if it_is_negative?(@x_reg)
      old_pc = @pc
      update_cycles_n_bytes(ABSOLUTE)
      @cycles_completed_this_pass += new_page?(old_pc,@pc) ? 1 : 0
    when 0xC8 #INY
      @y_reg = (@y_reg+1)% WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@y_reg)
      set_negative_flag! if it_is_negative?(@y_reg)
      update_cycles_n_bytes(IMPLIED)
    when 0xC9 #CMP
      tmp = @m.read(@pc+1)
      set_zero_flag! if @a_reg-tmp == 0
      set_carry_flag! if @a_reg-tmp >= 0
      update_cycles_n_bytes(IMMEDIATE)
    when 0xCA #DEX
      @x_reg = (@x_reg-1)% WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@x_reg)
      set_negative_flag! if it_is_negative?(@x_reg)
      update_cycles_n_bytes(IMPLIED)
    when 0xD0 #BNE
      cycles = RELATIVE[:cycles]
      if not zero_flag?
        cycles += 1
        new_pc = relative(@m.read(@pc+1))
        cycles +=2 if new_page?(@pc,new_pc)
        @pc = new_pc+RELATIVE[:bytes]
      else
        @pc+=RELATIVE[:bytes]
      end
      @cycles_completed_this_pass += cycles
    when 0xD8 #CLD
      disable_decimal_mode!
      update_cycles_n_bytes(IMPLIED)
    when 0xE0 #CPX
      clear_zero_flag!
      clear_negative_flag!
      clear_carry_flag!
      set_zero_flag! if @x_reg-@m.read(zero_page(@m.read(@pc+1))) == 0
      set_carry_flag! if @x_reg-@m.read(zero_page(@m.read(@pc+1))) > 0
      set_negative_flag! if it_is_negative?(@x_reg-@m.read(zero_page(@m.read(@pc+1))))
      update_cycles_n_bytes(IMMEDIATE)
    when 0xE6 #INC zero page
      tmp = (@m.read(zero_page(@m.read(@pc+1))+1))% WORD_SIZE
      @m.write(zero_page(@m.read(@pc+1)),tmp)
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(tmp)
      set_negative_flag! if it_is_negative?(tmp)
      update_cycles_n_bytes(ZERO_PAGE)
    when 0xE8 #INX
      @x_reg = (@x_reg+1)%WORD_SIZE
      clear_zero_flag!
      clear_negative_flag!
      set_zero_flag! if it_is_zero?(@x_reg)
      set_negative_flag! if it_is_negative?(@x_reg)
      update_cycles_n_bytes(IMPLIED)
    when 0xF0
      cycles = RELATIVE[:cycles]
      if zero_flag?
        cycles += 1
        new_pc = relative(@m.read(@pc+1))
        cycles +=2 if new_page?(@pc,new_pc)
        @pc = new_pc+RELATIVE[:bytes]
      else
        @pc+=RELATIVE[:bytes]
      end
      @cycles_completed_this_pass += cycles
    else
      raise "Unknown opcode @ memory[#{sprintf("%04X",@pc)}] = #{opcode}"
    end
  end
  
  #tests for status
  def it_is_zero?(value)
    value == 0
  end
  def it_is_negative?(value)
    value > 0x7F ? true : false
  end
  def new_page?(old_pc,new_pc)
    old_pc%WORD_SIZE == new_pc%WORD_SIZE
  end

  #status flag accessors
  def disable_interrupts!
    @status |= (1<<2)
  end
  def enable_interrupts!
    @status &= ~(1<<2)
  end
  def interrupts_disabled?
    @status&(1<<2) == 0? false : true
  end
  def disable_decimal_mode!
    @status |= (1<<3)
  end
  def enable_decimal_mode!
    @status &= ~(1<<3)
  end
  def decimal_mode_disabled?
    @status&(1<<3) == 0? false : true
  end
  def set_zero_flag!
    @status |= (1<<1)
  end
  def clear_zero_flag!
    @status &= ~(1<<1)
  end
  def zero_flag?
    @status&(1<<1) == 0? false : true
  end
  def set_negative_flag!
    @status |= (1<<7)
  end
  def clear_negative_flag!
    @status &= ~(1<<7)
  end
  def negative_flag?
    @status&(1<<7) == 0? false : true
  end
  def set_carry_flag!
    @status |= (1<<0)
  end
  def clear_carry_flag!
    @status &= ~(1<<0)
  end
  def carry_flag?
    @status&(1<<0) == 0? false : true
  end
end

require 'cpu'
require 'color_palette'
require 'memory/ram'
require 'ppu_memory_massage'

#TODO: sprram_io_address_inc_amt is this also effected by control reg like for vram?
class Ppu
  include ColorPalette
  include PPUMemoryMassage
  (CTRL1_REG  = 0x2000).freeze
  (CTRL2_REG  = 0x2001).freeze
  (STATUS_REG = 0x2002).freeze
  #next two are the bridge to spr-ram from PRG
  (SPR_RAM_ADDR_REG = 0x2003).freeze
  (SPR_RAM_IO_REG   = 0x2003).freeze
  #next three are the bridge to vram from PRG
  (VRAM_ADDR_1_REG = 0x2005).freeze
  (VRAM_ADDR_2_REG = 0x2006).freeze
  (VRAM_IO_REG     = 0x2007).freeze
  #direct memory access
  (DMA_REG = 0x4014).freeze
  #NTSC
  (SCANLINES_PER_FRAME     = 262).freeze
  (CPU_CYCLES_PER_SCANLINE = 341).freeze
  (MEMORY_FETCHES          = 170).freeze
  (CPU_CYCLES_PER_VBLANK   = SCANLINES_PER_FRAME*CPU_CYCLES_PER_SCANLINE).freeze
  (PIXELS_X = 256).freeze
  (PIXELS_Y = 224).freeze
  #VRAM
  (VRAM_SIZE = 0x10000).freeze
  (VRAM_MIRRORED_RAM = 0x0000..0x3FFF).freeze
  (VRAM_MIRROR_1     = 0x4000..0x7FFF).freeze
  #SPR RAM
  (SPR_RAM_SIZE = 256).freeze

  (MONOCHROME = 1).freeze
  (COLOR      = 0).freeze

  attr_accessor :output_buffer
  attr_accessor :vram,:spr
  attr_reader :current_scanline, :memory_fetch_phase
  def initialize(memory,cpu)
    @m = memory
    @cpu = cpu
    #used to count cycles till VBLANK
    @acc_cycles = 0
    #used to count cycles for each scanline
    @scan_cycles = 0
    #rendering vars
    @current_scanline = 0
    @current_pixel    = 0
    @current_tile     = 0
    @memory_fetch_phase = 1
    
    @current_tile = 2

    #CTRL1
    @nims_enabled     = false
    @current_name_table = 0x00
    @cur_sprite_tbl   = 0x0000
    @cur_backgrnd_tbl = 0x0000
    @sprite_size      = 0

    #CTRL2
    @color_mode = COLOR

    #used when r/w via SPR_RAM_IO_REG
    #@sprram_io_address_inc_amt = 1
    #used when r/w via VRAM_IO_REG
    @vram_io_address_inc_amt = 1

    #setup video ram
    @vram = Ram.new(VRAM_SIZE,0x0000,0x00)

    #setup sprite ram
    @spr = Ram.new(SPR_RAM_SIZE,0x00,0x00)

    #index into vram for VRAM_IO_REG read/writes
    @vram_io_address = 0x0000
    #index into spr-ram for SPR_RAM_IO_REG read/writes
    @sprram_io_address = 0x0000

    setup_memory

    #video out!
    @output_buffer = Array.new(PIXELS_X*PIXELS_Y)
    @cur_pixel = 0
  end
  def palette(type)
    case type
      when :sprite
        
      when :image
    end
  end
  def name_table(index)
    start  = (index*0x0400 + 0x2000)
    finish = start + 0x02BF
    (start..finish).inject([]) do |table,address|
      table << @vram.read(address)
    end
  end
  def pattern_table(index)
    start  = (index*0x1000)
    finish = start + 0x1000
    (start..finish).inject([]) do |table,address|
      table << @vram.read(address)
    end
  end
  def pattern_tables
    pattern_table(0)+pattern_table(1)
  end
  def attribute_table(index)
    start  = (index*0x0400 +0x23C0)
    finish = start + 0x0030
    (start..finish).inject([]) do |table,address|
      table << @vram.read(address)
    end 
  end
  
  def name_table_byte(addr)
    @vram.read((@current_name_table*0x0400 + 0x2000) + addr)
  end
  
  def attribute_table_byte(addr)
    
  end
  
  def reset!
    @current_scanline = 0
    @scan_cycles = 0
    @memory_fetch_phase = 1
    @current_tile = 2
  end

  def render_scanlines!(cycles_to_process)
    while cycles_to_process >= 1
      if next_scanline?
        @current_scanline = (@current_scanline + 1)%SCANLINES_PER_FRAME
        @scan_cycles -= CPU_CYCLES_PER_SCANLINE - 1 #PPU does nothing for one cycle
      end
      case @current_scanline
        #the first 20 since VINT was set no rendering!
        when 0..19 #do nothing
        when 20 #the 21 accesses memory but no rendering
          memory_fetch
        when 21..260
          memory_fetch
        when 261 #nothing happens here
        else #invalid state
      end
      cycles_to_process -= 2
    end
  end
  def memory_fetch
    case @memory_fetch_phase
      when 1 #fetch a name table byte
        name_table_byte(@current_tile)
        attribute_table_byte(0)
        pattern_table(0)
        pattern_table(1)
      when 2 #fetch an attribute table byte
      when 3 #pattern table bitmap #0
      when 4 #pattern table bitmap #1
      else #invalid state
    end
    @memory_fetch_phase = (@memory_fetch_phase + 1) % 170
  end
  
  def next_scanline?
    @scan_cycles >= CPU_CYCLES_PER_SCANLINE
  end
  def update(cycles)
    cycles *= 3
    @acc_cycles  += cycles
    @scan_cycles += cycles
    vblank! if vblank?
    render_scanlines!(cycles)
  end
  def color_mode?
    @color_mode == COLOR
  end
  def vblank?
    @acc_cycles >= CPU_CYCLES_PER_VBLANK
  end
  def vblank!
    @acc_cycles = 0
    @m.write(STATUS_REG,@m.read(STATUS_REG)|(1<<7))
    @cpu.request_interrupt(Cpu::NMI) if nmis_enabled?
  end
  def nmis_enabled?
    @nmis_enabled
  end
  def address_updated(address,new_value,read_write)
    if read_write == 'r'
      case address
      when STATUS_REG
        #clear VBLANK bit
        @m.write(address,new_value&(1<<7))
        #clear VRAM address registers
        @m.write(VRAM_ADDR_1_REG,0x00)
        @m.write(VRAM_ADDR_2_REG,0x00)
      when SPR_RAM_IO_REG
        @spr.write(@sprram_io_address,new_value)
        @sprram_io_address += 1 #@sprram_io_address_inc_amt
      when VRAM_IO_REG
        @vram.write(@vram_io_address,new_value)
        @vram_io_address += @vram_io_address_inc_amt
      end
    else
      case address
      when CTRL1_REG
        @current_name_table = (new_value)&(0x03) #0,1,2,3
        @vram_io_address_inc_amt = (new_value)&(1<<2) == 0 ? 1 : 32
        @cur_sprite_tbl = (new_value)&(1<<3)*0x1000
        @cur_backgrnd_tbl = (new_value)&(1<<4)*0x1000
        @sprite_size = (new_value)&(1<<5) #0 = 8x8 and 1 = 8x16
        #bit 6 is not used
        @nmis_enabled = (new_value)&(1<<7) == 0 ? false : true
      when CTRL2_REG
        @color_mode = (new_value)&(1<<0)
      when VRAM_ADDR_2_REG
        @vram_io_address = ((@vram_io_address)&0x00FF)*256 + (new_value)
      when VRAM_IO_REG
        #puts "#{sprintf "%02X",@vram_io_address} #{sprintf "%02X",new_value}"
        @vram.write(@vram_io_address,new_value)
        @vram_io_address += @vram_io_address_inc_amt
      when SPR_RAM_ADDR_REG
        @sprram_io_address = new_value
      when SPR_RAM_IO_REG
        @spr.write(@sprram_io_address,new_value)
        @sprram_io_address += 1
      when DMA_REG
        spr_index = 0
        start = new_value*0x100
        (start..(start+255)).each do |addr|
          @spr.write(spr_index,@m.read(addr))
          spr_index += 1
        end
      end
    end
  end
end

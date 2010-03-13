#A facade of rom and ram, so the cpu only worries about addresses
require 'memory/rom'
require 'memory/ram'
require 'common/stacked'

class MainMemory
  #CPU goodies
  (CPU_RAM_SIZE  = 0x4020).freeze
  (CPU_RAM_START = 0x0000).freeze
  (CPU_MIRRORED_RAM = 0x0000..0x07FF).freeze
  (CPU_MIRROR_1  = 0x0800..0x0FFF).freeze
  (CPU_MIRROR_2  = 0x1000..0x17FF).freeze
  (CPU_MIRROR_3  = 0x1800..0x1FFF).freeze
  (CPU_STACK_SIZE  = 0x0100).freeze
  (CPU_STACK_START = 0x0100).freeze

  (IOR_START = 0x2000).freeze
  (IOR_SIZE  = 0x2020).freeze
  (IOR_MIRRORED_RAM = 0x2000..0x2007).freeze

  def initialize(mmc)
    #mess with ROM
    @mmc = mmc
    @rom_start = @mmc.prg_start
    @rom_end   = @mmc.prg_start + @mmc.prg_size-1

    #mess with RAM
    @ram = Ram.new(CPU_RAM_SIZE,CPU_RAM_START,0x00)
    
    #add a stack to CPU RAM
    @ram.extend(Stacked)
    @ram.setup_stack(CPU_STACK_START,CPU_STACK_SIZE)
    @ram_start = @ram.start_offset
    @ram_end   = @ram.start_offset + @ram.size-1
    
    #reflectored!
    @ram.mirror(CPU_MIRRORED_RAM,CPU_MIRROR_1)
    @ram.mirror(CPU_MIRRORED_RAM,CPU_MIRROR_2)
    @ram.mirror(CPU_MIRRORED_RAM,CPU_MIRROR_3)
    
    #m3mory mapped shenanigans
    start  = IOR_START+8
    start  = IOR_START+8
    finish = start+8
    while finish <= 0x3FFF
      @ram.mirror(IOR_MIRRORED_RAM,start..finish)
      start = finish
      finish += 8
    end
  end
  #read from prg or ram
  def read(address)
    result = 0
    if address >= @rom_start and address <= @rom_end
      result = @mmc.prg_read(address)
    elsif address >= @ram_start and address <= @ram_end
      result = @ram.read(address)
    else
      raise 'Address out of bounds!'
    end
    result
  end
  #write to prg or ram
  def write(address,value)
    if address >= @rom_start and address <= @rom_end
      @mmc.prg_write(address,value)
    elsif address >= @ram_start and address <= @ram_end
      @ram.write(address,value)
    else
      raise 'Address out of bounds!'
    end
  end
  def pop
    @ram.pop
  end
  def push(value)
    @ram.push(value)
  end
  def set_stack_ptr(value)
    @ram.set_stack_ptr(value)
  end
  def register_for_writes(observer,address)
    if address >= @rom_start and address <= @rom_end
      @mmc.prg_register_for_writes(observer,address)
    elsif address >= @ram_start and address <= @ram_end
      @ram.register_for_writes(observer,address)
    else
      raise 'Address out of bounds!'
    end
  end
  def register_for_reads(observer,address)
    if address >= @rom_start and address <= @rom_end
      @mmc.prg_register_for_reads(observer,address)
    elsif address >= @ram_start and address <= @ram_end
      @ram.register_for_reads(observer,address)
    else
      raise 'Address out of bounds!'
    end
  end
  def chr_read_block(here_to_there)
    @mmc.chr_read_block(here_to_there)
  end
  #used by the ppu to load vrom
  def chr_read(address)
    @mmc.chr_read(address)
  end
  #probably don't need this
  def chr_write(address,value)
    @mmc.chr_write(address,value)
  end
  #probably don't need this
  def chr_register_for_reads(object,address)
    @mmc.chr_register_for_reads(object,address)
  end
  #probably don't need this
  def chr_register_for_writes(object,address)
    @mmc.chr_register_for_writes(object,address)
  end
end

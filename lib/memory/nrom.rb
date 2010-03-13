#MMC No mapper
require 'memory/rom'

#Represents a MMC-less cartridge
class Nrom
  #Copies prg and chr
  def initialize(prg,chr)
    @prg = Rom.new(0xBFE0,0x4020,0x00)
    @chr = Rom.new(chr.length,0x0000,0x00)
    i = 0
    prg.each do |v|
      @prg.write(0x8000+i,v)
      @prg.write(0xC000+i,v)
      i += 1
    end
    i = 0
    chr.each do |v|
      @chr.write(i,v)
      i += 1
    end
  end
  
  def prg_size;  @prg.size end
  def prg_start; @prg.start_offset end
  def chr_size;  @chr.size end
  def chr_start; @chr.start_offset end
  
  #Read from PRG ROM
  def prg_read(address)
    @prg.read(address)
  end
  #Write to PRG ROM
  def prg_write(address,value)
    @prg.write(address,value)
  end
  #Request write update notifications on an address
  def prg_register_for_writes(object,address)
    @prg.register_for_writes(object,address,read_write)
  end
  #Request write update notifications on an address
  def prg_register_for_reads(object,address)
    @prg.register_for_reads(object,address,read_write)
  end
  #Read from CHR ROM
  def chr_read(address)
    @chr.read(address)
  end
  #Write to CHR ROM
  def chr_write(address,value)
    @chr.write(address,value)
  end
  #Request write update notifications on an address
  def chr_register_for_reads(object,address)
    @chr.register_for_reads(object,address,read_write)
  end
  #Request write update notifications on an address
  def chr_register_for_writes(object,address)
    @chr.register_for_writes(object,address,read_write)
  end
  def chr_read_block(here_to_there)
    @chr.read_block(here_to_there)
  end
end

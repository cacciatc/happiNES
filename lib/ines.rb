require 'memory/rom'
require 'memory/nrom'

#a class that loads an iNES file
class Ines
  #ppens an iNES file and returns a mapper linked to ROM
  def load(fname)
    File.open(fname,'rb') do |file|
      raise 'Corrupt .nes file!' if not (file.sysread(3)    == 'NES')
      raise 'Corrput .nes file!' if not (read_bytes(file,1).first == 26)
      @prg_rom_banks = read_bytes(file,1).first
      @chr_rom_banks = read_bytes(file,1).first
      @rom_ctrl_1    = read_bytes(file,1).first
      @rom_ctrl_2    = read_bytes(file,1).first
      @sav_ram_banks = read_bytes(file,1).first
      read_bytes(file,7)
      @trainer = read_bytes(file,512) if trainer?
      @prg_rom = read_bytes(file,prg_rom_length)
      @chr_rom = read_bytes(file,chr_rom_length)
    end
    @mapper_number = ((@rom_ctrl_2&0xF0)*2**4)+(@rom_ctrl_1&0xF0)
    create_mapper
  end
  #wrapper for reading an unsigned byte
  def read_bytes(file,n)
    file.sysread(n).unpack('C*')
  end
  #determines if a trainer is present in this ROM
  def trainer?
    @rom_ctrl_1|(1<<2) == 1 ? true : false
  end
  #returns the number of 16Kb banks of PRG
  def prg_rom_length
    (@prg_rom_banks*16*1024)
  end
  #returns the number of 8Kb banks of CHR
  def chr_rom_length
    #@chr_rom_banks = 1 if @chr_rom_banks == 0
    (@chr_rom_banks*8*1024)
  end
  #helper method that creates a MMC
  def create_mapper
    map = nil
    case @mapper_number
    when 0 #NROM
      map = Nrom.new(@prg_rom,@chr_rom)
    else
      raise 'Unknown mapper number #{@mapper_number}'
    end
    map
  end
  private :read_bytes,:create_mapper
end

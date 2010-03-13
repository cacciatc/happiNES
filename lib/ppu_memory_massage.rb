#this module sets up all of the PPU's memory
module PPUMemoryMassage
  def setup_memory
    #setup memory mapped regs
    @m.register_for_writes(self,Ppu::CTRL1_REG)
    @m.register_for_writes(self,Ppu::CTRL2_REG)
    @m.register_for_writes(self,Ppu::SPR_RAM_ADDR_REG)
    @m.register_for_writes(self,Ppu::VRAM_ADDR_1_REG)
    @m.register_for_writes(self,Ppu::VRAM_ADDR_2_REG)
    @m.register_for_writes(self,Ppu::VRAM_IO_REG)
    @m.register_for_writes(self,Ppu::DMA_REG)

    @m.register_for_reads(self,Ppu::STATUS_REG)
    
    #pull in CHR ROM
    #(0..(1024*8)-1).each {|addr| @vram.write(addr,@m.vrom_read(addr))}
    chr_address_range = 0..(1024*8)-1
    @vram.write_block(chr_address_range,@m.chr_read_block(chr_address_range))
    
    #palette mirroring
    #do i need mirroring both ways?
    @vram.mirror(0x3F00..0x3F00,0x3F04..0x3F04)
    @vram.mirror(0x3F00..0x3F00,0x3F08..0x3F08)
    @vram.mirror(0x3F00..0x3F00,0x3F0C..0x3F0C)
    @vram.mirror(0x3F00..0x3F00,0x3F10..0x3F10)
    @vram.mirror(0x3F00..0x3F00,0x3F14..0x3F14)
    @vram.mirror(0x3F00..0x3F00,0x3F18..0x3F18)
    @vram.mirror(0x3F00..0x3F00,0x3F1C..0x3F1C)

    @vram.mirror(0x3F00..0x3F1F,0x3F20..0x3F3F)
    @vram.mirror(0x3F00..0x3F1F,0x3F40..0x3F5F)
    @vram.mirror(0x3F00..0x3F1F,0x3F60..0x3F7F)
    @vram.mirror(0x3F00..0x3F1F,0x3F80..0x3F9F)
    @vram.mirror(0x3F00..0x3F1F,0x3FA0..0x3FBF)
    @vram.mirror(0x3F00..0x3F1F,0x3FC0..0x3FDF)
    @vram.mirror(0x3F00..0x3F1F,0x3FE0..0x3FFF)
    
    @vram.mirror(Ppu::VRAM_MIRRORED_RAM,Ppu::VRAM_MIRROR_1)
  end
end
#trying to figure out rendering!
require 'rubygems'
require 'gosu'

require 'lib/cpu'
require 'lib/ines'
require 'lib/memory/main_memory'
require 'lib/color_palette'
require 'lib/ppu_spy'

require '../bitrap/lib/bitrap'

class NESRenderer < Gosu::Window
  include Bitrap
  def initialize
    #gosu init
    @w,@h = 1200,800
    super(@w,@h,false)
    self.caption = "PPU Rendering at it's finest!"
    @title_font = Gosu::Font.new(self,'arial',14)
    @text_font = Gosu::Font.new(self,'arial',11)
    
    #nes init
    create_hardware
    initialize_visual
  end
  def draw
    #debug info:
    @title_font.draw("current_scanline: #{@core.ppu.current_scanline}",5,605,1,1,1,0xFFFFFFFF)
    @title_font.draw("memory fetch phase: #{@core.ppu.memory_fetch_phase}",5,625,1,1,1,0xFFFFFFFF)
  end
  def update
    @core.run(60,true)
  end
  
  def create_hardware
    ines = Ines.new
    mem = MainMemory.new(ines.load("assembler//tutor.nes"))
    @core = Cpu.new(mem,0xC000)
    @core.ppu.extend(PPUSpy)
    @core.run(114*262,false)
  end
  
  def initialize_visual
    @vb = Bitmap.new(256,240)
  end
  
  def button_down(id)
    if id == Gosu::KbSpace
      @core.pause!
    end
    if id == Gosu::KbEscape
      exit
    end
  end
end

NESRenderer.new.show

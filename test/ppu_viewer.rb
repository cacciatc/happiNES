require 'rubygems'
require 'gosu'

require 'cpu'
require 'ines'
require 'memory/main_memory'
require 'color_palette'

class PPUViewer < Gosu::Window
  include ColorPalette
  def initialize
    super(1200,800,false)
    self.caption='PPU Viewer'
    ines = Ines.new
    mem = MainMemory.new(ines.load("..//assembler//tutor.nes"))
    @core = Cpu.new(mem,0xC000)
    @addr = 0x00
    @core.run(114*262,false)
    @w,@h = (width/2)/8,(height/4)/8
    @font = Gosu::Font.new(self,'arial',14)
    @font2 = Gosu::Font.new(self,'arial',11)
    @x,@y = 0,0
    @mono = [Gosu::Color.new(0,0,0),Gosu::Color.new(0,0,255),Gosu::Color.new(0,0,255),Gosu::Color.new(0,0,0),Gosu::Color.new(255,0,0),Gosu::Color.new(0,0,0)]
  end

  def draw
    @x,@y = 0,0
    @core.run(300,false)
    draw_palettes
    #draw_pattern_tables
    draw_name_tables
  end
  def draw_pattern_tables
    #one
    pt = @core.ppu.get_pattern_table(0)
    index = 0
    @x = 0
    w,h = width/30,(height-@h)/32
    while index < 0x1000/8
      puts pt[index+8] if pt[index+8] != 0
      puts pt[index] if pt[index] != 0 
      (0..7).each do |i|
        bh = pt[index+8]&(1<<i)
        bl = pt[index]&(1<<i)
        ref = bh*2 + bl
        color = PALETTE[ref]
        c = Gosu::Color.new(color[0],color[1],color[2])
        @font2.draw(sprintf("0x%02X",ref),@x+(w/4),@y+(h/2),1,1,1,0xFFFFFFFF)
        draw_quad(@x,@y,c,@x+w,@y,c,@x,@y+h,c,@x+w,@y+h,c)
        @x += w
        if @x >= width
          @x = 0
          @y += h
        end
      end
      index +=1
      index +=8 if index == 8
    end
    #two
    #@core.ppu.get_pattern_table(1)
  end
  
  def draw_name_tables
    nt = @core.ppu.get_name_table(1)
    pt = @core.ppu.get_pattern_table(0)
    index = 0
    @x = 0
    w,h = width/30,(height-@h)/32
    while index < 0x02BF
        pattern_bytes = pt[nt[index]]
        @font2.draw(sprintf("%02X",nt[index]),@x+(w/4),@y+(h/2),1,1,1,0xFFFFFFFF)
        @x += w
        if @x >= width
          @x = 0
          @y += h
        end
      index +=1
    end
  end
  #in monochrome
  #def draw_pattern_tables
    #@tile_index = 0x40
    #while @tile_index <= 0
     # pixels = @core.ppu.pattern_table_tile(0,@tile_index)
      #pixels.each do |p|
       # puts p,@mono[p]
        #draw_quad(@x,@y,@mono[p],@x,@y,@mono[p],@x,@y,@mono[p],@x,@y,@mono[p])
        #@x += 1
        #if @x > 7
       #   @y += 1
        #end
        #if @x >= width
         # @x = 0
         # @y += 1
        #end
      #end
     # @tile_index += 1
    #end
  #end
  def draw_palettes
    @addr = 0x3F00
    @x,@y=0,0
    while @addr <= 0x3F1F
      color_ref = @core.ppu.vram.read(@addr)
      color = PALETTE[color_ref]
      c = Gosu::Color.new(color[0],color[1],color[2])
      @font.draw(sprintf("0x%02X",color_ref),@x+(@w/4),@y+(@h/2),1,1,1,0xFFFFFFFF)
      draw_quad(@x,@y,c,@x+@w,@y,c,@x,@y+@h,c,@x+@w,@y+@h,c)
      @addr += 1
      @x += @w
      if @x >= width
        @x = 0
        @y += @h
      end
    end
  end
  def button_down(id)
    #if id == Gosu::KbEscape
    #  @core.ppu.vram.dump("vram.dump")
    #  @core.ppu.spr.dump("spr.dump")
    #end
  end
end

PPUViewer.new.show

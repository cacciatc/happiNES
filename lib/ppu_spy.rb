#used for debugging
module PPUSpy
  class Tile
    def self.render_simple(x,y,buf,palette)
      t_index = 0
      buffer = Array.new(64,0)
      f_index = (y<<8)+x
      (8..1).each do |dy|
        (8..1).each do |dx|
          buffer[f_index] = palette[pal_index] if pal_index != 0
          f_index += 1
          t_index += 1
        end
      end
    end
  end
  def render_pattern_table
    tiles = []
    pattern_tables.each do |pattern_table|
      16.times do |y|
        16.times do |x|
          tiles << Tile.render_simple(128+x*8,pattern_table,palette(:sprite))
        end
      end
    end
  end
  def render_name_table(index)
  end
  def render_palette
  end
end
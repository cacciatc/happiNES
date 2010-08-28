#Used for RAM that needs to repeat itself...
#Used for RAM that needs to repeat itself...
#Used for RAM that needs to repeat itself...
module Mirrored
  def mirror(this_range,to_that_range)
    @mirrors.push([this_range,to_that_range])
  end
  def two_sided_mirror(this_range,to_that_range)
    @mirrors.push([this_range,to_that_range])
    @mirrors.push([to_that_range,this_range])
  end
  #Naively mirrors
  def on_the_wall(address,new_value)
    @mirrors.each do |this,that|
      if this.include?(address)
        @m[(address-this.first)+that.first] = new_value
      end
    end
  end
  #Mirrors with performance enhancing drugs
  def smarter_on_the_wall(address,new_value,old_value)
    if not new_value == old_value
      @mirrors.each do |this,that|
        if this.include?(address)
          @m[(address-this.first)+that.first] = new_value
        end
      end
    end
  end
end

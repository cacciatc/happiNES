#for manipulating blocks 'o memory
module Blocked
  #takes here_to_there range and an array of values, does not notify observers or mirror
  def write_block(here_to_there,values)
    here_to_there.each_with_index do |address,i|
      raw_write(address,values[i])
    end
  end
  #takes a here_to_there range, does not notify observers or mirror
  def read_block(here_to_there)
    here_to_there.inject([]) do |block,address|
      block << raw_read(address)
    end
  end
end
require 'common/observed'
require 'common/blocked'
#Cartrige rom, used to represent both CHR and PRG ROM
class Rom
  include Observed
  include Blocked
  attr_reader :start_offset,:size
  #Creates ROM starting at start_offset with a size, and all cells = init_value
  def initialize(size,start_offset,init_value)
    @m = Array.new(size,init_value)
    @size,@start_offset = size,start_offset
    @w_observers,@r_observers = {},{} #for the observed module
  end
  def read(address)
    raise 'Address out of bounds!' if address < @start_offset or address > @size+@start_offset-1
    notify_of_read(address,@m[address-@start_offset]) #tell any observers
    @m[address-@start_offset]
  end
  def write(address,value)
    raise 'Address out of bounds!' if address < @start_offset or address > @size+@start_offset-1
    @m[address-@start_offset] = value
    notify_of_write(address,value) #tell any observers
  end
  #used internally, doesn't report to observers and doesn't mirror
  def raw_write(address,value)
    @m[address-@start_offset] = value
  end
  #used internally, doesn't report to observers and doesn't mirror  
  def raw_read(address)
    @m[address-@start_offset]
  end
  private :raw_write,:raw_write
end

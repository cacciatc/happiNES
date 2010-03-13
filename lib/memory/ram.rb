require 'common/observed'
require 'common/mirrored'
require 'common/dumped'
require 'common/blocked'

#General purpose RAM
class Ram
  include Observed
  include Mirrored
  include Dumped
  include Blocked

  attr_reader :size,:start_offset
  def initialize(size,start_offset,init_value)
    @m = Array.new(size,init_value)
    @size,@start_offset = size,start_offset
    @w_observers,@r_observers = {},{} #for observed
    @mirrors = [] #for mirrored
  end
  def read(address)
    raise 'Address out of bounds!' if address < @start_offset or address > @size+@start_offset-1
    notify_of_read(address,@m[address-@start_offset]) #tell any observers
    @m[address-@start_offset]
  end
  def write(address,value)
    raise 'Address out of bounds!' if address < @start_offset or address > @size+@start_offset-1
    #silently discard write requests to protected memory e.g. mirrored mem
    #if not @mirrors.detect{|ranges| ranges[1].include?(address-@start_offset)}
      old_value = @m[address-@start_offset]
      raw_write(address,value)
      #checks if we gots to mirror and does so
      smarter_on_the_wall(address,value,old_value)
      notify_of_write(address,value) #tell any observers
    #end
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

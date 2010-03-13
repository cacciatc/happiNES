#Used with ROM or RAM that needs to tell others about hormonal changes inside
module Observed
  def register_for_reads(object,address)
    @r_observers[address] ||= []
    @r_observers[address].push(object)
  end
  def register_for_writes(object,address)
    @w_observers[address] ||= []
    @w_observers[address].push(object)
  end
  def notify_of_read(address,new_value)
    @r_observers[address].each {|o| o.address_updated(address,new_value,'r')} if not @r_observers[address] == nil
  end
  def notify_of_write(address,new_value)
    @w_observers[address].each {|o| o.address_updated(address,new_value,'w')} if not @w_observers[address] == nil
  end
end

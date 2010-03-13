#Used to add a stack to RAM
module Stacked
  attr_accessor :stack_start_offset,:stack_size,:stack_ptr
 
  def setup_stack(start_offset,size)
    @stack_start_offset = start_offset
    @stack_size = size
    @stack_ptr = start_offset + size-1
  end
  def push(value)
    @m[@stack_ptr] = value
    @stack_ptr -= 1
    @stack_ptr = @stack_start_offset + @stack_size-1 if @stack_ptr == @stack_start_offset-1
  end
  def pop
    @stack_ptr += 1
    @stack_ptr = @stack_start_offset if @stack_ptr == @stack_start_offset + @stack_size
    tmp = @m[@stack_ptr]
    tmp
  end
  def set_stack_ptr(value)
    @stack_ptr = value
  end 
end

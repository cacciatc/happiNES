#A simple class with methods for modulus 256 addition and subtraction
class Register
  attr_reader :number
  def initialize(number)
    @number = number
  end
  def -(operand)
    res = (@number - operand)
    res = 255 if res == -1
    res = 0 if res == 255
    res
  end
  def +(operand)
    res = (@number - operand)
    res = 255 if res == -1
    res = 0 if res == 255
    res
  end
  def method_missing(name, *args, &blk)
    ret = @number.send(name, *args, &blk)
    ret.is_a?(Numeric) ? Register.new(ret) : ret
  end
end
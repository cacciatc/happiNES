module AddressingModes
  def AddressingModes.included(mod)
    const_set('WORD_SIZE',2**8) if not const_defined?('WORD_SIZE')
  end
  def zero_page(value)
    value
  end
  def indexed_zero_page(value,register_value)
    (value + register_value)%WORD_SIZE
  end
  def absolute(least,most)
    (most*WORD_SIZE)+least
  end
  def indexed_absolute(least,most,register_value)
    ((most*WORD_SIZE)+least+register_value)%(WORD_SIZE**2)
  end
  def indirect(least,most)
    new_most  = @m.read(absolute(least,most))
    new_least = @m.read(indexed_absolute(least,most,1))
    (new_most*WORD_SIZE)+new_least
  end
  def relative(value)
    @pc+(value <= 0x7F ? value : value-0xFF-1)
  end
  def indexed_indirect(value)
    least = @m.read((value+@x_reg)%WORD_SIZE)
    most  = @m.read((value+@x_reg)%WORD_SIZE+1)
    (most*WORD_SIZE)+least
  end
  def indirect_indexed(value)
    least = @m.read(value)
    most  = @m.read(value+1)
    ((most*WORD_SIZE)+least+@y_reg)%WORD_SIZE
  end
end

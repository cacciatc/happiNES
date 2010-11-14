module StatusOperations
  #interrupts
  def disable_interrupts!
    @status |= (1<<2)
  end
  def enable_interrupts!
    @status &= ~(1<<2)
  end
  def interrupts_disabled?
    @status&(1<<2) == 0? false : true
  end
  
  #decimal mode
  def disable_decimal_mode!
    @status |= (1<<3)
  end
  def enable_decimal_mode!
    @status &= ~(1<<3)
  end
  def decimal_mode_disabled?
    @status&(1<<3) == 0? false : true
  end
  
  #zero flag
  def set_zero_flag!
    @status |= (1<<1)
  end
  def clear_zero_flag!
    @status &= ~(1<<1)
  end
  def zero_flag?
    @status&(1<<1) == 0? false : true
  end
  
  #negative flag
  def set_negative_flag!
    @status |= (1<<7)
  end
  def clear_negative_flag!
    @status &= ~(1<<7)
  end
  def negative_flag?
    @status&(1<<7) == 0? false : true
  end
  
  #carry flag
  def set_carry_flag!
    @status |= (1<<0)
  end
  def clear_carry_flag!
    @status &= ~(1<<0)
  end
  def carry_flag?
    @status&(1<<0) == 0? false : true
  end
end
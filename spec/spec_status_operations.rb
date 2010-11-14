require 'lib/cpu/status_operations'

describe "StatusOperations" do
  before do
    @a = eval %q{
    class TestCPU
      include StatusOperations
      def initialize
        @status = 0x00
      end
    end
    TestCPU.new}
  end
  it "should be able to disable interrupts" do
    @a.disable_interrupts!
    @a.interrupts_disabled?.should == true
  end
  it "should be able to enable interrupts" do
    @a.enable_interrupts!
    @a.interrupts_disabled?.should == false
  end
  it "should be able to query the interrupts flag" do
    @a.respond_to?('interrupts_disabled?').should == true
  end
  it "should be able to disable decimal mode" do
    @a.disable_decimal_mode!
    @a.decimal_mode_disabled?.should == true
  end
  it "should be able to enable decimal mode" do
    @a.enable_decimal_mode!
    @a.decimal_mode_disabled?.should == false
  end
  it "should be able to query the decimal mode flag" do
    @a.respond_to?('decimal_mode_disabled?').should == true
  end
  it "should be able to set the zero flag" do
    @a.set_zero_flag!
    @a.zero_flag?.should == true
  end
  it "should be able to clear the zero flag" do
    @a.clear_zero_flag!
    @a.zero_flag?.should == false
  end
  it "should be able to query the zero flag" do
    @a.respond_to?('zero_flag?').should == true
  end
  it "should be able to set the negative flag" do
    @a.set_negative_flag!
    @a.negative_flag?.should == true
  end
  it "should be able to clear the negative flag" do
    @a.clear_negative_flag!
    @a.negative_flag?.should == false
  end
  it "should be able to query the negative flag" do
    @a.respond_to?('negative_flag?').should == true
  end
  it "should be able to set the carry flag" do
    @a.set_carry_flag!
    @a.carry_flag?.should == true
  end
  it "should be able to clear the carry flag" do
    @a.clear_carry_flag!
    @a.carry_flag?.should == false
  end
  it "should be able to query the carry flag" do
    @a.respond_to?('carry_flag?').should == true
  end
end
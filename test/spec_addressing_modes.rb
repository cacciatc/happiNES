describe "AddressingModes" do
  before do
    @a = eval %q{
    class Memory
      def read(addr)
        0
      end
    end
    class TestCPUA
      include AddressingModes
      def initialize
        @pc,@x_reg,@y_reg = 0,0,0
        @m = Memory.new
      end
    end
    TestCPUA.new}
  end
  it "should have a default word size if mixin class doesn't" do
    @a.class.const_defined?('WORD_SIZE').should == true
    @b = eval %q{
    class TestCPUB < TestCPUA
      WORD_SIZE = 512
    end
    TestCPUB.new}
    @b.class.const_defined?('WORD_SIZE').should == true
    @b.class::WORD_SIZE.should == 512
  end
  it "should support zero page" do
    @a.zero_page(0xFF).should == 0XFF
  end
  it "should support indexed zero page" do
    @a.indexed_zero_page(0xFF,0x02).should == 0x01
  end
  it "should support absolute" do
    @a.absolute(0xFF,0xFF).should == 0xFFFF
  end
  it "should support indexed absolute" do
    @a.indexed_absolute(0x02,0x02,0x02).should == 0x0204
  end
  it "should support indirect" do
    @a.indirect(0xFF,0x00).should == 0x00
  end
  it "should support relative" do
    @a.relative(0x7F).should == 0x7F
  end
  it "should support indexed indirect" do
    @a.indexed_indirect(0x20).should == 0x00
  end
  it "should support indirect indexed" do
    @a.indirect_indexed(0x20).should == 0x00
  end
end

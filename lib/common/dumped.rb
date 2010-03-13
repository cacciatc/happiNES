#Sad sad sad
module Dumped
  def dump(filename="#{self.class}.dump")
    File.open(filename,'w') do |f|
      a = 0
      @m.each {|i| f.puts sprintf("[%4X] %2X",a,i); a+= 1}
    end
  end
end
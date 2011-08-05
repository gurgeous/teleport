require "spec_helper"

describe "a new ec2 instance" do
  ec2
  
  it "broken" do
    puts @ec2.inspect
    #:a.should == :b
  end
end

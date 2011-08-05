require "spec_helper"

describe Teleport::Config do
  context "with a blank Telfile" do
    inside_dir("#{TELDIRS}/blank")

    let(:config) do
      Teleport::Config.new
    end
    it "defaults to the current username" do
      config.user.should == `whoami`.strip      
    end
    it "defaults to the first vm in RUBIES" do
      config.ruby.should == Teleport::Config::RUBIES.first
    end
  end

  context "with a simple Telfile" do
    inside_dir("#{TELDIRS}/simple")
    
    let(:config) do
      Teleport::Config.new
    end
    it "has the master role" do
      config.role(:master).name.should == :master
      config.role(:master).packages.should == %w(nginx)
    end
    it "has server one" do
      config.server("one").name.should == "one"
      config.server("one").packages.should == %w(strace)
    end
    it "has default packages" do
      config.packages.should == %w(atop)
    end
    it "has callbacks" do
      config.callbacks[:before_install].should_not == nil
      config.callbacks[:after_install].should_not == nil      
    end
    it "has an apt line" do
      config.apt.first.line.should == "blah blah blah"
      config.apt.first.options[:key].should == "123"      
    end
  end
end

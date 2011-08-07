require "erb"
require "spec_helper"

describe "a new ec2 instance" do
  inside_dir("#{TELDIRS}/ec2")
  ec2

  before do
    # create Telfile
    @telfile = "/tmp/end_to_end_Telfile"
    File.open(@telfile, "w") do |f|
      f.write ERB.new(File.read("Telfile.erb")).result(binding)
    end
  end
  
  it "installs properly" do
    ARGV.clear
    ARGV << "--file"
    ARGV << @telfile
    ARGV << ENV["TELEPORT_IP"]
    Teleport::Main.new
  end

  it "installs again" do
    ARGV.clear
    ARGV << "--file"
    ARGV << @telfile
    ARGV << ENV["TELEPORT_IP"]
    Teleport::Main.new
  end
end

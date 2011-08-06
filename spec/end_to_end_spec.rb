require "spec_helper"

describe "a new ec2 instance" do
  inside_dir("#{TELDIRS}/ec2")
  ec2
  
  it "installs properly" do
    ARGV.clear
    ARGV << ENV["TELEPORT_IP"]
    lambda { Teleport::Main.new}.should exit_with_code(0)
  end
end

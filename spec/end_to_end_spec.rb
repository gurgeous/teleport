require "erb"
require "spec_helper"

describe "a new ec2 instance" do
  ec2
  puts "DESCRIBE: #{self}"
  puts @ip_address.inspect
  
  telfile(<<EOF)
user "gub"
ruby "1.8.7"
ssh_options ["-o", "User=ubuntu", "-o", "StrictHostKeyChecking=no", "-o", "IdentityFile=#{ENV["TELEPORT_SSH_KEY"]}"]

role :master, :packages => %w(nginx)
server "#{@ip_address}", :role => :master, :packages => %w(strace)
packages %w(atop)

before_install do
  puts "BEFORE_INSTALL"
end

after_install do
  puts "AFTER_INSTALL"
  run "touch /tmp/gub.txt"
end
EOF

  it "installs properly" do
    ARGV.clear
    ARGV << @ip_address
    Teleport::Main.new
  end

  it "installs again" do
    ARGV.clear
    ARGV << @ip_address
    Teleport::Main.new
  end
end

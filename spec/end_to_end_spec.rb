require "erb"
require "spec_helper"

describe "a new ec2 instance" do
  ec2

  # Telfile
  telfile do
    <<EOF
user "gub"
ruby "1.9.3"
ssh_options ["-o", "User=ubuntu", "-o", "StrictHostKeyChecking=no", "-o", "IdentityFile=#{ENV["TELEPORT_SSH_KEY"]}"]

role :master, :packages => %w(nginx), :recipes => %w(ruby.rb)
server "#{$ec2_ip_address}", :role => :master, :packages => %w(strace), :recipes => %w(some_command)
packages %w(atop)

before_install do
  puts "BEFORE_INSTALL"
end

after_files do
  puts "AFTER_FILES"
  puts "test.txt"
  p File.read("/test.txt")
end

after_gemfiles do
  puts "AFTER_GEMFILES"
  Util.run "gem list"
end

after_recipes do
  puts "AFTER_RECIPES"
end

after_install do
  puts "AFTER_INSTALL"
  run "touch /tmp/gub.txt"
end

EOF
  end

  # Roles. This is clunky, unfortunately.
  
  # amd: commenting the Gemfiles because they are too slow. revisit for bundler 1.1?
  # role(nil, "test.txt.erb" => "<%= 1+2 %>", "Gemfile" => "source 'http://rubygems.org'\ngem 'trollop'", "Gemfile.lock" => "GEM\n  remote: http://rubygems.org/\n  specs:\n    trollop (1.16.2)\n\nPLATFORMS\n  ruby\n\nDEPENDENCIES\n  trollop")
  # role("master", "Gemfile" => "source 'http://rubygems.org'\ngem 'awesome_print'", "Gemfile.lock" => "GEM\n  remote: http://rubygems.org/\n  specs:\n    awesome_print (0.4.0)\n\nPLATFORMS\n  ruby\n\nDEPENDENCIES\n  awesome_print")
  role(nil, "test.txt.erb" => "<%= 1+2 %>")

  # Recipes
  recipe("ruby.rb", "Util.run 'echo ruby.rb is running'")
  recipe("some_command", "#!/bin/bash\necho some_command is running")
  
  it "installs properly" do
    ARGV.clear
    ARGV << $ec2_ip_address
    Teleport::Main.new
  end

  it "installs again" do
    ARGV.clear
    ARGV << $ec2_ip_address
    Teleport::Main.new
  end
end

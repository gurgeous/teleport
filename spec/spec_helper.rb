SUPPORT = "#{File.dirname(__FILE__)}/support"

$LOAD_PATH << "#{File.dirname(__FILE__)}/../lib"
$LOAD_PATH << File.dirname(__FILE__)
$LOAD_PATH << SUPPORT

require "teleport"
require "rspec"

Dir["#{SUPPORT}/*.rb"].each { |i| require File.basename(i) }

TELDIRS = "#{File.dirname(__FILE__)}/teldirs"

RSpec.configure do |config|
  config.extend Support::InsideDir
  config.extend Support::Ec2

  ec2_configured = Support::Ec2.configured?
  warn(Support::Ec2.message) if !ec2_configured

  #config.filter_run_excluding(:config => lambda { |value|
    #return true if value == :mongohq && !mongohq_configured
  #})
end

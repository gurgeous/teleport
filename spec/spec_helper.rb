$LOAD_PATH.unshift << File.dirname(__FILE__)
$LOAD_PATH.unshift << "#{File.dirname(__FILE__)}/../lib"

require "teleport"
require "rspec"

TELDIRS = "#{File.dirname(__FILE__)}/teldirs"

module WithDir
  def self.included(group)
    group.extend(self)
  end

  def with_dir(dir)
    before do
      @pwd = Dir.pwd
      Dir.chdir(dir)
    end
    after do
      Dir.chdir(@pwd)
    end
  end
end

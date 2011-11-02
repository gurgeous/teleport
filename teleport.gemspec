$LOAD_PATH << File.expand_path("../lib", __FILE__)

require "teleport/version"

Gem::Specification.new do |s|
  s.name        = "teleport"
  s.version     = Teleport::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Adam Doppelt"]
  s.email       = ["amd@gurge.com"]
  s.homepage    = "http://github.com/gurgeous/teleport"  
  s.summary     = "Teleport - opinionated Ubuntu server setup with Ruby."
  s.description = "Easy Ubuntu server setup via teleportation."

  s.rubyforge_project = "teleport"

  s.add_development_dependency("amazon-ec2")
  s.add_development_dependency("awesome_print")
  s.add_development_dependency("rake")  
  s.add_development_dependency("rdoc", ["~> 3.9"])  
  s.add_development_dependency("rspec", ["~> 2.6"])
  
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

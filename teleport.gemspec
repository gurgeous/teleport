$:.push File.expand_path("../lib", __FILE__)
require "teleport/version"

Gem::Specification.new do |s|
  s.name        = "teleport"
  s.version     = Teleport::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Adam Doppelt", "John McGrath"]
  s.email       = ["amd@gurge.com", "john@rglabsinc.com"]
  s.homepage    = "http://github.com/rglabs/teleport"  
  s.summary     = %Q{Teleport - opinionated Ubuntu server setup with Ruby.}
  s.description = %Q{Easy Ubuntu server setup via teleportation.}

  s.rubyforge_project = "teleport"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
end

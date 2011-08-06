require "bundler"
require "bundler/setup"

require "rake"
require "rdoc/task"
require "rspec"
require "rspec/core/rake_task"

$LOAD_PATH << File.expand_path("../lib", __FILE__)
require "teleport/version"

#
# gem
#

task :gem => :build
task :build do
  system "gem build --quiet teleport.gemspec"
end

task :install => :build do
  system "sudo gem install --quiet teleport-#{Teleport::VERSION}.gem"
end

task :release => :build do
  system "git tag -a #{Teleport::VERSION} -m 'Tagging #{Teleport::VERSION}'"
  system "git push --tags"
  system "gem push teleport-#{Teleport::VERSION}.gem"
end

#
# rspec
#

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = %w(--color --tty)
  spec.pattern = "spec/**/*_spec.rb"
end

#
# rdoc
#

RDoc::Task.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "teleport #{Teleport::VERSION}"
  rdoc.rdoc_files.include("lib/**/*.rb")
end

task :default => :spec

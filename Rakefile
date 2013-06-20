require "bundler/gem_helper"
require "rake/testtask"
require "rdoc/task"
require "rspec"
require "rspec/core/rake_task"

Bundler::GemHelper.install_tasks

#
# rspec
#

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.rspec_opts = %w(--color --tty)
  spec.pattern = "spec/**/*_spec.rb"
end

RSpec::Core::RakeTask.new("spec:unit") do |spec|
  spec.pattern = "spec/unit/**/*_spec.rb"
end

RSpec::Core::RakeTask.new("spec:end") do |spec|
  spec.pattern = "spec/end*_spec.rb"
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

require "bundler"
require "rake/rdoctask"

Bundler::GemHelper.install_tasks

Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = "rdoc"
  rdoc.title = "teleport #{Teleport::VERSION}"
  rdoc.rdoc_files.include("lib/**/*.rb")
end

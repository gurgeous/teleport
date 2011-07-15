teleport
  Gemfile
  Rakefile
  LICENSE
  README.md
  teleport.gemspec
  bin/teleport
  lib/teleport.rb
  lib/teleport/main.rb
  lib/teleport/util.rb
  lib/teleport/version.rb
  lib/teleport/setup.sh

teleport HOSTNAME

teleport/teleport.rb
        /run.rb
        /files/...
        /files_master/...

teleport.rb        
  user :amd
  role :master, :packages => %w(a b c)
  server "sd1", :master
  server "sd2", :db
  apt_key "7F0CEB10"
  packages %w(a b c)

run.rb
  create_user
  apt_sources
  packages
  files
  if role == :app
    run "mkdir gub"
  end

teleport new (creates sample directory)


module Teleport
  class Install
    include Constants    
    include Util
    
    attr_reader :config
    
    def initialize(config)
      @config = config
      _run
    end

    #
    # public API
    #

    def user
      config.user
    end

    #
    # private API
    #

    def _run
      run_verbose!
      _finish_ruby_install
      _hostname
      _create_user
    end

    def _finish_ruby_install
      # fixup 1.8.7
      ruby_version = `ruby --version`.strip
      if ruby_version =~ /1.8.7/ && ruby_version !~ /Enterprise Edition/
        %w(irb libopenssl-ruby libreadline-ruby rdoc ri ruby-dev).each do |i|
          package_if_necessary(i)
        end
        if fails?("which gem")
          banner "Installing rubygems..."
          Dir.chdir(DIR) do
            run "wget http://production.cf.rubygems.org/rubygems/rubygems-1.8.5.tgz"
            run "tar xfpz rubygems-1.8.5.tgz"
            Dir.chdir("rubygems-1.8.5") do
              run "ruby setup.rb"
            end
          end
          ln("/usr/bin/gem1.8", "/usr/bin/gem")
        end
      end

      # update rubygems if necessary
      gem_version = `gem --version`.strip.split(".").map(&:to_i)
      if (gem_version <=> [1, 8, 5]) == -1
        banner "Upgrading rubygems..."
        run "gem update --system"
      end
      
      # uninstall all gems except for bundler
      gems = `gem list`.split("\n").map { |i| i.split.first }
      gems.delete("bundler")
      if !gems.empty?
        banner "Uninstalling #{gems.length} system gems..."
        gems.each do |i|
          run "gem uninstall -aIx #{i}"
        end
      end
      
      # install bundler
      gem_if_necessary("bundler")
    end

    def _hostname
      # read DIR/config to get CONFIG_HOST
      config = { }
      File.readlines("#{DIR}/config").each do |i|
        if i =~ /CONFIG_([^=]+)='([^']*)'/
          config[$1.downcase.to_sym] = $2
        end
      end

      old_hostname = `hostname`.strip
      return if old_hostname == config[:host]
      
      banner "Setting hostname to #{config[:host]} (it was #{old_hostname})..."
      File.open("/etc/hostname", "w") do |f|
        f.write config[:host]
      end
      run "hostname -F /etc/hostname"

      banner "Fixing up /etc/hosts..."
      tmppath = "/etc/hosts.tmp"
      File.open("/etc/hosts") do |fin|
        File.open(tmppath, "w") do |fout|
          while line = fin.gets
            line = line.gsub(/\b#{Regexp.escape(old_hostname)}\b/, config[:host])
            fout.write line
          end
        end
      end
      mv(tmppath, "/etc/hosts")
    end

    def _create_user
      # create the account
      if !File.directory?("/home/#{user}")
        banner "Creating #{user} account..."
        run "useradd --create-home --shell /bin/bash --groups adm #{user}"
      end
      if fails?("grep '^#{user}' /etc/sudoers.d/teleport")
        banner "Setting up sudoers..."
        File.open("/etc/sudoers.d/teleport", "w") do |f|
          f.puts "#{user} ALL=(ALL) NOPASSWD: ALL"
        end
        chmod("/etc/sudoers.d/teleport", 0440)
      end
    end
  end
end

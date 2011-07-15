module Teleport
  class Install
    include Constants    
    include Util
    
    attr_reader :config, :host
    
    def initialize(config)
      @config = config
      run_verbose!
      _run
    end

    #
    # public API
    #

    def user
      config.user
    end

    def role
      @role.name
    end

    def install_packages(*list)
      list.flatten.each do |i|
        package_if_necessary(i)
      end
    end

    #
    # private API
    #

    def _run
      _root!
      _config
      _finish_ruby_install
      _hostname
      _create_user
      _packages
    end

    def _root!
      # become root if necessary
      return if whoami == "root"
      
      if fails?("sudo -n echo gub")
        fatal("Please setup sudo for #{user}.")
      end
      banner "Becoming root..."
      $stdout.flush
      exec("sudo ruby -I gem -r teleport -e \"Teleport::Main.new(:install)\"") 
    end

    def _config
      # read DIR/config to get CONFIG_HOST (and set @host)
      config_file = { }
      File.readlines("config").each do |i|
        if i =~ /CONFIG_([^=]+)='([^']*)'/
          config_file[$1.downcase.to_sym] = $2
        end
      end
      @host = config_file[:host]

      # do we have a server object?
      @server = config.server(@host)
      if !@server && !config.servers.empty?
        fatal "Hm. I couldn't find server #{@host.inspect} in teleport.rb."
      end

      @role = nil
      if @server && (role_name = @server.options[:role])
        @role = config.role(role_name)
        if !@role
          fatal "Hm. I couldn't find role #{role_name.inspect} in teleport.rb."
        end
      end
    end

    def _finish_ruby_install
      # fixup 1.8.7
      ruby_version = `ruby --version`.strip
      if ruby_version =~ /1.8.7/ && ruby_version !~ /Enterprise Edition/
        install_packages(%w(irb libopenssl-ruby libreadline-ruby rdoc ri ruby-dev))
        if fails?("which gem")
          banner "Installing rubygems..."
          run "wget http://production.cf.rubygems.org/rubygems/rubygems-1.8.5.tgz"
          run "tar xfpz rubygems-1.8.5.tgz"
          Dir.chdir("rubygems-1.8.5") do
            run "ruby setup.rb"
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
      old_hostname = `hostname`.strip
      return if old_hostname == @host
      
      banner "Setting hostname to #{config[:host]} (it was #{old_hostname})..."
      File.open("/etc/hostname", "w") do |f|
        f.write @host
      end
      run "hostname -F /etc/hostname"

      banner "Fixing up /etc/hosts..."
      tmppath = "/etc/hosts.tmp"
      File.open("/etc/hosts") do |fin|
        File.open(tmppath, "w") do |fout|
          while line = fin.gets
            line = line.gsub(/\b#{Regexp.escape(old_hostname)}\b/, @host)
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

      # ssh key, if present
      # ssh-keygen -t rsa -f ~/.ssh/id_teleport
      authorized_keys = "/home/#{user}/.ssh/authorized_keys"
      if !File.exists?(authorized_keys)
        if File.exists?(PUBKEY)
          mkdir_if_necessary(File.dirname(authorized_keys), user, 0700)
          cp(PUBKEY, authorized_keys, user, 0600)
        end
      end
    end

    def _packages
      banner "Packages..."
      packages = config.packages
      packages += @role.packages if !@role
      packages += @server.packages if @server
      install_packages(packages)
    end
  end
end


# user :amd
# ruby "1.8.7"
# apt_key "7F0CEB10"
# packages %w(a b c)
# role :master, :packages => %w(d e f)
# server "vox", :role => :master, :packages => %w(a b c)

# create_user
# apt_sources
# packages
# files
# if role == :app
#   run "mkdir gub"
# end

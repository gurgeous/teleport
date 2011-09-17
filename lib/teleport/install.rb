module Teleport
  # Class that performs the install on the target machine.
  class Install
    include Constants
    include Util
    include Mirror

    def initialize(config)
      @config = config
      run_verbose!
      _read_config

      # setup @config constants
      Config::DSL.const_set("HOST", @host)
      Config::DSL.const_set("USER", @config.user)
      Config::DSL.const_set("ROLE", @role && @role.name)

      # add mixins
      @config.dsl.extend(Mirror)
      @config.dsl.extend(Util)
      @config.dsl.run_verbose!

      _with_callback(:install) do
        _gem_reset
        _hostname
        _with_callback(:user) do
          _create_user
        end
        _apt
        _with_callback(:packages) do
          _packages
        end
        _with_callback(:files) do
          _files
        end
        _with_callback(:gems) do
          _gem_install
        end
        _with_callback(:shell) do
          _shell
        end
      end
    end

    protected

    def _read_config
      # read DIR/config to get CONFIG_HOST (and set @host)
      config_file = {}
      File.readlines("config").each do |i|
        if i =~ /CONFIG_([^=]+)='([^']*)'/
          config_file[$1.downcase.to_sym] = $2
        end
      end
      @host = config_file[:host]

      # do we have a server object?
      @server = @config.server(@host)
      if !@server && !@config.servers.empty?
        fatal "Hm. I couldn't find server #{@host.inspect} in Telfile."
      end

      @role = nil
      if @server && (role_name = @server.options[:role])
        @role = @config.role(role_name)
        if !@role
          fatal "Hm. I couldn't find role #{role_name.inspect} in Telfile."
        end
      end
    end

    def _gem_reset
      banner "Resetting Gems..."

      # update rubygems if necessary
      gem_version = `gem --version`.strip.split(".").map(&:to_i)
      if (gem_version <=> RUBYGEMS.split(".").map(&:to_i)) == -1
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

    def _gem_install
      banner "Installing Gems..."
      @config.gems.each { |g| gem_if_necessary("#{g}") }
    end

    def _shell
      banner "Running Shell Commands..."
      @config.shell.each do |line|
        banner "Executing: #{line}"
        run("#{line}")
      end
    end

    def _hostname
      banner "Hostname..."

      # ipv4?
      return if @host =~ /^\d+(\.\d+){3}$/
      # ipv6?
      return if @host =~ /:/

      old_hostname = `hostname`.strip
      return if old_hostname == @host

      puts "setting hostname to #{@host} (it was #{old_hostname})..."
      File.open("/etc/hostname", "w") do |f|
        f.write @host
      end
      run "hostname -F /etc/hostname"

      puts "adding #{@host} to /etc/hosts ..."
      _rewrite("/etc/hosts") do |fout|
        hosts = File.read("/etc/hosts")

        # old_hostname => @host
        # We also want to write a 127.0.0.1 hostname hostname.domain.tld line.
        host_name = @host.split(".").first
        fqdn = @host
        hosts.unshift("127.0.0.1 #{host_name} #{fqdn}")
        hosts.gsub!(_etc_hosts_regex(old_hostname), "\\1#{@host}\\2")
        if hosts !~ _etc_hosts_regex(@host)
          # not found? append to localhost
          hosts.gsub!(_etc_hosts_regex("localhost"), "\\1localhost #{@host}\\2")
          if hosts !~ _etc_hosts_regex(@host)
            puts "  Hm. I couldn't add it, unfortunately. You'll have to do it manually."
          end
        end

        fout.write hosts
      end
    end

    def _create_user
      user = @config.user

      banner "Creating #{user} account..."
      # create the account
      if !File.directory?("/home/#{user}")
        run "useradd --create-home --shell /bin/bash --groups adm #{user}"
      end

      # try to sudo - if it fails, add user to sudoers
      if fails?("sudo -u #{user} sudo -n echo gub")
        puts "setting up sudoers..."
        File.open("/etc/sudoers", "a") do |f|
          f.puts <<EOF
# added by teleport
#{user} ALL=(ALL) NOPASSWD: ALL
EOF
        end
      end

      # ssh key, if present
      if File.exists?(PUBKEY)
        authorized_keys = "/home/#{user}/.ssh/authorized_keys"
        if !File.exists?(authorized_keys)
          puts "adding #{PUBKEY} to authorized_keys..."
          mkdir_if_necessary(File.dirname(authorized_keys), user, 0700)
          cp(PUBKEY, authorized_keys, user, 0600)
        end
      end
    end

    def _apt
      return if @config.apt.empty?
      banner "Apt..."

      dirty = false

      # keys
      keys = @config.apt.map { |i| i.options[:key] }.compact
      keys.each do |i|
        if fails?("apt-key list | grep #{i}")
          run "apt-key adv --keyserver keyserver.ubuntu.com --recv #{i}"
          dirty = true
        end
      end

      # teleport.list
      apt = @config.apt.sort_by { |i| i.line }
      rewrite = _rewrite("/etc/apt/sources.list.d/teleport.list") do |f|
        f.puts "# Generated by teleport"
        apt.each do |i|
          f.puts i.line
        end
      end

      if dirty || rewrite
        run "apt-get update"
      end
    end

    def _packages
      banner "Packages..."
      list = @config.packages
      list += @role.packages if @role
      list += @server.packages if @server
      list.sort.each { |i| package_if_necessary(i) }
    end

    def _files
      banner "Files..."
      files = ["files"]
      files << "files_#{@role.name}" if @role
      files.each do |i|
        install_dir(i) if File.exists?("#{DATA}/#{i}")
      end
    end

    protected

    def _with_callback(op, &block)
      if before = @config.callbacks["before_#{op}".to_sym]
        before.call
      end
      yield
      if after = @config.callbacks["after_#{op}".to_sym]
        after.call
      end
    end

    def _rewrite(path, &block)
      tmp = "#{path}.tmp"
      begin
        File.open(tmp, "w") { |f| yield(f) }
        if !File.exists?(path) || different?(path, tmp)
          copy_perms(path, tmp) if File.exists?(path)
          mv(tmp, path)
          return true
        end
      ensure
        File.unlink(tmp) if File.exists?(tmp)
      end
      false
    end

    def _etc_hosts_regex(host)
      /^([^#]+[ \t])#{Regexp.escape(host)}([ \t]|$)/
    end
  end
end

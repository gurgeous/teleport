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

      # setup @config constants. Put them in mirror so they're
      # accessible to both the DSL and Mirror itself. That way you can
      # access these if you call install_file directly.
      Mirror.const_set("HOST", @host)
      Mirror.const_set("USER", @config.user)
      Mirror.const_set("ROLE", @role && @role.name)
      Mirror.const_set("SERVER", @server)

      # add mixins
      @config.dsl.extend(Mirror)
      @config.dsl.extend(Util)
      @config.dsl.run_verbose!

      # handle CONFIG_RECIPE
      if @config_file[:recipe]
        _with_callback(:install) do
          _with_callback(:recipes) do
            _recipe(@config_file[:recipe])
          end
        end
        return
      end

      _with_callback(:install) do
        _gems
        _hostname
        _with_callback(:user) do
          _create_user
        end
        _apt
        _with_callback(:packages) do
          _packages
        end
        _with_callback(:gemfiles) do
          _gemfiles
        end
        _with_callback(:files) do
          _files
        end
        _with_callback(:recipes) do
          _recipes
        end
      end
    end

    protected

    def _read_config
      # read DIR/config to get CONFIG_HOST (and set @host)
      @config_file = { }
      File.readlines("config").each do |i|
        if i =~ /CONFIG_([^=]+)='([^']*)'/
          @config_file[$1.downcase.to_sym] = $2
        end
      end
      @host = @config_file[:host]

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

    def _gems
      banner "Gems..."

      # update rubygems if necessary
      gem_version = `gem --version`.strip.split(".").map(&:to_i)
      if (gem_version <=> RUBYGEMS.split(".").map(&:to_i)) == -1
        banner "Upgrading rubygems..."
        run "gem update --system"
      end

      # install bundler
      gem_if_necessary("bundler")
    end

    def _recipes
      list = @config.recipes
      list += @role.recipes if @role
      list += @server.recipes if @server

      banner "Recipes..."
      list.each { |i| _recipe(i) }
    end

    def _recipe(recipe)
      path = "#{DATA}/recipes/#{recipe}"
      if File.exists?(path)
        banner "#{recipe}..."
        # eval ruby files instead of running them
        if path =~ /\.rb$/
          eval(File.read(path), nil, path)
        else
          run path
        end
      else
        fatal "Recipe '#{recipe}' does not exist inside recipes/"
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

      # list of hostnames to add to /etc/hosts
      hostnames = []
      hostnames << @host
      hostnames << @host.split(".").first if @host.index(".")
      hostnames = hostnames.join(" ")

      puts "adding #{hostnames} to /etc/hosts ..."
      _rewrite("/etc/hosts") do |fout|
        hosts = File.read("/etc/hosts")

        # old_hostname => @host
        hosts.gsub!(_etc_hosts_regex(old_hostname), "\\1#{hostnames}\\2")
        if hosts !~ _etc_hosts_regex(@host)
          # not found? append to localhost
          hosts.gsub!(_etc_hosts_regex("localhost"), "\\1localhost #{hostnames}\\2")
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
          puts "adding #{File.basename(@config.ssh_key || PUBKEY)} to authorized_keys..."
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

    def _gemfiles
      files = ["files"]
      files << "files_#{@role.name}" if @role
      Dir.chdir(DATA) do
        files.each do |i|
          gemfile = "#{i}/Gemfile"
          if File.exists?(gemfile)
            banner "Gemfiles - #{gemfile}..."
            run "bundle install --gemfile #{gemfile}"
          end
        end
      end
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

module Teleport
  class Install
    include Constants    
    include Util
    
    attr_reader :config
    
    def initialize(config)
      @config = config
      _run
    end

    def _run
      run_verbose!
      _finish_ruby_install
      _hostname
    end

    def _finish_ruby_install
      # update rubygems if necessary
      gem_version = `gem --version`.strip.split(".").map(&:to_i)
      if (gem_version <=> [1, 8, 5]) == -1
        banner "Upgrading rubygems..."
        run "gem update --system"
      end
      
      # uninstall all gems except for bundler
      gems = `gem list`.split("\n")
      gems = gems.map { |i| i.split.first }
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

      if `hostname`.strip != config[:host]
        banner "Setting hostname to #{config[:host]}..."
        File.open("/etc/hostname", "w") do |f|
          f.write config[:host]
        end
        run "hostname -F /etc/hostname"
      end
    end
  end
end

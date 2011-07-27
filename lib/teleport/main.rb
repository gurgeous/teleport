require "erb"
require "getoptlong"

module Teleport
  class Main
    include Constants
    include Util    

    DIR = "/tmp/_teleported"
    TAR = "#{DIR}.tgz"
    
    attr_accessor :host, :options
    
    def initialize(cmd = :teleport)
      opts = GetoptLong.new(
                            ["--help", "-h", GetoptLong::NO_ARGUMENT]
                            )
      opts.each do |opt, arg|
        case opt
        when "--help"
          usage(0)
        end
      end

      $stderr = $stdout
      
      case cmd
      when :teleport
        usage(1) if ARGV.empty?
        teleport(ARGV.shift)
      when :install
        install
      end
    end

    #
    # teleport
    #

    def sanity!
      if !File.exists?(Config::PATH)
        fatal("Sadly, I can't find #{Config::PATH} here. Please create one.")
      end
      @config = Config.new
    end

    def assemble_tgz(host)
      banner "Assembling #{TAR}..."
      rm_and_mkdir(DIR)
      
      # gem
      run("cp", ["-r", "#{File.dirname(__FILE__)}/../../lib", GEM])
      # data
      run("cp", ["-r", ".", DATA])
      # config.sh
      File.open("#{DIR}/config", "w") do |f|
        f.puts("CONFIG_HOST='#{host}'")        
        f.puts("CONFIG_RUBY='#{@config.ruby}'")
        f.puts("CONFIG_RUBYGEMS='#{RUBYGEMS}'")        
      end
      # keys
      ssh_key = "#{ENV["HOME"]}/.ssh/#{PUBKEY}"
      if File.exists?(ssh_key)
        run("cp", [ssh_key, DIR])
      else
        puts "Could not find #{ssh_key} - skipping."
      end
      
      Dir.chdir(File.dirname(DIR)) do
        run("tar", ["cfpz", TAR, File.basename(DIR)])
      end
    end

    def ssh_tgz(host)
      begin
        banner "scp #{TAR} to #{host}:#{TAR}..."
        run "scp #{TAR} #{host}:#{TAR}"
        
        banner "ssh to #{host} and run..."
        cmd = <<EOF
        cd /tmp && \
        (sudo -n echo gub > /dev/null 2> /dev/null || (echo `whoami` could not sudo. && exit 1)) && \
        sudo -s 'rm -rf #{DIR} && tar xfpz #{TAR} && #{DIR}/gem/teleport/run.sh'
EOF
        run("ssh", [host, cmd])
      rescue RunError
        fatal("Failed!")
      end
      banner "Success!"
    end

    def teleport(host)
      sanity!
      assemble_tgz(host)
      ssh_tgz(host)
    end

    #
    # install
    #

    def install
      Dir.chdir(DATA) do
        sanity!
      end
      Install.new(@config).run
    end
    
    def usage(exit_code)
      puts "Usage: teleport <hostname>"
      puts "  --help      print this help text"
      exit(exit_code)
    end
  end
end

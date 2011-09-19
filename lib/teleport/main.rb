require "optparse"

module Teleport
  # The main class for the teleport command line.
  class Main
    include Constants
    include Util    

    TAR = "#{DIR}.tgz"
    
    def initialize(cmd = :teleport)
      cli(cmd)
      
      case @options[:cmd]
      when :teleport
        $stderr = $stdout
        teleport
      when :install
        $stderr = $stdout
        install
      when :infer
        infer
      end
    end
    
    # Parse ARGV.
    def cli(cmd)
      @options = { }
      @options[:cmd] = cmd

      opt = OptionParser.new do |o|
        o.banner = "Usage: teleport <hostname>"
        o.on("-i", "--infer", "infer a new Telfile from YOUR machine") do |f|
          @options[:cmd] = :infer
        end
        o.on_tail("-h", "--help", "print this help text") do
          puts opt
          exit(0)
        end
      end
      begin
        opt.parse!
      rescue OptionParser::InvalidOption, OptionParser::MissingArgument
        puts $!
        puts opt
        exit(1)
      end

      if @options[:cmd] == :teleport
        # print this error message early, to give the user a hint
        # instead of complaining about command line arguments
        if ARGV.length != 1
          puts opt
          exit(1)
        end
        @options[:host] = ARGV.shift
      end
    end

    # Read Telfile
    def read_config
      if !File.exists?("Telfile")
        fatal("Sadly, I can't find Telfile here. Please create one.")
      end
      @config = Config.new("Telfile")
    end

    # Assemble the the tgz before we teleport to the host
    def assemble_tgz
      banner "Assembling #{TAR}..."
      rm_and_mkdir(DIR)
      
      # gem
      run("cp", ["-r", "#{File.dirname(__FILE__)}/../../lib", GEM])
      # data
      mkdir(DATA)
      copy = []
      copy << "Telfile"
      copy += Dir["files*"]
      copy.sort.each { |i| run("cp", ["-r", i, DATA]) }
      # config.sh
      File.open("#{DIR}/config", "w") do |f|
        f.puts("CONFIG_HOST='#{@options[:host]}'")        
        f.puts("CONFIG_RUBY='#{@config.ruby}'")
        f.puts("CONFIG_RUBYGEMS='#{RUBYGEMS}'")        
      end
      # keys
      ssh_key = "#{ENV["HOME"]}/.ssh/#{PUBKEY}"
      if File.exists?(ssh_key)
        run("cp", [ssh_key, DIR])
      end
      
      Dir.chdir(File.dirname(DIR)) do
        run("tar", ["cfpz", TAR, File.basename(DIR)])
      end
    end

    # Copy the tgz to the host, then run there.
    def ssh_tgz
      begin
        banner "scp #{TAR} to #{@options[:host]}:#{TAR}..."

        args = []
        args += @config.ssh_options if @config.ssh_options        
        args << TAR
        args << "#{@options[:host]}:#{TAR}"
        run("scp", args)

        cmd = [
               "cd /tmp",
               "(sudo -n echo gub > /dev/null 2> /dev/null || (echo `whoami` could not sudo. && exit 1))",
               "sudo rm -rf #{DIR}",
               "sudo tar xfpz #{TAR}",
               "sudo #{DIR}/gem/teleport/run.sh"
              ]
        banner "ssh to #{@options[:host]} and run..."

        args = []
        args += @config.ssh_options if @config.ssh_options
        args << @options[:host]
        args << cmd.join(" && ")
        run("ssh", args)
      rescue RunError
        fatal("Failed!")
      end
      banner "Success!"
    end

    # Teleport to the host.
    def teleport
      read_config
      assemble_tgz
      ssh_tgz
    end

    # We're running on the host - install!
    def install
      Dir.chdir(DATA) do
        read_config
      end
      Install.new(@config)
    end

    # try to infer a new Telfile based on the current machine
    def infer
      Infer.new
    end
  end
end

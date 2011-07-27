module Teleport
  class Config
    RUBIES = ["1.9.2", "REE", "1.8.7"]
    PATH = "Telfile"

    attr_accessor :user, :ruby, :roles, :servers, :apt, :packages, :callbacks, :dsl
    
    def initialize
      @user = Util.whoami
      @ruby = RUBIES.first
      @roles = []
      @servers = []
      @apt = []
      @packages = []
      @callbacks = { }
      
      @dsl = DSL.new(self)
      @dsl.instance_eval(File.read(PATH), PATH)
      sanity!
    end

    def role(n)
      @roles.find { |i| i.name == n.to_sym }
    end

    def server(n)
      @servers.find { |i| i.name == n.to_s }      
    end

    def sanity!
      if !RUBIES.include?(ruby)
        fatal("I don't recognize ruby #{ruby.inspect}.")
      end
    end

    def fatal(s)
      Util.fatal("teleport.rb: #{s}")
    end

    #
    # models
    #

    class Role
      attr_reader :name, :options, :packages
      
      def initialize(name, options)
        raise "role name should be a sym" if !name.is_a?(Symbol)
        raise "role options should be a hash" if !options.is_a?(Hash)
        
        @name, @options, @packages = name, options, []
        if p = @options.delete(:packages)
          raise "role :packages should be an array" if !p.is_a?(Array)
          @packages = p
        end
      end
    end

    class Server
      attr_reader :name, :options, :packages
      
      def initialize(name, options)
        raise "server name should be a string" if !name.is_a?(String)
        raise "server options should be a hash" if !options.is_a?(Hash)
        raise "server :role should be a sym" if !options[:role].is_a?(Symbol)
        
        @name, @options, @packages = name, options, []
        if p = @options.delete(:packages)
          raise "server :packages should be an array" if !p.is_a?(Array)
          @packages = p
        end
      end
    end

    class Apt
      attr_reader :line, :options

      def initialize(line, options)
        raise "apt line should be a string" if !line.is_a?(String)
        raise "apt options should be a hash" if !options.is_a?(Hash)
        @line, @options = line, options
      end
    end

    #
    # DSL
    #

    class DSL
      include Util
      
      def initialize(config)
        @config = config
        run_verbose!
      end
      
      def user(v)
        @config.user = v
      end

      def ruby(v)
        @config.ruby = v
      end
      
      def role(name, options = {})
        raise "options should be a hash" if !options.is_a?(Hash)
        @config.roles << Role.new(name, options)
      end

      def server(name, options = {})
        raise "options should be a hash" if !options.is_a?(Hash)        
        @config.servers << Server.new(name, options)
      end

      def apt(line, options = {})
        @config.apt << Apt.new(line, options)
      end

      def packages(*list)
        @config.packages += list.flatten
      end

      #
      # callbacks
      #

      %w(install user packages files).each do |op|
        %w(before after).each do |before_after|
          callback = "#{before_after}_#{op}".to_sym
          define_method(callback) do |&block|
            @config.callbacks[callback] = block
          end
        end
      end
    end
  end
end

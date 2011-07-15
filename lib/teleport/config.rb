module Teleport
  class Config
    RUBIES = ["1.9.2", "REE", "1.8.7"]
    PATH = "teleport.rb"

    attr_accessor :user, :ruby, :roles, :servers, :apt_keys, :packages
    
    Role = Struct.new(:name, :options)
    Server = Struct.new(:name, :options)
    
    def initialize
      @ruby = RUBIES.first
      @roles = []
      @servers = []
      @apt_keys = []
      @packages = []
      DSL.new(self).instance_eval(File.read(PATH), PATH)
      sanity!
    end

    def sanity!
      if !user
        fatal("Looks like you forgot to call 'user'.")
      end
      if !RUBIES.include?(ruby)
        fatal("I don't recognize ruby #{ruby.inspect}.")
      end
    end

    def fatal(s)
      Util.fatal("teleport.rb: #{s}")
    end
    
    #
    # DSL
    #

    class DSL
      def initialize(config)
        @config = config
      end
      
      def user(v)
        @config.user = v
      end

      def ruby(v)
        @config.ruby = v
      end
      
      def role(name, options = {})
        @config.roles << Role.new(name, options)
      end

      def server(name, options = {})
        @config.servers << Server.new(name, options)
      end

      def apt_key(key)
        @config.apt_keys << key
      end

      def packages(*list)
        @config.packages += list.flatten
      end
    end
  end
end

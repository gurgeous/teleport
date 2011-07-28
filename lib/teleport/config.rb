module Teleport
  # This class parses Telfile, and includes DSL and the models.
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
    end

    def role(n)
      @roles.find { |i| i.name == n.to_sym }
    end

    def server(n)
      @servers.find { |i| i.name == n.to_s }      
    end

    # The model for role in the Telfile.
    class Role
      attr_reader :name, :options, :packages
      
      def initialize(name, options)
        raise "Telfile: role name must be a sym" if !name.is_a?(Symbol)
        raise "Telfile: role options must be a hash" if !options.is_a?(Hash)
        
        @name, @options, @packages = name, options, []
        if p = @options.delete(:packages)
          raise "Telfile: role :packages must be an array" if !p.is_a?(Array)
          @packages = p
        end
      end
    end

    # The model for server in the Telfile.
    class Server
      attr_reader :name, :options, :packages
      
      def initialize(name, options)
        raise "Telfile: server name must be a string" if !name.is_a?(String)
        raise "Telfile: server options must be a hash" if !options.is_a?(Hash)
        raise "Telfile: server :role must be a sym" if !options[:role].is_a?(Symbol)
        
        @name, @options, @packages = name, options, []
        if p = @options.delete(:packages)
          raise "Telfile: server :packages must be an array" if !p.is_a?(Array)
          @packages = p
        end
      end
    end

    # The model for an apt line in the Telfile.
    class Apt
      attr_reader :line, :options

      def initialize(line, options)
        raise "Telfile: apt line must be a string" if !line.is_a?(String)
        raise "Telfile: apt options must be a hash" if !options.is_a?(Hash)
        @line, @options = line, options

        if k = @options[:key]
          raise "Telfile: apt :key must be an String" if !k.is_a?(String)
        end
      end
    end

    # DSL used when parsing Telfile.
    class DSL
      def initialize(config)
        @config = config
      end

      def ruby(v)
        raise "Telfile: ruby must be a string" if !v.is_a?(String)                
        raise "Telfile: don't recognize ruby #{v.inspect}." if !Config::RUBIES.include?(v)
        @config.ruby = v
      end
      
      def user(v)
        raise "Telfile: user must be a string" if !v.is_a?(String)        
        @config.user = v
      end

      def role(name, options = {})
        @config.roles << Role.new(name, options)
      end

      def server(name, options = {})
        @config.servers << Server.new(name, options)
      end

      def apt(line, options = {})
        @config.apt << Apt.new(line, options)
      end

      def packages(*list)
        @config.packages += list.flatten
      end

      %w(install user packages files).each do |op|
        %w(before after).each do |before_after|
          callback = "#{before_after}_#{op}".to_sym
          define_method(callback) do |&block|
            if @config.callbacks[callback]
              raise "Telfile: you already defined the #{callback} callback"
            end
            @config.callbacks[callback] = block
          end
        end
      end
    end
  end
end

module Teleport
  # This class parses Telfile, and includes DSL and the models.
  class Config
    RUBIES = ["1.9.3", "1.9.2", "REE", "1.8.7"]

    attr_accessor :user, :ruby, :ssh_options, :roles, :servers, :apt, :packages, :recipes, :callbacks, :dsl

    def initialize(file = "Telfile")
      @roles = []
      @servers = []
      @apt = []
      @packages = []
      @recipes = []
      @callbacks = { }

      @dsl = DSL.new(self)
      @dsl.instance_eval(File.read(file), file)

      @user ||= Util.whoami
      @ruby ||= RUBIES.first

      sanity_check_gemfiles
    end

    def role(n)
      @roles.find { |i| i.name == n.to_sym }
    end

    def server(n)
      @servers.find { |i| i.name == n.to_s }
    end

    def sanity_check_gemfiles
      files = ["files"] + @roles.map { |i| "files_#{i.name}" }
      files.each do |i|
        gemfile = "#{i}/Gemfile"
        lock = "#{gemfile}.lock"
        if File.exists?(gemfile) && !File.exists?(lock)
          Util.fatal "Hm. I found #{gemfile}, but you forgot to create #{lock}."
        end
      end
    end

    # The model for role in the Telfile.
    class Role
      attr_reader :name, :options, :packages, :recipes

      def initialize(name, options)
        raise "role name must be a sym" if !name.is_a?(Symbol)
        raise "role options must be a hash" if !options.is_a?(Hash)

        @name, @options, @packages, @recipes = name, options, [], []

        # Packages
        if p = @options.delete(:packages)
          raise "role :packages must be an array" if !p.is_a?(Array)
          @packages = p
        end

        # Recipes
        if r = @options.delete(:recipes)
          raise "server :recipes must be an array" if !r.is_a?(Array)
          @recipes = r
        end
      end
    end

    # The model for server in the Telfile.
    class Server
      attr_reader :name, :options, :packages, :recipes

      def initialize(name, options)
        raise "server name must be a string" if !name.is_a?(String)
        raise "server options must be a hash" if !options.is_a?(Hash)
        raise "server :role must be a sym" if options[:role] && !options[:role].is_a?(Symbol)

        @name, @options, @packages, @recipes = name, options, [], []

        # Packages
        if p = @options.delete(:packages)
          raise "server :packages must be an array" if !p.is_a?(Array)
          @packages = p
        end

        # Recipes
        if r = @options.delete(:recipes)
          raise "server :recipes must be an array" if !r.is_a?(Array)
          @recipes = r
        end
      end
    end

    # The model for an apt line in the Telfile.
    class Apt
      attr_reader :line, :options

      def initialize(line, options)
        raise "apt line must be a string" if !line.is_a?(String)
        raise "apt options must be a hash" if !options.is_a?(Hash)
        @line, @options = line, options

        if k = @options[:key]
          raise "apt :key must be an String" if !k.is_a?(String)
        end
      end
    end

    # DSL used when parsing Telfile.
    class DSL
      def initialize(config)
        @config = config
      end

      def ruby(v)
        raise "ruby called twice" if @config.ruby
        raise "ruby must be a string" if !v.is_a?(String)
        raise "don't recognize ruby #{v.inspect}." if !Config::RUBIES.include?(v)
        @config.ruby = v
      end

      def user(v)
        raise "user called twice" if @config.user
        raise "user must be a string" if !v.is_a?(String)
        @config.user = v
      end

      def ssh_options(v)
        raise "ssh_options called twice" if @config.ssh_options
        raise "ssh_options must be an Array" if !v.is_a?(Array)
        @config.ssh_options = v
      end

      def role(name, options = {})
        raise "role #{name.inspect} defined twice" if @config.roles.any? { |i| i.name == name }
        @config.roles << Role.new(name, options)
      end

      def server(name, options = {})
        raise "server #{name.inspect} defined twice" if @config.servers.any? { |i| i.name == name }
        @config.servers << Server.new(name, options)
      end

      def apt(line, options = {})
        @config.apt << Apt.new(line, options)
      end

      def packages(*list)
        @config.packages += list.flatten
      end

      def recipes(*list)
        @config.recipes += list.flatten
      end

      %w(install user packages gemfiles files).each do |op|
        %w(before after).each do |before_after|
          callback = "#{before_after}_#{op}".to_sym
          define_method(callback) do |&block|
            if @config.callbacks[callback]
              raise "you already defined the #{callback} callback"
            end
            @config.callbacks[callback] = block
          end
        end
      end
    end
  end
end

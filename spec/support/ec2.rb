# spin up a fresh ec2 instance
module Support
  module Ec2
    AMI_10_04 = "fbbf7892"
    AMI_10_10 = "08f40561"
    AMI_11_04 = "68ad5201"
    KEYPAIR = "teleport"
    GROUP = "teleport"

    AMI = AMI_10_04

    DESCRIBE_COLS = %w(type id ami nil nil status key nil nil size started zone nil nil nil nil ip ip_priv).map { |i| i.to_sym if i != "nil" }

    def self.configured?
      ENV["TELEPORT_EC2"]
    end

    def self.message
      <<EOF
------------------------------------------------------------------------
If you want to test against EC2, do the following:

1. Create an ec2_teleport directory somewhere
2. Copy your private key and cert to <ec2_teleport>/pk.pem and
   <ec2_teleport>/cert.pem.
3. Setup a "teleport" keypair on EC2.
4. Set the TELEPORT_EC2 environment variable to point to your
   <ec2_teleport> directory.

End-to-end tests that rely on EC2 will be skipped in the meantime.
------------------------------------------------------------------------
EOF
    end

    #
    # specs call this
    #

    def ec2
      before do
        ENV["TELEPORT_IP"] = @ec2 = Instance::start
      end
      after do
        Instance::stop
      end
    end

    #
    # this class does all the work
    # 

    module Instance
      extend self
      
      def start
        raise "not configured" if !Support::Ec2::configured?

        ENV["EC2_PRIVATE_KEY"] = "#{ENV["TELEPORT_EC2"]}/pk.pem"
        ENV["EC2_CERT"]        = "#{ENV["TELEPORT_EC2"]}/cert.pem"
        
        # stop existing instances
        stop

        puts "Running new ec2 instance..."
        
        # setup security group
        run_allow_failure "ec2-add-group #{GROUP} -d teleport"
        run_allow_failure "ec2-authorize #{GROUP} -p 22"

        # create the instance
        run "ec2-run-instances ami-#{AMI} --instance-type m1.large --group #{GROUP} --key #{KEYPAIR}"

        # wait for the new instance to start
        puts "Waiting for ec2 instance to start..."
        while true
          sleep 3
          instance = describe_instances.first
          puts "  #{instance[:id]}: #{instance[:status]}"
          break if instance[:status] == "running"
        end

        # return the ip address
        instance[:ip]
      end

      def stop
        puts "Terminating existing ec2 instances..."      
        instances = describe_instances
        terminate = instances.map { |i| i[:id] }
        if !terminate.empty?
          puts "  #{terminate.join(" ")}"
          run "ec2-terminate-instances #{terminate.join(" ")}"
        end
      end

      protected

      #
      # ec2 commands
      #
      
      def describe_instances
        lines = run("ec2-describe-instances").split("\n")
        lines = lines.map do |line|
          map = { }
          line = line.split("\t")
          DESCRIBE_COLS.each_with_index do |key, index|
            map[key] = line[index] if key
          end
          map
        end

        # cull stuff we don't care about
        lines = lines.select { |i| i[:type] == "INSTANCE" }
        lines = lines.select { |i| i[:key] == KEYPAIR }
        lines = lines.select { |i| i[:status] !~ /terminated|shutting-down/ }
        lines
      end

      def run(command)
        result = `#{command}`
        if $? != 0
          if $?.termsig == Signal.list["INT"]
            raise "#{command} interrupted"
          end
          raise "#{command} failed : #{$?.to_i / 256}"
        end
        result
      end

      def run_allow_failure(command)
        `#{command} > /dev/null 2> /dev/null`      
      end
    end
  end
end

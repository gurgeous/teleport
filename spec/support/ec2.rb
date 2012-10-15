require "AWS"

# spin up a fresh ec2 instance
module Support
  module Ec2
    # these are all us-east-1 64-bit instance
    AMI_10_04 = "8fac75e6" # lucid
    AMI_10_10 = "098f5760" # maverick
    AMI_11_04 = "35c31a5c" # natty
    AMI_11_10 = "8baa73e2" # oneiric
    AMI_12_04 = "3c994355" # precise
    KEYPAIR = "teleport"
    GROUP = "teleport"

    AMI = "ami-#{AMI_12_04}"

    def self.configured?
      ENV["TELEPORT_ACCESS_KEY_ID"] && ENV["TELEPORT_SECRET_ACCESS_KEY"] && ENV["TELEPORT_SSH_KEY"]
    end

    def self.message
      <<EOF
------------------------------------------------------------------------
If you want to test against EC2, do the following:

1. Create a "teleport" keypair on EC2.
2. Set the TELEPORT_ACCESS_KEY_ID, TELEPORT_SECRET_ACCESS_KEY and
   TELEPORT_SSH_KEY environment variables.

End-to-end tests that rely on EC2 will be skipped in the meantime.
------------------------------------------------------------------------
EOF
    end

    #
    # specs call this
    #

    def ec2
      controller = nil
      before(:all) do
        if ENV["TELEPORT_IP"]
          $ec2_ip_address = ENV["TELEPORT_IP"]
        else
          controller = Controller.new
          controller.stop
          $ec2_ip_address = controller.start
        end
      end
      after(:all) do
        controller.stop if controller
      end
    end

    #
    # this controller class does all the work
    #

    class Controller
      def initialize
        raise "not configured" if !Support::Ec2::configured?
        @ec2 = AWS::EC2::Base.new(:access_key_id => ENV["TELEPORT_ACCESS_KEY_ID"], :secret_access_key => ENV["TELEPORT_SECRET_ACCESS_KEY"])
      end

      def start
        puts "Running new ec2 instance..."
        # setup security group and allow ssh
        begin
          @ec2.create_security_group(:group_name => GROUP, :group_description => GROUP)
        rescue AWS::InvalidGroupDuplicate
          # ignore
        end
        @ec2.authorize_security_group_ingress(:group_name => GROUP, :ip_protocol => "tcp", :from_port => 22, :to_port => 22)

        # create the instance
        @ec2.run_instances(:image_id => AMI, :instance_type => "m1.large", :key_name => KEYPAIR, :security_group => GROUP)

        # wait for the new instance to start
        puts "Waiting for ec2 instance to start..."
        while true
          sleep 3
          if instance = describe_instances.first
            status = instance["instanceState"]["name"]
            puts "  #{instance["instanceId"]}: #{status}"
            break if status == "running"
          end
        end

        # return the ip address
        ip = instance["ipAddress"]
        puts "  #{instance["instanceId"]}: #{ip}"
        puts "  sleeping to give ssh a chance to start..."
        sleep 10
        ip
      end

      def stop
        puts "Terminating existing ec2 instances..."
        ids = describe_instances.map { |i| i["instanceId"] }
        if !ids.empty?
          puts "  terminate: #{ids.join(" ")}"
          @ec2.terminate_instances(:instance_id => ids)
        end
      end

      def describe_instances
        list = []
        hash = @ec2.describe_instances
        if hash = hash["reservationSet"]
          list = hash["item"].map { |i| i["instancesSet"]["item"] }.flatten
        end
        # cull stuff we don't care about
        list = list.select { |i| i["keyName"] == KEYPAIR }
        list = list.select { |i| i["instanceState"]["name"] !~ /terminated|shutting-down/ }
        list
      end
    end
  end
end

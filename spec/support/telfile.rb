# run inside a specific dir
module Support
  module Telfile
    TMP = "/tmp/teleport_spec"
    
    def telfile(telfile_contents)
      before(:all) do
        puts "TELFILE: #{self}"
        puts @ip_address.inspect
        @pwd = Dir.pwd
        `rm -rf #{TMP} && mkdir -p #{TMP}`
        Dir.chdir(TMP)
        File.open("Telfile", "w") do |f|
          f.puts(telfile_contents)
          puts "WROTE #{telfile_contents}"
        end
      end
      
      after(:all) do
        Dir.chdir(@pwd)
      end
    end
  end
end

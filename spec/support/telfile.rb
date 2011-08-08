# run inside a specific dir
module Support
  module Telfile
    TMP = "/tmp/teleport_spec"

    def telfile(contents = nil, &block)
      pwd = nil
      before(:all) do
        pwd = Dir.pwd
        `rm -rf #{TMP} && mkdir -p #{TMP}`
        Dir.chdir(TMP)
        File.open("Telfile", "w") do |f|
          if block
            contents = block.call
          end
          f.puts(contents)
        end
      end
      
      after(:all) do
        Dir.chdir(pwd)
      end
    end
  end
end

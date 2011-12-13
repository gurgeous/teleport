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

    def role(role, files)
      before(:all) do
        path = (role == nil) ? "files" : "files_#{role}"
        `mkdir -p #{path}`
        Dir.chdir(path) do
          files.each_pair do |key, value|
            File.open(key, "w") { |f| f.write(value) }
          end
        end
      end
    end

    def recipe(name, content)
      before(:all) do
        path = "recipes"
        `mkdir -p #{path}`
        Dir.chdir(path) do
          File.open(name, "w") { |f| f.write(content) }
          if name !~ /\.rb/
            File.chmod 0755, name
          end
        end
      end
    end
  end
end

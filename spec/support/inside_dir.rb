# run inside a specific dir
module Support
  module InsideDir
    def inside_dir(dir)
      before do
        @pwd = Dir.pwd
        Dir.chdir(dir)
      end
      after do
        Dir.chdir(@pwd)
      end
    end
  end
end

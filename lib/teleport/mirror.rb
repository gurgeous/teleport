require "erb"

module Teleport
  # Helper module for recursively mirroring files from a src to a dst.
  module Mirror
    include Constants

    # Don't install these files.
    IGNORE = [
              ".",
              "..",
              "Gemfile",
              "Gemfile.lock",              
              /^.#/,
             ]

    # Install file from the teleport data directory into the normal
    # filesystem. Path can use a few different formats:
    #
    # * #{DATA}/xyz - Full path into the data directory
    # * files/xyz - Path into the #{DATA}/files directory
    # * files_role/xyz - Path into a role directory    
    # * xyz - Assumed to be #{DATA}/files/xyz
    #
    # Note that the path can be an erb file. For example,
    # "etc/hosts.erb" will be installed as "etc/hosts".
    #
    # Returns true if the file was installed, false if the file had
    # previously been installed and no change was required.
    def install_file(path)
      path, dst = path_to_src(path), path_to_dst(path)

      # run erb if necessary
      if path =~ /#{DATA}\/(.*)\.erb$/
        tmp = "#{DATA}/#{$1.gsub('/', '_')}"
        dst = dst.gsub(/\.erb$/, "")
        File.open(tmp, "w") do |f|
          f.write ERB.new(File.read(path)).result(binding)
        end
        copy_metadata(path, tmp)
        path = tmp
      end

      if !File.symlink?(path)
        cp_if_necessary(path, dst, user_for_file(dst), mode_for_file(dst))
      else
        ln_if_necessary(File.readlink(path), dst)
      end
    end

    # Install directory from the teleport data directory into the
    # normal filesystem. Path can use a few different formats:
    #
    # * #{DATA}/xyz - Full path into the data directory
    # * files/xyz - Path into the #{DATA}/files directory
    # * files_role/xyz - Path into a role directory    
    # * xyz - Assumed to be #{DATA}/files/xyz
    #
    # Returns true if the dir was installed, false if the dir had
    # previously been installed and no change was required.
    def install_dir(path)
      dirty = false

      path, dst = path_to_src(path), path_to_dst(path)
      mkdir_if_necessary(dst, user_for_file(dst)) if !dst.empty?      
      
      files = Dir.new(path).to_a.sort
      files.delete_if { |file| IGNORE.any? { |i| i === file } }
      files.each do |i|
        i = "#{path}/#{i}"
        if File.directory?(i)
          dirty = install_dir(i) || dirty
        else
          dirty = install_file(i) || dirty
        end
      end
      
      dirty
    end

    protected
    
    def normalize_path(path)
      case path
      when /^#{DATA}/
        # already absolute - do nothing
      when /^files/
        path = "#{DATA}/#{path}"
      else
        path = "#{DATA}/files/#{path}"
      end
      path
    end
    
    def path_to_src(path)
      normalize_path(path)
    end

    def path_to_dst(path)
      path = normalize_path(path)
      path = path[%r{#{DATA}/files[^/]*(.*)}, 1]
      path
    end

    def user_for_file(f)
      f[%r{^/home/([^/]+)}, 1] || "root"      
    end

    def mode_for_file(f)
      case f
      when %r{sudoers} then 0440
      when %r{/\.ssh/} then 0400
      end
    end
  end
end

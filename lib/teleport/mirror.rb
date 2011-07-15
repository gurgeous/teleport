require "erb"

module Teleport
  module Mirror
    include Constants

    def _normalize_path(path)
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
    
    def _path_to_src(path)
      _normalize_path(path)
    end

    def _path_to_dst(path)
      path = _normalize_path(path)
      if path =~ %r{#{DATA}/files[^/]*(.*)}
        path = $1
      end
      path
    end

    def _user_for_file(f)
      f[%r{^/home/([^/]+)}, 1] || "root"      
    end

    def _mode_for_file(f)
      case f
      when %r{sudoers} then 0440
      when %r{/\.ssh/} then 0400
      end
    end
    
    def install_file(path)
      path, dst = _path_to_src(path), _path_to_dst(path)

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
      
      cp_if_necessary(path, dst, _user_for_file(dst), _mode_for_file(dst))
    end

    def install_dir(path)
      dirty = false

      path, dst = _path_to_src(path), _path_to_dst(path)
      mkdir_if_necessary(dst, _user_for_file(dst)) if !dst.empty?      
      
      files = Dir.new(path).to_a.sort
      files.delete_if { |i| i == "." || i == ".." || i =~ /^.#/ }
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
  end
end

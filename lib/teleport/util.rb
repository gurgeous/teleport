require "cgi"
require "etc"
require "fileutils"

module Teleport
  module Util
    class RunError < StandardError ; end

    extend self
    
    RESET   = "\e[0m"
    RED     = "\e[1;37;41m"
    GREEN   = "\e[1;37;42m"
    YELLOW  = "\e[1;37;43m"
    BLUE    = "\e[1;37;44m"
    MAGENTA = "\e[1;37;45m"
    CYAN    = "\e[1;37;46m"

    #
    # running commands
    #

    def run_verbose!
      @run_verbose = true
    end

    def verbose?
      @run_verbose ||= nil
    end
    
    def run(command, args = nil)
      line = nil
      if args
        args = args.map(&:to_s)
        line = "#{command} #{args.join(" ")}"
        vputs line
        system(command, *args)
      else
        line = command
        vputs line
        system(command)
      end
      if $? != 0
        if $?.termsig == Signal.list["INT"]
          raise "#{line} interrupted"
        end
        raise RunError, "#{line} failed : #{$?.to_i / 256}"
      end
    end

    def run_capture(command, *args)
      if !args.empty?
        args = args.flatten.map { |i| shell_escape(i) }.join(" ")
        command = "#{command} #{args}"
      end
      result = `#{command}`
      if $? != 0
        if $?.termsig == Signal.list["INT"]
          raise "#{command} interrupted"
        end
        raise RunError, "#{command} failed : #{$?.to_i / 256} #{result.inspect}"
      end
      result
    end

    def run_quietly(command, *args)
      if !args.empty?
        args = args.flatten.map { |i| shell_escape(i) }.join(" ")
        command = "#{command} #{args}"
      end
      run("#{command} > /dev/null 2> /dev/null")
    end

    def succeeds?(command)
      system("#{command} > /dev/null 2> /dev/null")
      $? == 0
    end

    def fails?(command)
      !succeeds?(command)
    end

    def shell_escape(s)
      s = s.to_s
      if s !~ /^[0-9A-Za-z+,.\/:=@_-]+$/
        s = s.gsub("'") { "'\\''" }
        s = "'#{s}'"
      end
      s
    end

    #
    # file ops
    #
    
    def mkdir(dir, owner = nil, mode = nil)
      FileUtils.mkdir_p(dir, :verbose => verbose?)
      chmod(dir, mode) if mode
      chown(dir, owner) if owner
    end

    def mkdir_if_necessary(dir, owner = nil, mode = nil)
      mkdir(dir, owner, mode) if !(File.exists?(dir) || File.symlink?(dir))
    end

    def rm_and_mkdir(dir)
      raise "don't do this" if dir == ""
      run "rm -rf #{dir} && mkdir -p #{dir}"
    end

    def copy_metadata(src, dst)
      stat = File.stat(src)
      File.chmod(stat.mode, dst)
      File.utime(stat.atime, stat.mtime, dst)
    end

    def cp(src, dst, owner = nil, mode = nil)
      FileUtils.cp_r(src, dst, :preserve => true, :verbose => verbose?)
      if owner && !File.symlink?(dst)      
        chown(dst, owner) 
      end
      if mode
        chmod(dst, mode)
      end
    end

    def cp_with_mkdir(src, dst, owner = nil, mode = nil)
      mkdir_if_necessary(File.dirname(dst))
      cp(src, dst, owner, mode)
    end

    def cp_if_necessary(src, dst, owner = nil, mode = nil)
      if !(File.exists?(dst) && FileUtils.compare_file(src, dst))
        cp(src, dst, owner, mode)
        true
      end
    end

    def mv(src, dst)
      FileUtils.mv(src, dst, :verbose => verbose?)
    end

    def mv_with_mkdir(src, dst)
      mkdir_if_necessary(File.dirname(dst))
      mv(src, dst)
    end
    
    def chown(file, user)
      user = user.to_s
      # who is the current owner?
      @uids ||= {}
      @uids[user] ||= Etc.getpwnam(user).uid
      uid = @uids[user]
      if File.stat(file).uid != uid
        FileUtils.chown(uid, uid, file, :verbose => verbose?)
      end
    end

    def chmod(file, mode)
      if File.stat(file).mode != mode
        FileUtils.chmod(mode, file, :verbose => verbose?)      
      end
    end
    
    def rm(file)
      FileUtils.rm(file, :force => true, :verbose => verbose?)
    end
    
    def rm_if_necessary(file)
      if File.exists?(file)
        rm(file)
        true
      end
    end

    def ln(src, dst)
      FileUtils.ln_sf(src, dst, :verbose => verbose?)
    end
    
    def ln_if_necessary(src, dst)
      ln = false
      if !File.symlink?(dst)
        ln = true
      elsif File.readlink(dst) != src
        rm(dst)
        ln = true
      end
      if ln
        ln(src, dst)
        true
      end
    end

    def rm_old_files(dir, days_to_keep)
      run "find #{dir} -type f -mtime +#{days_to_keep} | xargs --no-run-if-empty rm"
    end

    #
    # processes
    #
    
    def process_by_pid?(pidfile)
      begin
        if File.exists?(pidfile)
          pid = File.read(pidfile).to_i
          if pid != 0
            Process.kill(0, pid)
            return true
          end
        end
      rescue Errno::ENOENT, Errno::ESRCH
      end
      false
    end

    #
    # script helpers
    #

    def banner(s, color = GREEN)
      s = "#{s} ".ljust(60, " ")      
      $stderr.write "#{color}[#{Time.new.strftime('%H:%M:%S')}] #{s}#{RESET}\n"
      $stderr.flush
    end

    def warning(msg)
      banner("Warning: #{msg}", YELLOW)
    end

    def fatal(msg)
      banner(msg, RED)
      exit(1)
    end

    def whoami
      # who is the current owner?
      @whoami ||= Etc.getpwuid(Process.uid).name
    end

    def package_is_installed?(pkg)
      succeeds?("dpkg-query -f='${Status}' -W #{pkg} | grep 'install ok installed'")    
    end

    def package_if_necessary(pkg)
      if !package_is_installed?(pkg)
        banner "#{pkg}..."
        run "apt-get -y install #{pkg}"
      end
    end

    def gem_if_necessary(gem)
      grep = args = nil
      if gem =~ /(.*)-(\d+\.\d+\.\d+)$/
        gem, version = $1, $2
        grep = "^#{gem}.*#{version}"
        args = " --version #{version}"
      else
        grep = "^#{gem}"
      end
      if fails?("gem list #{gem} | grep '#{grep}'")
        banner "#{gem}..."
        run "gem install #{gem} #{args} --no-rdoc --no-ri"
        return true
      end
      false
    end

    private

    def vputs(s)
      $stderr.puts s if verbose?
    end
  end
end

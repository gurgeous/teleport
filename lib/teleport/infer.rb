require "set"

# Many, many thanks to Blueprint!
# https://github.com/devstructure/blueprint

module Teleport
  class Infer
    include Util
    
    MD5SUMS = {
      '/etc/adduser.conf' => ['/usr/share/adduser/adduser.conf'],
      '/etc/apparmor.d/tunables/home.d/ubuntu' =>
      ['2a88811f7b763daa96c20b20269294a4'],
      '/etc/apt/apt.conf.d/00CDMountPoint' =>
      ['cb46a4e03f8c592ee9f56c948c14ea4e'],
      '/etc/apt/apt.conf.d/00trustcdrom' =>
      ['a8df82e6e6774f817b500ee10202a968'],
      '/etc/chatscripts/provider' => ['/usr/share/ppp/provider.chatscript'],
      '/etc/default/console-setup' =>
      ['0fb6cec686d0410993bdf17192bee7d6',
       'b684fd43b74ac60c6bdafafda8236ed3',
       '/usr/share/console-setup/console-setup'],
      '/etc/default/grub' => ['ee9df6805efb2a7d1ba3f8016754a119',
                              'ad9283019e54cedfc1f58bcc5e615dce'],
      '/etc/default/irqbalance' => ['7e10d364b9f72b11d7bf7bd1cfaeb0ff'],
      '/etc/default/keyboard' => ['06d66484edaa2fbf89aa0c1ec4989857'],
      '/etc/default/locale' => ['164aba1ef1298affaa58761647f2ceba',
                                '7c32189e775ac93487aa4a01dffbbf76'],
      '/etc/default/rcS' => ['/usr/share/initscripts/default.rcS'],
      '/etc/environment' => ['44ad415fac749e0c39d6302a751db3f2'],
      '/etc/hosts.allow' => ['8c44735847c4f69fb9e1f0d7a32e94c1'],
      '/etc/hosts.deny' => ['92a0a19db9dc99488f00ac9e7b28eb3d'],
      '/etc/initramfs-tools/modules' =>
      ['/usr/share/initramfs-tools/modules'],
      '/etc/inputrc' => ['/usr/share/readline/inputrc'],
      '/etc/iscsi/iscsid.conf' => ['6c6fd718faae84a4ab1b276e78fea471'],
      '/etc/kernel-img.conf' => ['f1ed9c3e91816337aa7351bdf558a442'],
      '/etc/ld.so.conf' => ['4317c6de8564b68d628c21efa96b37e4'],
      '/etc/networks' => ['/usr/share/base-files/networks'],
      '/etc/nsswitch.conf' => ['/usr/share/base-files/nsswitch.conf'],
      '/etc/pam.d/common-account' => ['9d50c7dda6ba8b6a8422fd4453722324'],
      '/etc/pam.d/common-auth' => ['a326c972f4f3d20e5f9e1b06eef4d620'],
      '/etc/pam.d/common-password' => ['9f2fbf01b1a36a017b16ea62c7ff4c22'],
      '/etc/pam.d/common-session' => ['e2b72dd3efb2d6b29698f944d8723ab1'],
      '/etc/pam.d/common-session-noninteractive' =>
      ['508d44b6daafbc3d6bd587e357a6ff5b'],
      '/etc/ppp/chap-secrets' => ['faac59e116399eadbb37644de6494cc4'],
      '/etc/ppp/pap-secrets' => ['698c4d412deedc43dde8641f84e8b2fd'],
      '/etc/ppp/peers/provider' => ['/usr/share/ppp/provider.peer'],
      '/etc/profile' => ['/usr/share/base-files/profile'],
      '/etc/python/debian_config' => ['7f4739eb8858d231601a5ed144099ac8'],
      '/etc/rc.local' => ['10fd9f051accb6fd1f753f2d48371890'],
      '/etc/rsyslog.d/50-default.conf' =>
      ['/usr/share/rsyslog/50-default.conf'],
      '/etc/security/opasswd' => ['d41d8cd98f00b204e9800998ecf8427e'],
      '/etc/sgml/xml-core.cat' => ['bcd454c9bf55a3816a134f9766f5928f'],
      '/etc/shells' => ['0e85c87e09d716ecb03624ccff511760'],
      '/etc/ssh/sshd_config' => ['e24f749808133a27d94fda84a89bb27b',
                                 '8caefdd9e251b7cc1baa37874149a870'],
      '/etc/sudoers' => ['02f74ccbec48997f402a063a172abb48'],
      '/etc/ufw/after.rules' => ['/usr/share/ufw/after.rules'],
      '/etc/ufw/after6.rules' => ['/usr/share/ufw/after6.rules'],
      '/etc/ufw/before.rules' => ['/usr/share/ufw/before.rules'],
      '/etc/ufw/before6.rules' => ['/usr/share/ufw/before6.rules'],
      '/etc/ufw/ufw.conf' => ['/usr/share/ufw/ufw.conf']
    }

    NEW_FILES_WITHIN = %w(cron.d logrotate.d rsyslog.d init)
    CHECKSUM_FILES = %w(bash.bashrc environment inputrc rc.local ssh/ssh_config ssh/sshd_config)
    
    def initialize
      @telfile = []

      if fails?("uname -a | grep -q Ubuntu")
        fatal "Sorry, --infer can only run on an Ubuntu machine."
      end
      
      append "#" * 72
      append "# Telfile inferred from #{`hostname`.strip} at #{Time.now}"
      append "#" * 72
      append
      
      user
      ruby
      apt
      packages
      files

      banner "Done!"
      $stderr.puts
      @telfile.each { |i| puts i }
    end

    def append(s = nil)
      @telfile << (s || "")
    end

    def user
      append "user #{`whoami`.strip.inspect}"
    end

    def ruby
      version = `ruby --version`
      ruby = nil
      case version
      when /Ruby Enterprise Edition/ then ruby = "REE"
      when /1\.8\.7/ then ruby = "1.8.7"
      when /1\.9\.2/ then ruby = "1.9.2"
      end
      append "ruby #{ruby.inspect}" if ruby
    end

    def apt
      banner "Calculating apt sources and keys..."
      list = run_capture_lines("cat /etc/apt/sources.list /etc/apt/sources.list.d/*.list")
      list = list.grep(/^deb /).sort
      list.each do |line|
        if line =~ /^deb http:\/\/(\S+)\s+(\S+)/
          source, dist = $1, $2
          file = source.chomp("/").gsub(/[^a-z0-9.-]/, "_")
          file = "/var/lib/apt/lists/#{file}_dists_#{dist}_Release"
          next if !File.exists?(file)

          verify = run_capture("gpgv --keyring /etc/apt/trusted.gpg #{file}.gpg #{file} 2>&1")
          key = verify[/key ID ([A-Z0-9]{8})$/, 1]
          next if key == "437D05B5" # canonical key
          append "apt #{line.inspect}, :key => #{key.inspect}"
        end
      end
    end

    def packages
      banner "Looking for interesting packages..."      
      @packages = Apt.new.added
      if !@packages.empty?
        append
        append "# Note: You should read this package list very carefully and remove"
        append "# packages that you don't want on your server."
        append
        append "packages %w(#{@packages.join(" ")})"
      end
    end

    def files
      banner "Looking for interesting files..."            
      files = []

      # read checksums from dpkg status
      conf = { }
      File.readlines("/var/lib/dpkg/status").each do |line|
        if line =~ /^ (\S+) ([0-9a-f]{32})/
          conf[$1] = $2
        end
      end

      # look for changed conf files
      $stderr.puts "  scanning conf files from interesting packages..."
      @packages.each do |pkg|
        list = run_capture_lines("dpkg -L #{pkg}")
        list = list.select { |i| i =~ /^\/etc/ }.sort
        list = list.select { |i| File.file?(i) }
        list = list.select { |i| conf[i] && conf[i] != md5sum(i) }
        files += list
      end

      # look for new files in NEW_FILES_WITHIN
      dirs = NEW_FILES_WITHIN.map { |i| "/etc/#{i}" }
      dirs.sort.each do |dir|
        $stderr.puts "  scanning #{dir} for new files..."
        list = Dir["#{dir}/*"].sort
        list = list.select { |i| !MD5SUMS[i] }
        list = list.select { |i| fails?("dpkg -S #{i}") }
        files += list
      end
      
      # now look for changed files from CHECKSUM_FILES
      scan = CHECKSUM_FILES.map { |i| "/etc/#{i}" }
      scan = scan.select { |i| File.file?(i) }
      scan.each do |i|
        new_sum = md5sum(i)
        if old_sum = MD5SUMS[i]
          match = old_sum.any? do |sum|
            sum = md5sum(sum) if sum =~ /^\//
            new_sum == sum
          end
          files << i if !match
        elsif old_sum = conf[i]
          files << i if new_sum != old_sum
        end
      end

      if !files.empty?
        append
        append "#" * 72
        append "# Also, I think these should be included in files/"
        append "#" * 72
        append
        files.sort.each do |i|
          append "# #{i}"
        end
        append
        append "# You can do that with this magical command:"
        append "#"
        append "# mkdir files && cd files && tar cf - #{files.join(" ")} | tar xf -"
      end
    end

    class Apt
      include Util

      BLACKLIST = /^linux-(generic|headers|image)/
      
      Package = Struct.new(:name, :status, :deps, :base, :parents)

      def initialize
        @packages = nil
        @map = nil
      end

      def packages
        if !@packages
          # run dpkg
          lines = run_capture_lines("dpkg-query '-f=${Package}\t${Status}\t${Pre-Depends},${Depends},${Recommends}\t${Essential}\t${Priority}\n' -W")
          @packages = lines.map do |line|
            name, status, deps, essential, priority = line.split("\t")
            deps = deps.gsub(/\([^)]+\)/, "")
            deps = deps.split(/[,|]/)
            deps = deps.map(&:strip).select { |i| !i.empty? }.sort
            base = false
            base = true if essential == "yes"
            base = true if priority =~ /^(important|required|standard)$/
            Package.new(name, status, deps, base, [])
          end

          # calculate ancestors
          @packages.each do |pkg|
            pkg.deps.each do |i|
              if d = self[i]
                d.parents << pkg.name
              end
            end
          end
          @packages.each do |pkg|
            pkg.parents = pkg.parents.sort.uniq
          end
        end
        
        @packages
      end

      def [](name)
        if !@map
          @map = { }
          packages.each { |i| @map[i.name] = i }
        end
        @map[name]
      end

      def base_packages
        packages.select { |i| i.base }.map(&:name)    
      end

      def ignored_packages
        list = packages.select { |i| i.base }.map(&:name)
        list += %w(grub-pc installation-report language-pack-en language-pack-gnome-en linux-generic-pae linux-server os-prober ubuntu-desktop ubuntu-minimal ubuntu-standard wireless-crda)
        dependencies(list)
      end

      def dependencies(list)
        check = list
        while !check.empty?
          check = check.map do |i|
            if pkg = self[i]
              pkg.deps
            end
          end
          check = check.compact.flatten.uniq.sort
          check -= list
          list += check
        end
        list.sort
      end

      def added
        # calculate raw list
        ignored = Set.new(ignored_packages)
        list = packages.select do |i|
          i.status == "install ok installed" && !ignored.include?(i.name)
        end
        list = list.map(&:name)

        # now calculate parents
        roots = []
        check = list
        while !check.empty?
          check = check.map do |i|
            if pkg = self[i]
              if !pkg.parents.empty?
                pkg.parents
              else
                roots << pkg.name
                nil
              end
            end
          end
          check = check.compact.flatten.uniq.sort
          check -= list
          list += check
        end

        # blacklist
        roots = roots.reject { |i| i =~ BLACKLIST }
        
        roots.sort
      end
    end
  end
end

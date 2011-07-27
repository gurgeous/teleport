#!/bin/bash

#
# This script runs on the target machine. First it installs ruby if
# necessary, then it runs teleport.
#

# bail on errors
set -eu



#
# constants
#

if [ $(uname -m) == "x86_64" ]; then
  PLATFORM=amd64
else
  PLATFORM=i386
fi



#
# functions
#

function banner() {
  printf '\e[1;37;43m[%s] %-60s\e[0m\n' `date '+%H:%M:%S'` "run.sh: $1"
}

function install_ruby() {
  banner "apt-get update / upgrade..."
  sudo apt-get update
  sudo apt-get -y upgrade
  sudo apt-get install -y wget libreadline5
  
  banner "installing Ruby $CONFIG_RUBY..."
  case $CONFIG_RUBY in
    1.8.7 ) install_ruby_187 ;;
    1.9.2 ) install_ruby_192 ;;
    REE )   install_ruby_ree ;;
	* )     echo "error: unknown ruby ($CONFIG_RUBY)"; exit 99 ;;
  esac
}

function install_ruby_187() {
  sudo apt-get -y install irb libopenssl-ruby libreadline-ruby rdoc ri ruby ruby-dev
  
  wget http://production.cf.rubygems.org/rubygems/rubygems-$CONFIG_RUBYGEMS.tgz
  tar xfpz rubygems-$CONFIG_RUBYGEMS.tgz
  (cd rubygems-$CONFIG_RUBYGEMS ; ruby setup.rb)
  ln -s /usr/bin/gem1.8 /usr/bin/gem
}

function install_ruby_192() {
  local patch=p180
  
  # see http://threebrothers.org/brendan/blog/ruby-1-9-2-on-ubuntu-11-04/
  sudo apt-get install -y bison build-essential checkinstall libffi5 libssl-dev libyaml-dev zlib1g-dev

  wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-$patch.tar.gz
  tar xvzf ruby-1.9.2-$patch.tar.gz
  
  cd ruby-1.9.2-$patch
  ./configure --prefix=/usr/local \
              --program-suffix=1.9.2 \
              --with-ruby-version=1.9.2 \
              --disable-install-doc
  make
  sudo checkinstall -D -y \
                    --fstrans=no \
                    --nodoc \
                    --pkgname="ruby1.9.2" \
                    --pkgversion="1.9.2-$patch" \
                    --provides="ruby"
  cd ..

  sudo update-alternatives --install /usr/local/bin/ruby ruby /usr/local/bin/ruby1.9.2 500 \
                           --slave   /usr/local/bin/ri   ri   /usr/local/bin/ri1.9.2 \
                           --slave   /usr/local/bin/irb  irb  /usr/local/bin/irb1.9.2 \
                           --slave   /usr/local/bin/gem  gem  /usr/local/bin/gem1.9.2 \
                           --slave   /usr/local/bin/erb  erb  /usr/local/bin/erb1.9.2 \
                           --slave   /usr/local/bin/rdoc rdoc /usr/local/bin/rdoc1.9.2
}

function install_ruby_ree() {
  local ree="ruby-enterprise_1.8.7-2011.03_${PLATFORM}_ubuntu10.04.deb"
  wget http://rubyenterpriseedition.googlecode.com/files/$ree
  sudo dpkg -i $ree
}


#
# main
#

cd /tmp/_teleported
source ./config

# do we need to install ruby?
if ! which ruby > /dev/null ; then
  install_ruby
fi

# run teleport!
ruby -I gem -r teleport -e "Teleport::Main.new(:install)"

#!/bin/bash

# bail on errors
set -eu

#
# functions
#

function banner() {
  printf '\e[1;37;43m[%s] %-60s\e[0m\n' `date '+%H:%M:%S'` "run.sh: $1"
}

function install_ruby() {
  banner "apt-get update / upgrade..."
  #apt-get update
  #apt-get -y upgrade
  apt-get install -y wget libreadline5
  
  banner "installing Ruby $CONFIG_RUBY..."
  case $CONFIG_RUBY in
    1.8.7 ) install_ruby_187 ;;
    1.9.2 ) install_ruby_192 ;;
    REE )   install_ruby_ree ;;
	* )     echo "error: unknown ruby ($CONFIG_RUBY)"; exit 99 ;;
  esac
}

function install_ruby_187() {
  apt-get -y install ruby
}

function install_ruby_192() {
  # courtesy of http://threebrothers.org/brendan/blog/ruby-1-9-2-on-ubuntu-11-04/
  apt-get install -y bison build-essential checkinstall libffi5 libssl-dev libyaml-dev zlib1g-dev

  wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p180.tar.gz
  tar xvzf ruby-1.9.2-p180.tar.gz
  
  cd ruby-1.9.2-p180
  ./configure --prefix=/usr/local \
              --program-suffix=1.9.2 \
              --with-ruby-version=1.9.2 \
              --disable-install-doc
  make
  checkinstall -D -y \
               --fstrans=no \
               --nodoc \
               --pkgname='ruby1.9.2' \
               --pkgversion='1.9.2-p180' \
               --provides='ruby' \
               --requires='libc6,libffi5,libgdbm3,libncurses5,libreadline5,openssl,libyaml-0-2,zlib1g' \
               --maintainer=brendan.ribera@gmail.com
  cd ..

  update-alternatives --install /usr/local/bin/ruby ruby /usr/local/bin/ruby1.9.2 500 \
                      --slave   /usr/local/bin/ri   ri   /usr/local/bin/ri1.9.2 \
                      --slave   /usr/local/bin/irb  irb  /usr/local/bin/irb1.9.2 \
                      --slave   /usr/local/bin/gem  gem  /usr/local/bin/gem1.9.2 \
                      --slave   /usr/local/bin/erb  erb  /usr/local/bin/erb1.9.2 \
                      --slave   /usr/local/bin/rdoc rdoc /usr/local/bin/rdoc1.9.2
}


function install_ruby_ree() {
  if [ $(uname -m) == "x86_64" ]; then
    local platform="amd64"
  else
    local platform="i386"
  fi
  local ree="ruby-enterprise_1.8.7-2011.03_${platform}_ubuntu10.04.deb"
  wget http://rubyenterpriseedition.googlecode.com/files/$ree
  dpkg -i $ree
}


#
# main
#

cd /tmp/_teleported
source ./config

if ! which ruby > /dev/null ; then
  install_ruby
fi

ruby -I gem -r teleport -e "Teleport::Main.new(:install)"

#!/bin/bash

#
# This script runs on the target machine. First it installs ruby if
# necessary, then it runs teleport.
#

# bail on errors
set -eu



#
# functions
#

function banner() {
  printf '\e[1;37;43m[%s] %-72s\e[0m\n' `date '+%H:%M:%S'` "run.sh: $1"
}

function fatal() {
  printf '\e[1;37;41m[%s] %-72s\e[0m\n' `date '+%H:%M:%S'` "run.sh: error - $1"
  exit 1
}

function install_ruby() {
  banner "apt-get update / upgrade..."
  apt-get update
  apt-get -y upgrade

  # which version of readline to install?
  local readline
  if [ "${DISTRIB_RELEASE//[.]/}" -lt "1110" ] ; then
    readline=libreadline5-dev
  else
    readline=libreadline-gplv2-dev
  fi
  apt-get install -y wget $readline

  banner "installing Ruby $CONFIG_RUBY..."
  case $CONFIG_RUBY in
    1.8.7 ) install_ruby_187 ;;
    1.9.2 ) install_ruby_192 ;;
    1.9.3 ) install_ruby_193 ;;
    REE )   install_ruby_ree ;;
	* )     fatal "unknown ruby ($CONFIG_RUBY)" ;;
  esac
}

function install_ruby_187() {
  apt-get -y install irb libopenssl-ruby libreadline-ruby rdoc ri ruby ruby-dev

  wget http://production.cf.rubygems.org/rubygems/rubygems-$CONFIG_RUBYGEMS.tgz
  tar xfpz rubygems-$CONFIG_RUBYGEMS.tgz
  (cd rubygems-$CONFIG_RUBYGEMS ; ruby setup.rb)
  ln -s /usr/bin/gem1.8 /usr/bin/gem
}

#
# thanks to http://threebrothers.org/brendan/blog/ruby-1-9-2-on-ubuntu-11-04/
# for suggestions
#

function install_ruby_19_requirements() {
  local ffi
  if [ "${DISTRIB_RELEASE//[.]/}" -lt "1110" ] ; then
    ffi=libffi5
  else
    ffi=libffi6
  fi
  apt-get install -y bison build-essential checkinstall $ffi libssl-dev libyaml-dev zlib1g-dev
}

function install_ruby_192() {
  local patch=p290

  install_ruby_19_requirements

  wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-$patch.tar.gz
  tar xvzf ruby-1.9.2-$patch.tar.gz

  cd ruby-1.9.2-$patch
  ./configure --prefix=/usr/local \
              --program-suffix=192 \
              --with-ruby-version=1.9.2 \
              --disable-install-doc
  make
  checkinstall -D -y \
                    --fstrans=no \
                    --nodoc \
                    --pkgname="ruby1.9.2" \
                    --pkgversion="1.9.2-$patch" \
                    --provides="ruby"
  cd ..

  update-alternatives --install /usr/local/bin/ruby ruby /usr/local/bin/ruby192 500 \
                      --slave   /usr/local/bin/ri   ri   /usr/local/bin/ri192 \
                      --slave   /usr/local/bin/irb  irb  /usr/local/bin/irb192 \
                      --slave   /usr/local/bin/gem  gem  /usr/local/bin/gem192 \
                      --slave   /usr/local/bin/erb  erb  /usr/local/bin/erb192 \
                      --slave   /usr/local/bin/rdoc rdoc /usr/local/bin/rdoc192
}

function install_ruby_193() {
  local patch=p125

  install_ruby_19_requirements

  wget http://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.3-$patch.tar.gz
  tar xvzf ruby-1.9.3-$patch.tar.gz

  cd ruby-1.9.3-$patch
  ./configure --prefix=/usr/local \
              --program-suffix=193 \
              --with-ruby-version=1.9.3 \
              --disable-install-doc
  make
  checkinstall -D -y \
                    --nodoc \
                    --pkgname="ruby1.9.3" \
                    --pkgversion="1.9.3-$patch" \
                    --provides="ruby"
  cd ..

  update-alternatives --install /usr/local/bin/ruby ruby /usr/local/bin/ruby193 500 \
                      --slave   /usr/local/bin/ri   ri   /usr/local/bin/ri193 \
                      --slave   /usr/local/bin/irb  irb  /usr/local/bin/irb193 \
                      --slave   /usr/local/bin/gem  gem  /usr/local/bin/gem193 \
                      --slave   /usr/local/bin/erb  erb  /usr/local/bin/erb193 \
                      --slave   /usr/local/bin/rdoc rdoc /usr/local/bin/rdoc193
}

function install_ruby_ree() {
  local ree="ruby-enterprise_1.8.7-2012.02_${ARCH}_ubuntu10.04.deb"

  # this is necessary on 12.04 (thanks noeticpenguin)
  apt-get -y install libssl0.9.8
  
  wget http://rubyenterpriseedition.googlecode.com/files/$ree
  dpkg -i $ree

  # remove all gems
  gem list | cut -d" " -f1 | xargs gem uninstall
}


#
# main
#

# are we on Ubuntu?
if ! grep -q Ubuntu /etc/lsb-release ; then
  fatal "Teleport only works with Ubuntu"
fi

# which version?
. /etc/lsb-release
case $DISTRIB_RELEASE in
  10.* | 11.* | 12.04 ) ;; # nop
  *)
    banner "warning - Ubuntu $DISTRIB_RELEASE hasn't been tested with Teleport yet"
esac

# which architecture?
if [ $(uname -m) == "x86_64" ] ; then
  ARCH=amd64
else
  ARCH=i386
fi

# read our config
cd /tmp/_teleported
source ./config

# do we need to install ruby?
if ! which ruby > /dev/null ; then
  install_ruby
fi

# run teleport!
ruby -I gem -r teleport -e "Teleport::Main.new(:install)"

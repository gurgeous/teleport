## Welcome to Teleport

Teleport is a lightweight way to set up Ubuntu machines. The name derives from the mechanism that teleport uses to setup the target machine - it copies itself onto the target machine via ssh and then runs itself there. In effect, it "teleports" to the target. This design makes it possible for teleport to bootstrap itself onto a fresh machine. There's no need to install ruby or anything else by hand.

Teleport strives to be **idempotent** - you can run it repeatedly without changing the result. In other words, as you build up your teleport config file you can generally run it over and over again without fear of breaking the target machine.

Teleport is great for managing a small number of hosted machines, either dedicated or in the cloud. Due to it's opinionated nature and limited scope you may find that it works better for you than other, more complicated tools.

At the moment Teleport supports **Ubuntu 10.04 LTS with Ruby 1.8.7, 1.9.2, or [REE](http://www.rubyenterpriseedition.com/)**.

## Getting Started

1. Install Teleport on your local machine.

    ```
    $ sudo gem install teleport
    ```    
    
1. Create a `teleport.rb` config file. Here's a simple example. Note that we actually define two machines, `server_app1` and `server_db1`:

    ```
    $ mkdir ~/teleport
    $ cd ~/teleport
    ```
    
    Put this into `~/teleport/teleport.rb`:
    
    ``` ruby
    user :admin
    ruby "1.9.2"
    apt "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen", :key => "7F0CAB10"    
    role :app, :packages => [:memcached]
    role :db, :packages => [:mongodb-10gen]
    server "server_app1", :role => :app
    server "server_db1", :role => :db    
    packages [:atop, :emacs, :gcc]
    ```
    
1. You'll want to copy files to your new machines too. Put the files into your teleport directory. For example, maybe you want to automatically have your `.bashrc` and `.emacs` files copied to your new server. You'll want the `memcached` and `mongodb` config files too. Here's what your teleport directory should look like:

    ```
    teleport.rb
    files/home/admin/.bashrc
    files/home/admin/.emacs            
    files_app/etc/default/memcached
    files_app/etc/memcached.conf
    files_db/etc/mongodb.conf
    ```
    
1. Now run Teleport:

    ```
    $ teleport server_app1
    ```
    
Teleport will ssh to the machine and set it up per your instructions.

## Order of Operations

Here is the exact sequence of operations performed by Teleport on the target machine:

1. apt-get update/upgrade
1. install ruby
1. install/update rubygems, but remove all gems except for bundler
1. set the hostname
1. create the user account and setup /etc/sudoers.d/teleport
1. set up id_teleport public key if possible (see below)
1. configure apt (this may require a second apt-get update)
1. install packages
1. install files

## A Word About SSH

Make sure you can ssh to the target machine before you try running Teleport!

Teleport copies itself to the target machine and runs there. It uses ssh to connect to the target. Remember that ssh will use port 22 and your current username by default when connecting. This is most likely **NOT** what you want.

Before running Teleport against a new machine, you may need to add a section to your ~/.ssh/config file:

```
Host server_*
User ubuntu
IdentityFile ~/path/to/your/sshkey
```

Depending on your needs, you may want to change your ssh config once Teleport finishes setting up the machine.

#### /etc/hosts

To reiterate, Teleport just uses straight ssh to get the job done. You might need to edit your /etc/hosts file so that ssh can find your target machine. We recommend that you always use hostnames instead of IP addresses. Whenever you bring up a new machine, simply add it to your /etc/hosts file.

#### id_teleport

Some machines are pre-provisioned with ssh keys, like Amazon EC2 boxes. For other providers you just get a root account and a password. Wouldn't it be nice if Teleport would automatically set up a key for you?

If you provide a public key, Teleport will copy it to `~/.ssh/authorized_keys` on your target machine automatically. It looks for your public key here:

```
~/.ssh/id_teleport.pub
```

You can use an existing key, or create a new one with this command:

```
$ ssh-keygen -t rsa -f ~/.ssh/id_teleport
```

## teleport.rb Reference

Your teleport.rb config file explains how to set up your machine(s). Here are the supported commands:

#### ruby

The version of ruby to install on the target. You can specify:

* 1.9.2 (default)
* 1.8.7
* REE

Example:

``` ruby
ruby "REE"
```

#### user

The account to create on the new machine. This account will be created along with `/etc/sudoers.d/teleport` to let the user sudo. Also, `id_teleport.rb` will be copied to `~/.ssh/authorized_keys` if provided. See **A Word About SSH** above.

If you don't specify a user, Teleport will use the current username from your machine.

#### apt

Add apt sources and keys. You can call this repeatedly. Example:

``` ruby
apt "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen", :key => "7F0CAB10"
```

This will add that line to `/etc/apt/sources.list.d/teleport.list` and add the key using apt-key if necessary. If necessary, Teleport will run apt-get update.

#### packages

A list of packages to install using apt-get. These will be installed on all machines regardless of role. Be sure to use `apt` to add sources if necessary. Example:

``` ruby
packages %w(atop imagemagick nginx wget)
```

#### server

Customzie each target machine, either by specifying packages directly or by using roles. You don't have to use `server` at all, but if you use it Teleport will insist that you use it for each of your machines.

Examples:

``` ruby
server "server1", :packages => [:xfsprogs] # install xfsprogs
server "server1", :role => :db # this machine is a db
```

#### role

Just like with [Capistrano](https://github.com/capistrano/capistrano/), roles are used to group similar machines. A **role** is nothing more than a way to say "install these packages and files for all machines of this type." Note that roles are totally optional - you don't have to use them at all.

Examples:

``` ruby
role :app, :packages => [:imagemagick, :nginx]
role :db, :packages => [:"mysql-server"]
```

Then you can use the roles when you define your servers:

``` ruby
server "server_app1", :role => :app
server "server_app2", :role => :app
server "server_app3", :role => :app
server "server_db1, :role => :db
```

Roles are also used to figure out which files to install. See below. 

## Files

After Teleport finishes installing packages, it will copy files to the target machine from `files/`. If your server defines a role, it will copy `files_<ROLE>/` as well. Permissions and timestamps will generally be copied from the source file. Files will be owned by `root` unless they live in `/home`.

Also, you can use ERB to create templates. For example, you can customize the prompt on each server by creating `files/home/admin/.bashrc.erb`:

```
PS1='<%= host %> $'
```

Or you can make it more elaborate:

```
<% if host == "server1" %>
PS1='Don't mess with this machine!!! $'
<% end %>
```

## Recipes

* /etc/hosts
* rails - with bluepill, nginx and unicorn
* bundle exec
* cron.d
* delayed_job
* firehol
* logrotate.d
* memcached
* mongodb
* munin
* niceties - bashrc, inputrc, .emacs, .irbrc...
* REE settings

## Todo

* Customization/callbacks/controller?
* Tests
* Clean vm runs
* Switch to scp then ssh, instead of just ssh? that would allow stdin
* recipes

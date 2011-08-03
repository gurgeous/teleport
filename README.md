## Welcome to Teleport

Teleport is a lightweight way to set up Ubuntu machines. The name derives from the mechanism that teleport uses to setup the target machine - it copies itself onto the target machine via ssh and then runs itself there. In effect, it "teleports" to the target. This design makes it possible for teleport to bootstrap itself onto a fresh machine. There's no need to install ruby or anything else by hand.

Teleport strives to be **idempotent** - you can run it repeatedly without changing the result. In other words, as you build up your teleport config file you can generally run it over and over again without fear of breaking the target machine.

Teleport is great for managing a small number of hosted machines, either dedicated or in the cloud. Due to it's opinionated nature and limited scope you may find that it works better for you than other, more complicated tools.

At the moment Teleport supports **Ubuntu 10.04/10.10/11.04 with Ruby 1.8.7, 1.9.2, or [REE](http://www.rubyenterpriseedition.com/)**.

## Getting Started

1. Install Teleport on your local machine.

    ```
    $ sudo gem install teleport
    ```    
    
1. Create a `Telfile` config file. Here's a simple example. Note that we actually define two machines, `server_app1` and `server_db1`:

    ```
    $ mkdir ~/teleport
    $ cd ~/teleport
    ```
    
    Put this into `~/teleport/Telfile`:
    
    ``` ruby
    user "admin"
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
    Telfile
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

## Full Documentation

Full docs are in the wiki:

https://github.com/rglabs/teleport/wiki

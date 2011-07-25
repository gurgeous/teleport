## Welcome to Teleport

Teleport sets up Ubuntu machines. The name derives from the mechanism that teleport uses to setup the target machine - it copies itself onto the target machine via ssh and then runs itself there. In effect, it "teleports" to the target.

This design makes it possible for teleport to bootstrap itself onto a fresh machine. There's no need to install ruby or anything else by hand.

Teleport strives to be **idempotent** - you can run it repeatedly without changing the result. In other words, as you build up your teleport config file you can generally run it over and over again without fear of breaking the target machine.

Teleport is great for managing a small number of hosted machines, either dedicated or in the cloud. Due to it's opinionated nature and limited scope you may find that it works better for you than other, more complicated tools.


## Getting Started

1. Provision a new machine from your provider.
   
1. Install teleport on your local machine.

    ```
    sudo gem install teleport
    ```    
    
1. Create a teleport.rb config file. Here's a simple example. Note that we actually defined two machines here, server_app1 and server_db1:

    ```
    $ mkdir ~/teleport
    $ cd ~/teleport
    $ cat > teleport.rb
    ```
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
    
1. You'll want to copy files to your new machines too. Put the files into your teleport directory. For example, maybe you want to automatically have your .bashrc and .emacs files copied to your new server. You'll want the memcached and mongodb config files too:

    ```
    $ mkdir -p files/home/admin
    $ mkdir -p files_app/etc/default    
    $ mkdir -p files_db/etc
    $ cp ~/.bashrc files/home/admin/.bashrc
    $ cp ~/.emacs file/home/admin/.emacs
    $ cp /etc/memcached.conf files_app/etc/memcached.conf
    $ cp /etc/mongodb.conf files_db/etc/mongodb.conf
    $ cp /etc/default/memcached files_app/etc/default/memcached
    ```
    
1. Now run teleport:

    ```
    $ teleport server_app1
    ```
    
Teleport will ssh to the machine and set it up per your instructions.

## Under the Hood

Here is the exact sequence of operations performed by teleport on the target machine:

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

Make sure you can ssh to the target machine before you try running teleport!

Teleport copies itself to the target machine and runs there. It uses ssh to connect to the target. Remember that ssh will use port 22 and your current username by default when connecting. This is most likely **NOT** what you want.

Before running teleport against a new machine, you may need to add a section to your ~/.ssh/config file:

```
Host server_*
User ubuntu
IdentityFile ~/path/to/your/sshkey
```

Depending on your needs, you may want to change your ssh config once teleport finishes setting up the machine.

#### id_teleport

Some machines come pre-provisioned with ssh keys, like Amazon EC2 boxes. For other providers you just get a root account and a password. Wouldn't it be nice if teleport would automatically set up a key for you?

If you provide a public key, teleport will copy it to `~/.ssh/authorized_keys` on your target machine automatically. It looks for your public key here:

```
~/.ssh/id_teleport.pub
```

You can use an existing key, or create a new one with this command:

```
$ ssh-keygen -t rsa -f ~/.ssh/id_teleport
```

## Reference

## Todo

* Customization/callbacks/controller?
* Tests
* Clean vm runs
* Switch to scp then ssh, instead of just ssh? that would allow stdin
* recipes?

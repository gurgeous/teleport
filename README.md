## Welcome to Teleport

Teleport is a lightweight way to set up Ubuntu machines. The name derives from the mechanism that teleport uses to setup the target machine - it copies itself onto the target machine via ssh and then runs itself there. In effect, it "teleports" to the target. This design makes it possible for teleport to bootstrap itself onto a fresh machine. There's no need to install ruby or anything else by hand.

Teleport strives to be **idempotent** - you can run it repeatedly without changing the result. In other words, as you build up your teleport config file you can generally run it over and over again without fear of breaking the target machine.

Teleport is great for managing a small number of hosted machines, either dedicated or in the cloud. Due to it's opinionated nature and limited scope you may find that it works better for you than other, more complicated tools.

At the moment Teleport supports **Ubuntu 10.04 LTS with Ruby 1.8.7, 1.9.2, or [REE](http://www.rubyenterpriseedition.com/)**.

## Full Documentation

Full docs are in the wiki:

https://github.com/rglabs/teleport/wiki

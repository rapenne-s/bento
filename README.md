# Bento

A KISS deployment tool to keep your NixOS fleet (servers & workstations) up to date.

This name was chosen because Bento are good, and comes with the idea of "ready to use".  And it doesn't use "nix" in its name.

# Why?

There is currently no tool to manage a bunch of NixOS systems that could be workstations anywhere in the world, or servers in a datacenter, using flakes or not.

# Features

- secure 🛡️: each client can only access its own configuration files (ssh authentication + sftp chroot)
- insightful 📒: you can check the remote systems are running the same NixOS built locally with their configuration files, thanks to reproducibility
- efficient 🏂🏾: configurations can be built on the central management server to serve binary packages if it is used as a substituters by the clients
- organized 💼: system administrators have all configurations files in one repository to easy management
- peace of mind 🧘🏿: configurations validity can be verified locally by system administrators
- smart 💡: secrets (arbitrary files) can (soon) be deployed without storing them in the nix store
- robustness in mind 🦾: clients just need to connect to a remote ssh, there are many ways to bypass firewalls (corkscrew, VPN, Tor hidden service, I2P, ...)
- extensible 🧰 🪡: you can change every component, if you prefer using GitHub repositories to fetch configuration files instead of a remote sftp server, you can change it
- for all NixOS 💻🏭📱: it can be used for remote workstations, smartphones running NixoS, servers in a datacenter

# Prerequisites

This setup need a machine to be online most of the time.  NixOS systems (clients) will regularly check for updates on this machine over ssh.

**Bentoo** doesn't necesserarily require a public IP, don't worry, you can use tor hidden service, i2p tunnels, a VPN or whatever floats your boat given it permit to connect to ssh.

# How it works

The ssh server is containing all the configuration files for the machines. When you make a change, run `bento` to rebuild systems and copy all the configuration files to a new directory used by each client as a sftp chroot, each client regularly poll for changes in their dedicated sftp directory and if it changed, they download all the configuration files and run nixos-rebuild. It automatically detects if the configuration is using flakes or not.

`bento` is the only script to add to `$PATH`, however a few other files are required to setup your configuration management:

- `fleet.nix` file that must be included in the ssh host server configuration, it declares the hosts with their name and ssh key, creates the chroots and enable sftp for each of them. You basically need to update this file when a key change, or a host is added/removed
- `utils/bento.nix` that has to be imported into each host configuration, it adds a systemd timer triggering a service looking for changes and potentially trigger a rebuild if any
- `bento deploy` create copies of configuration files for each host found in `host` into the corresponding chroot directory (default is `/home/chroot/$machine/`
- `bento build` iterates over each host configuration to run `nixos-rebuild build`, but you can pass `dry-build` as a parameter if you just want to ensures each configuration is valid.

On the client, the system configuration is stored in `/var/bento/` and also contains scripts `update.sh` and `bootstrap.sh` used to look for changes and trigger a rebuild.

There is a diagram showing the design pattern of **bento**:

![diagram](https://dataswamp.org/~solene/static/nixos-fleet-pattern.png)

# Layout

Here is the typical directory layout for using **bento** for three hosts `router`, `nas` and `t470`:

```
├── fleet.nix
├── hosts
│   ├── router
│   │   ├── configuration.nix
│   │   ├── hardware-configuration.nix
│   │   └── utils -> ../../utils/
│   ├── all-flakes-systems
│   │   ├── configuration.nix
│   │   ├── flake.lock
│   │   ├── flake.nix
│   │   ├── hardware-configuration.nix
│   │   └── utils -> ../../utils/
│   └── t470
│       ├── configuration.nix
│       ├── default-spec.nix
│       ├── flake.lock
│       ├── flake.nix
│       ├── hardware-configuration.nix
│       ├── home.nix
│       ├── minecraft.nix
│       ├── nfs.nix
│       ├── nvidia.nix
│       └── utils -> ../../utils/
├── README.md
└── utils
    └── bento.nix
    └── common-stuff.nix
```

# Workflow

1. make configuration changes per host in `hosts/` or a global include file in `utils` (you can rename it as you wish)
2. run `sudo bento deploy` to verify, build every system, and publish the configuration files on the SFTP server
3. hosts will pickup changes and run a rebuild

# Track each host state

As each host is sending a log upon rebuild to tell if it failed or succeeded, we can use this file to check what happened since the sftp file `last_time_changed` was created.

Using `bento status` you can track the current state of each hosts (time since last update, current NixOS version, status report)

[![asciicast](https://asciinema.org/a/519060.svg)](https://asciinema.org/a/519060)

# Examples

## Adding a new host

Here are the steps to add a server named `kikimora` to bento:

[![asciicast](https://asciinema.org/a/518834.svg)](https://asciinema.org/a/518834)

1. generate a ssh-key on `kikimora` for root user
2. add kikimora's public key to bento `fleet.nix` file
3. reconfigure the ssh host to allow kikimora's key (it should include the `fleet.nix` file)
4. copy kikimora's config (usually `/etc/nixos/` in bento `hosts/kikimora/` directory
5. add utils/bento.nix to its config (in `hosts/kikimora` run `ln -s ../../utils .` and add `./utils/bento.nix` in `imports` list)
6. check kikimora's config locally with `bento build dry-build`, you can check only `kikimora` with `env NAME=kikimora bento build dry-build`
7. populate the chroot with `sudo bento deploy` to copy the files in `/home/chroot/kikimora/config/`
8. run bootstrap script on kikimora to switch to the new configuration from sftp and enable the timer to poll for upgrades
9. you can get bento's log with `journalctl -u bento-upgrade.service` and see next timer information with `systemctl status bento-upgrade.timer`

## Deploying changes

Here are the steps to deploy a change in a host managed with **bento**

1. edit its configuration file to make the changes in `hosts/the_host_name/something.nix`
2. run `sudo bento deploy` to build and publish configuration files
3. wait for the timer of that system to trigger the update, or ask the user to open http://localhost:51337/ to force the update

If you don't want to wait for the timer, you can ssh into the machine to run `systemctl start bento-upgrade.service`

## Status report of the fleet

Using `bento status`, you instantly get a report of your fleet, all information are extracted from the logs files deposited after each update:

- what is the version they should have (built locally) against the version they are currently running
- their state:
  - **sync pending**: no configuration file changed, only files specific to **Bento**
  - **rebuild pending**: the local version has been updated and the remote must run `nixos-rebuild`
  - **up to date**: everything is fine
  - **extra logs**: the update process has been run more than necessary, this shouldn't happen. The most common case is to run the update service manually.
  - **failing**: the update process failed
  - **rollbacked**: the update process failed and a rollback has been done to previous version. **Bento** won't try until a new configuration is available.
- the time elapsed since last rebuild
- the time elapsed since the new onfiguration has been made available

Non-flakes systems aren't reproducible (without efforts), so we can't compare the remote version with the local one, but we can report this information.

Example of output:

```
   machine   local version   remote version              state                                     time
   -------       ---------      -----------      -------------                                     ----
  interbus      non-flakes      1dyc4lgr 📌      up to date 💚                              (build 11s)
  kikimora        996vw3r6      996vw3r6 💚    sync pending 🚩       (build 5m 53s) (new config 2m 48s)
       nas        r7ips2c6      lvbajpc5 🛑 rebuild pending 🚩       (build 5m 49s) (new config 1m 45s)
      t470        b2ovrtjy      ih7vxijm 🛑      rollbacked 🔃                           (build 2m 24s)
        x1        fcz1s2yp      fcz1s2yp 💚      up to date 💚                           (build 2m 37s)
```

# TODO

## Major priority

- DONE ~~client should report their current version after an upgrade, we should be able to compute the same value from the config on the server side, this would allow to check if a client is correctly up to date~~
- being able to create a podman compatible NixOS image that would be used as the chroot server, to avoid reconfiguring the host and use sudo to distribute files
- DONE ~~auto rollback like "magicrollback" by deploy-rs in case of losing connectivity after an upgrade~~
- DONE ~~`local_build.sh` and `populate_chroot` should be only one command installed in `$PATH`~~
- DONE ~~upgrades could be triggered by the user by accessing a local socket, like opening a web page in a web browser to trigger it, if it returns output that'd be better~~
- a way to tell a client (when using flakes) to try to update flakes every time even if no configuration changed, to keep them up to date
- ~~being able to use a single flakes with multiple hosts that **bento** will automatically assign to the nixosConfiguration names as hosts~~

## Minor

- a systray info widget could tell the user an upgrade has been done
- DONE ~~updates should add a log file in the sftp chroot if successful or not~~
- the sftp server could be on another server than the one with the configuration files
- provide more useful modules in the utility nix file (automatically use the host as a binary cache for instance)
- have a local information how to ssh to the client to ease the rebuild trigger (like a SSH file containing ssh command line)

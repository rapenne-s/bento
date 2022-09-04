# Bento

A KISS deployment tool to keep your NixOS fleet (servers & workstations) up to date.

This name was chosen because Bento are good, and comes with the idea of "ready to use".  And it doesn't use "nix" in its name.

# Why?

There is currently no tool to manage a bunch of NixOS systems that could be workstations anywhere in the world, or servers in a datacenter, using flakes or not.

# Features

- secure 🛡️: each client can only access its own configuration files (ssh authentication + sftp chroot)
- efficient 🏂🏾: configurations can be built on the central management server to serve binary packages if it is used as a substituters by the clients
- organized 💼: system administrators have all configurations files in one repository to easy management
- peace of mind 🧘🏿: configurations validity can be verified locally by system administrators
- smart 💡: secrets (arbitrary files) can (soon) be deployed without storing them in the nix store
- robustness in mind 🦾: clients just need to connect to a remote ssh, there are many ways to bypass firewalls (corkscrew, VPN, Tor hidden service, I2P, ...)
- extensible 🧰 🪡: you can change every component, if you prefer using GitHub repositories to fetch configuration files instead of a remote sftp server, you can change it

# Prerequisites

This setup need a machine to be online most of the time.  NixOS systems (clients) will regularly check for updates on this machine over ssh.

If you don't absolutely require a public IP, don't worry, you can use tor hidden service, i2p tunnels, a VPN or whatever floats your boat given it permit to connect to ssh.

# How it works

The ssh server is containing all the configuration files for the machines. When you make a change, you run a script copying all the configuration files to a new directory used by each client as a sftp chroot, each client regularly poll for changes in their dedicated sftp directory and if it changed, they download all the configuration files and run nixos-rebuild. It automatically detects if the configuration is using flakes or not.

**Bento** is just a framework and a few scripts to make this happening, ideally this should be a command in `$PATH` instead of scripts in your configuration directory:

- `populate_chroot.sh` create copies of configuration files for each host found in `host` into the corresponding chroot directory (default is `/home/chroot/$machine/`
- `fleet.nix` file that must be included in the ssh host server configuration, it declares the hosts with their name and ssh key, creates the chroots and enable sftp for each of them. You basically need to update this file when a key change, or a host is added/removed
- `local_build.sh` iterates over each host configuration to run `dry-build`, but you can pass `build` as a parameter, this ensures each configuration work, and if you use this system as a substituter you can build their configurations to offload compilations on the clients
- `utils/bento.nix` that have to be imported into each host configuration, it adds a systemd timer triggering a service looking for changes and potentially trigger a rebuild if any

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
│   ├── nas
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
├── local_build.sh
├── populate_chroot.sh
├── README.md
└── utils
    └── bento.nix
```

# Workflow

1. make configuration changes per host in `hosts/` or a global include file in `utils` (you can rename it as you wish)
2. OPTIONAL: run `./local_build.sh` to check the configurations are valid
3. OPTIONAL: run `./local_build.sh build` to build systems locally and make them available in the store. This is useful if you want to serve the result as a substituter (requires configuration on each client)
4. run `./populate_chroot.sh`
5. hosts will pickup changes and run a rebuild

# Examples

## Adding a new host

Here are the steps to add a server named `kikimora` to bento:

[![asciicast](https://asciinema.org/a/518834.svg)](https://asciinema.org/a/518834)

1. generate a ssh-key on `kikimora` for root user
2. add kikimora's public key to bento `fleet.nix` file
3. reconfigure the ssh host to allow kikimora's key (it should include the `fleet.nix` file)
4. copy kikimora's config (usually `/etc/nixos/` in bento `hosts/kikimora/` directory
5. add utils/bento.nix to its config (in `hosts/kikimora` run `ln -s ../../utils .` and add `./utils/bento.nix` in `imports` list)
6. check kikimora's config locally with `./local_build.sh`, you can check only kikimora with `env NAME=kikimora ./local_build.sh`
7. populate the chroot with `sudo ./populate_chroot.sh` to copy the files in `/home/chroot/kikimora/`
8. run bootstrap script on kikimora to switch to the new configuration from sftp and enable the timer to poll for upgrades
9. you can get bento's log with `journalctl -u bento-upgrade.service` and see next timer information with `systemctl status bento-upgrade.timer`

## Deploying changes

Here are the steps to deploy a change in a host managed with **bento**

1. edit its configuration file to make the changes in `hosts/the_host_name/something.nix`
2. OPTIONAL: run `./local_build.sh` to check if the configurations are valid
3. run `sudo ./populate_chroot.sh`
4. wait for the timer of that system to trigger the update

If you don't want to wait for the timer, you can ssh into the machine to run `systemctl start bento-upgrade.service`

# TODO

- auto rollback like "magicrollback" by deploy-rs
- updates should add a log file in the sftp chroot if successful or not
- the sftp server could be on another server than the one with the configuration files
- `local_build.sh` and `populate_chroot` should be only one command installed in `$PATH`

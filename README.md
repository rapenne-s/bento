# Bento

A KISS deployment tool to keep your NixOS fleet (servers & workstations) up to date.

# Why?

There is currently no tool to manage a bunch of NixOS systems that could be workstations anywhere in the world, or servers in a datacenter, using flakes or not.

# Prerequisites

This setup need a machine that need to be online most of the time.  NixOS systems (clients) will regularly check for updates on this machine over ssh.

If you don't have a public IP, don't worry, you can use tor hidden service, i2p tunnels, a VPN or whatever floats your boat given it permit to connect to ssh.

# How it works

The ssh server is holding all the configuration files for the machines. When you make a change, you need to copy all the files to a new directory in a sftp chroot used by each client, each client regularly poll for changes in their dedicated sftp directory and if it changed, they download all the configuration files and run nixos-rebuild. It automatically detects if the configuration is using flakes or not.

**Bentoo** is just a framework and a few scripts to make this happening:

- `populate_chroot.sh` create copies of configuration files for each host found in `host` into the corresponding chroot directory (default is `/home/chroot/$machine/`
- `fleet.nix` file that must be included in the ssh host server configuration, it declares the hosts with their name and ssh key, creates the chroots and enable sftp for each of them. You basically need to update this file when a key change, or a host is added/removed
- `local_build.sh` iterates over each host configuration to run `dry-build`, but you can pass `build` as a parameter, this ensures each configuration work, and if you use this system as a substituter you can build their configurations to offload compilations on the clients
- `utils/bento.nix` that have to be imported into each host configuration, it adds a systemd timer triggering a service looking for changes and potentially trigger a rebuild if any

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

1. make configuraiton changes in some host in `hosts/` or a global include file in `utils` (you can rename it as you wish)
2. OPTIONAL: run `./local_build.sh` to check the configurations are valid
3. OPTIONAL: run `./local_build.sh build` to build systems locally and make them available in the store. This is useful if you want to serve the result as a substituter (requires configuration on each client)
4. run `./populate_chroot.sh`
5. hosts will pickup changes and run a rebuild

# TODO

- auto rollback like "magicrollback" by deploy-rs
- updates should add a log file in the sftp chroot if successful or not

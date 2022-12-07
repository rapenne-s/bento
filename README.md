# Bento

A KISS deployment tool to keep your NixOS fleet (servers & workstations) up to date.

This name was chosen because Bento are good, and comes with the idea of "ready to use".  And it doesn't use "nix" in its name.

Use with flakes: `nix shell github:rapenne-s/bento`

# Documentation

- [Reference documentation](doc/reference.md): contains environment variable, command line parameters
- [How-to](doc/how-to.md): contains examples and how-to guides

# About Bento

## Explanation

There is currently no tool to manage a bunch of NixOS systems that could be workstations anywhere in the world, or servers in a datacenter, using flakes or not.

Most NixOS deployment tools are working on a "push" model, in which a system is connecting to a remote NixOS to push its new version.

Bento has a different approach with a "pull" model:

- privacy first 🛡️: each client can only access its own configuration files (using ssh authentication to reach a SFTP chroot)
- insightful 📒: you can check the remote systems are running the same NixOS built locally with their configuration files, thanks to reproducibility
- efficient 🏂🏾: configurations can be built on the central management server to serve binary packages if it is used as a substituters by the clients
- organized 💼: system administrators have all configurations files in one repository to ease management
- peace of mind 🧘🏿: configurations can be validated locally by system administrators
- smart 💡: secrets (arbitrary files) can (soon) be deployed without storing them in the nix store
- robustness in mind 🦾: clients ony need to connect to a remote ssh server, there are many ways to bypass firewalls (corkscrew, VPN, Tor hidden service, I2P, ...)
- extensible 🧰 🪡: you can change every component, if you prefer using GitHub repositories to fetch configuration files instead of a remote sftp server, you can change it
- for all NixOS 💻🏭📱: it can be used for anything running NixOS: remote workstations, smartphones or servers in a datacenter

# Prerequisites

This setup need a machine to be online most of the time.  NixOS systems (clients) will regularly check for updates on this machine over ssh.

**Bento** doesn't necesserarily require a public IP, don't worry, you can use tor hidden service, i2p tunnels, a VPN or whatever floats your boat given it permit to connect to ssh.

**Bento** will use `nvd` instead of `nix store diff-closures` if it's available in the `$PATH`.

# How it works

The ssh server is containing all the configuration files for the machines. When you make a change, run `bento` to rebuild systems and copy all the configuration files to a new directory used by each client as a sftp chroot, each client regularly poll for changes in their dedicated sftp directory and if it changed, they download all the configuration files and run nixos-rebuild. It automatically detects if the configuration is using flakes or not.

`bento` is the only script to add to `$PATH`, however a few other files are required to setup your configuration management:

- `utils/fleet.nix` file that must be included in the ssh host server configuration, it declares the hosts with their name and ssh key, creates the chroots and enable sftp for each of them. You basically need to update this file when a key change, or a host is added/removed
- `utils/bento.nix` that has to be imported into each host configuration, it adds a systemd timer triggering a service looking for changes and potentially trigger a rebuild if any
- `bento deploy` create copies of configuration files for each host found in `host` into the corresponding chroot directory (default is `/home/chroot/$machine/`
- `bento build` iterates over each host configuration to run `nixos-rebuild build`, but you can pass `dry-build` as a parameter if you just want to ensures each configuration is valid.

On the client, the system configuration is stored in `/var/bento/` and also contains scripts `update.sh` and `bootstrap.sh` used to look for changes and trigger a rebuild.

There is a diagram showing the design pattern of **bento**:

![diagram](https://dataswamp.org/~solene/static/nixos-fleet-pattern.png)

# CAVEATS

- if you propagate a new version while a host is updating, it may be incorrectly seen as "up to date" because the log file deposited will be newer than the `last_time_changed` file
- ~~if you make a change to the bento-upgrade.service systemd unit, update process will be aborted after nixos-rebuild is successful, and no log will be reported. This is because the systemd unit is stopped to be updated.~~
- if the sftp server is not reachable while a remote system updated (because it started before the main server got down or because of SELF UPDATE), it won't receive the log file and the system will be shown as "rebuild/sync pending"

# TODO

## Major priority

- being able to create a podman compatible NixOS image that would be used as the chroot server, to avoid reconfiguring the host and use sudo to distribute files
- a way to tell a client (when using flakes) to try to update flakes every time even if no configuration changed, to keep them up to date
- automatic reboot should be scheduled if desired, this may require making bento a NixOS module to set a timer in it, if no timer then it would reboot immediately
- document config.sh in the reference
- figure out how to make a tutorial for bento
- `config.sh` should have variables for the local / remote / both `nixos-rebuild` parameters (useful for `--fallback`)

## Minor

- a systray info widget could tell the user an upgrade has been done
- the sftp server could be on another server than the one with the configuration files
- provide more useful modules in the utility nix file (automatically use the host as a binary cache for instance)
- have a local information how to ssh to the client to ease the rebuild trigger (like a SSH file containing ssh command line)

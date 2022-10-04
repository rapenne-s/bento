# Layout

Here is the typical directory layout for using **bento** for the non-flakes system `router`, a single flake my-laptop for the system `t470`, and a flake with multiples configuration in `all-flakes-systems`:

```
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
│   └── my-laptop
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
    └── fleet.nix
```


# Workflow

1. make configuration changes per host in `hosts/` or a global include file in `utils` (you can rename it as you wish)
2. run `sudo bento deploy` to verify, build every system, and publish the configuration files on the SFTP server
3. hosts will pickup changes and run a rebuild

# Get started with bento

1. `bento init`
2. copy the configuration file of the server in a subdirectory of `hosts`, add `fleet.nix` to it
3. add keys to `fleet.nix`
4. run `bento deploy` as root
5. follow deployment with `bento status`
6. add new hosts keys to `fleet.nix` and their configuration in your `hosts` directory

# Adding a new host

Here are the steps to add a server named `kikimora` to bento:

[![asciicast](https://asciinema.org/a/520498.svg)](https://asciinema.org/a/520498)

1. generate a ssh-key on `kikimora` for root user
2. add kikimora's public key to bento `fleet.nix` file
3. reconfigure the ssh host to allow kikimora's key (it should include the `fleet.nix` file)
4. copy kikimora's config (usually `/etc/nixos/` in bento `hosts/kikimora/` directory
5. add utils/bento.nix to its config (in `hosts/kikimora` run `ln -s ../../utils .` and add `./utils/bento.nix` in `imports` list)
6. check kikimora's config locally with `bento build dry-build`, you can check only `kikimora` with `env NAME=kikimora bento build dry-build`
7. populate the chroot with `sudo bento deploy` to copy the files in `/home/chroot/kikimora/config/`
8. run bootstrap script on kikimora to switch to the new configuration from sftp and enable the timer to poll for upgrades
9. you can get bento's log with `journalctl -u bento-upgrade.service` and see next timer information with `systemctl status bento-upgrade.timer`

# Deploying changes

Here are the steps to deploy a change in a host managed with **bento**

1. edit its configuration file to make the changes in `hosts/the_host_name/something.nix`
2. run `sudo bento deploy` to build and publish configuration files
3. wait for the timer of that system to trigger the update, or ask the user to open http://localhost:51337/ to force the update

If you don't want to wait for the timer, you can ssh into the machine to run `systemctl start bento-upgrade.service`

# Track each host state

As each host is sending a log upon rebuild to tell if it failed or succeeded, the files are used to check what happened since the sftp file `last_time_changed` was created.

Using `bento status` you can track the current state of each hosts (time since last update, current NixOS version, status report)

[![asciicast](https://asciinema.org/a/520504.svg)](https://asciinema.org/a/520504)

# Update all flakes

With `bento flake-update` you can easily update your flakes recursively to the latest version.

A parameter can be added to only update a given source with, i.e to update all nixpkgs in the flakes `bento flake-update nixpkgs`.

# Show differences between a running system version and its new version

With `env NAME=my-laptop bento diff` you can display the differences of packages between what `my-laptop` is running and its new version.

The output should look like this:

```
Changes in x1 between p50qql7f42rl0fccdwxw45k21pnqb9ii-nixos-system-x1-22.11.20220921.d6490a0 and 7zfxxddmg8l6qc6bksar5gm62ylwsdv5-nixos-system-x1-22.11.20220927.7e52b35
bind: 9.18.6 → 9.18.7
cpupower: 5.19.9, 5.19.9_fish → 5.19.11, 5.19.11_fish
gh: 2.15.0, 2.15.0_fish → 2.16.1, 2.16.1_fish
imagemagick: 7.1.0-48 → 7.1.0-49, +18.0 KiB
initrd-linux: 5.19.9 → 5.19.11
libblockdev: 2.26 → 2.28
libbytesize: 2.6 → 2.7
libdmtx: 0.7.5 → 0.7.7
linux: 5.19.9, 5.19.9-modules → 5.19.11, 5.19.11-modules, +126.6 KiB
man: -11.8 KiB
nixos: +12.5 KiB
nixos-system-x1: 22.11.20220921.d6490a0 → 22.11.20220927.7e52b35
opencv: 4.5.4 → 4.6.0, +1901.6 KiB
plasma-workspace: +62.4 KiB
root-authorized_keys: ∅ → ε
source: +701.9 KiB
systemsettings: +62.6 KiB
-------------
```

# Push a configuration to a remote system

It's possible to use `bento` in a *push* model using `TARGET_IP`:

```
env TARGET_IP=10.43.43.1 NAME=myserver bento build switch
```

If the remote system is using a non-standard port, you need to define the according ssh option with `NIX_SSHOPTS`:

```
env NIX_SSHOPTS="-p2222" TARGET_IP=10.43.43.1 NAME=laptop bento build switch
```

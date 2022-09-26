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

# Status report of the fleet

Using `bento status`, you instantly get a report of your fleet, all information are extracted from the logs files deposited after each update:

- what is the version they should have (built locally) against the version they are currently running
- their current state
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

# Update all flakes

With `bento flake-update` you can easily update your flakes recursively to the latest version.

A parameter can be added to only update a given source with, i.e to update all nixpkgs in the flakes `bento flake-update nixpkgs`.

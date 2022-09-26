# Usage

- `bento init`
  - create the layout for bento in the current directory (only work from flakes)

- `bento deploy`
  - build configurations and deploy configuration files, requires to be root

- `bento build [dry-run|build|test|switch]`
  - dry-build or build configurations. Using `test` or `switch`, can be used to apply a configuration locally. Default is `build`.

- `bento status [delay]`
  - display information for remote hosts, if `delay` is set, loop infinitely to display the status every `delay` seconds. Default delay is `0` and doesn't loop.

- `bento flake-update [input]`
  - recursively update flakes lock files
  - with [input] parameter it only update the input passed as parameter

- `env NAME=someconfig bento deploy|build`
  - only build / deploy the system "someconfig"

# Environment variables

`bento` is using the following environment variables as configuration:
- `BENTO_DIR`: contains the path of a bento directory, so you can run `bento` commands from anywhere
- `NAME`: contains machine names (flake config or directory in `hosts/`) to restrict commands `deploy` and `build` to this machine only
- `VERBOSE`: if defined to anything, display `nixos-rebuild` output for local builds done with `bento build` or `bento deploy`

# Self update mode

You can create a file named `SELF_UPDATE` in a host directory using flakes. When that host will look for updates on the sftp server, if there is no changes to rebuild, if `SELF_UPDATE` exists along with a `flake.nix` file, it will try to update the inputs, if an input is updated, then the usual rebuild is happening.

This is useful if you want to let remote hosts to be autonomous and pick up new nixpkgs version as soon as possible.

Systems will be reported as "auto upgraded" in the `bento status` command if they rebuild after a local flake update.

This adds at least 8 kB of inbound bandwidth for each input when checking for changes.

# Auto reboot

You can create a file named `REBOOT` in a host directory. When that host will rebuild the system, it will look at the new kernel, kernel modules and initrd, if they changed, a reboot will occur immediately after reporting a successful upgrade.  A kexec is used for UEFI systems for a faster reboot (this avoids BIOS and bootloader steps).

# Status report of the fleet

Use `bento status` to get a report of your fleet, all information are extracted from the logs files deposited after each update:

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

# Status list

- **sync pending**: no configuration file changed, only files specific to **Bento** changed
- **rebuild pending**: the local version has been updated and remote will need to run `nixos-rebuild`
- **up to date**: no difference between the local configuration and what the remote system is running
- **extra logs**: the update process has been run more than once, this shouldn't happen. The most common case is that the update service has been started again manually.
- **failing**: the update process failed
- **rollbacked**: the update process failed, but a rollback has been done to previous version. **Bento** won't try to update until a new configuration is available.

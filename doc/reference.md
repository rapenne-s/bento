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

# Track each host state

As each host is sending a log upon rebuild to tell if it failed or succeeded, we can use this file to check what happened since the sftp file `last_time_changed` was created.

Using `bento status` you can track the current state of each hosts (time since last update, current NixOS version, status report)

[![asciicast](https://asciinema.org/a/520504.svg)](https://asciinema.org/a/520504)

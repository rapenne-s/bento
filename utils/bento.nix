{
  lib,
  pkgs,
  ...
}: let
  timer = "*:0/15";
in {
  systemd.timers.bento-upgrade = {
    enable = true;
    timerConfig = {
      OnCalendar = "${timer}";
      Unit = "bento-upgrade.service";
    };
    wantedBy = ["timers.target"];
    after = ["network-online.target"];
  };

  systemd.services.bento-upgrade = {
    enable = true;
    path = with pkgs; [openssh git nixos-rebuild nix gzip];
    serviceConfig.Type = "oneshot";
    script = ''
      cd /var/bento
      /bin/sh update.sh
    '';
  };
}

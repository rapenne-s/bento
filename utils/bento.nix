{
  lib,
  pkgs,
  ...
}: let
  timer = "*:0/15";
in {
  systemd.services.bento-upgrade = {
    enable = true;
    startAt = lib.mkDefault "${timer}";
    path = with pkgs; [openssh git nixos-rebuild nix gzip];
    serviceConfig.Type = "oneshot";
    script = ''
      cd /var/bento
      /bin/sh update.sh
    '';
    restartIfChanged = false;
  };

  systemd.sockets.listen-update = {
    enable = true;
    wantedBy = ["sockets.target"];
    requires = ["network.target"];
    listenStreams = ["51337"];
    socketConfig.Accept = "yes";
  };

  systemd.services."listen-update@" = {
    path = with pkgs; [systemd];
    enable = true;
    serviceConfig.StandardInput = "socket";
    serviceConfig.ExecStart = "${pkgs.systemd.out}/bin/systemctl start bento-upgrade.service";
    serviceConfig.ExecStartPost = "${pkgs.systemd.out}/bin/journalctl -f --no-pager -u bento-upgrade.service";
  };
}

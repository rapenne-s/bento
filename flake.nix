{
  description = "bento: an asynchronous NixOS deployment tool";

  inputs.nixpkgs.url = github:NixOS/nixpkgs/nixos-22.05;

  outputs = { self, nixpkgs }: {

    packages.x86_64-linux.default =
      with import nixpkgs { system = "x86_64-linux"; };

      stdenv.mkDerivation {
        name = "bento";
        src = self;

        patchPhase = ''
            substituteInPlace bento --replace 'inotifywait' "${pkgs.inotify-tools}/bin/inotifywait";
        '';

        installPhase = ''
          mkdir -p $out/bin
          mkdir -p $out/share
          install -Dm555 bento $out/bin/
          install -Dm444 fleet.nix $out/share/
          install -Dm444 config.sh.sample $out/share/
          install -Dm444 LICENSE $out/share/
          install -Dm444 README.md $out/share/
          install -Dm444 utils/bento.nix $out/share/
        '';
      };
  };
}

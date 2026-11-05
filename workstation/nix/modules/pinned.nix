{ pkgs, ... }:
let
  locked = (builtins.fromJSON (builtins.readFile ../flake.lock)).nodes.nixpkgs.locked;
  source = builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/${locked.rev}.tar.gz";
    sha256 = locked.narHash;
  };
  applicationPkgs = import source {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfreePredicate = p:
      builtins.elem (pkgs.lib.getName p) [ "chitubox" "chitubox-basic" ];
  };
in {
  imports = [ ./three-d.nix ];
  programs.threeD.packageSet = applicationPkgs;
}

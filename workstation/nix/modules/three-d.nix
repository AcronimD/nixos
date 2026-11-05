{ config, lib, pkgs, ... }:
let
  cfg = config.programs.threeD;
  appPkgs = cfg.packageSet;
  chitubox = appPkgs.callPackage ../packages/chitubox.nix { };
in {
  options.programs.threeD.enable = lib.mkEnableOption "Blender, Cura and CHITUBOX";
  options.programs.threeD.packageSet = lib.mkOption {
    type = lib.types.raw;
    default = pkgs;
    internal = true;
    description = "Package set used for the three applications and their wrappers.";
  };
  config = lib.mkIf cfg.enable {
    assertions = [ {
      assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
      message = "This Cura/CHITUBOX distribution requires x86_64-linux.";
    } ];
    nixpkgs.config.allowUnfreePredicate = p: builtins.elem (lib.getName p) [ "chitubox" "chitubox-basic" ];
    hardware.graphics.enable = true;
    environment.systemPackages = [
      (appPkgs.callPackage ../packages/blender-compat.nix { })
      appPkgs.cura-appimage
      chitubox
    ];
  };
}


{ lib, pkgs, ... }:
{
  programs.threeD.enable = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  virtualisation.virtualbox.guest.enable = true;
  # Work around expedited RCU stalls seen with this Linux/VirtualBox combination.
  boot.kernelParams = [ "rcupdate.rcu_normal=1" ];
  # VBoxService loads crypt_r dynamically; without this Guest Control cannot log in.
  systemd.services.virtualbox.environment.LD_LIBRARY_PATH =
    lib.makeLibraryPath [ pkgs.libxcrypt ];
}

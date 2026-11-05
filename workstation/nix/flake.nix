{
  description = "Reproducible Blender, Cura and CHITUBOX workstation";

  # Match the NixOS installation instead of upgrading the whole operating system.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/da6dc0e7b26060f2f71ce3ef7088fb56ee44fa36";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
    in {
      packages.${system} = {
        blender = pkgs.callPackage ./packages/blender-compat.nix { };
        cura = pkgs.cura-appimage;
        chitubox = pkgs.callPackage ./packages/chitubox.nix { };
      };
      nixosModules.default = import ./modules/three-d.nix;
      # Pins the applications without replacing the host's nixpkgs input.
      nixosModules.pinned = import ./modules/pinned.nix;
      nixosConfigurations.nixos-vm = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./hosts/nixos-vm/configuration.nix
          self.nixosModules.default
          ./hosts/nixos-vm/virtualbox.nix
        ];
      };
    };
}

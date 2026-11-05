#!/usr/bin/env bash
# Install the portable module into an existing NixOS configuration.
set -euo pipefail
export PATH=/run/current-system/sw/bin:/run/wrappers/bin:${PATH:-}
usage() {
  cat <<'EOF'
Usage: sudo bash scripts/install.sh [--prepare-only | --build-only] [--config-dir DIR]
Default: back up /etc/nixos, add the module, build and switch the existing host.
--prepare-only: copy pinned application sources; print the import to add manually.
               Use this for flake-managed or symlinked configurations.
--build-only: integrate and build, without activating the generation.
--config-dir: configuration directory (default /etc/nixos); custom paths require
              --build-only or --prepare-only and are useful for isolated checks.
EOF
}
die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
mode=switch
config_dir=/etc/nixos
while (($#)); do
  case "$1" in
    --prepare-only) mode=prepare; shift ;;
    --build-only) mode=build; shift ;;
    --config-dir) (($# >= 2)) || die '--config-dir needs a directory'; config_dir=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done
[[ $(id -u) == 0 ]] || die 'Run with sudo bash scripts/install.sh'
[[ -e /etc/NIXOS ]] || die 'This installer requires an already installed NixOS.'
[[ $(uname -m) == x86_64 ]] || die 'The vendor applications require x86_64-linux.'
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ -f "$project/nix/modules/pinned.nix" ]] || die 'The project checkout is incomplete.'
config_dir=$(realpath -e -- "$config_dir")
[[ -d "$config_dir" ]] || die 'Configuration directory does not exist.'
[[ $config_dir == /etc/nixos || $mode != switch ]] || die 'Custom directories cannot be activated automatically.'
config=$config_dir/configuration.nix
original=$config_dir/configuration.before-workstation.nix
destination=$config_dir/workstation-apps
[[ -f "$config" ]] || die "Missing $config"
if [[ $mode != prepare ]]; then
  [[ ! -e "$config_dir/flake.nix" ]] || die 'A flake.nix exists. Use --prepare-only and import the module in your host flake.'
  [[ ! -L "$config" && ! -L "$original" ]] || die 'Symlinked configuration: use --prepare-only and integrate manually.'
  # Preserve the host package source. Non-login systemd/sudo environments may lack NIX_PATH.
  if host_nixpkgs=$(nix-instantiate --find-file nixpkgs 2>/dev/null); then
    :
  elif [[ -d /nix/var/nix/profiles/per-user/root/channels/nixos/nixos ]]; then
    host_nixpkgs=$(readlink -f /nix/var/nix/profiles/per-user/root/channels/nixos)
  else
    die 'Host nixpkgs was not found. Use --prepare-only and your existing host rebuild command.'
  fi
  [[ -d "$host_nixpkgs/nixos" ]] || die 'The host nixpkgs path lacks the NixOS module tree.'
fi
[[ ! -L "$destination" ]] || die 'Refusing to overwrite a symlinked application directory.'
if [[ -e "$destination" && ! -f "$destination/.managed-by-nixos-3d" ]]; then
  die "Unmanaged destination exists: $destination"
fi
wrapper=$(mktemp)
trap 'rm -f -- "$wrapper"' EXIT
cat > "$wrapper" <<'EOF'
# Managed entry point: NixOS 3D workstation installer.
# Edit configuration.before-workstation.nix for host settings.
{ ... }: {
  imports = [
    ./configuration.before-workstation.nix
    ./workstation-apps/module.nix
  ];
}
EOF
if [[ $mode != prepare && -e "$original" ]]; then
  cmp -s "$config" "$wrapper" || die 'The managed entry point changed. Use --prepare-only or integrate manually.'
fi
if [[ $mode != prepare && ! -e "$original" ]]; then
  # Avoid integrating twice into the original development VM or another managed host.
  if grep -Eq 'three-d\.nix|workstation-apps/module\.nix|3d-workstation/' "$config"; then
    die 'This host already imports this project. Follow its existing flake/module update procedure.'
  fi
fi
stamp=$(date +%Y%m%d-%H%M%S)
# A fresh NixOS installation may not have /var/backups yet.
mkdir -p -- /var/backups
backup=$(mktemp -d "/var/backups/nixos-3d-github-$stamp-XXXXXX")
cp -a -- "$config_dir" "$backup/configuration"
exec > >(tee "$backup/install.log") 2>&1
printf 'Backup: %s\n' "$backup/configuration"
mkdir -p "$destination/nix"
cp -R -- "$project/nix/." "$destination/nix/"
touch "$destination/.managed-by-nixos-3d"
cat > "$destination/module.nix" <<'EOF'
{ ... }: {
  imports = [ ./nix/modules/pinned.nix ];
  programs.threeD.enable = true;
}
EOF
printf 'Pinned application module: %s/module.nix\n' "$destination"
if [[ $mode == prepare ]]; then
  printf 'Add ./workstation-apps/module.nix to your NixOS imports, then rebuild using your existing host configuration.\n'
  exit 0
fi
if [[ ! -e "$original" ]]; then
  # Keep the file beside its original imports; relative hardware paths still work.
  cp -a -- "$config" "$original"
  install -m 0644 "$wrapper" "$config"
fi
printf '+ nixos-rebuild build -I nixos-config=%s\n' "$config"
cd "$backup"
nixos-rebuild build -I "nixpkgs=$host_nixpkgs" -I "nixos-config=$config"
if [[ $mode == build ]]; then
  echo 'BUILD_COMPLETE (no activation)'
  exit 0
fi
# VBox Guest Control may create a root login without a user bus.
if loginctl list-users --no-legend | grep -Eq '^ *0 '; then
  systemctl start user@0.service
fi
printf '+ nixos-rebuild switch -I nixos-config=%s\n' "$config"
nixos-rebuild switch -I "nixpkgs=$host_nixpkgs" -I "nixos-config=$config"
for app in blender cura chitubox; do
  test -x "/run/current-system/sw/bin/$app"
  test -f "/run/current-system/sw/share/applications/$app.desktop"
  printf 'INSTALLED_OK %s\n' "$app"
done
echo 'INSTALL_COMPLETE: open your desktop application menu.'

#!/usr/bin/env bash
# Run inside the existing project VM. Other machines must use their own hardware module.
set -euo pipefail
export PATH=/run/current-system/sw/bin:/run/wrappers/bin:$PATH
project=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test "$(id -u)" = 0 || { echo 'Run with sudo bash scripts/install-vm.sh'; exit 1; }
test -e /dev/disk/by-uuid/bfb3249e-d274-4a1a-aeaa-528aa1fd9575 || {
  echo 'This script targets the original VM only. See the repository README.md for installation on another system.'
  exit 1
}
stamp=$(date +%Y%m%d-%H%M%S)
backup="/var/backups/nixos-3d/$stamp"
mkdir -p "$backup" /etc/nixos/3d-workstation "$project/logs"
cp -a /etc/nixos/. "$backup/"
cp -R "$project/nix/." /etc/nixos/3d-workstation/
export NIX_CONFIG='experimental-features = nix-command flakes'
cd /etc/nixos/3d-workstation
exec > >(tee "$project/logs/install-$stamp.log") 2>&1
set -x
echo "Configuration backup: $backup"
nixos-rebuild build --flake .#nixos-vm
# Guest Control creates a root login without a user bus; activation needs that bus.
if loginctl list-users --no-legend | grep -Eq '^ *0 '; then
  systemctl start user@0.service
fi
cat > /etc/nixos/configuration.nix <<'EOF'
# The pinned flake is the recommended deployment entry point.
# Keep legacy nixos-rebuild invocations aware of the application modules too.
{ ... }: {
  imports = [
    ./3d-workstation/hosts/nixos-vm/configuration.nix
    ./3d-workstation/modules/three-d.nix
    ./3d-workstation/hosts/nixos-vm/virtualbox.nix
  ];
}
EOF
nixos-rebuild switch --flake .#nixos-vm
readlink -f /run/current-system
ls /run/current-system/sw/bin/{blender,cura,chitubox}
ls /run/current-system/sw/share/applications/{blender,cura,chitubox}.desktop
echo INSTALL_COMPLETE

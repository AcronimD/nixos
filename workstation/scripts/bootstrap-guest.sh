#!/usr/bin/env bash
set -euo pipefail
project=/media/sf_nixos-project
test "$(id -u)" = 0
test -d "$project/logs"
exec > >(tee "$project/logs/bootstrap-guest.log") 2>&1
set -x
mkdir -p "$project/hosts/nixos-vm" "$project/logs/original"
cp -n /etc/nixos/configuration.nix "$project/logs/original/configuration.nix"
cp -n /etc/nixos/hardware-configuration.nix "$project/logs/original/hardware-configuration.nix"
cat /etc/os-release
nixos-version
df -h / /nix/store
id alex
nix-channel --list
readlink -f /nix/var/nix/profiles/per-user/root/channels/nixos
journalctl -b -u virtualbox --no-pager -n 100 > "$project/logs/guestcontrol-before.log"

# VBoxService dlopens libcrypt; its package does not currently expose the path.
# A runtime-only systemd drop-in lasts until reboot. The final VM module will
# express the dependency declaratively if this workaround succeeds.
libdirs=()
for f in /nix/store/*-libxcrypt-*/lib/libcrypt.so.* /nix/store/*-libxcrypt-legacy-*/lib/libcrypt.so.* /nix/store/*-linux-pam-*/lib/libpam.so.*; do
  if test -e "$f"; then libdirs+=("$(dirname "$f")"); fi
done
test "${#libdirs[@]}" -gt 0
library_path=$(IFS=:; echo "${libdirs[*]}")
mkdir -p /run/systemd/system/virtualbox.service.d
printf '[Service]\nEnvironment="LD_LIBRARY_PATH=%s"\n' "$library_path" > /run/systemd/system/virtualbox.service.d/project-libraries.conf
systemctl daemon-reload
systemctl restart virtualbox.service
systemctl --no-pager status virtualbox.service
echo BOOTSTRAP_COMPLETE

#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Archiso container build failed at line $LINENO" >&2' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/work"
OUT="$ROOT/out"
PROFILE="$ROOT/profile"

[[ "$(uname -m)" == "x86_64" ]] || { echo "This ISO build requires x86_64." >&2; exit 1; }

# Prevent concurrent builds from racing over the package database.
if command -v flock >/dev/null 2>&1; then
  exec 9>/tmp/igorcoin-archiso-build.lock
  flock -n 9 || { echo "Another IgorCoin-Qortal ISO build is already running." >&2; exit 1; }
fi

rm -rf "$WORK" "$OUT" "$PROFILE"
mkdir -p "$WORK" "$OUT"

FREE_KB="$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')"
[[ -n "$FREE_KB" && "$FREE_KB" -ge 12582912 ]] || {
  echo "At least 12 GiB free space is required for the build." >&2
  exit 1
}

echo "==> Refreshing official Arch package databases and keyring"
pacman -Sy --noconfirm archlinux-keyring
pacman -Syu --noconfirm archiso curl grub

echo "==> Starting from the current official Archiso releng profile"
cp -a /usr/share/archiso/configs/releng "$PROFILE"

# Keep upstream releng's full package set and add only curl for the Qortal script.
cat "$ROOT/packages.x86_64" >> "$PROFILE/packages.x86_64"
awk 'NF && $1 !~ /^#/ {print $1}' "$PROFILE/packages.x86_64" | sort -u > "$PROFILE/packages.x86_64.tmp"
mv "$PROFILE/packages.x86_64.tmp" "$PROFILE/packages.x86_64"

# Override only the upstream ISO identity/metadata and retain official boot defaults.
cp "$ROOT/profiledef.sh" "$PROFILE/profiledef.sh"
cp "$ROOT/pacman.conf" "$PROFILE/pacman.conf"

# Keep the existing Qortal installer script unchanged and make it available
# in the standard Arch live shell as: igorcoin-qortal-install
install -Dm755 "$ROOT/../scripts/install-qortal.sh" \
  "$PROFILE/airootfs/usr/local/bin/igorcoin-qortal-install"

# Enable NetworkManager in the live environment so Wi-Fi works after boot.
install -d "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sfn /usr/lib/systemd/system/NetworkManager.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"

# Enable Bluetooth where supported.
ln -sfn /usr/lib/systemd/system/bluetooth.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/bluetooth.service"

# Add the Estonian-flag default wallpaper to the live image.
install -Dm644 "$ROOT/../assets/estonia-default.svg" \
  "$PROFILE/airootfs/usr/share/backgrounds/igorcoin/estonia-default.svg"
install -Dm755 "$ROOT/../scripts/set-wallpaper.sh" \
  "$PROFILE/airootfs/usr/local/bin/igorcoin-set-wallpaper"

# Add the Wi-Fi-first installer launchers.
install -Dm755 "$ROOT/../scripts/igorcoin-install.sh" \
  "$PROFILE/airootfs/usr/local/bin/igorcoin-install"
install -Dm755 "$ROOT/../scripts/igorcoin-qortal-install.sh" \
  "$PROFILE/airootfs/usr/local/bin/igorcoin-qortal-install"

echo "==> Building branded image using official Archiso releng"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

ISO="$(find "$OUT" -maxdepth 1 -type f -name 'igorcoin-qortal-os-*.iso' -print -quit)"
if [[ -z "$ISO" ]]; then
  ISO="$(find "$OUT" -maxdepth 1 -type f -name '*.iso' -print -quit)"
fi
[[ -n "$ISO" && -s "$ISO" ]] || { echo "Archiso did not produce a non-empty ISO." >&2; exit 1; }
if [[ "$ISO" != "$OUT/amd.iso" ]]; then
  mv "$ISO" "$OUT/amd.iso"
fi

file "$OUT/amd.iso"
xorriso -indev "$OUT/amd.iso" -pvd_info >/dev/null
(cd "$OUT" && sha256sum amd.iso > amd.iso.sha256)
sha256sum --check "$OUT/amd.iso.sha256"
echo "Branded Archiso image built and checksum verified."

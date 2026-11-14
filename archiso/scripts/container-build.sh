#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Archiso container build failed at line $LINENO" >&2' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/work"
OUT="$ROOT/out"
PROFILE="$ROOT/profile"

[[ "$(uname -m)" == "x86_64" ]] || { echo "This ISO build requires x86_64." >&2; exit 1; }
mkdir -p "$WORK" "$OUT"
FREE_KB="$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')"
[[ -n "$FREE_KB" && "$FREE_KB" -ge 12582912 ]] || {
  echo "At least 12 GiB free space is required for the build." >&2
  exit 1
}

echo "==> Refreshing Arch keyring and packages"
pacman -Sy --noconfirm archlinux-keyring
pacman -Syu --noconfirm
pacman -S --needed --noconfirm archiso base-devel git curl jq sudo grub \
  squashfs-tools dosfstools mtools xorriso libisoburn e2fsprogs btrfs-progs

echo "==> Recording the latest GRUB version from the official Arch repositories"
GRUB_VERSION="$(grub-install --version)"
echo "$GRUB_VERSION"
printf '%s\\n' "$GRUB_VERSION" > "$OUT/grub-version.txt"

echo "==> Preparing official Archiso releng profile"
rm -rf "$PROFILE"
cp -a /usr/share/archiso/configs/releng "$PROFILE"
cp "$ROOT/profiledef.sh" "$PROFILE/profiledef.sh"
cp "$ROOT/packages.x86_64" "$PROFILE/packages.x86_64"
cp "$ROOT/pacman.conf" "$PROFILE/pacman.conf"
rm -rf "$PROFILE/grub"
cp -a "$ROOT/grub" "$PROFILE/grub"
cp -a "$ROOT/airootfs/." "$PROFILE/airootfs/"
chmod 0755 "$PROFILE/airootfs/root/customize_airootfs.sh"
chmod 0440 "$PROFILE/airootfs/etc/sudoers.d/99-liveuser"

echo "==> Building IgorCoin-Qortal OS Live ISO"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

ISO="$(find "$OUT" -maxdepth 1 -type f -name 'igorcoin-qortal-os-*.iso' -print -quit)"
if [[ -z "$ISO" ]]; then
  ISO="$(find "$OUT" -maxdepth 1 -type f -name '*.iso' -print -quit)"
fi
test -n "$ISO"
if [[ "$ISO" != "$OUT/amd.iso" ]]; then
  mv "$ISO" "$OUT/amd.iso"
fi
file "$OUT/amd.iso"
(cd "$OUT" && sha256sum amd.iso > amd.iso.sha256)
echo "ISO built. This workflow does not yet sign the boot chain for Secure Boot."

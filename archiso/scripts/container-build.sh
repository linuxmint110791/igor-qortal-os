#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Archiso container build failed at line $LINENO" >&2' ERR
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/work"
OUT="$ROOT/out"
PROFILE="$ROOT/profile"
LOCALREPO=/tmp/igorcoin-localrepo

pacman -Syu --noconfirm
pacman -S --needed --noconfirm archiso base-devel git curl jq sudo squashfs-tools dosfstools e2fsprogs btrfs-progs libisoburn

KERNEL_VERSION="$(pacman -Si linux | awk -F': ' '/^Version/ {print $2; exit}')"
case "$KERNEL_VERSION" in
  7.3.4*) echo "Verified Arch kernel package: $KERNEL_VERSION" ;;
  *) echo "Expected Linux 7.3.4, repository offers: $KERNEL_VERSION" >&2; exit 1 ;;
esac

# Calamares is built from AUR as an unprivileged makepkg user.
id builder >/dev/null 2>&1 || useradd -m -G wheel builder
printf 'builder ALL=(ALL) NOPASSWD: /usr/bin/pacman\n' > /etc/sudoers.d/90-builder
chmod 0440 /etc/sudoers.d/90-builder
install -d -o builder -g builder /tmp/calamares-build
sudo -u builder git clone https://aur.archlinux.org/calamares.git /tmp/calamares-build
cd /tmp/calamares-build
sudo -u builder makepkg --syncdeps --noconfirm
install -d "$LOCALREPO"
cp ./*.pkg.tar.zst "$LOCALREPO/"
repo-add "$LOCALREPO/igorcoin.db.tar.gz" "$LOCALREPO"/*.pkg.tar.zst

mkdir -p "$WORK" "$OUT"
rm -rf "$PROFILE"
cp -a /usr/share/archiso/configs/releng "$PROFILE"
cp "$ROOT/profiledef.sh" "$PROFILE/profiledef.sh"
cp "$ROOT/packages.x86_64" "$PROFILE/packages.x86_64"
cp "$ROOT/pacman.conf" "$PROFILE/pacman.conf"
cp -a "$ROOT/airootfs/." "$PROFILE/airootfs/"
chmod 0755 "$PROFILE/airootfs/root/customize_airootfs.sh"
chmod 0440 "$PROFILE/airootfs/etc/sudoers.d/99-liveuser"

# Temporary repository provides Calamares to mkarchiso.
sed -i '1i[igorcoin]\nServer = file:///tmp/igorcoin-localrepo' "$PROFILE/pacman.conf"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"
ISO="$(find "$OUT" -maxdepth 1 -type f -name '*.iso' -print -quit)"
test -n "$ISO"
mv "$ISO" "$OUT/igorcoin-qortal-os-x86_64.iso"
sha256sum "$OUT/igorcoin-qortal-os-x86_64.iso" | tee "$OUT/igorcoin-qortal-os-x86_64.iso.sha256"

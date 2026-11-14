#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Archiso container build failed at line $LINENO" >&2' ERR
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/work"
OUT="$ROOT/out"
PROFILE="$ROOT/profile"
LOCALREPO=/tmp/igorcoin-localrepo

echo "==> Preflight: architecture, disk space and build tools"
[[ "$(uname -m)" == "x86_64" ]] || { echo "This ISO build requires x86_64." >&2; exit 1; }
mkdir -p "$WORK" "$OUT"
FREE_KB="$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')"
[[ -n "$FREE_KB" && "$FREE_KB" -ge 15728640 ]] || {
  echo "At least 15 GiB free space is required in the build volume." >&2
  exit 1
}
for tool in pacman mkarchiso xorriso mksquashfs mformat mkfs.fat; do
  command -v "$tool" >/dev/null 2>&1 || echo "Will install required build utility: $tool"
done

echo "==> Updating Arch rolling base (cached package downloads are reused)"
pacman -Syu --noconfirm
pacman -S --needed --noconfirm archiso base-devel git curl jq sudo \
  squashfs-tools dosfstools mtools xorriso libisoburn e2fsprogs btrfs-progs

for tool in mkarchiso xorriso mksquashfs mformat mkfs.fat; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required utility after installation: $tool" >&2; exit 1; }
done

KERNEL_VERSION="$(pacman -Si linux | awk -F': ' '/^Version/ {print $2; exit}')"
HEADER_VERSION="$(pacman -Si linux-headers | awk -F': ' '/^Version/ {print $2; exit}')"
[[ "$HEADER_VERSION" == "$KERNEL_VERSION" ]] || { echo "Kernel/header version mismatch: $KERNEL_VERSION vs $HEADER_VERSION" >&2; exit 1; }
echo "Using current Arch rolling kernel: $KERNEL_VERSION"

# Build Calamares from AUR as an unprivileged makepkg user.
id builder >/dev/null 2>&1 || useradd -m -G wheel builder
printf 'builder ALL=(ALL) NOPASSWD: /usr/bin/pacman\n' > /etc/sudoers.d/90-builder
chmod 0440 /etc/sudoers.d/90-builder
install -d -o builder -g builder /tmp/calamares-build
sudo -u builder git clone --depth 1 https://aur.archlinux.org/calamares.git /tmp/calamares-build
cd /tmp/calamares-build
sudo -u builder makepkg --syncdeps --noconfirm
install -d "$LOCALREPO"
cp ./*.pkg.tar.zst "$LOCALREPO/"
repo-add "$LOCALREPO/igorcoin.db.tar.gz" "$LOCALREPO"/*.pkg.tar.zst

rm -rf "$PROFILE"
cp -a /usr/share/archiso/configs/releng "$PROFILE"
cp "$ROOT/profiledef.sh" "$PROFILE/profiledef.sh"
cp "$ROOT/packages.x86_64" "$PROFILE/packages.x86_64"
cp "$ROOT/pacman.conf" "$PROFILE/pacman.conf"
cp -a "$ROOT/airootfs/." "$PROFILE/airootfs/"
chmod 0755 "$PROFILE/airootfs/root/customize_airootfs.sh"
chmod 0440 "$PROFILE/airootfs/etc/sudoers.d/99-liveuser"

# The local, unsigned Calamares repository is confined to this disposable container.
printf '\n[igorcoin]\nSigLevel = Optional TrustAll\nServer = file:///tmp/igorcoin-localrepo\n' >> "$PROFILE/pacman.conf"

echo "==> Building bootable x86_64 Live ISO"
mkarchiso -v -w "$WORK" -o "$OUT" "$PROFILE"

ISO="$(find "$OUT" -maxdepth 1 -type f -name '*.iso' -print -quit)"
test -n "$ISO"
mv "$ISO" "$OUT/igorcoin-qortal-os-x86_64.iso"
sha256sum "$OUT/igorcoin-qortal-os-x86_64.iso" | tee "$OUT/igorcoin-qortal-os-x86_64.iso.sha256"
chown -R "${HOST_UID:-1001}:${HOST_GID:-121}" "$WORK" "$OUT" 2>/dev/null || true

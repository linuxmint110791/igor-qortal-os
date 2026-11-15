#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Archiso container build failed at line $LINENO" >&2' ERR

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/work"
OUT="$ROOT/out"
PROFILE="$ROOT/profile"

[[ "$(uname -m)" == "x86_64" ]] || { echo "This ISO build requires x86_64." >&2; exit 1; }

# Prevent two builds in the same container from racing over the pacman database.
if command -v flock >/dev/null 2>&1; then
  exec 9>/tmp/igorcoin-archiso-build.lock
  flock -n 9 || { echo "Another IgorCoin ISO build is already running." >&2; exit 1; }
fi

# Prefer Arch's global geo mirror; retain the distribution mirrorlist as fallback.
MIRRORLIST="/etc/pacman.d/mirrorlist"
if [[ -f "$MIRRORLIST" ]]; then
  MIRROR_TMP="$(mktemp)"
  grep -vF 'https://geo.mirror.pkgbuild.com/$repo/os/$arch' "$MIRRORLIST" > "$MIRROR_TMP" || true
  {
    printf '%s\n' '# IgorCoin-Qortal OS: global Arch mirror first'
    printf '%s\n' 'Server = https://geo.mirror.pkgbuild.com/$repo/os/$arch'
    cat "$MIRROR_TMP"
  } > "$MIRRORLIST"
  rm -f "$MIRROR_TMP"
fi

# The work directory is bind-mounted from the host. Old partial airootfs trees
# can leave a stale pacman db.lck behind, so start with a clean build workspace.
rm -rf "$WORK" "$OUT"
mkdir -p "$WORK" "$OUT"

FREE_KB="$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')"
[[ -n "$FREE_KB" && "$FREE_KB" -ge 12582912 ]] || {
  echo "At least 12 GiB free space is required for the build." >&2
  exit 1
}

# Force non-interactive confirmation for every pacman call made by this build,
# including pacstrap/mkarchiso package installation.
PACMAN_WRAPPER_DIR="$(mktemp -d)"
trap 'rm -rf "$PACMAN_WRAPPER_DIR"' EXIT
cat > "$PACMAN_WRAPPER_DIR/pacman" <<'PACMAN_WRAPPER'
#!/usr/bin/env bash
exec /usr/bin/pacman --noconfirm "$@"
PACMAN_WRAPPER
chmod 0755 "$PACMAN_WRAPPER_DIR/pacman"
export PATH="$PACMAN_WRAPPER_DIR:$PATH"

echo "==> Using global Arch mirror first; configured mirrors remain as fallback"
echo "==> Refreshing Arch keyring and packages (automatic confirmation enabled)"
pacman -Sy archlinux-keyring
pacman -Syu
pacman -S --needed archiso base-devel git curl jq sudo grub \
  squashfs-tools dosfstools mtools xorriso libisoburn e2fsprogs btrfs-progs

echo "==> Recording the latest GRUB version from the official Arch repositories"
GRUB_VERSION="$(grub-install --version)"
echo "$GRUB_VERSION"
printf '%s\n' "$GRUB_VERSION" > "$OUT/grub-version.txt"

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
[[ -n "$ISO" && -s "$ISO" ]] || { echo "Archiso did not produce a non-empty ISO." >&2; exit 1; }
if [[ "$ISO" != "$OUT/amd.iso" ]]; then
  mv "$ISO" "$OUT/amd.iso"
fi

file "$OUT/amd.iso"
xorriso -indev "$OUT/amd.iso" -pvd_info >/dev/null
(cd "$OUT" && sha256sum amd.iso > amd.iso.sha256)
sha256sum --check "$OUT/amd.iso.sha256"
echo "ISO built and verified. Secure Boot signing is not implemented."

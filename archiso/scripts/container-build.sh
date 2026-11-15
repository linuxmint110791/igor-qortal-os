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

# Remove Firefox from upstream releng: this OS ships without a web browser.
sed -i '/^firefox$/d' "$PROFILE/packages.x86_64"
# Add IgorCoin desktop and Qortal Hub dependencies.
cat "$ROOT/packages.x86_64" >> "$PROFILE/packages.x86_64"
awk 'NF && $1 !~ /^#/ {print $1}' "$PROFILE/packages.x86_64" | sort -u > "$PROFILE/packages.x86_64.tmp"
mv "$PROFILE/packages.x86_64.tmp" "$PROFILE/packages.x86_64"

# Override only the upstream ISO identity/metadata and retain official boot defaults.
cp "$ROOT/profiledef.sh" "$PROFILE/profiledef.sh"
cp "$ROOT/pacman.conf" "$PROFILE/pacman.conf"

# Keep the existing Qortal installer script unchanged and make it available
# in the standard Arch live shell as: igorcoin-qortal-install
install -Dm755 "$ROOT/../scripts/install-qortal.sh" \
  "$PROFILE/airootfs/usr/local/lib/igorcoin/install-qortal.sh"

# Download the official Qortal Hub Linux AppImage and verify its published SHA256.
QORTAL_HUB_URL="https://github.com/Qortal/Qortal-Hub/releases/download/v3.0.3/Qortal-Hub.AppImage"
QORTAL_HUB_SHA256="a5affb4c438d5c0934e438b5518b6955653420148cf599f1c690bce6e69394b8"
install -d "$PROFILE/airootfs/opt/qortal-hub"
curl -fL --retry 3 "$QORTAL_HUB_URL" -o "$PROFILE/airootfs/opt/qortal-hub/Qortal-Hub.AppImage"
echo "$QORTAL_HUB_SHA256  $PROFILE/airootfs/opt/qortal-hub/Qortal-Hub.AppImage" | sha256sum --check
chmod 755 "$PROFILE/airootfs/opt/qortal-hub/Qortal-Hub.AppImage"

# Enable NetworkManager in the live environment so Wi-Fi works after boot.
install -d "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants"
ln -sfn /usr/lib/systemd/system/NetworkManager.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"

# Enable Bluetooth where supported.
if [[ -f /usr/lib/systemd/system/bluetooth.service ]]; then
  ln -sfn /usr/lib/systemd/system/bluetooth.service \
    "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/bluetooth.service"
fi

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

# Native Qortal Hub desktop launcher (not a browser shortcut).
install -Dm644 "$ROOT/../desktop/qortal-hub.desktop" "$PROFILE/airootfs/usr/share/applications/qortal-hub.desktop"

# KDE menu launchers and default wallpaper application on first Plasma start.
install -Dm644 "$ROOT/../desktop/igorcoin-installer.desktop" \
  "$PROFILE/airootfs/usr/share/applications/igorcoin-installer.desktop"
install -Dm644 "$ROOT/../desktop/igorcoin-qortal.desktop" \
  "$PROFILE/airootfs/usr/share/applications/igorcoin-qortal.desktop"
install -Dm644 "$ROOT/../desktop/arch-terminal.desktop" \
  "$PROFILE/airootfs/usr/share/applications/arch-terminal.desktop"

# Put clickable installer and terminal icons directly on the live user's desktop.
install -d "$PROFILE/airootfs/etc/skel/Desktop"
install -m755 "$ROOT/../desktop/igorcoin-installer.desktop" \
  "$PROFILE/airootfs/etc/skel/Desktop/Install-IgorCoin-Qortal-OS.desktop"
install -m755 "$ROOT/../desktop/arch-terminal.desktop" \
  "$PROFILE/airootfs/etc/skel/Desktop/Arch-Terminal.desktop"
install -m755 "$ROOT/../desktop/igorcoin-qortal.desktop" \
  "$PROFILE/airootfs/etc/skel/Desktop/Install-Qortal.desktop"
install -m755 "$ROOT/../desktop/qortal-hub.desktop" \
  "$PROFILE/airootfs/etc/skel/Desktop/Qortal-Hub.desktop"

install -Dm755 "$ROOT/../scripts/set-wallpaper.sh" \
  "$PROFILE/airootfs/usr/local/bin/igorcoin-set-wallpaper"
install -d "$PROFILE/airootfs/etc/xdg/autostart"
cat > "$PROFILE/airootfs/etc/xdg/autostart/igorcoin-wallpaper.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Name=IgorCoin default wallpaper
Exec=/usr/local/bin/igorcoin-set-wallpaper
OnlyShowIn=KDE;
EOF

# SDDM starts KDE Plasma in the graphical live session.
ln -sfn /usr/lib/systemd/system/sddm.service \
  "$PROFILE/airootfs/etc/systemd/system/display-manager.service"
ln -sfn /usr/lib/systemd/system/NetworkManager.service \
  "$PROFILE/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"

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
(cd "$OUT" && sha256sum amd.iso > amd.iso.sha256 && sha256sum --check amd.iso.sha256)
echo "Branded Archiso image built and checksum verified."

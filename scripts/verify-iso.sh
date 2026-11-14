#!/usr/bin/env bash
set -Eeuo pipefail

ISO_FILE="${1:-}"
if [[ -z "$ISO_FILE" || ! -s "$ISO_FILE" ]]; then
  echo "Usage: $0 /path/to/igorcoin-qortal-os.iso" >&2
  exit 2
fi

for tool in xorriso unsquashfs file; do
  command -v "$tool" >/dev/null 2>&1 || {
    echo "Required ISO verification tool is missing: $tool" >&2
    exit 1
  }
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
SQUASHFS="$TMP_DIR/filesystem.squashfs"
ROOTFS="$TMP_DIR/rootfs"

echo "==> Checking ISO format and boot catalog"
file "$ISO_FILE"
xorriso -indev "$ISO_FILE" -report_el_torito plain

echo "==> Extracting the live root filesystem"
xorriso -osirrox on -indev "$ISO_FILE" -extract /live/filesystem.squashfs "$SQUASHFS"
test -s "$SQUASHFS"
unsquashfs -s "$SQUASHFS"
unsquashfs -d "$ROOTFS" "$SQUASHFS" >/dev/null

check_file() {
  local path="$1"
  if [[ ! -s "$ROOTFS/$path" ]]; then
    echo "ISO is missing required file: /$path" >&2
    exit 1
  fi
  echo "OK: /$path"
}

echo "==> Checking systemd and Qortal services"
check_file usr/lib/systemd/systemd
check_file usr/bin/systemctl
check_file etc/systemd/system/igorcoin-auto-update.timer
check_file etc/systemd/system/igorcoin-auto-update.service
check_file etc/systemd/system/igorcoin-reticulum.service
check_file usr/local/bin/igor-install-qortal
check_file usr/local/bin/igorcoin-reticulum
check_file usr/local/bin/igorcoin-network-tray
check_file opt/reticulum-venv/bin/rnsd

echo "==> Checking Debian 13 AMD64 kernel"
KERNEL_IMAGE="$(find "$ROOTFS/boot" -maxdepth 1 -type f -name 'vmlinuz-*' -printf '%f\n' | sort -V | tail -n 1)"
if [[ -z "$KERNEL_IMAGE" ]]; then
  echo "ISO does not contain a Linux kernel image in /boot." >&2
  exit 1
fi
KERNEL_VERSION="${KERNEL_IMAGE#vmlinuz-}"
case "$KERNEL_VERSION" in
  *+deb13-amd64) ;;
  *)
    echo "Expected a Debian 13 AMD64 kernel, found: $KERNEL_VERSION" >&2
    exit 1
    ;;
esac
check_file "boot/$KERNEL_IMAGE"
check_file "lib/modules/$KERNEL_VERSION/modules.dep"

echo "==> Checking Qortal desktop branding and installer"
check_file usr/share/pixmaps/qortal-logo.png
check_file etc/calamares/branding/igorcoin/branding.desc
check_file etc/calamares/branding/igorcoin/show.qml
check_file etc/calamares/branding/igorcoin/qortal-logo.png
check_file etc/calamares/branding/igorcoin/qortal-wallet-qr.png
check_file etc/calamares/settings.conf
grep -Eq '^branding:[[:space:]]*igorcoin$' "$ROOTFS/etc/calamares/settings.conf" || {
  echo "Calamares is not configured to use Igorcoin branding." >&2
  exit 1
}
check_file usr/share/backgrounds/igorcoin-qortal/igorcoin-qortal-desktop.jpg
check_file usr/share/color-schemes/Igorcoin-Qortal.colors
check_file usr/share/sddm/themes/breeze/theme.conf.user
check_file etc/sddm.conf.d/10-igorcoin-qortal.conf
check_file etc/skel/.config/plasma-org.kde.plasma.desktop-appletsrc
check_file usr/bin/plasma-systemmonitor
check_file usr/share/plasma/plasmoids/org.kde.plasma.systemmonitor/metadata.json
check_file usr/share/applications/igorcoin-system-monitor.desktop
check_file usr/share/applications/qortal-website.desktop
check_file usr/share/applications/qortal-hub.desktop
check_file usr/bin/neowofetch
check_file usr/local/bin/neofetch
check_file usr/local/bin/igorcoin-terminal-ticker
check_file etc/skel/.config/tmux/tmux.conf
check_file usr/bin/tmux
check_file usr/share/konsole/Igorcoin-Green.colorscheme
check_file etc/skel/.local/share/konsole/Igorcoin-Qortal.profile
check_file etc/skel/.config/konsolerc
check_file usr/share/backgrounds/igorcoin-qortal/qortal-dark.jpg
check_file usr/share/backgrounds/igorcoin-qortal/qortal-extra-dark.jpg
check_file usr/share/backgrounds/igorcoin-qortal/qortal-light.jpg
check_file usr/share/backgrounds/igorcoin-qortal/qortal-future.png
check_file usr/share/wallpapers/Igorcoin-Qortal/metadata.json
check_file etc/xdg/kdeglobals
check_file usr/share/sounds/freedesktop/stereo/dialog-information.oga

echo "==> Verifying wallet QR contents"
if command -v zbarimg >/dev/null 2>&1; then
  decoded="$(zbarimg --quiet --raw "$ROOTFS/etc/calamares/branding/igorcoin/qortal-wallet-qr.png")"
  [[ "$decoded" == "QZwfPesnDjvE4S3baXHDbFN5UZZAifqaSZ" ]] || {
    echo "Wallet QR does not match the configured QORT address." >&2
    exit 1
  }
fi

echo "ISO structural verification passed."

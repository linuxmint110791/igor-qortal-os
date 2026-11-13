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

echo "==> Checking ISO format and boot catalog"
file "$ISO_FILE"
xorriso -indev "$ISO_FILE" -report_el_torito plain

echo "==> Extracting the live root filesystem"
xorriso -osirrox on -indev "$ISO_FILE" \
  -extract /live/filesystem.squashfs "$SQUASHFS"
test -s "$SQUASHFS"
unsquashfs -s "$SQUASHFS"

check_file() {
  local path="$1"
  if ! unsquashfs -cat "$SQUASHFS" "$path" >/dev/null 2>&1; then
    echo "ISO is missing required file: /$path" >&2
    exit 1
  fi
  echo "OK: /$path"
}

echo "==> Checking the systemd init system"
check_file usr/lib/systemd/systemd
check_file usr/bin/systemctl
check_file etc/systemd/system/igorcoin-auto-update.timer
check_file etc/systemd/system/igorcoin-auto-update.service
check_file etc/systemd/system/igorcoin-reticulum.service

echo "==> Checking Igorcoin/Qortal components"
check_file usr/local/bin/igor-install-qortal
check_file usr/local/bin/igorcoin-reticulum
check_file usr/local/bin/igorcoin-network-tray
check_file opt/reticulum-venv/bin/rnsd
check_file usr/share/pixmaps/qortal-logo.png
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
check_file boot/vmlinuz-7.3.4+deb14-amd64
check_file lib/modules/7.3.4+deb14-amd64/modules.dep
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

echo "ISO structural verification passed."

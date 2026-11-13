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

echo "ISO structural verification passed."

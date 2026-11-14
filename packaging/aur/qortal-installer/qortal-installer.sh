#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_URL="https://link.qortal.dev/linux-script"
APP_NAME="Qortal Installer"
TMP_SCRIPT=""

cleanup() {
  [[ -n "${TMP_SCRIPT:-}" && -f "$TMP_SCRIPT" ]] && rm -f "$TMP_SCRIPT"
}
trap cleanup EXIT

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

confirm_install() {
  local message="This downloads and runs the official Qortal Linux setup script from:\n\n${SCRIPT_URL}\n\nThe script installs Qortal Core and Qortal Hub, may install system packages, and may request sudo access. Continue?"
  if command -v kdialog >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    kdialog --title "$APP_NAME" --yesno "$message" || exit 0
  elif command -v zenity >/dev/null 2>&1 && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    zenity --question --title="$APP_NAME" --text="$message" || exit 0
  else
    printf '%b\n' "$message"
    read -r -p "Continue? [y/N] " answer
    [[ "$answer" =~ ^([yY]|[yY][eE][sS])$ ]] || exit 0
  fi
}

command -v curl >/dev/null 2>&1 || die "curl is required."
command -v bash >/dev/null 2>&1 || die "bash is required."
confirm_install

TMP_SCRIPT="$(mktemp "${TMPDIR:-/tmp}/qortal-setup.XXXXXXXX.sh")"
printf 'Downloading official Qortal installer…\n'
curl --fail --location --silent --show-error --proto '=https' --tlsv1.2 "$SCRIPT_URL" -o "$TMP_SCRIPT"
[[ -s "$TMP_SCRIPT" ]] || die "The downloaded installer is empty."
head -n 1 "$TMP_SCRIPT" | grep -q '^#!/.*bash' || die "Downloaded file does not look like a Bash installer."
printf '\nDownloaded script SHA-256: '
sha256sum "$TMP_SCRIPT" | awk '{print $1}'
printf '\nStarting official Qortal installer. Review its prompts carefully.\n\n'
bash "$TMP_SCRIPT"

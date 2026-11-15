#!/usr/bin/env bash
set -Eeuo pipefail
WALLPAPER="/usr/share/backgrounds/igorcoin/estonia-default.svg"
if ! command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
  echo "KDE Plasma wallpaper utility is not installed." >&2
  exit 1
fi
[[ -r "$WALLPAPER" ]] || { echo "Wallpaper file missing: $WALLPAPER" >&2; exit 1; }
plasma-apply-wallpaperimage "$WALLPAPER"

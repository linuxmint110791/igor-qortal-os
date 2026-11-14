#!/usr/bin/env bash
set -Eeuo pipefail

# Official Qortal universal Linux installer maintained by Qortal/QORTector-scripts.
# This wrapper downloads the upstream script at run time; it does not bundle
# or silently execute it during OS installation.

URL="https://link.qortal.dev/linux-script"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! command -v curl >/dev/null 2>&1 && ! command -v wget >/dev/null 2>&1; then
  echo "Install curl or wget first." >&2
  exit 1
fi

echo "Downloading the official Qortal Linux installer..."
if command -v curl >/dev/null 2>&1; then
  curl -fL --retry 3 "$URL" -o "$TMP/Qortal-Setup-Linux.sh"
else
  wget -qO "$TMP/Qortal-Setup-Linux.sh" "$URL"
fi

test -s "$TMP/Qortal-Setup-Linux.sh"
echo "Starting Qortal's interactive installer..."
bash "$TMP/Qortal-Setup-Linux.sh"

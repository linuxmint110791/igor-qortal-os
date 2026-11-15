#!/usr/bin/env bash
set -Eeuo pipefail
if ! nmcli -t -f STATE general 2>/dev/null | grep -qx connected; then
  echo "Connect to Wi-Fi before downloading Qortal."
  nmtui
fi
if ! nmcli -t -f STATE general 2>/dev/null | grep -qx connected; then
  echo "No network connection detected. Qortal installation stopped."
  exit 1
fi
exec /usr/local/lib/igorcoin/install-qortal.sh

#!/usr/bin/env bash
set -Eeuo pipefail
echo "IGORCOIN-QORTAL OS INSTALLER"
echo "Before starting Archinstall, connect to Wi-Fi."
if ! nmcli -t -f STATE general 2>/dev/null | grep -qx connected; then
  echo "Opening NetworkManager text interface. Select your Wi-Fi and connect."
  nmtui
fi
if ! nmcli -t -f STATE general 2>/dev/null | grep -qx connected; then
  echo "No network connection detected. Installation stopped; connect first and retry."
  exit 1
fi
echo "Network connected. Starting the official Archinstall installer."
exec sudo archinstall

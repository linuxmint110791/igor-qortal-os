#!/usr/bin/env bash
set -Eeuo pipefail

HUB="/opt/qortal-hub/Qortal-Hub.AppImage"
CORE_DIR="$HOME/qortal"
STATE_DIR="$HOME/.local/state/igorcoin-qortal"
mkdir -p "$STATE_DIR"

# Start the user's local Qortal Core when it has already been installed.
# The Qortal installer remains an explicit first-time action.
if [[ -x "$CORE_DIR/start.sh" ]] && ! pgrep -f '[q]ortal.jar' >/dev/null 2>&1; then
  (
    cd "$CORE_DIR"
    nohup ./start.sh >> "$STATE_DIR/core.log" 2>&1 </dev/null &
  )
fi

# Open the native Qortal Hub desktop app after the local Core start request.
exec "$HUB"

#!/bin/bash
# Installs MotoBuds.app to /Applications and launches it. Local-dev helper.
#
# Usage: Bundle/install.sh [debug|release]
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/MotoBuds.app"
DEST="/Applications/MotoBuds.app"

if [ ! -d "$APP" ]; then
    echo "==> $APP missing, building first"
    bash "$ROOT/Bundle/build-app.sh" "$CONFIG"
fi

if [ -d "$DEST" ]; then
    osascript -e 'tell application "MotoBuds" to quit' 2>/dev/null || true
    sleep 1
fi

echo "==> copying to $DEST"
rm -rf "$DEST"
cp -R "$APP" "$DEST"

echo "==> launching"
open "$DEST"

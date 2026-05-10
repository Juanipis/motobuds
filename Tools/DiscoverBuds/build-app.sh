#!/bin/bash
# Build DiscoverBuds as a proper .app bundle so macOS TCC attributes the
# Bluetooth permission request to the app itself (not to its parent process).
#
# Usage: ./build-app.sh [output-dump-path]
#   output-dump-path defaults to ../../docs/sdp-gatt-dump.txt
set -euo pipefail

cd "$(dirname "$0")"
SCRIPT_DIR="$(pwd)"
PROJECT_ROOT="$(cd ../.. && pwd)"

# Subcommand: build | discover | sniff
SUB="${1:-build-and-discover}"
shift || true

echo "→ swift build (release)"
swift build -c release

APP_DIR="$SCRIPT_DIR/DiscoverBuds.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
cp Bundle/Info.plist "$APP_DIR/Contents/Info.plist"
cp .build/release/DiscoverBuds "$APP_DIR/Contents/MacOS/DiscoverBuds"
codesign --force --sign - --timestamp=none "$APP_DIR" >/dev/null

run_app() {
    local out="$1"; shift
    mkdir -p "$(dirname "$out")"
    : > "$out"
    echo "→ launching $APP_DIR  out=$out  args=$*"
    open -W "$APP_DIR" --args "$@" "$out" || true
    echo "----"
    tail -n +1 "$out"
}

case "$SUB" in
    build) ;;
    build-and-discover|discover)
        run_app "$PROJECT_ROOT/docs/sdp-gatt-dump.txt" "discover"
        ;;
    sniff)
        # ./build-app.sh sniff <mac> <channel> [seconds] [out.txt]
        MAC="${1:?mac required}"; shift
        CH="${1:?channel required}"; shift
        SECS="${1:-15}"
        OUT="$PROJECT_ROOT/docs/sniff-ch${CH}.txt"
        run_app "$OUT" "sniff" "$MAC" "$CH" "$SECS"
        ;;
    probe)
        # ./build-app.sh probe <mac> <channel> <script-or-raw...>
        MAC="${1:?mac required}"; shift
        CH="${1:?channel required}"; shift
        OUT="$PROJECT_ROOT/docs/probe-ch${CH}-${1:-out}.txt"
        run_app "$OUT" "probe" "$MAC" "$CH" "$@"
        ;;
    listen)
        # ./build-app.sh listen <mac> <channel> [seconds]
        MAC="${1:?mac required}"; shift
        CH="${1:?channel required}"; shift
        SECS="${1:-60}"
        OUT="$PROJECT_ROOT/docs/listen-ch${CH}.txt"
        run_app "$OUT" "listen" "$MAC" "$CH" "$SECS"
        ;;
    *)
        echo "usage: $0 [build | discover | sniff <mac> <ch> [secs] | probe <mac> <ch> [op_hex] [secs]]"
        exit 2
        ;;
esac

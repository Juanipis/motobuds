#!/bin/bash
# Assembles MotoBuds.app from `swift build` output and ad-hoc signs it.
#
# Layout produced:
#   MotoBuds.app/Contents/Info.plist
#   MotoBuds.app/Contents/MacOS/MotoBudsApp
#   MotoBuds.app/Contents/Resources/AppIcon.icns
#
# Usage:
#   Bundle/build-app.sh [release|debug]
#
# Environment:
#   VERSION       Semantic version baked into Info.plist (default: 0.0.0-dev)
#   BUILD_NUMBER  Build counter (default: 1)
#   SIGN_IDENTITY Codesign identity (default: "-" for ad-hoc)

set -euo pipefail

CONFIG="${1:-debug}"
VERSION="${VERSION:-0.0.0-dev}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN_DIR="$ROOT/.build/$( [ "$CONFIG" = "release" ] && echo "release" || echo "debug" )"
APP="$ROOT/.build/MotoBuds.app"

echo "==> swift build ($CONFIG, version $VERSION build $BUILD_NUMBER)"
if [ "$CONFIG" = "release" ]; then
    swift build -c release --product MotoBudsApp
else
    swift build --product MotoBudsApp
fi

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$ROOT/Bundle/AppInfo.plist" "$APP/Contents/Info.plist"
cp "$BIN_DIR/MotoBudsApp"       "$APP/Contents/MacOS/MotoBudsApp"

# App icon — regenerate if missing so CI is self-contained.
if [ ! -f "$ROOT/Bundle/AppIcon.icns" ]; then
    echo "==> AppIcon.icns missing, regenerating"
    bash "$ROOT/Bundle/make-icon.sh"
fi
cp "$ROOT/Bundle/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Stamp version + build into Info.plist.
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER"       "$APP/Contents/Info.plist"

echo "==> signing ($SIGN_IDENTITY)"
codesign --force --sign "$SIGN_IDENTITY" \
    --identifier "com.juanipis.MotoBuds" \
    --options runtime \
    --timestamp=none \
    "$APP"

codesign -dv --verbose=2 "$APP" 2>&1 | head -10
echo
echo "==> done: $APP (v$VERSION, build $BUILD_NUMBER)"

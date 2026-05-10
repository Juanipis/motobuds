#!/bin/bash
# Assembles MotoBuds.app from `swift build` output and ad-hoc signs it.
#
# Layout produced:
#   MotoBuds.app/Contents/Info.plist
#   MotoBuds.app/Contents/MacOS/MotoBudsApp
#   MotoBuds.app/Contents/Resources/AppIcon.icns
#   MotoBuds.app/Contents/Frameworks/Sparkle.framework
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
SUBDIR="$( [ "$CONFIG" = "release" ] && echo "release" || echo "debug" )"
BIN_DIR="$ROOT/.build/$SUBDIR"
ARCH_BIN_DIR="$ROOT/.build/arm64-apple-macosx/$SUBDIR"
APP="$ROOT/.build/MotoBuds.app"

echo "==> swift build ($CONFIG, version $VERSION build $BUILD_NUMBER)"
if [ "$CONFIG" = "release" ]; then
    swift build -c release --product MotoBudsApp
else
    swift build --product MotoBudsApp
fi

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$ROOT/Bundle/AppInfo.plist" "$APP/Contents/Info.plist"
cp "$BIN_DIR/MotoBudsApp"       "$APP/Contents/MacOS/MotoBudsApp"

# Sparkle ships as a versioned .framework with embedded XPC services
# (Updater.app, Downloader, Installer). The app's @rpath points to
# Contents/Frameworks, so we copy the whole thing there. -R preserves the
# version symlinks Sparkle relies on; codesign re-seals it under the
# parent app's signature in the final pass.
SPARKLE_FW="$ARCH_BIN_DIR/Sparkle.framework"
if [ -d "$SPARKLE_FW" ]; then
    cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"
else
    echo "❌ Sparkle.framework not found at $SPARKLE_FW"
    exit 1
fi

# SwiftPM builds the executable with @executable_path rpaths suitable for
# `swift run`, not for an .app bundle. Append the canonical bundle rpath
# so dyld finds Sparkle inside Contents/Frameworks at runtime.
install_name_tool -add_rpath "@executable_path/../Frameworks" \
    "$APP/Contents/MacOS/MotoBudsApp" 2>/dev/null || true

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
# Sparkle's nested bundles must be signed before the framework, and the
# framework before the app. No --options=runtime: hardened runtime needs
# a Developer ID + entitlements chain we don't have for ad-hoc.
SPARKLE_VER="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
for inner in \
    "$SPARKLE_VER/Updater.app/Contents/MacOS/Autoupdate" \
    "$SPARKLE_VER/Updater.app" \
    "$SPARKLE_VER/XPCServices/Downloader.xpc/Contents/MacOS/Downloader" \
    "$SPARKLE_VER/XPCServices/Downloader.xpc" \
    "$SPARKLE_VER/XPCServices/Installer.xpc/Contents/MacOS/Installer" \
    "$SPARKLE_VER/XPCServices/Installer.xpc"; do
    if [ -e "$inner" ]; then
        codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$inner" 2>/dev/null || true
    fi
done
codesign --force --sign "$SIGN_IDENTITY" --timestamp=none \
    "$APP/Contents/Frameworks/Sparkle.framework"

codesign --force --sign "$SIGN_IDENTITY" \
    --identifier "com.juanipis.MotoBuds" \
    --timestamp=none \
    "$APP"

codesign -dv --verbose=2 "$APP" 2>&1 | head -10
echo
echo "==> done: $APP (v$VERSION, build $BUILD_NUMBER)"

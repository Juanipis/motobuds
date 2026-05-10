#!/bin/bash
# Adds a new <item> to docs/appcast.xml for a freshly published release.
# Sparkle clients poll that XML and use SUPublicEDKey in Info.plist to
# verify the EdDSA signature before installing.
#
# Required env:
#   VERSION              SemVer (no leading v)
#   SPARKLE_PRIVATE_KEY  Base64 EdDSA private key (44 chars). Stored in
#                        the SPARKLE_PRIVATE_KEY repo secret. If unset,
#                        the script no-ops gracefully so first releases
#                        can succeed before Sparkle is set up.

set -euo pipefail

VERSION="${VERSION:?VERSION env var required}"

if [ -z "${SPARKLE_PRIVATE_KEY:-}" ]; then
    echo "==> SPARKLE_PRIVATE_KEY not set — skipping appcast update"
    exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APPCAST="$ROOT/docs/appcast.xml"
ZIP_PATH="$ROOT/.build/MotoBuds-$VERSION.zip"
ZIP_URL="https://github.com/Juanipis/motobuds/releases/download/v$VERSION/MotoBuds-$VERSION.zip"
RELEASE_NOTES_URL="https://github.com/Juanipis/motobuds/releases/tag/v$VERSION"

[ -f "$ZIP_PATH" ] || { echo "❌ $ZIP_PATH does not exist — run Bundle/build-app.sh + package-zip.sh first"; exit 1; }
[ -f "$APPCAST"  ] || { echo "❌ $APPCAST missing — initialise it first"; exit 1; }

ZIP_SIZE="$(stat -f %z "$ZIP_PATH" 2>/dev/null || stat -c %s "$ZIP_PATH")"

KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s' "$SPARKLE_PRIVATE_KEY" > "$KEY_FILE"
chmod 600 "$KEY_FILE"

SIGN_UPDATE=""
for c in \
    "/opt/homebrew/Caskroom/sparkle/2.9.1/bin/sign_update" \
    "$(command -v sign_update || true)"; do
    if [ -n "$c" ] && [ -x "$c" ]; then SIGN_UPDATE="$c"; break; fi
done
if [ -z "$SIGN_UPDATE" ]; then
    SPARKLE_DIR="$(ls -d /opt/homebrew/Caskroom/sparkle/*/ 2>/dev/null | head -1)"
    [ -n "$SPARKLE_DIR" ] && SIGN_UPDATE="${SPARKLE_DIR}bin/sign_update"
fi
[ -x "$SIGN_UPDATE" ] || { echo "❌ sign_update not found"; exit 1; }

echo "==> signing $ZIP_PATH"
SIGNATURE="$("$SIGN_UPDATE" --ed-key-file "$KEY_FILE" "$ZIP_PATH")"
echo "    $SIGNATURE"

PUB_DATE="$(LC_ALL=C TZ=UTC date '+%a, %d %b %Y %H:%M:%S +0000')"

ITEM=$(cat <<XML
    <item>
      <title>MotoBuds $VERSION</title>
      <pubDate>$PUB_DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <sparkle:releaseNotesLink>$RELEASE_NOTES_URL</sparkle:releaseNotesLink>
      <enclosure
          url="$ZIP_URL"
          length="$ZIP_SIZE"
          type="application/zip"
          $SIGNATURE/>
    </item>
XML
)

TMP_OUT="$(mktemp)"
awk -v item="$ITEM" '
    /<\/channel>/ && !done { print item; done=1 }
    { print }
' "$APPCAST" > "$TMP_OUT"
mv "$TMP_OUT" "$APPCAST"

echo "==> appended <item> for $VERSION to $APPCAST"

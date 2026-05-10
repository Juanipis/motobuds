#!/bin/bash
# Packages the built MotoBuds.app into a versioned zip suitable for a GitHub
# release asset. Run after `Bundle/build-app.sh release`.
#
# Output:  .build/MotoBuds-<version>.zip   plus a SHA256 sidecar.

set -euo pipefail

VERSION="${VERSION:-0.0.0-dev}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/.build/MotoBuds.app"
OUT_ZIP="$ROOT/.build/MotoBuds-$VERSION.zip"
OUT_SHA="$ROOT/.build/MotoBuds-$VERSION.zip.sha256"

[ -d "$APP" ] || { echo "error: $APP does not exist — run build-app.sh first"; exit 1; }

rm -f "$OUT_ZIP" "$OUT_SHA"

# Apple-recommended way to zip .app bundles: preserves resource forks, code
# signature, and the top-level MotoBuds.app directory.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT_ZIP"

shasum -a 256 "$OUT_ZIP" | awk '{print $1}' > "$OUT_SHA"

echo "==> packaged $OUT_ZIP"
echo "    sha256: $(cat "$OUT_SHA")"
echo "    size:   $(du -h "$OUT_ZIP" | cut -f1)"

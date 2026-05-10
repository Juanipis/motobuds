#!/bin/bash
# Bumps the Homebrew Cask in Juanipis/homebrew-tap to point at a new
# MotoBuds release. Pulls the .sha256 sidecar straight from the GitHub
# release, rewrites Casks/motobuds.rb, and pushes a "feat: bump motobuds
# to vX.Y.Z" commit.
#
# Triggered automatically from semantic-release's successCmd when the
# HOMEBREW_TAP_TOKEN secret is set.

set -euo pipefail

VERSION="${VERSION:?VERSION env var required, e.g. 1.2.3}"
TAP_REPO="Juanipis/homebrew-tap"
ZIP_NAME="MotoBuds-$VERSION.zip"
ZIP_URL="https://github.com/Juanipis/motobuds/releases/download/v$VERSION/$ZIP_NAME"
SHA_URL="$ZIP_URL.sha256"
CASK_PATH="Casks/motobuds.rb"

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

echo "==> Fetching SHA-256 for $ZIP_NAME"
SHA="$(curl -fsSL "$SHA_URL" | tr -d '[:space:]')"
[ -n "$SHA" ] || { echo "❌ empty sha"; exit 1; }
echo "    $SHA"

echo "==> Cloning $TAP_REPO"
if [ -n "${HOMEBREW_TAP_TOKEN:-}" ]; then
    git clone --depth=1 \
        "https://x-access-token:$HOMEBREW_TAP_TOKEN@github.com/$TAP_REPO.git" \
        "$WORK_DIR/tap"
else
    git clone --depth=1 "https://github.com/$TAP_REPO.git" "$WORK_DIR/tap"
fi
CASK="$WORK_DIR/tap/$CASK_PATH"

if [ ! -f "$CASK" ]; then
    echo "==> Cask file missing — creating $CASK_PATH from scratch"
    mkdir -p "$(dirname "$CASK")"
    cat > "$CASK" <<RUBY
cask "motobuds" do
  version "$VERSION"
  sha256 "$SHA"

  url "https://github.com/Juanipis/motobuds/releases/download/v#{version}/MotoBuds-#{version}.zip"
  name "MotoBuds"
  desc "Native macOS companion for Motorola Moto Buds (ANC, EQ, battery, gestures)"
  homepage "https://github.com/Juanipis/motobuds"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "MotoBuds.app"

  zap trash: [
    "~/Library/Application Support/MotoBuds",
    "~/Library/Caches/com.juanipis.MotoBuds",
    "~/Library/Logs/MotoBudsMac.log",
    "~/Library/Preferences/com.juanipis.MotoBuds.plist",
  ]
end
RUBY
else
    echo "==> Rewriting cask"
    sed -i.bak -E \
        -e "s|^(  version )\"[^\"]+\"|\\1\"$VERSION\"|" \
        -e "s|^(  sha256 )\"[^\"]+\"|\\1\"$SHA\"|" \
        "$CASK"
    rm -f "$CASK.bak"
fi

cd "$WORK_DIR/tap"
git config user.name  "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add "$CASK_PATH"
if git diff --cached --quiet; then
    echo "==> Cask already at $VERSION, nothing to do"
    exit 0
fi
git commit -q -m "feat(motobuds): bump to $VERSION

sha256: $SHA
release: https://github.com/Juanipis/motobuds/releases/tag/v$VERSION"
git push origin main
echo "==> Pushed bump to $TAP_REPO"

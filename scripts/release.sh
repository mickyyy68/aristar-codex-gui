#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $(basename "$0") vX.Y.Z [release-notes]

Examples:
  ./scripts/release.sh v0.1.0
  ./scripts/release.sh v0.1.0 "Add new working set UI"

Requires gh CLI (https://cli.github.com/) and an authenticated session: gh auth login
EOF
}

if [[ "${1-}" == "-h" || "${1-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required for releases. Install it from https://cli.github.com/ and authenticate with 'gh auth login'." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "gh is installed but not authenticated. Run 'gh auth login' before releasing." >&2
  exit 1
fi

VERSION="$1"
NOTES="${2:-Release $VERSION}"
BIN_NAME="AristarCodexGUI"
BUILD_DIR="./.build/release"
ASSET="AristarCodexGUI-${VERSION}-macOS-arm64.zip"

if [[ -n "$(git status --porcelain)" ]]; then
  echo "Repository is dirty. Commit or stash changes before releasing." >&2
  exit 1
fi

if git show-ref --tags --verify --quiet "refs/tags/$VERSION"; then
  echo "Tag $VERSION already exists locally; remove it or pick a new version." >&2
  exit 1
fi

echo "Building release binary..."
swift build -c release

if [[ ! -f "$BUILD_DIR/$BIN_NAME" ]]; then
  echo "Expected binary not found at $BUILD_DIR/$BIN_NAME" >&2
  exit 1
fi

echo "Packaging $ASSET..."
rm -f "$ASSET"
zip -j -9 "$ASSET" "$BUILD_DIR/$BIN_NAME"

echo "Creating GitHub release with gh (tag will be created on GitHub)..."
gh release create "$VERSION" "$ASSET" --notes "$NOTES" --target "$(git rev-parse HEAD)"

echo "Done. Asset ready: $ASSET"

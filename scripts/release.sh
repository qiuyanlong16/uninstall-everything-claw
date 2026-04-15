#!/usr/bin/env bash
set -euo pipefail

VERSION=${1:-$(grep 'version:' pubspec.yaml | awk '{print $2}')}
GITHUB_TOKEN=${GITHUB_TOKEN:?Set GITHUB_TOKEN}

echo "Creating release v${VERSION}..."

gh release create "v${VERSION}" \
  --title "ClawSweeper v${VERSION}" \
  --notes "Release v${VERSION}" \
  --generate-notes

echo "Uploading artifacts..."
for f in dist/*; do
  gh release upload "v${VERSION}" "$f"
done

echo "Release v${VERSION} published!"

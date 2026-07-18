#!/bin/bash
# Builds a versioned release zip; optionally publishes a GitHub release.
#   ./scripts/release.sh v1.0.1            → dist/MousyMousy-v1.0.1.zip
#   ./scripts/release.sh v1.0.1 --publish  → also: git tag + gh release with asset
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh vX.Y.Z [--publish]}"

./scripts/build.sh
# ditto preserves the code signature and bundle metadata; plain zip can break both.
ZIP="dist/MousyMousy-$VERSION.zip"
ditto -c -k --keepParent "dist/Mousy Mousy.app" "$ZIP"
echo "wrote $ZIP"

if [[ "${2:-}" == "--publish" ]]; then
    command -v gh >/dev/null || { echo "gh CLI required for --publish"; exit 1; }
    git tag -a "$VERSION" -m "Mousy Mousy $VERSION" 2>/dev/null || echo "tag $VERSION exists, reusing"
    git push origin "$VERSION"
    gh release create "$VERSION" "$ZIP" --title "Mousy Mousy $VERSION" --generate-notes
fi

#!/bin/bash
# Builds, bundles, signs. Pass --install to copy into /Applications.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release

APP="dist/Mousy Mousy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MousyMousy "$APP/Contents/MacOS/MousyMousy"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# NEVER ad-hoc (-s -): see scripts/make-cert.sh header.
# Identity priority: Developer ID Application (distributable, notarizable)
# > Apple Development (local, Apple-chained) > MousyMousy Dev (self-signed
# fallback). All give a rebuild-stable designated requirement, so the
# Accessibility grant survives rebuilds; switching BETWEEN identities changes
# the requirement and re-prompts once.
find_identity() {
    security find-identity -v -p codesigning 2>/dev/null \
        | sed -n "s/.*\"\($1[^\"]*\)\".*/\1/p" | head -1
}
IDENTITY="MousyMousy Dev"
EXTRA=()
if DEV_ID=$(find_identity "Developer ID Application") && [[ -n "$DEV_ID" ]]; then
    IDENTITY="$DEV_ID"
    # Notarization requires hardened runtime + a secure timestamp.
    EXTRA=(--timestamp --options runtime)
elif APPLE_DEV=$(find_identity "Apple Development") && [[ -n "$APPLE_DEV" ]]; then
    IDENTITY="$APPLE_DEV"
fi
echo "Signing with: $IDENTITY"
codesign --force ${EXTRA[@]+"${EXTRA[@]}"} --sign "$IDENTITY" "$APP"
codesign --verify --verbose=2 "$APP"
echo "Built and signed: $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/Mousy Mousy.app"
    cp -R "$APP" "/Applications/Mousy Mousy.app"
    echo "Installed. Launch with: open '/Applications/Mousy Mousy.app'"
    echo "(Always launch via 'open' or Finder — never the bare binary — so TCC"
    echo " attributes the Accessibility grant to the app.)"
fi

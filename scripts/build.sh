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

# NEVER ad-hoc (-s -): see scripts/make-cert.sh header.
# Prefer an Apple-chained development identity when one exists (no manual
# Keychain trust step, SMAppService-friendliest); else the local self-signed
# cert. Both give a rebuild-stable designated requirement, so the
# Accessibility grant survives rebuilds either way.
IDENTITY="MousyMousy Dev"
APPLE_DEV=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Apple Development[^"]*\)".*/\1/p' | head -1)
if [[ -n "$APPLE_DEV" ]]; then
    IDENTITY="$APPLE_DEV"
fi
echo "Signing with: $IDENTITY"
codesign --force --sign "$IDENTITY" "$APP"
codesign --verify --verbose=2 "$APP"
echo "Built and signed: $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf "/Applications/Mousy Mousy.app"
    cp -R "$APP" "/Applications/Mousy Mousy.app"
    echo "Installed. Launch with: open '/Applications/Mousy Mousy.app'"
    echo "(Always launch via 'open' or Finder — never the bare binary — so TCC"
    echo " attributes the Accessibility grant to the app.)"
fi

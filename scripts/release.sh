#!/bin/bash
# Builds a versioned release zip; notarizes when possible; optionally publishes.
#   ./scripts/release.sh v1.0.1            → dist/MousyMousy-v1.0.1.zip
#   ./scripts/release.sh v1.0.1 --publish  → also: push tag + GitHub release with asset
#
# Notarization runs automatically when BOTH are true:
#   - the app is signed with a Developer ID Application identity (build.sh
#     picks it up from the keychain automatically), and
#   - a notarytool keychain profile exists (one-time setup, run yourself):
#       DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
#         xcrun notarytool store-credentials mousy-notary \
#         --apple-id <your-apple-id> --team-id <your PAID team id> \
#         --password <app-specific-password from account.apple.com>
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: release.sh vX.Y.Z [--publish]}"
XCODE_DEV=/Applications/Xcode.app/Contents/Developer
NOTARY_PROFILE="${NOTARY_PROFILE:-mousy-notary}"

./scripts/build.sh

APP="dist/Mousy Mousy.app"
ZIP="dist/MousyMousy-$VERSION.zip"

# Gate diagnostics matter: a silent skip has shipped un-notarized zips twice
# (once a codesign -dv vs -dvv bug, once a transient network failure right
# after a VPN toggle). Say WHY we skip, retry transient failures once, and
# refuse to publish un-notarized unless explicitly overridden.
NOTARIZE=1
# No pipe here: under pipefail, `codesign | grep -q` intermittently fails on
# SIGPIPE when grep exits at first match — the cause of two phantom gate skips.
SIGN_INFO=$(codesign -dvv "$APP" 2>&1 || true)
if [[ "$SIGN_INFO" != *"Developer ID Application"* ]]; then
    echo "NOTE: app is not Developer ID signed — cannot notarize."
    NOTARIZE=0
elif ! NOTARY_ERR=$(DEVELOPER_DIR="$XCODE_DEV" xcrun notarytool history \
        --keychain-profile "$NOTARY_PROFILE" 2>&1 >/dev/null); then
    sleep 5   # transient network flap (e.g. just after a VPN toggle) — retry once
    if ! NOTARY_ERR=$(DEVELOPER_DIR="$XCODE_DEV" xcrun notarytool history \
            --keychain-profile "$NOTARY_PROFILE" 2>&1 >/dev/null); then
        echo "NOTE: notary profile '$NOTARY_PROFILE' unavailable — cannot notarize."
        echo "      Reason: $NOTARY_ERR"
        NOTARIZE=0
    fi
fi
if [[ $NOTARIZE == 0 && "${2:-}" == "--publish" && "${ALLOW_UNNOTARIZED:-}" != "1" ]]; then
    echo "Refusing to publish un-notarized. Fix the above (or set ALLOW_UNNOTARIZED=1)."
    exit 1
fi
if [[ $NOTARIZE == 1 ]]; then
    echo "Notarizing with keychain profile '$NOTARY_PROFILE'…"
    ditto -c -k --keepParent "$APP" "$ZIP"
    DEVELOPER_DIR="$XCODE_DEV" xcrun notarytool submit "$ZIP" \
        --keychain-profile "$NOTARY_PROFILE" --wait
    # Staple needs api.apple-cloudkit.com with Apple's REAL certs — stapler
    # pins them, so corporate TLS interception (GlobalProtect VPN) fails with
    # Error 68. Run releases off-VPN.
    DEVELOPER_DIR="$XCODE_DEV" xcrun stapler staple "$APP"
    rm "$ZIP"    # re-zip below so the stapled ticket ships inside
    echo "Notarized and stapled."
fi

# ditto preserves the code signature and bundle metadata; plain zip can break both.
ditto -c -k --keepParent "$APP" "$ZIP"
echo "wrote $ZIP"

if [[ "${2:-}" == "--publish" ]]; then
    command -v gh >/dev/null || { echo "gh CLI required for --publish"; exit 1; }
    git tag -a "$VERSION" -m "Mousy Mousy $VERSION" 2>/dev/null || echo "tag $VERSION exists, reusing"
    git push origin "$VERSION"
    gh release create "$VERSION" "$ZIP" --title "Mousy Mousy $VERSION" --generate-notes
fi

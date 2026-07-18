#!/bin/bash
# Creates the stable self-signed "MousyMousy Dev" code-signing cert.
# WHY: TCC stores the app's designated requirement. Ad-hoc signatures degenerate
# to a per-build cdhash, so the Accessibility grant dies on every rebuild. A
# stable cert gives 'identifier "com.chris.mousymousy" and certificate leaf'
# — grants survive rebuilds indefinitely. Also required for SMAppService and
# macOS 26's stricter event-synthesis gating.
set -euo pipefail
CN="MousyMousy Dev"

if security find-certificate -c "$CN" >/dev/null 2>&1; then
    echo "Certificate '$CN' already exists — nothing to do."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

openssl req -x509 -newkey rsa:2048 -days 3650 -nodes \
    -keyout "$TMP/dev.key" -out "$TMP/dev.crt" \
    -subj "/CN=$CN" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=codeSigning"

# -legacy is load-bearing: without it Keychain imports the p12 but codesign
# cannot use the key.
openssl pkcs12 -export -legacy -in "$TMP/dev.crt" -inkey "$TMP/dev.key" \
    -out "$TMP/dev.p12" -password pass:mousy

security import "$TMP/dev.p12" -k ~/Library/Keychains/login.keychain-db \
    -P mousy -T /usr/bin/codesign

cat <<'EOF'

Certificate imported. ONE MANUAL STEP REMAINS:
  1. Open Keychain Access, find "MousyMousy Dev" under My Certificates.
  2. Double-click it → Trust → Code Signing → Always Trust.
  3. Close the window (enter your password when asked).

Then run scripts/build.sh
EOF

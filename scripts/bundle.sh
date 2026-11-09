#!/bin/bash
# Builds Gloss in release mode and wraps it in build/Gloss.app.
# Signing: ad-hoc for everyday builds; RELEASE=1 uses your Developer ID certificate (hardened runtime).
# Run scripts/dmg.sh with NOTARY_PROFILE to notarize.
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP="build/Gloss.app"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Gloss"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Gloss"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] || ./scripts/make-icon.sh
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Signing identity: SIGN_ID if set ("-" forces ad-hoc). For RELEASE=1 builds (make dmg, make install)
# the first "Developer ID Application" certificate in your keychain is used when there is one.
# The first time, macOS asks to let codesign use that key: enter your login password, "Always Allow".
if [ -z "${SIGN_ID:-}" ] && [ "${RELEASE:-0}" = "1" ]; then
    SIGN_ID="$(security find-identity -v -p codesigning 2>/dev/null \
        | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -1)"
fi
SIGN_ID="${SIGN_ID:--}"
# A signing run that was stopped can leave this behind, and codesign then refuses the bundle.
rm -f "$APP/Contents/MacOS/Gloss.cstemp"
if [ "$SIGN_ID" = "-" ]; then
    # Ad-hoc signature so macOS can track the Accessibility permission and notifications.
    codesign --force --sign - --timestamp=none "$APP" >/dev/null
else
    codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$APP"
fi
echo "Signed with: $SIGN_ID"
echo "Built $APP"

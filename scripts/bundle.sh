#!/bin/bash
# Builds Gloss in release mode and wraps it in build/Gloss.app.
# Signing: ad-hoc by default. Set SIGN_ID="Developer ID Application: Your Name (TEAMID)" to sign for
# distribution (hardened runtime), then run scripts/dmg.sh with NOTARY_PROFILE to notarize.
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

SIGN_ID="${SIGN_ID:--}"
if [ "$SIGN_ID" = "-" ]; then
    # Ad-hoc signature so macOS can track the Accessibility permission and notifications.
    codesign --force --sign - --timestamp=none "$APP" >/dev/null
else
    codesign --force --sign "$SIGN_ID" --options runtime --timestamp "$APP"
fi
echo "Built $APP"

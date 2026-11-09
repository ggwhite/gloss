#!/bin/bash
# Builds build/Gloss.dmg: Gloss.app plus a shortcut to /Applications, ready to share.
# Optional: NOTARY_PROFILE=<notarytool keychain profile> notarizes and staples it (needs SIGN_ID, see bundle.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
RELEASE=1 ./scripts/bundle.sh
STAGE="$(mktemp -d)/Gloss"
mkdir -p "$STAGE"
cp -R build/Gloss.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f build/Gloss.dmg
hdiutil create -volname "Gloss" -srcfolder "$STAGE" -ov -format UDZO build/Gloss.dmg >/dev/null
# Sign the disk image with the same Developer ID as the app (skipped for ad-hoc builds).
APP_SIGNER="$(codesign -dv --verbose=2 build/Gloss.app 2>&1 | sed -n 's/^Authority=\(Developer ID Application: .*\)/\1/p' | head -1)"
if [ -n "$APP_SIGNER" ]; then
    codesign --force --sign "$APP_SIGNER" --timestamp build/Gloss.dmg
fi
if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit build/Gloss.dmg --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple build/Gloss.dmg
fi
echo "Built build/Gloss.dmg"

#!/bin/bash
# Builds build/Gloss.dmg: Gloss.app plus a shortcut to /Applications, ready to share.
# Optional: NOTARY_PROFILE=<notarytool keychain profile> notarizes and staples it (needs SIGN_ID, see bundle.sh).
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/bundle.sh
STAGE="$(mktemp -d)/Gloss"
mkdir -p "$STAGE"
cp -R build/Gloss.app "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f build/Gloss.dmg
hdiutil create -volname "Gloss" -srcfolder "$STAGE" -ov -format UDZO build/Gloss.dmg >/dev/null
if [ -n "${NOTARY_PROFILE:-}" ]; then
    xcrun notarytool submit build/Gloss.dmg --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple build/Gloss.dmg
fi
echo "Built build/Gloss.dmg"

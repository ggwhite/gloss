#!/bin/bash
# Builds build/Gloss.dmg: Gloss.app plus a shortcut to /Applications, ready to share.
# Signs with your Developer ID (see bundle.sh), then notarizes and staples it when credentials are given,
# in either of these ways (environment variables, like the release workflow):
#   App Store Connect API key:  NOTARY_KEY_PATH (.p8 file), NOTARY_KEY_ID, NOTARY_ISSUER_ID
#   Apple ID:                   NOTARY_APPLE_ID, NOTARY_PASSWORD (app-specific), NOTARY_TEAM_ID
#   Saved keychain profile:     NOTARY_PROFILE (from `xcrun notarytool store-credentials`)
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
if [ -z "$APP_SIGNER" ]; then
    echo "Built build/Gloss.dmg (ad-hoc: not signed with a Developer ID, so not notarized)"
    exit 0
fi
codesign --force --sign "$APP_SIGNER" --timestamp build/Gloss.dmg

CRED=()
if [ -n "${NOTARY_KEY_PATH:-}" ]; then
    CRED=(--key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER_ID:?}")
elif [ -n "${NOTARY_APPLE_ID:-}" ]; then
    CRED=(--apple-id "$NOTARY_APPLE_ID" --password "${NOTARY_PASSWORD:?}" --team-id "${NOTARY_TEAM_ID:?}")
elif [ -n "${NOTARY_PROFILE:-}" ]; then
    CRED=(--keychain-profile "$NOTARY_PROFILE")
fi
if [ ${#CRED[@]} -eq 0 ]; then
    echo "Built build/Gloss.dmg (signed by $APP_SIGNER; not notarized: no notary credentials)"
    exit 0
fi
xcrun notarytool submit build/Gloss.dmg "${CRED[@]}" --wait
xcrun stapler staple build/Gloss.dmg
xcrun stapler validate build/Gloss.dmg
echo "Built build/Gloss.dmg (signed by $APP_SIGNER, notarized and stapled)"

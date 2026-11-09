#!/bin/bash
# Builds Gloss in release mode and wraps it in build/Gloss.app.
#
#   VERSION=v1.2.3   version shown in Finder/About (default: latest git tag, else Info.plist)
#   UNIVERSAL=1      one binary for Apple silicon and Intel (arm64 + x86_64)
#   RELEASE=1        sign with the first "Developer ID Application" certificate in the keychain
#   SIGN_ID=...      sign with this identity ("-" forces ad-hoc)
#
# Everyday builds are ad-hoc. The first Developer ID build asks to let codesign use your key:
# enter your login password and choose "Always Allow".
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${CONFIG:-release}"
APP="build/Gloss.app"
ARCH_FLAGS=()
[ "${UNIVERSAL:-0}" = "1" ] && ARCH_FLAGS=(--arch arm64 --arch x86_64)

swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"}
BIN="$(swift build -c "$CONFIG" ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/Gloss"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Gloss"
cp Resources/Info.plist "$APP/Contents/Info.plist"
[ -f Resources/AppIcon.icns ] || ./scripts/make-icon.sh
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Version: v1.2.3 → 1.2.3; build number = commit count.
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null || true)}"
VERSION="${VERSION#v}"
if [ -n "$VERSION" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
fi
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP/Contents/Info.plist"

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
echo "Built $APP ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"), $(lipo -archs "$APP/Contents/MacOS/Gloss"))"

#!/bin/bash
# Builds Gloss in release mode and wraps it in build/Gloss.app (ad-hoc signed).
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
printf 'APPL????' > "$APP/Contents/PkgInfo"

# Ad-hoc signature so macOS can track the Accessibility permission and notifications.
codesign --force --sign - --timestamp=none "$APP" >/dev/null
echo "Built $APP"

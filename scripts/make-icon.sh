#!/bin/bash
# Draws the app icon (Sources/Gloss/IconArt.swift) and writes Resources/AppIcon.icns.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
TMP="$(mktemp -d)/AppIcon.iconset"
"$(swift build --show-bin-path)/Gloss" --render-icon "$TMP"
iconutil -c icns "$TMP" -o Resources/AppIcon.icns
cp "$TMP/icon_512x512@2x.png" Resources/AppIcon-1024.png
echo "Wrote Resources/AppIcon.icns"

#!/bin/bash
# Records the README's animated pictures into assets/*.webp (needs ffmpeg and img2webp: brew install ffmpeg webp).
# Every scene runs off-screen with the made-up demo deck: nothing from your vault appears.
set -euo pipefail
cd "$(dirname "$0")/.."
swift build
BIN="$(swift build --show-bin-path)/Gloss"
TMP="$(mktemp -d)"
mkdir -p assets

record() { # scene width [quality]
    local q="${3:-70}"
    "$BIN" --record "$TMP/$1" --scene "$1" >/dev/null
    mkdir -p "$TMP/$1-small"
    ffmpeg -loglevel error -y -i "$TMP/$1/frame-%04d.tiff" -vf "scale=$2:-2:flags=lanczos" -start_number 0 "$TMP/$1-small/f-%04d.png"
    # Each frame lasts until the next one was captured, so the animation plays at its real speed.
    local args=() i=0 prev="" t
    while read -r t; do
        if [ -n "$prev" ]; then args+=(-d "$((t - prev))" "$(printf "$TMP/$1-small/f-%04d.png" "$i")"); i=$((i + 1)); fi
        prev="$t"
    done < "$TMP/$1/times.txt"
    args+=(-d 1500 "$(printf "$TMP/$1-small/f-%04d.png" "$i")")   # hold the last frame
    img2webp -loop 0 -lossy -q "$q" -m 6 "${args[@]}" -o "assets/$1.webp" >/dev/null
    echo "assets/$1.webp $(du -h "assets/$1.webp" | cut -f1)"
}

record window 820 62
record quiz 468
record overview 468
record practice 820 62
record fix 508
cp Resources/AppIcon-1024.png assets/icon.png

#!/bin/zsh
# Regenerates every app icon size from scripts/make-icon.swift.
#   scripts/make-icon.sh
set -euo pipefail

cd "$(dirname "$0")/.."
ICONSET="EasyNotch/Resources/Assets.xcassets/AppIcon.appiconset"
MASTER="$(mktemp -d)/icon-1024.png"

swift scripts/make-icon.swift "$MASTER"

# name:pixel-size pairs, matching Contents.json
for pair in 16x16:16 16x16@2x:32 32x32:32 32x32@2x:64 128x128:128 128x128@2x:256 \
            256x256:256 256x256@2x:512 512x512:512 512x512@2x:1024; do
    name="${pair%%:*}"
    pixels="${pair##*:}"
    sips -z "$pixels" "$pixels" "$MASTER" --out "$ICONSET/icon_$name.png" >/dev/null
done
echo "Updated $ICONSET"

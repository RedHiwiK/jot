#!/bin/bash
# Regenerate the app icon from icon-source.png (or the image passed as $1).
set -euo pipefail
cd "$(dirname "$0")"

SRC=${1:-icon-source.png}
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# The source artwork already includes the tile, shadow and alpha channel; only resize.
sips -z 1024 1024 "$SRC" --out "$TMP/icon-1024.png" >/dev/null
cp "$TMP/icon-1024.png" AppIcon-1024.png

mkdir -p "$TMP/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -Z $s       "$TMP/icon-1024.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}.png"    >/dev/null
  sips -Z $((s*2)) "$TMP/icon-1024.png" --out "$TMP/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o AppIcon.icns
echo "✓ AppIcon.icns / AppIcon-1024.png"

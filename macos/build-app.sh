#!/bin/bash
# Package the SwiftPM build as macOS/build/Jot.app with the matching jot CLI in Contents/Helpers.
#
#   ./build-app.sh                 release build for this Mac's architecture
#   ./build-app.sh debug           debug build
#   UNIVERSAL=1 ./build-app.sh     arm64 + x86_64 (used for releases)
set -euo pipefail
cd "$(dirname "$0")"

CONFIG=${1:-release}
VERSION=$(go run -C .. ./cmd/jot --version)
VERSION=${VERSION##* }

SWIFT_ARGS=(-c "$CONFIG")
GO_ARCHS=("$(go env GOARCH)")
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
  SWIFT_ARGS+=(--arch arm64 --arch x86_64)
  GO_ARCHS=(arm64 amd64)
fi
swift build "${SWIFT_ARGS[@]}"
BIN_DIR=$(swift build "${SWIFT_ARGS[@]}" --show-bin-path)

APP="build/Jot.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Helpers"
cp "$BIN_DIR/Jot" "$APP/Contents/MacOS/Jot"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"

HELPERS=()
for arch in "${GO_ARCHS[@]}"; do
  out="build/jot-darwin-$arch"
  CGO_ENABLED=0 GOOS=darwin GOARCH=$arch go build -C .. -trimpath -ldflags "-s -w" -o "$PWD/$out" ./cmd/jot
  HELPERS+=("$out")
done
lipo -create "${HELPERS[@]}" -output "$APP/Contents/Helpers/jot"
rm -f "${HELPERS[@]}"

cat > "$APP/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>Jot</string>
    <key>CFBundleIdentifier</key><string>io.github.redhiwik.jot</string>
    <key>CFBundleName</key><string>Jot</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleDisplayName</key><string>Jot</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSSupportsAutomaticGraphicsSwitching</key><true/>
</dict>
</plist>
PLIST

# Ad-hoc signature only: the bundle is not notarized.
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"
echo "✓ $APP ($VERSION, ${GO_ARCHS[*]})"

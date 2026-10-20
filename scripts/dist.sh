#!/bin/bash
# Build every release artifact into dist/:
#   jot_<os>_<arch>.tar.gz   CLI binaries (darwin/linux × arm64/amd64) plus the agent skill
#   Jot_macos.zip            universal macOS app with the bundled CLI
#   checksums.txt            SHA-256 of the above
# Names carry no version so that releases/latest/download/<name> stays a stable URL.
set -euo pipefail
cd "$(dirname "$0")/.."

rm -rf dist && mkdir -p dist

for target in darwin/arm64 darwin/amd64 linux/arm64 linux/amd64; do
  os=${target%/*} arch=${target#*/}
  name="jot_${os}_${arch}"
  mkdir -p "dist/$name"
  CGO_ENABLED=0 GOOS=$os GOARCH=$arch go build -trimpath -ldflags "-s -w" -o "dist/$name/jot" ./cmd/jot
  cp LICENSE README.md "dist/$name/"
  cp -R skills "dist/$name/"
  tar -C dist -czf "dist/$name.tar.gz" "$name"
  rm -rf "dist/$name"
done

UNIVERSAL=1 macos/build-app.sh release
ditto -c -k --sequesterRsrc --keepParent macos/build/Jot.app dist/Jot_macos.zip

(cd dist && shasum -a 256 *.tar.gz *.zip > checksums.txt)
ls -l dist

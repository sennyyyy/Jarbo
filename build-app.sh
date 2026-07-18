#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
cd "$ROOT"
mkdir -p "$ROOT/.build/release"
SWIFTC="$(xcrun --find swiftc)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
for ARCH in arm64 x86_64; do
  mkdir -p "$ROOT/.build/ModuleCache-$ARCH"
  "$SWIFTC" -parse-as-library -O -swift-version 6 -module-name Jarbo \
    -target "$ARCH-apple-macosx14.0" \
    -sdk "$SDK" \
    -module-cache-path "$ROOT/.build/ModuleCache-$ARCH" \
    "$ROOT"/Sources/Jarbo/*.swift \
    -o "$ROOT/.build/release/Jarbo-$ARCH"
done
lipo -create \
  "$ROOT/.build/release/Jarbo-arm64" \
  "$ROOT/.build/release/Jarbo-x86_64" \
  -output "$ROOT/.build/release/Jarbo"
APP="$ROOT/dist/Jarbo.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/Jarbo" "$APP/Contents/MacOS/Jarbo"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"
if [[ -d "$ROOT/Resources" ]]; then
  cp -R "$ROOT/Resources/." "$APP/Contents/Resources/"
fi
codesign --force --deep --sign - \
  --requirements '=designated => identifier "com.senhong.jarbo"' "$APP"
echo "$APP"

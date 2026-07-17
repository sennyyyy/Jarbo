#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
cd "$ROOT"
mkdir -p "$ROOT/.build/release"
"$ROOT/patch-sdk-interfaces.sh" >/dev/null
for ARCH in arm64 x86_64; do
  mkdir -p "$ROOT/.build/ModuleCache-$ARCH"
  /usr/bin/swiftc -parse-as-library -O -module-name Jarbo \
    -target "$ARCH-apple-macosx14.0" \
    -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk \
    -module-cache-path "$ROOT/.build/ModuleCache-$ARCH" \
    -vfsoverlay "$ROOT/.build/sdk-patch/overlay.yaml" \
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

#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
cd "$ROOT"

./preflight.sh
mkdir -p "$ROOT/.build/VerifyModuleCache" "$ROOT/.build/swiftpm"
env \
  CLANG_MODULE_CACHE_PATH="$ROOT/.build/VerifyModuleCache" \
  SWIFTPM_MODULECACHE_OVERRIDE="$ROOT/.build/VerifyModuleCache" \
  swift test --disable-sandbox --scratch-path "$ROOT/.build/swiftpm"
./build-app.sh

APP="$ROOT/dist/Jarbo.app"
EXECUTABLE="$APP/Contents/MacOS/Jarbo"
[[ -d "$APP" ]] || { print -u2 "Missing app bundle: $APP"; exit 1; }
[[ -x "$EXECUTABLE" ]] || { print -u2 "Missing app executable: $EXECUTABLE"; exit 1; }
plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --verify --deep --strict "$APP"
ARCHS="$(lipo -archs "$EXECUTABLE")"
[[ "$ARCHS" == *arm64* && "$ARCHS" == *x86_64* ]] || {
  print -u2 "Expected universal arm64/x86_64 build; found: $ARCHS"
  exit 1
}
print "Jarbo verification passed: $APP ($ARCHS)"

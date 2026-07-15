#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h}"
SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk"
PATCH="$ROOT/.build/sdk-patch"
OVERLAY="$PATCH/overlay.yaml"
mkdir -p "$PATCH"
print -n '{"version":0,"case-sensitive":"false","roots":[{"type":"file","name":"/Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap","external-contents":"' > "$OVERLAY"
print -n "$ROOT/work/empty.modulemap" >> "$OVERLAY"
print -n '"}' >> "$OVERLAY"
first=0
i=0
while IFS= read -r source; do
  i=$((i+1))
  target="$PATCH/$i.swiftinterface"
  sed 's/swiftlang-6\.0\.3\.1\.5/swiftlang-6.0.3.1.10/g' "$source" > "$target"
  if [[ $first -eq 0 ]]; then print ',' >> "$OVERLAY"; fi
  first=0
  escaped_source=${source//\\/\\\\}; escaped_source=${escaped_source//\"/\\\"}
  escaped_target=${target//\\/\\\\}; escaped_target=${escaped_target//\"/\\\"}
  print -n "{\"type\":\"file\",\"name\":\"$escaped_source\",\"external-contents\":\"$escaped_target\"}" >> "$OVERLAY"
done < <(find -L "$SDK" \( -name 'arm64e-apple-macos.swiftinterface' -o -name 'x86_64-apple-macos.swiftinterface' \) -print)
print ']}' >> "$OVERLAY"
print "$OVERLAY"

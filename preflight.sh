#!/bin/zsh
set -euo pipefail

fail() {
  print -u2 "Jarbo preflight failed: $1"
  exit 1
}

[[ "$(uname -s)" == "Darwin" ]] || fail "macOS is required."
command -v xcrun >/dev/null || fail "xcrun is missing. Install Xcode and select it with xcode-select."
command -v codesign >/dev/null || fail "codesign is missing. Install the Xcode command-line tools."
command -v lipo >/dev/null || fail "lipo is missing. Install the Xcode command-line tools."
command -v ditto >/dev/null || fail "ditto is missing from this macOS installation."

SWIFTC="$(xcrun --find swiftc 2>/dev/null)" || fail "Swift compiler not found through xcrun."
SDK="$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)" || fail "macOS SDK not found."
[[ -x "$SWIFTC" ]] || fail "Swift compiler is not executable: $SWIFTC"
[[ -d "$SDK" ]] || fail "macOS SDK path does not exist: $SDK"

SWIFT_VERSION="$($SWIFTC --version 2>&1 | head -1)"
XCODE_VERSION="$(xcodebuild -version 2>/dev/null | paste -sd ' ' - || true)"
print "Jarbo preflight passed"
print "  Swift: $SWIFT_VERSION"
print "  SDK:   $SDK"
print "  Xcode: ${XCODE_VERSION:-Command Line Tools only}"

#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h}"
cd "$ROOT"

if [[ $# -ne 1 || ! "$1" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 "Usage: ./release.sh <major.minor.patch>"
  exit 64
fi

VERSION="$1"
TAG="v$VERSION"
NOTES="release-notes/$TAG.md"
if git rev-parse "$TAG" >/dev/null 2>&1; then
  print -u2 "Release $TAG already exists."
  exit 65
fi
if [[ ! -f "$NOTES" ]]; then
  print -u2 "Missing $NOTES. Add Working and Known limitations sections before publishing."
  exit 67
fi
if ! git remote get-url origin >/dev/null 2>&1; then
  print -u2 "No origin remote is configured. Add one with: git remote add origin <repository-url>"
  exit 66
fi

CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' Info.plist 2>/dev/null || print 0)
NEXT_BUILD=$((CURRENT_BUILD + 1))
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEXT_BUILD" Info.plist

./build-app.sh
ARCHIVE="dist/Jarbo-$VERSION.zip"
ditto -c -k --norsrc --keepParent dist/Jarbo.app "$ARCHIVE"

git add .github .gitignore Info.plist Package.swift README.md Sources build-app.sh patch-sdk-interfaces.sh release-notes release.sh
git commit -m "Release $TAG"
git tag -a "$TAG" -F "$NOTES"
git push origin HEAD
git push origin "$TAG"

print "Published $TAG"
print "$ARCHIVE"

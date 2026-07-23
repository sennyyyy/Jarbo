#!/bin/zsh

set -euo pipefail

SOURCE_ROOT="${0:A:h}"
DESTINATION="${1:-/Users/senhong/Desktop/Jarbo}"
TIMESTAMP="$(date '+%Y-%m-%d-%H%M%S')"
ARCHIVE_DIR="$DESTINATION/archive/desktop-pre-sync"

if ! command -v rsync >/dev/null 2>&1; then
  print -u2 "rsync is required to synchronize Jarbo."
  exit 1
fi

if ! git -C "$SOURCE_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  print -u2 "Jarbo source is not a Git working tree: $SOURCE_ROOT"
  exit 1
fi

mkdir -p "$DESTINATION" "$ARCHIVE_DIR" "$DESTINATION/builds"

# Preserve Desktop-only roadmap drafts before the current tracked roadmap is copied.
if [[ -f "$DESTINATION/Jarbo_Project_Roadmap.md" ]] && \
   ! cmp -s "$SOURCE_ROOT/Jarbo_Project_Roadmap.md" "$DESTINATION/Jarbo_Project_Roadmap.md"; then
  cp -p "$DESTINATION/Jarbo_Project_Roadmap.md" \
    "$ARCHIVE_DIR/Jarbo_Project_Roadmap-$TIMESTAMP.md"
fi

# Mirror repository metadata so the Desktop checkout retains complete history and
# matches the active source branch. Desktop-only files are intentionally preserved.
mkdir -p "$DESTINATION/.git"
rsync -a --delete "$SOURCE_ROOT/.git/" "$DESTINATION/.git/"

# Copy project data and release artifacts. Rebuildable caches and local tooling are
# excluded to keep the Desktop archive portable and reasonably sized.
rsync -a \
  --exclude '.git/' \
  --exclude '.build/' \
  --exclude '.tools/' \
  --exclude '.DS_Store' \
  --exclude 'work/' \
  "$SOURCE_ROOT/" "$DESTINATION/"

# Keep immutable source snapshots for every tagged version that is not already in
# the Desktop archive. Existing historical folders are never replaced.
for tag in ${(f)"$(git -C "$SOURCE_ROOT" tag --list 'v*' --sort=version:refname)"}; do
  version_dir="$DESTINATION/builds/$tag"
  if [[ ! -d "$version_dir" ]]; then
    mkdir -p "$version_dir"
    git -C "$SOURCE_ROOT" archive "$tag" | tar -x -C "$version_dir"
  fi
done

current_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$SOURCE_ROOT/Info.plist")"
current_snapshot="$DESTINATION/builds/v$current_version"
snapshot_tmp="$(mktemp -d "${TMPDIR:-/tmp}/jarbo-snapshot.XXXXXX")"
trap 'rm -rf "$snapshot_tmp"' EXIT
git -C "$SOURCE_ROOT" archive HEAD | tar -x -C "$snapshot_tmp"
mkdir -p "$current_snapshot"
rsync -a --delete "$snapshot_tmp/" "$current_snapshot/"

# A standalone bundle makes the complete repository history recoverable even if
# the checkout metadata is accidentally removed.
bundle_tmp="$DESTINATION/.Jarbo-complete-history-$TIMESTAMP.bundle"
git -C "$SOURCE_ROOT" bundle create "$bundle_tmp" --all
mv -f "$bundle_tmp" "$DESTINATION/Jarbo-complete-history.bundle"

branch="$(git -C "$SOURCE_ROOT" branch --show-current)"
commit="$(git -C "$SOURCE_ROOT" rev-parse HEAD)"
short_commit="$(git -C "$SOURCE_ROOT" rev-parse --short HEAD)"

{
  print -r -- '# Jarbo Desktop Sync Status'
  print
  print -r -- "- Last synchronized: $(date '+%Y-%m-%d %H:%M:%S %Z')"
  print -r -- "- Source: \`$SOURCE_ROOT\`"
  print -r -- "- Branch: \`$branch\`"
  print -r -- "- Commit: \`$commit\` (\`$short_commit\`)"
  print -r -- "- Current version: \`$current_version\`"
  print
  print -r -- '## Saved content'
  print
  print -r -- '- Current source, resources, tests, scripts, documentation, and release metadata'
  print -r -- '- Packaged application and archives from `dist/`'
  print -r -- '- Historical source snapshots under `builds/`'
  print -r -- '- Complete Git checkout and `Jarbo-complete-history.bundle` recovery bundle'
  print -r -- '- Desktop-only roadmap drafts under `archive/desktop-pre-sync/`'
  print
  print -r -- 'Rebuildable `.build/`, `.tools/`, and `work/` caches are intentionally excluded.'
} > "$DESTINATION/SYNC-STATUS.md"

print "Jarbo synchronized to $DESTINATION"
print "Version $current_version at $short_commit ($branch)"

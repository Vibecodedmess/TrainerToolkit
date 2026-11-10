#!/usr/bin/env bash
# Refreshes the data snapshots bundled in the app (offline first-launch data).
# Usage: scripts/update-snapshots.sh      (run from the repo root; works in Git Bash on Windows)
#
# Sources and terms: see DATA_SOURCES.md. Run this by hand when preparing a release,
# not in a loop. The app itself refreshes at runtime.
set -euo pipefail

DEST="Packages/TrainerKit/Sources/DataSources/Snapshots"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$DEST"

# id | URL | file name   (must match DataSourceCatalog.swift)
SOURCES=(
  "gamemaster|https://raw.githubusercontent.com/pvpoke/pvpoke/master/src/data/gamemaster.min.json|gamemaster.json"
  "events|https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/events.min.json|events.json"
  "raids|https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/raids.min.json|raids.json"
  "research|https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/research.min.json|research.json"
  "rocketLineups|https://raw.githubusercontent.com/bigfoott/ScrapedDuck/data/rocketLineups.min.json|rocketLineups.json"
)

now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
manifest_entries=()

for entry in "${SOURCES[@]}"; do
  IFS='|' read -r id url file <<<"$entry"
  echo "Fetching $id ..."
  curl -fsSL --retry 2 -A "TrainerToolkit-snapshot-script" -o "$TMP/$file" "$url"

  # Basic sanity check: non-trivial size and JSON-looking start. Full validation runs in
  # `swift test` (BundledSnapshotTests), which CI runs before every build.
  size=$(wc -c <"$TMP/$file")
  first=$(head -c 1 "$TMP/$file")
  if [ "$size" -lt 100 ] || { [ "$first" != "[" ] && [ "$first" != "{" ]; }; then
    echo "  $id looks wrong (size $size, starts with '$first'); keeping the old snapshot." >&2
    # Keep the old manifest date for this source if present.
    old=$(grep -o "\"$id\": *\"[^\"]*\"" "$DEST/manifest.json" 2>/dev/null | head -1 || true)
    [ -n "$old" ] && manifest_entries+=("  $old")
    continue
  fi
  if command -v jq >/dev/null 2>&1 && ! jq -e . "$TMP/$file" >/dev/null; then
    echo "  $id is not valid JSON; keeping the old snapshot." >&2
    continue
  fi
  mv "$TMP/$file" "$DEST/$file"
  manifest_entries+=("  \"$id\": \"$now\"")
  echo "  ok ($size bytes)"
done

{
  echo "{"
  for i in "${!manifest_entries[@]}"; do
    sep=","; [ "$i" -eq $((${#manifest_entries[@]} - 1)) ] && sep=""
    echo "${manifest_entries[$i]}$sep"
  done
  echo "}"
} >"$DEST/manifest.json"

echo "Snapshots updated in $DEST"
cat "$DEST/manifest.json"

#!/bin/bash
#
# list-backups.sh — List backup archives for a given type
# Layer 1 (server-side): outputs JSON to stdout.
# Usage: list-backups.sh <mods|players|world>
#
# Output format:
# {
#   "files": [
#     {"name":"file.tar.gz","sha256":"abc...","mtime":"...","size":12345}
#   ],
#   "current": "abc..."   # sha256 of current (deployed) archive, or null
# }
#
# Environment variables:
#   BACKUPS_DIR — path to backups root (default: /mnt/backups)
#
# Dependencies: bash, jq, sha256sum, date, stat

set -euo pipefail

BACKUPS_DIR="${BACKUPS_DIR:-/mnt/backups}"

type="${1:-}"
case "$type" in
    mods|state) ;;
    *) echo "Usage: $0 <mods|state>" >&2; exit 1 ;;
esac

dir="$BACKUPS_DIR/$type"

# Read current.txt (sha256 name) — only exists for mods
current_sha256=""
current_file="$dir/current.txt"
if [ -f "$current_file" ]; then
    read -r sha256_val name_val < "$current_file" 2>/dev/null || true
    current_sha256="$sha256_val"
fi

# Generate NDJSON (one file object per line), then slurp into final JSON with jq
{
    if [ -d "$dir" ]; then
        for f in $(ls -t "$dir"/*.tar.gz 2>/dev/null); do
            [ -f "$f" ] || continue
            name=$(basename "$f")
            mtime=$(date -u -d "@$(stat -c %Y "$f")" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
            size=$(stat -c %s "$f" 2>/dev/null || echo 0)
            sha256=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1 || echo "")

            jq -n \
                --arg name "$name" \
                --arg sha256 "$sha256" \
                --arg mtime "$mtime" \
                --argjson size "$size" \
                '{name: $name, sha256: $sha256, mtime: $mtime, size: $size}'
        done
    fi
} | jq -r -s \
    --arg current "${current_sha256:-}" \
    '{files: ., current: (if $current == "" then null else $current end)}'
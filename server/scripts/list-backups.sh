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

set -euo pipefail

BACKUPS_DIR="${BACKUPS_DIR:-/mnt/backups}"

type="${1:-}"
case "$type" in
    mods|players|world) ;;
    *) echo "Usage: $0 <mods|players|world>" >&2; exit 1 ;;
esac

dir="$BACKUPS_DIR/$type"

# Read current.txt (sha256 name) — only exists for mods
current_sha256=""
current_file="$dir/current.txt"
if [ -f "$current_file" ]; then
    read -r sha256_val name_val < "$current_file" 2>/dev/null || true
    current_sha256="$sha256_val"
fi

# Start JSON output
printf '{\n'

# Files array
printf '  "files": [\n'
first=1
if [ -d "$dir" ]; then
    for f in $(ls -t "$dir"/*.tar.gz 2>/dev/null); do
        [ -f "$f" ] || continue
        name=$(basename "$f")
        mtime=$(date -u -d "@$(stat -c %Y "$f")" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "null")
        size=$(stat -c %s "$f" 2>/dev/null || echo 0)
        sha256=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1 || echo "")

        [ "$first" -eq 0 ] && printf ',\n'
        first=0
        printf '    {"name":"%s","sha256":"%s","mtime":"%s","size":%s}' \
            "$name" "$sha256" "$mtime" "$size"
    done
fi
printf '\n  ],\n'

# Current field
if [ -n "$current_sha256" ]; then
    printf '  "current": "%s"\n' "$current_sha256"
else
    printf '  "current": null\n'
fi

printf '}\n'
#!/bin/bash
#
# deploy_state.sh — Deploy state (players + world combined) archive to the server
#
# Usage:
#   deploy_state.sh <filename>   — deploy a specific archive from backups/state/
#   deploy_state.sh --latest     — deploy the newest export-* or import-* archive
#
# What it does:
#   1. Resolves the archive path
#   2. Stops TES3MP
#   3. Extracts players/ → players/, cell/ → world/cell/, etc.
#   4. Starts TES3MP
#
# Requirements: bash, tar, docker, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

BACKUPS_DIR="$BASE_DIR/backups"

# Directories (on host)
PLAYER_DIR="$BASE_DIR/players"
WORLD_CELL_DIR="$BASE_DIR/world/cell"
WORLD_WORLD_DIR="$BASE_DIR/world/world"
WORLD_MAP_DIR="$BASE_DIR/world/map"
WORLD_RECORDSTORE_DIR="$BASE_DIR/world/recordstore"
WORLD_CUSTOM_DIR="$BASE_DIR/world/custom"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

echo "=== TES3MP Deploy State (Players + World) ==="

# ────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────

_get_uncompressed_size() {
    local archive="$1"
    gzip -dc "$archive" 2>/dev/null | wc -c | tr -d ' '
}

_get_free_kb() {
    local path="$1"
    df --output=avail "$path" 2>/dev/null | tail -1 | tr -d ' '
}

resolve_archive() {
    if [ "$#" -eq 0 ]; then
        err "Usage: deploy_state.sh <filename> or deploy_state.sh --latest"
        exit 1
    fi

    case "$1" in
        --latest)
            local latest
            latest=$(ls -t "$BACKUPS_DIR"/state/export-*.tar.gz "$BACKUPS_DIR"/state/import-*.tar.gz 2>/dev/null | head -1)
            if [ -z "$latest" ]; then
                err "No export-* or import-* archives found in $BACKUPS_DIR/state"
                exit 1
            fi
            echo "$latest"
            ;;
        *)
            local archive_path="$BACKUPS_DIR/state/$1"
            if [ ! -f "$archive_path" ]; then
                err "Archive not found: $archive_path"
                exit 1
            fi
            echo "$archive_path"
            ;;
    esac
}

# ────────────────────────────────────────────────────
# Main flow
# ────────────────────────────────────────────────────

ARCHIVE_PATH=$(resolve_archive "$@")
echo "Archive: $ARCHIVE_PATH"
echo ""

# Step 1: Check extract space
echo "[1/4] Checking extract space..."
available_kb=$(_get_free_kb "$BASE_DIR")
uncompressed_size=$(_get_uncompressed_size "$ARCHIVE_PATH")
uncompressed_kb=$((uncompressed_size / 1024))

if [ "$available_kb" -lt "$uncompressed_kb" ]; then
    err "Not enough disk space for extraction."
    err "  Available: $((available_kb / 1024)) MB"
    err "  Archive uncompressed: $((uncompressed_kb / 1024)) MB"
    exit 1
fi
ok "Extract space OK: $((available_kb / 1024)) MB available, ~$((uncompressed_kb / 1024)) MB needed"

# Step 2: Stop TES3MP
echo ""
echo "[2/4] Stopping TES3MP..."
cd "$BASE_DIR" && docker compose stop tes3mp 2>/dev/null || true
ok "TES3MP stopped"

# Step 3: Extract archive into world and player directories
echo ""
echo "[3/4] Extracting state archive..."
if [ -d "$PLAYER_DIR" ]; then
    rm -rf "$PLAYER_DIR"/*
fi
for subdir in cell world map recordstore custom; do
    target="$BASE_DIR/world/$subdir"
    if [ -d "$target" ]; then
        rm -rf "$target"/*
    fi
done
mkdir -p "$PLAYER_DIR" "$WORLD_CELL_DIR" "$WORLD_WORLD_DIR" "$WORLD_MAP_DIR" "$WORLD_RECORDSTORE_DIR" "$WORLD_CUSTOM_DIR"

# Extract into BASE_DIR as staging area, then move
tar xzf "$ARCHIVE_PATH" -C "$BASE_DIR" players/ cell/ world/ map/ recordstore/ custom/ 2>/dev/null || {
    # Fallback: extract all and move manually
    local tmp_stage
    tmp_stage=$(mktemp -d)
    trap 'rm -rf "$tmp_stage"' EXIT
    tar xzf "$ARCHIVE_PATH" -C "$tmp_stage"

    # Move players
    if [ -d "$tmp_stage/players" ]; then
        cp -r "$tmp_stage/players"/* "$PLAYER_DIR/" 2>/dev/null || true
    fi

    # Move world subdirs
    for subdir in cell world map recordstore custom; do
        if [ -d "$tmp_stage/$subdir" ]; then
            cp -r "$tmp_stage/$subdir"/* "$BASE_DIR/world/$subdir/" 2>/dev/null || true
        fi
    done
}
ok "State extracted from archive"

# Step 4: Start TES3MP
echo ""
echo "[4/4] Starting TES3MP..."
cd "$BASE_DIR" && docker compose up -d
ok "TES3MP started"

touch /tes3mp-easy/needs_restart.flag 2>/dev/null || true
echo ""
echo "=== Done! State deployed successfully. ==="
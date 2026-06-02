#!/bin/bash
#
# deploy_world.sh — Deploy world archive to the server
#
# Three modes:
#   deploy_world.sh              — deploy from current.txt (checks sha256)
#   deploy_world.sh --latest     — deploy the latest import-* or init-* archive
#   deploy_world.sh <filename>   — rollback to a specific archive from backups/world/
#
# What it does:
#   1. Determines which archive to deploy
#   2. Checks free space for backup
#   3. Backs up current world
#   4. Stops TES3MP
#   5. Checks free space for extraction
#   6. Cleans world subdirectories
#   7. Extracts archive (only cell/ + world/ + map/ + recordstore/ + custom/)
#   8. Starts TES3MP
#   9. Writes current.txt
#
# Requirements: bash, tar, docker, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

BACKUPS_DIR="$BASE_DIR/backups/world"
CURRENT_FILE="$BACKUPS_DIR/current.txt"

# Mount point directories (on host)
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

# Source the shared packaging library for package_world()
export WORLD_CELL_DIR
export WORLD_WORLD_DIR
export WORLD_MAP_DIR
export WORLD_RECORDSTORE_DIR
export WORLD_CUSTOM_DIR
source "$SCRIPT_DIR/package.sh"

echo "=== TES3MP Deploy World ==="

# ────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────

# Get uncompressed size of a tar.gz archive in bytes
_get_uncompressed_size() {
    local archive="$1"
    gzip -dc "$archive" 2>/dev/null | wc -c | tr -d ' '
}

# Get available disk space in KB at a given path
_get_free_kb() {
    local path="$1"
    df --output=avail "$path" 2>/dev/null | tail -1 | tr -d ' '
}

# Determine which archive to deploy
resolve_archive() {
    if [ "$#" -eq 0 ]; then
        # Mode: current.txt
        if [ ! -f "$CURRENT_FILE" ]; then
            err "current.txt not found: $CURRENT_FILE"
            err "Specify an archive or use --latest."
            exit 1
        fi
        local sha256_from_file filename
        read -r sha256_from_file filename < "$CURRENT_FILE"
        local archive_path="$BACKUPS_DIR/$filename"
        if [ ! -f "$archive_path" ]; then
            err "Archive referenced in current.txt not found: $archive_path"
            exit 1
        fi
        # Verify sha256
        local actual_sha256
        actual_sha256=$(sha256sum "$archive_path" | cut -d' ' -f1)
        if [ "$actual_sha256" != "$sha256_from_file" ]; then
            err "SHA256 mismatch for $archive_path"
            err "  expected: $sha256_from_file"
            err "  actual:   $actual_sha256"
            exit 1
        fi
        echo "$archive_path"
        return 0
    fi

    case "$1" in
        --latest)
            # Find the latest import-* or init-* archive (not backup-*)
            local latest
            latest=$(ls -t "$BACKUPS_DIR"/import-*.tar.gz "$BACKUPS_DIR"/init-*.tar.gz 2>/dev/null | head -1)
            if [ -z "$latest" ]; then
                err "No import-* or init-* archives found in $BACKUPS_DIR"
                exit 1
            fi
            echo "$latest"
            ;;
        *)
            # Rollback: use the filename directly
            local archive_path="$BACKUPS_DIR/$1"
            if [ ! -f "$archive_path" ]; then
                err "Archive not found: $archive_path"
                exit 1
            fi
            echo "$archive_path"
            ;;
    esac
}

# Check free space for backup
check_backup_space() {
    local archive_path="$1"
    local available_kb
    available_kb=$(_get_free_kb "$BACKUPS_DIR")

    # Estimate size of current world
    local world_size=0
    for d in "$WORLD_CELL_DIR" "$WORLD_WORLD_DIR" "$WORLD_MAP_DIR" "$WORLD_RECORDSTORE_DIR" "$WORLD_CUSTOM_DIR"; do
        if [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ]; then
            world_size=$((world_size + $(du -sb "$d" 2>/dev/null | cut -f1)))
        fi
    done
    # Multiply by 2 for safety margin
    local needed_bytes=$((world_size * 2))
    local needed_kb=$((needed_bytes / 1024))

    if [ "$available_kb" -lt "$needed_kb" ]; then
        err "Not enough disk space for backup."
        err "  Available: $((available_kb / 1024)) MB"
        err "  Needed (2x margin): $((needed_kb / 1024)) MB"
        exit 1
    fi
    ok "Backup space OK: $((available_kb / 1024)) MB available, ~$((needed_kb / 1024)) MB needed"
}

# Check free space for extraction
check_extract_space() {
    local archive_path="$1"
    local available_kb
    available_kb=$(_get_free_kb "$BASE_DIR")
    local uncompressed_size
    uncompressed_size=$(_get_uncompressed_size "$archive_path")
    local uncompressed_kb=$((uncompressed_size / 1024))

    if [ "$available_kb" -lt "$uncompressed_kb" ]; then
        err "Not enough disk space for extraction."
        err "  Available: $((available_kb / 1024)) MB"
        err "  Archive uncompressed: $((uncompressed_kb / 1024)) MB"
        # Restore: start server and abort
        info "Starting server back up..."
        cd "$BASE_DIR" && docker compose up -d 2>/dev/null || true
        exit 1
    fi
    ok "Extract space OK: $((available_kb / 1024)) MB available, ~$((uncompressed_kb / 1024)) MB needed"
}

# Clean world subdirectories
clean_world_dirs() {
    for d in "$WORLD_CELL_DIR" "$WORLD_WORLD_DIR" "$WORLD_MAP_DIR" "$WORLD_RECORDSTORE_DIR" "$WORLD_CUSTOM_DIR"; do
        if [ -d "$d" ]; then
            rm -rf "$d"/*
        fi
    done
    ok "World directories cleaned"
}

# ────────────────────────────────────────────────────
# Main flow
# ────────────────────────────────────────────────────

ARCHIVE_PATH=$(resolve_archive "$@")
echo "Archive: $ARCHIVE_PATH"
echo ""

# Step 1: Check backup space
echo "[1/4] Checking backup space..."
check_backup_space "$ARCHIVE_PATH"

# Step 2: Backup current world
echo ""
echo "[2/4] Backing up current world..."
TIMESTAMP=$(date +%F_%H-%M-%S)
BACKUP_FILE="$BACKUPS_DIR/backup-${TIMESTAMP}-world.tar.gz"
package_world "$BACKUP_FILE"
ok "World backup saved: $BACKUP_FILE"

# Step 3: Check extract space
echo ""
echo "[3/4] Checking extract space..."
check_extract_space "$ARCHIVE_PATH"

# Step 4: Clean and extract
echo ""
echo "[4/4] Cleaning world directories and extracting..."
clean_world_dirs

# Extract only world subdirectories (cell/, world/, map/, recordstore/, custom/)
# Skip requiredDataFiles.json and current.txt (metadata)
tar xzf "$ARCHIVE_PATH" -C "$BASE_DIR/world" \
    --wildcards 'cell/' 'cell/*' \
    'world/' 'world/*' \
    'map/' 'map/*' \
    'recordstore/' 'recordstore/*' \
    'custom/' 'custom/*' \
    2>/dev/null || {
        # If --wildcards not supported, extract and then remove metadata
        tar xzf "$ARCHIVE_PATH" -C "$BASE_DIR/world"
        rm -f "$BASE_DIR/world/requiredDataFiles.json" "$BASE_DIR/world/current.txt"
    }

ok "World extracted from archive"

# Write current.txt (after extraction)
ARCHIVE_FILENAME=$(basename "$ARCHIVE_PATH")
ARCHIVE_SHA256=$(sha256sum "$ARCHIVE_PATH" | cut -d' ' -f1)
echo "$ARCHIVE_SHA256 $ARCHIVE_FILENAME" > "$CURRENT_FILE"
ok "current.txt updated: $ARCHIVE_SHA256 $ARCHIVE_FILENAME"

echo ""
touch /tes3mp-easy/needs_restart.flag 2>/dev/null || true
echo "=== Done! World deployed. Use 'Restart' in admin menu to apply. ==="

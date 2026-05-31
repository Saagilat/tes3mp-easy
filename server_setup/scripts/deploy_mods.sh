#!/bin/bash
#
# deploy_mods.sh — Deploy mods archive to the server
#
# Three modes:
#   deploy_mods.sh              — deploy from current.txt (checks sha256)
#   deploy_mods.sh --latest     — deploy the latest import-* or init-* archive
#   deploy_mods.sh <filename>   — rollback to a specific archive from backups/mods/
#
# What it does:
#   1. Determines which archive to deploy
#   2. Checks free space for backup
#   3. Backs up current mods (only if current.txt is invalid or rollback)
#      Always backs up world and players
#   4. Stops TES3MP
#   5. Checks free space for extraction
#   6. Extracts plugins/ → mods/plugins/, scripts/ → mods/scripts/
#   7. Generates customScripts.lua
#   8. Updates current.txt
#   9. Creates/updates nginx symlink
#   10. Starts TES3MP
#
# Requirements: bash, tar, docker, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

BACKUPS_DIR="$BASE_DIR/backups/mods"
CURRENT_FILE="$BACKUPS_DIR/current.txt"

# Mount point directories (on host)
MODS_PLUGINS_DIR="$BASE_DIR/mods/plugins"
MODS_SCRIPTS_DIR="$BASE_DIR/mods/scripts"

# World and players dirs (for backup)
WORLD_CELL_DIR="$BASE_DIR/world/cell"
WORLD_WORLD_DIR="$BASE_DIR/world/world"
WORLD_MAP_DIR="$BASE_DIR/world/map"
WORLD_RECORDSTORE_DIR="$BASE_DIR/world/recordstore"
WORLD_CUSTOM_DIR="$BASE_DIR/world/custom"
PLAYER_DIR="$BASE_DIR/players"

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

# Source the shared packaging library
export PLUGINS_DIR="$MODS_PLUGINS_DIR"
export SERVER_SCRIPTS_DIR="$MODS_SCRIPTS_DIR"
export ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")
export WORLD_CELL_DIR
export WORLD_WORLD_DIR
export WORLD_MAP_DIR
export WORLD_RECORDSTORE_DIR
export WORLD_CUSTOM_DIR
export PLAYER_DIR

source "$SCRIPT_DIR/package.sh"

echo "=== TES3MP Deploy Mods ==="

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

# Check if current.txt is valid (sha256 matches, archive exists)
_check_current_valid() {
    if [ ! -f "$CURRENT_FILE" ]; then
        return 1
    fi
    local sha256_from_file filename
    read -r sha256_from_file filename < "$CURRENT_FILE"
    if [ -z "$sha256_from_file" ] || [ -z "$filename" ]; then
        return 1
    fi
    local archive_path="$BACKUPS_DIR/$filename"
    if [ ! -f "$archive_path" ]; then
        return 1
    fi
    local actual_sha256
    actual_sha256=$(sha256sum "$archive_path" | cut -d' ' -f1)
    if [ "$actual_sha256" != "$sha256_from_file" ]; then
        return 1
    fi
    return 0
}

# Determine which archive to deploy
resolve_archive() {
    if [ "$#" -eq 0 ]; then
        # Mode: current.txt
        if ! _check_current_valid; then
            err "current.txt is invalid or missing."
            err "Specify an archive or use --latest."
            exit 1
        fi
        local sha256_from_file filename
        read -r sha256_from_file filename < "$CURRENT_FILE"
        echo "$BACKUPS_DIR/$filename"
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
    local need_mods_backup="${1:-no}"
    local available_kb
    available_kb=$(_get_free_kb "$BACKUPS_DIR")

    local total_needed_kb=0

    # Estimate world size
    local world_size=0
    for d in "$WORLD_CELL_DIR" "$WORLD_WORLD_DIR" "$WORLD_MAP_DIR" "$WORLD_RECORDSTORE_DIR" "$WORLD_CUSTOM_DIR"; do
        if [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ]; then
            world_size=$((world_size + $(du -sb "$d" 2>/dev/null | cut -f1)))
        fi
    done
    total_needed_kb=$((total_needed_kb + (world_size * 2 / 1024)))

    # Estimate players size
    local player_size=0
    if [ -d "$PLAYER_DIR" ] && [ -n "$(ls -A "$PLAYER_DIR" 2>/dev/null)" ]; then
        player_size=$(du -sb "$PLAYER_DIR" 2>/dev/null | cut -f1)
    fi
    total_needed_kb=$((total_needed_kb + (player_size * 2 / 1024)))

    # Estimate mods size (only if we need to backup mods)
    if [ "$need_mods_backup" = "yes" ]; then
        local mods_size=0
        if [ -d "$MODS_PLUGINS_DIR" ] && [ -n "$(ls -A "$MODS_PLUGINS_DIR" 2>/dev/null)" ]; then
            mods_size=$((mods_size + $(du -sb "$MODS_PLUGINS_DIR" 2>/dev/null | cut -f1)))
        fi
        if [ -d "$MODS_SCRIPTS_DIR" ] && [ -n "$(ls -A "$MODS_SCRIPTS_DIR" 2>/dev/null)" ]; then
            mods_size=$((mods_size + $(du -sb "$MODS_SCRIPTS_DIR" 2>/dev/null | cut -f1)))
        fi
        total_needed_kb=$((total_needed_kb + (mods_size * 2 / 1024)))
    fi

    if [ "$available_kb" -lt "$total_needed_kb" ]; then
        err "Not enough disk space for backup."
        err "  Available: $((available_kb / 1024)) MB"
        err "  Needed (2x margin): $((total_needed_kb / 1024)) MB"
        exit 1
    fi
    ok "Backup space OK: $((available_kb / 1024)) MB available, ~$((total_needed_kb / 1024)) MB needed"
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

# Generate customScripts.lua from mods/scripts/
generate_custom_scripts_lua() {
    local output_file="$BASE_DIR/configs/customScripts.lua"
    mkdir -p "$(dirname "$output_file")"

    echo "-- This file is auto-generated by deploy_mods.sh" > "$output_file"
    echo "-- Do not edit manually — changes will be overwritten" >> "$output_file"

    local count=0
    if [ -d "$MODS_SCRIPTS_DIR" ]; then
        for file in "$MODS_SCRIPTS_DIR"/*.lua "$MODS_SCRIPTS_DIR"/*.LUA; do
            [ -f "$file" ] || continue
            local name
            name="$(basename "$file" .lua)"
            echo "require(\"custom.$name\")" >> "$output_file"
            ((count++)) || true
        done
    fi

    echo "[deploy_mods.sh] Generated customScripts.lua ($count scripts)" >&2
}

# ────────────────────────────────────────────────────
# Main flow
# ────────────────────────────────────────────────────

ARCHIVE_PATH=$(resolve_archive "$@")
echo "Archive: $ARCHIVE_PATH"
echo ""

# Determine if this is a rollback or current.txt is invalid
IS_ROLLBACK=0
if [ "$#" -gt 0 ] && [ "$1" != "--latest" ]; then
    IS_ROLLBACK=1
fi
if ! _check_current_valid; then
    IS_ROLLBACK=1
fi

# Step 1-2: Check backup space (determine if mods backup is needed)
NEED_MODS_BACKUP="no"
if [ "$IS_ROLLBACK" -eq 1 ]; then
    NEED_MODS_BACKUP="yes"
fi

echo "[1/9] Checking backup space..."
check_backup_space "$NEED_MODS_BACKUP"

# Step 2: Backup
echo ""
echo "[2/9] Backing up data..."
TIMESTAMP=$(date +%F_%H-%M-%S)

# Mods backup (only if needed)
if [ "$NEED_MODS_BACKUP" = "yes" ]; then
    MODS_BACKUP_FILE="$BACKUPS_DIR/backup-${TIMESTAMP}-mods.tar.gz"
    package_mods "$MODS_BACKUP_FILE"
    ok "Mods backup saved: $MODS_BACKUP_FILE"
else
    info "current.txt is valid — mods backup not needed (data matches archive)"
fi

# Always backup world and players
WORLD_BACKUP_FILE="$BASE_DIR/backups/world/backup-${TIMESTAMP}-world.tar.gz"
package_world "$WORLD_BACKUP_FILE"
ok "World backup saved: $WORLD_BACKUP_FILE"

PLAYERS_BACKUP_FILE="$BASE_DIR/backups/players/backup-${TIMESTAMP}-players.tar.gz"
package_players "$PLAYERS_BACKUP_FILE"
ok "Players backup saved: $PLAYERS_BACKUP_FILE"

# Step 3: Stop TES3MP
echo ""
echo "[3/9] Stopping TES3MP..."
cd "$BASE_DIR" && docker compose down
ok "TES3MP stopped"

# Step 4: Check extract space
echo ""
echo "[4/9] Checking extract space..."
check_extract_space "$ARCHIVE_PATH"

# Step 5: Extract plugins/ → mods/plugins/, scripts/ → mods/scripts/
echo ""
echo "[5/9] Extracting mods archive..."

# Clean mods directories
if [ -d "$MODS_PLUGINS_DIR" ]; then
    rm -rf "$MODS_PLUGINS_DIR"/*
fi
if [ -d "$MODS_SCRIPTS_DIR" ]; then
    rm -rf "$MODS_SCRIPTS_DIR"/*
fi
mkdir -p "$MODS_PLUGINS_DIR" "$MODS_SCRIPTS_DIR"

# Extract plugins/ and scripts/ from archive
TMP_EXTRACT=$(mktemp -d)
tar xzf "$ARCHIVE_PATH" -C "$TMP_EXTRACT"

if [ -d "$TMP_EXTRACT/plugins" ]; then
    cp -r "$TMP_EXTRACT/plugins"/. "$MODS_PLUGINS_DIR/"
fi
if [ -d "$TMP_EXTRACT/scripts" ]; then
    cp -r "$TMP_EXTRACT/scripts"/. "$MODS_SCRIPTS_DIR/"
fi
rm -rf "$TMP_EXTRACT"

ok "Mods extracted from archive"

# Step 6: Generate customScripts.lua
echo ""
echo "[6/9] Generating customScripts.lua..."
generate_custom_scripts_lua
ok "customScripts.lua generated"

# Step 7: Write current.txt
echo ""
echo "[7/9] Writing current.txt..."
ARCHIVE_FILENAME=$(basename "$ARCHIVE_PATH")
ARCHIVE_SHA256=$(sha256sum "$ARCHIVE_PATH" | cut -d' ' -f1)
mkdir -p "$BACKUPS_DIR"
echo "$ARCHIVE_SHA256 $ARCHIVE_FILENAME" > "$CURRENT_FILE"
ok "current.txt updated: $ARCHIVE_SHA256 $ARCHIVE_FILENAME"

# Step 8: Create nginx symlink
echo ""
echo "[8/9] Creating nginx symlink..."
NGINX_SYMLINK="$BASE_DIR/backups/mods/current.tar.gz"
ln -sf "$ARCHIVE_PATH" "$NGINX_SYMLINK"
ok "Nginx symlink: $NGINX_SYMLINK → $(basename "$ARCHIVE_PATH")"

# Step 9: Start TES3MP
echo ""
echo "[9/9] Starting TES3MP..."
cd "$BASE_DIR" && docker compose up -d
ok "TES3MP started"

echo ""
echo "=== Done! Mods deployed successfully. ==="
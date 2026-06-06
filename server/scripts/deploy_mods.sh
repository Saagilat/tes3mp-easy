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
#   2. Checks free space for backup (world + players only)
#   3. Backs up current world and players
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

BACKUPS_DIR="$BASE_DIR/backups"
CURRENT_FILE="$BACKUPS_DIR/mods/current.txt"

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
export WORLD_CELL_DIR WORLD_WORLD_DIR WORLD_MAP_DIR WORLD_RECORDSTORE_DIR WORLD_CUSTOM_DIR
export PLAYER_DIR
export BACKUPS_DIR

source "$SCRIPT_DIR/package.sh"

echo "=== TES3MP Deploy Mods ==="

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

_check_current_valid() {
    if [ ! -f "$CURRENT_FILE" ]; then
        return 1
    fi
    local sha256_from_file filename
    read -r sha256_from_file filename < "$CURRENT_FILE"
    if [ -z "$sha256_from_file" ] || [ -z "$filename" ]; then
        return 1
    fi
    local archive_path="$BACKUPS_DIR/mods/$filename"
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

resolve_archive() {
    if [ "$#" -eq 0 ]; then
        if ! _check_current_valid; then
            err "current.txt is invalid or missing."
            err "Specify an archive or use --latest."
            exit 1
        fi
        local sha256_from_file filename
        read -r sha256_from_file filename < "$CURRENT_FILE"
        echo "$BACKUPS_DIR/mods/$filename"
        return 0
    fi

    case "$1" in
        --latest)
            local latest
            latest=$(ls -t "$BACKUPS_DIR"/mods/import-*.tar.gz "$BACKUPS_DIR"/mods/init-*.tar.gz 2>/dev/null | head -1)
            if [ -z "$latest" ]; then
                err "No import-* or init-* archives found in $BACKUPS_DIR/mods"
                exit 1
            fi
            echo "$latest"
            ;;
        *)
            local archive_path="$BACKUPS_DIR/mods/$1"
            if [ ! -f "$archive_path" ]; then
                err "Archive not found: $archive_path"
                exit 1
            fi
            echo "$archive_path"
            ;;
    esac
}

check_backup_space() {
    local available_kb
    available_kb=$(_get_free_kb "$BACKUPS_DIR")

    local total_needed_kb=0

    local world_size=0
    for d in "$WORLD_CELL_DIR" "$WORLD_WORLD_DIR" "$WORLD_MAP_DIR" "$WORLD_RECORDSTORE_DIR" "$WORLD_CUSTOM_DIR"; do
        if [ -d "$d" ] && [ -n "$(ls -A "$d" 2>/dev/null)" ]; then
            world_size=$((world_size + $(du -sb "$d" 2>/dev/null | cut -f1)))
        fi
    done
    total_needed_kb=$((total_needed_kb + (world_size * 2 / 1024)))

    local player_size=0
    if [ -d "$PLAYER_DIR" ] && [ -n "$(ls -A "$PLAYER_DIR" 2>/dev/null)" ]; then
        player_size=$(du -sb "$PLAYER_DIR" 2>/dev/null | cut -f1)
    fi
    total_needed_kb=$((total_needed_kb + (player_size * 2 / 1024)))

    if [ "$available_kb" -lt "$total_needed_kb" ]; then
        err "Not enough disk space for backup."
        err "  Available: $((available_kb / 1024)) MB"
        err "  Needed (2x margin): $((total_needed_kb / 1024)) MB"
        exit 1
    fi
    ok "Backup space OK: $((available_kb / 1024)) MB available, ~$((total_needed_kb / 1024)) MB needed"
}

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
        cd "$BASE_DIR" && docker compose up -d 2>/dev/null || true
        exit 1
    fi
    ok "Extract space OK: $((available_kb / 1024)) MB available, ~$((uncompressed_kb / 1024)) MB needed"
}

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

# Step 1: Check backup space (world + players only, mods backup not needed)
echo "[1/6] Checking backup space..."
check_backup_space

# Step 2: Backup world and players (current state)
echo ""
echo "[2/6] Backing up world and players..."
TIMESTAMP=$(date +%F_%H-%M-%S)

MODS_SHA256=$(sha256sum "$ARCHIVE_PATH" | cut -d' ' -f1)

WORLD_BACKUP_FILE="$BACKUPS_DIR/world/backup-${TIMESTAMP}-world.tar.gz"
package_world "$WORLD_BACKUP_FILE" "$MODS_SHA256"
ok "World backup saved: $WORLD_BACKUP_FILE"

PLAYERS_BACKUP_FILE="$BACKUPS_DIR/players/backup-${TIMESTAMP}-players.tar.gz"
package_players "$PLAYERS_BACKUP_FILE" "$MODS_SHA256"
ok "Players backup saved: $PLAYERS_BACKUP_FILE"

# Step 3: Check extract space
echo ""
echo "[3/6] Checking extract space..."
check_extract_space "$ARCHIVE_PATH"

# Step 4: Extract
echo ""
echo "[4/6] Extracting mods archive..."
if [ -d "$MODS_PLUGINS_DIR" ]; then
    rm -rf "$MODS_PLUGINS_DIR"/*
fi
if [ -d "$MODS_SCRIPTS_DIR" ]; then
    rm -rf "$MODS_SCRIPTS_DIR"/*
fi
mkdir -p "$MODS_PLUGINS_DIR" "$MODS_SCRIPTS_DIR"

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

# Step 5: Generate customScripts.lua
echo ""
echo "[5/6] Generating customScripts.lua..."
generate_custom_scripts_lua
ok "customScripts.lua generated"

# Step 6: Write current.txt
echo ""
echo "[6/6] Writing current.txt..."
ARCHIVE_FILENAME=$(basename "$ARCHIVE_PATH")
ARCHIVE_SHA256=$(sha256sum "$ARCHIVE_PATH" | cut -d' ' -f1)
mkdir -p "$BACKUPS_DIR/mods"
echo "$ARCHIVE_SHA256 $ARCHIVE_FILENAME" > "$CURRENT_FILE"
ok "current.txt updated: $ARCHIVE_SHA256 $ARCHIVE_FILENAME"

touch /tes3mp-easy/needs_restart.flag 2>/dev/null || true
echo ""
echo "=== Done! Mods deployed. Use 'Restart' in admin menu to apply. ==="
#!/bin/bash
#
# export_world.sh — create a snapshot of world data and save to backups
#
# Usage: bash export_world.sh
#
# Creates: backups/world/export-<timestamp>-world.tar.gz
#
# Requirements: bash, tar

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

BACKUPS_DIR="$BASE_DIR/backups/world"
WORLD_CELL_DIR="$BASE_DIR/world/cell"
WORLD_WORLD_DIR="$BASE_DIR/world/world"
WORLD_MAP_DIR="$BASE_DIR/world/map"
WORLD_RECORDSTORE_DIR="$BASE_DIR/world/recordstore"
WORLD_CUSTOM_DIR="$BASE_DIR/world/custom"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

export WORLD_CELL_DIR
export WORLD_WORLD_DIR
export WORLD_MAP_DIR
export WORLD_RECORDSTORE_DIR
export WORLD_CUSTOM_DIR

source "$SCRIPT_DIR/package.sh"

echo "=== TES3MP Export World ==="

mkdir -p "$BACKUPS_DIR"
TIMESTAMP=$(date +%F_%H-%M-%S)
ARCHIVE_PATH="$BACKUPS_DIR/export-${TIMESTAMP}-world.tar.gz"

package_world "$ARCHIVE_PATH"

if [[ -f "$ARCHIVE_PATH" ]]; then
    echo "$(basename "$ARCHIVE_PATH")"
    ok "World snapshot saved: $ARCHIVE_PATH"
else
    err "Failed to create snapshot"
    exit 1
fi

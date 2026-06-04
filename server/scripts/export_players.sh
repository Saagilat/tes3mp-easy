#!/bin/bash
#
# export_players.sh — create a snapshot of player data and save to backups
#
# Usage: bash export_players.sh
#
# Creates: backups/players/export-<timestamp>-players.tar.gz
#
# Requirements: bash, tar

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

BACKUPS_DIR="$BASE_DIR/backups/players"
PLAYER_DIR="$BASE_DIR/players"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }
ok()   { echo -e "${GREEN}[OK]${NC}   $*"; }
info() { echo -e "${BLUE}[INFO]${NC} $*"; }

export PLAYER_DIR

source "$SCRIPT_DIR/package.sh"

echo "=== TES3MP Export Players ==="

mkdir -p "$BACKUPS_DIR"
TIMESTAMP=$(date +%F_%H-%M-%S)
ARCHIVE_PATH="$BACKUPS_DIR/export-${TIMESTAMP}-players.tar.gz"

package_players "$ARCHIVE_PATH"

if [[ -f "$ARCHIVE_PATH" ]]; then
    echo "$(basename "$ARCHIVE_PATH")"
    ok "Players snapshot saved: $ARCHIVE_PATH"
else
    err "Failed to create snapshot"
    exit 1
fi

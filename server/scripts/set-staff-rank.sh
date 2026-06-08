#!/bin/bash
#
# set-staff-rank.sh — Set staff rank for a player
#
# Usage: set-staff-rank.sh <player_name> <rank>
#   rank: 0=none, 1=moderator, 2=admin, 3=owner
#
# What it does:
#   1. Backs up current players
#   2. Backs up current world
#   3. Sets settings.staffRank in the player's JSON file
#   4. Touches needs_restart.flag
#
# Requirements: bash, tar, jq

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <player_name> <rank>" >&2
    exit 1
fi

PLAYER_NAME="$1"
RANK="$2"

# Validate rank
if [[ "$RANK" != "0" && "$RANK" != "1" && "$RANK" != "2" && "$RANK" != "3" ]]; then
    echo "Error: rank must be 0 (none), 1 (moderator), 2 (admin), or 3 (owner)" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

PLAYER_DIR="$BASE_DIR/players"
PLAYER_FILE="$PLAYER_DIR/$PLAYER_NAME.json"
BACKUPS_DIR="$BASE_DIR/backups"

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

# Check player file exists
if [[ ! -f "$PLAYER_FILE" ]]; then
    err "Player file not found: $PLAYER_FILE"
    exit 1
fi

source "$SCRIPT_DIR/package.sh"

TIMESTAMP=$(date +%F_%H-%M-%S)

echo "=== TES3MP Set Staff Rank ==="
echo "Player: $PLAYER_NAME"
echo "Rank: $RANK"
echo ""

# Step 1: Backup players
echo "[1/3] Backing up current players..."
BACKUP_PLAYERS="$BACKUPS_DIR/players/backup-${TIMESTAMP}-players.tar.gz"
package_players "$BACKUP_PLAYERS"
ok "Players backup saved: $BACKUP_PLAYERS"

# Step 2: Backup world
echo ""
echo "[2/3] Backing up current world..."
BACKUP_WORLD="$BACKUPS_DIR/world/backup-${TIMESTAMP}-world.tar.gz"
package_world "$BACKUP_WORLD"
ok "World backup saved: $BACKUP_WORLD"

# Step 3: Set staff rank
echo ""
echo "[3/3] Setting staff rank for $PLAYER_NAME..."
jq --argjson rank "$RANK" '.settings.staffRank = $rank' "$PLAYER_FILE" > "${PLAYER_FILE}.tmp" || {
    err "Failed to update staff rank"
    rm -f "${PLAYER_FILE}.tmp"
    exit 1
}
mv "${PLAYER_FILE}.tmp" "$PLAYER_FILE"
ok "Staff rank for $PLAYER_NAME set to $RANK"

touch "$BASE_DIR/needs_restart.flag" 2>/dev/null || true

echo ""
echo "=== Done! Use 'Restart' in admin menu to apply. ==="
#!/bin/bash
#
# import_players.sh — Import player data from a players.tar.gz archive
#
# What it does:
#   1. Checks for archive at /tes3mp-easy/import-players/players.tar.gz
#   2. Backs up current players via package.sh
#   3. Extracts players.tar.gz to container-data/server/data/player/
#   4. ** Does NOT stop TES3MP ** (players can be hot-added)
#   5. Cleans up import directory
#
# Usage:
#   Place players.tar.gz in /tes3mp-easy/import-players/
#   Run: bash import_players.sh
#
# Requirements: bash, tar, docker, docker compose
#
# Note: This script does NOT restart TES3MP. Player data is read
#       at runtime, so new/changed player files take effect immediately.
#       Cells are NOT modified.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$BASE_DIR/container-data"

IMPORT_DIR="$BASE_DIR/import-players"
ARCHIVE="$IMPORT_DIR/players.tar.gz"

SERVER_DATA_DIR="$DATA_DIR/server/data"
PLAYER_DIR="$SERVER_DATA_DIR/player"

# Backup directory
BACKUPS_DIR="$DATA_DIR/backups"

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

# --- Source the shared packaging library for package_players() ---
export PLAYER_DIR

source "$SCRIPT_DIR/package.sh"

echo "=== TES3MP Import Players ==="
echo "Archive:       $ARCHIVE"
echo "Player dir:    $PLAYER_DIR"
echo ""

# --- Dependency check ---
for cmd in tar docker; do
    if ! command -v "$cmd" &>/dev/null; then
        err "'$cmd' not found. Install it and try again."
        exit 1
    fi
done

# --- Step 1: Check archive ---
echo "[1/5] Checking archive..."
if [ ! -f "$ARCHIVE" ]; then
    err "Archive not found: $ARCHIVE"
    err "Place players.tar.gz in $IMPORT_DIR/ and re-run."
    exit 1
fi
ok "Archive found: $ARCHIVE"

# --- Step 2: Backup current players ---
echo ""
echo "[2/5] Backing up current players..."

TIMESTAMP=$(date +%F_%H-%M-%S)
mkdir -p "$BACKUPS_DIR"
package_players "$BACKUPS_DIR/players_${TIMESTAMP}.tar.gz"

ok "Player backup saved to: $BACKUPS_DIR"

# --- Step 3: Extract players archive ---
echo ""
echo "[3/5] Extracting player data to $PLAYER_DIR..."

mkdir -p "$PLAYER_DIR"
tar xzf "$ARCHIVE" -C "$SERVER_DATA_DIR"

ok "Player data extracted"

# --- Step 4: Verify extraction ---
echo ""
echo "[4/5] Verifying player data..."
player_count=0
if [ -d "$PLAYER_DIR" ]; then
    player_count=$(ls -1 "$PLAYER_DIR" 2>/dev/null | wc -l)
fi

if [ "$player_count" -gt 0 ]; then
    ok "Player files found: $player_count"
else
    warn "No player files found after extraction — archive may be empty or malformed"
fi

# --- Step 5: Clean up ---
echo ""
echo "[5/5] Cleaning up import directory..."

rm -rf "$IMPORT_DIR"
ok "Import directory cleaned up"

echo ""
echo "=== Done! Players imported without server restart ==="
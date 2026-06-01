#!/bin/bash
#
# import_players.sh — Import player data from a players.tar.gz archive
#
# What it does:
#   1. Checks for archive at /tes3mp-easy/import-players/players.tar.gz
#   2. Moves it to backups/players/import-<timestamp>-players.tar.gz
#   3. Cleans up import directory
#   4. Does NOT stop TES3MP (import only — deploy is a separate step)
#
# Usage:
#   Place players.tar.gz in /tes3mp-easy/import-players/
#   Run: bash import_players.sh
#
# Requirements: bash, tar
#
# Note: This script only saves the archive. To deploy it, run deploy_players.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

IMPORT_DIR="$BASE_DIR/import-players"
ARCHIVE="$IMPORT_DIR/players.tar.gz"

BACKUPS_DIR="$BASE_DIR/backups/players"

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

echo "=== TES3MP Import Players ==="
echo "Archive:       $ARCHIVE"
echo ""

# --- Step 1: Check archive ---
echo "[1/3] Checking archive..."
if [ ! -f "$ARCHIVE" ]; then
    err "Archive not found: $ARCHIVE"
    err "Place players.tar.gz in $IMPORT_DIR/ and re-run."
    exit 1
fi
ok "Archive found: $ARCHIVE"

# --- Step 2: Move to backups ---
echo ""
echo "[2/3] Moving archive to backups..."

TIMESTAMP=$(date +%F_%H-%M-%S)
mkdir -p "$BACKUPS_DIR"
DEST="$BACKUPS_DIR/import-${TIMESTAMP}-players.tar.gz"
mv "$ARCHIVE" "$DEST"
ok "Archive saved to: $DEST"

# --- Step 3: Clean up ---
echo ""
echo "[3/3] Cleaning up import directory..."
rm -rf "$IMPORT_DIR"
ok "Import directory cleaned up"

echo ""
touch /tes3mp-easy/needs_restart.flag 2>/dev/null || true
echo "=== Done! Players archive saved. Run deploy_players.sh to deploy. ==="

#!/bin/bash
#
# import_world.sh — Import world data from a world.tar.gz archive
#
# What it does:
#   1. Checks for archive at /tes3mp-easy/import-world/world.tar.gz
#   2. Moves it to backups/world/import-<timestamp>-world.tar.gz
#   3. Cleans up import directory
#   4. Does NOT stop TES3MP (import only — deploy is a separate step)
#
# Usage:
#   Place world.tar.gz in /tes3mp-easy/import-world/
#   Run: bash import_world.sh
#
# Requirements: bash, tar
#
# Note: This script only saves the archive. To deploy it, run deploy_world.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

IMPORT_DIR="$BASE_DIR/import-world"
ARCHIVE="$IMPORT_DIR/world.tar.gz"

BACKUPS_DIR="$BASE_DIR/backups/world"

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

echo "=== TES3MP Import World ==="
echo "Archive:       $ARCHIVE"
echo ""

# --- Step 1: Check archive ---
echo "[1/3] Checking archive..."
if [ ! -f "$ARCHIVE" ]; then
    err "Archive not found: $ARCHIVE"
    err "Place world.tar.gz in $IMPORT_DIR/ and re-run."
    exit 1
fi
ok "Archive found: $ARCHIVE"

# --- Step 2: Move to backups ---
echo ""
echo "[2/3] Moving archive to backups..."

TIMESTAMP=$(date +%F_%H-%M-%S)
mkdir -p "$BACKUPS_DIR"
DEST="$BACKUPS_DIR/import-${TIMESTAMP}-world.tar.gz"
mv "$ARCHIVE" "$DEST"
ok "Archive saved to: $DEST"

# --- Step 3: Clean up ---
echo ""
echo "[3/3] Cleaning up import directory..."
rm -rf "$IMPORT_DIR"
ok "Import directory cleaned up"

echo ""
echo "=== Done! World archive saved. Run deploy_world.sh to deploy. ==="

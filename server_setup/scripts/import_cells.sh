#!/bin/bash
#
# import_cells.sh — Import cell data from a cells.tar.gz archive
#
# What it does:
#   1. Checks for archive at /tes3mp-easy/import-cells/cells.tar.gz
#   2. Backs up current cells via package.sh
#   3. Stops TES3MP container
#   4. Extracts cells.tar.gz to container-data/server/data/cell/
#   5. Starts TES3MP container
#   6. Cleans up import directory
#
# Usage:
#   Place cells.tar.gz in /tes3mp-easy/import-cells/
#   Run: bash import_cells.sh
#
# Requirements: bash, tar, docker, docker compose
#
# Note: TES3MP is stopped before extracting cells because
#       changing cell data at runtime is unsafe/risky.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
DATA_DIR="$BASE_DIR/container-data"

IMPORT_DIR="$BASE_DIR/import-cells"
ARCHIVE="$IMPORT_DIR/cells.tar.gz"

SERVER_DATA_DIR="$DATA_DIR/server/data"
CELL_DIR="$SERVER_DATA_DIR/cell"

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

# --- Source the shared packaging library for package_cells() ---
export CELL_DIR

source "$SCRIPT_DIR/package.sh"

echo "=== TES3MP Import Cells ==="
echo "Archive:    $ARCHIVE"
echo "Cell dir:   $CELL_DIR"
echo ""

# --- Dependency check ---
for cmd in tar docker; do
    if ! command -v "$cmd" &>/dev/null; then
        err "'$cmd' not found. Install it and try again."
        exit 1
    fi
done

# --- Step 1: Check archive ---
echo "[1/6] Checking archive..."
if [ ! -f "$ARCHIVE" ]; then
    err "Archive not found: $ARCHIVE"
    err "Place cells.tar.gz in $IMPORT_DIR/ and re-run."
    exit 1
fi
ok "Archive found: $ARCHIVE"

# --- Step 2: Backup current cells ---
echo ""
echo "[2/6] Backing up current cells..."

TIMESTAMP=$(date +%F_%H-%M-%S)
mkdir -p "$BACKUPS_DIR"
package_cells "$BACKUPS_DIR/cells_${TIMESTAMP}.tar.gz"

ok "Cell backup saved to: $BACKUPS_DIR"

# --- Step 3: Stop TES3MP ---
echo ""
echo "[3/6] Stopping TES3MP container..."

cd "$BASE_DIR"
if command -v docker &>/dev/null && [ -f "$BASE_DIR/docker-compose.yml" ]; then
    docker compose stop tes3mp
    ok "TES3MP container stopped"
else
    warn "Docker compose not found — stop TES3MP manually"
fi

# --- Step 4: Extract cells archive ---
echo ""
echo "[4/6] Extracting cell data to $CELL_DIR..."

mkdir -p "$CELL_DIR"
tar xzf "$ARCHIVE" -C "$SERVER_DATA_DIR"

ok "Cell data extracted"

# --- Step 5: Start TES3MP ---
echo ""
echo "[5/6] Starting TES3MP container..."

if command -v docker &>/dev/null && [ -f "$BASE_DIR/docker-compose.yml" ]; then
    cd "$BASE_DIR"
    docker compose start tes3mp
    ok "TES3MP container started"
else
    warn "Docker compose not found — start TES3MP manually"
fi

# --- Step 6: Clean up ---
echo ""
echo "[6/6] Cleaning up import directory..."

rm -rf "$IMPORT_DIR"
ok "Import directory cleaned up"

echo ""
echo "=== Done! ==="
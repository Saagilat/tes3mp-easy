#!/bin/bash
#
# import_mods.sh — Import mods archive, validate, and save (no deploy)
#
# What it does:
#   1. Checks for archive at /tes3mp-easy/import-mods/mods.tar.gz
#   2. Validates requiredDataFiles.json inside the archive (CRC32)
#   3. On success: moves archive to backups/mods/import-<timestamp>-mods.tar.gz
#   4. On failure: removes archive, prints error, exits with non-zero
#   5. Cleans up import directory
#   6. Does NOT stop TES3MP (import only — deploy is a separate step)
#
# Usage:
#   Place mods.tar.gz in /tes3mp-easy/import-mods/
#   Run: bash import_mods.sh
#
# Exit codes:
#   0 — success (archive validated and saved)
#   1 — error (archive invalid, missing, or disk issue)
#
# Requirements: bash, rhash, tar

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"

IMPORT_DIR="$BASE_DIR/import-mods"
ARCHIVE="$IMPORT_DIR/mods.tar.gz"

BACKUPS_DIR="$BASE_DIR/backups/mods"

# Original Morrowind files — NOT present in mod archive
ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")

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

echo "=== TES3MP Import Mods ==="
echo "Archive:       $ARCHIVE"
echo ""

# --- Dependency check ---
for cmd in rhash tar; do
    if ! command -v "$cmd" &>/dev/null; then
        err "'$cmd' not found. Install it and try again."
        exit 1
    fi
done

# --- Step 1: Check archive ---
echo "[1/4] Checking archive..."
if [ ! -f "$ARCHIVE" ]; then
    err "Archive not found: $ARCHIVE"
    err "Place mods.tar.gz in $IMPORT_DIR/ and re-run."
    exit 1
fi
ok "Archive found: $ARCHIVE"

# --- Step 2: Extract and validate requiredDataFiles.json ---
echo ""
echo "[2/4] Validating requiredDataFiles.json..."
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT

tar xzf "$ARCHIVE" -C "$TMP_DIR"

REQ_JSON="$TMP_DIR/plugins/requiredDataFiles.json"

if [ ! -f "$REQ_JSON" ]; then
    err "requiredDataFiles.json not found in archive (expected at plugins/requiredDataFiles.json)"
    rm -f "$ARCHIVE"
    exit 1
fi

# Validate each plugin listed in requiredDataFiles.json exists and CRC32 matches
VALIDATION_FAILED=0

while IFS= read -r line; do
    # Match lines like: "filename.ext": [] or "filename.ext": ["0xCRC32"]
    if [[ "$line" =~ ^[[:space:]]*\"([^\"]+)\":[[:space:]]*\[(.*)\] ]]; then
        filename="${BASH_REMATCH[1]}"
        crc_content="${BASH_REMATCH[2]}"

        # Skip original files (Morrowind.esm, Tribunal.esm, Bloodmoon.esm)
        skip=0
        for orig in "${ORIGINAL_FILES[@]}"; do
            if [[ "${filename,,}" == "${orig,,}" ]]; then
                skip=1
                break
            fi
        done
        [[ "$skip" -eq 1 ]] && continue

        filepath="$TMP_DIR/plugins/$filename"

        # Check file exists in archive
        if [ ! -f "$filepath" ]; then
            err "Plugin \"$filename\" listed in requiredDataFiles.json but not found in archive"
            VALIDATION_FAILED=1
            continue
        fi

        # Extract expected CRC from crc_content (e.g. "0xABCD1234")
        expected_crc=""
        if [[ "$crc_content" =~ '"0x([0-9A-Fa-f]+)"' ]]; then
            expected_crc="${BASH_REMATCH[1]}"
        fi

        if [[ -n "$expected_crc" ]]; then
            actual_crc=$(rhash --crc32 --simple "$filepath" 2>/dev/null | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')
            expected_crc_upper="${expected_crc^^}"
            if [[ "$actual_crc" != "$expected_crc_upper" ]]; then
                err "CRC32 mismatch for \"$filename\": expected 0x$expected_crc_upper, got 0x$actual_crc"
                VALIDATION_FAILED=1
            fi
        fi
    fi
done < "$REQ_JSON"

if [ "$VALIDATION_FAILED" -ne 0 ]; then
    err "Validation failed — removing archive and aborting"
    rm -f "$ARCHIVE"
    exit 1
fi
ok "All plugins validated"

# --- Step 3: Move to backups ---
echo ""
echo "[3/4] Moving archive to backups..."

TIMESTAMP=$(date +%F_%H-%M-%S)
mkdir -p "$BACKUPS_DIR"
DEST="$BACKUPS_DIR/import-${TIMESTAMP}-mods.tar.gz"
mv "$ARCHIVE" "$DEST"
ok "Archive saved to: $DEST"

# --- Step 4: Clean up ---
echo ""
echo "[4/4] Cleaning up import directory..."
rm -rf "$IMPORT_DIR"
ok "Import directory cleaned up"

echo ""
echo "=== Done! Mods archive validated and saved. Run deploy_mods.sh to deploy. ==="
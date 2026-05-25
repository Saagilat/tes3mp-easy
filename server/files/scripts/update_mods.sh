#!/bin/bash
#
# update_mods.sh — automatic mod updater for TES3MP server
#
# What it does:
#   1. Removes all .esp/.esm from data/ except original ones (Morrowind, Tribunal, Bloodmoon)
#   2. Copies all .esp/.esm from mods/ to data/
#   3. Computes CRC32 for all .esp/.esm in data/
#   4. Generates data/requiredDataFiles.json
#   5. Creates mods.zip for distribution to players
#   6. Rebuilds and restarts the Docker container
#
# Usage:
#   Place .esp/.esm files in mods/
#   Run: bash update_mods.sh
#
# Removing a mod:
#   Delete the file from mods/ and run the script again
#
# Requirements: bash, python3, zip, docker, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
MODS_DIR="$SCRIPT_DIR/mods"

# Original Morrowind files — NOT touched or deleted
ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")

echo "=== TES3MP Mod Updater ==="
echo "Data directory: $DATA_DIR"
echo "Mods directory: $MODS_DIR"
echo ""

# --- Dependency check ---
for cmd in python3 rsync zip docker; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found. Install it and try again."
        exit 1
    fi
done

# --- Check that data/ exists ---
if [ ! -d "$DATA_DIR" ]; then
    echo "Error: data/ directory not found in $SCRIPT_DIR"
    exit 1
fi

# --- Step 1: Remove mods from data/ (keep only originals) ---
echo "[1/6] Removing old mods from data/..."
for file in "$DATA_DIR"/*.esp "$DATA_DIR"/*.ESP "$DATA_DIR"/*.esm "$DATA_DIR"/*.ESM; do
    [ -f "$file" ] || continue
    basename="$(basename "$file")"

    # Skip original files
    skip=0
    for orig in "${ORIGINAL_FILES[@]}"; do
        if [ "$basename" = "$orig" ]; then
            skip=1
            break
        fi
    done

    if [ "$skip" -eq 1 ]; then
        echo "  - Preserved: $basename"
    else
        rm -f "$file"
        echo "  - Removed: $basename"
    fi
done

# --- Step 2: Copy mods ---
echo ""
echo "[2/6] Copying mods from mods/ to data/..."
if [ ! -d "$MODS_DIR" ]; then
    echo "  mods/ directory does not exist. Creating..."
    mkdir -p "$MODS_DIR"
fi

copied=0
for file in "$MODS_DIR"/*.esp "$MODS_DIR"/*.ESp "$MODS_DIR"/*.esm "$MODS_DIR"/*.ESM "$MODS_DIR"/*.ESP "$MODS_DIR"/*.EsM; do
    [ -f "$file" ] || continue
    basename="$(basename "$file")"

    # Check if we're trying to copy a mod with an original file name
    skip=0
    for orig in "${ORIGINAL_FILES[@]}"; do
        if [ "${basename,,}" = "${orig,,}" ]; then
            skip=1
            break
        fi
    done

    if [ "$skip" -eq 1 ]; then
        echo "  - Skipped (matches original): $basename"
        continue
    fi

    cp "$file" "$DATA_DIR/"
    echo "  - Copied: $basename"
    ((copied++)) || true
done

if [ "$copied" -eq 0 ]; then
    echo "  (no mods to copy)"
fi

# --- Step 3: Compute CRC32 ---
echo ""
echo ""
echo "[3/6] Generating requiredDataFiles.json..."

# Generate JSON via Python
export _DATA_DIR="$DATA_DIR"
export _ORIG_FILES="${ORIGINAL_FILES[*]}"
python3 <<'PYEOF'
import json, zlib, os, glob

data_dir = os.environ['_DATA_DIR']
original_files = os.environ['_ORIG_FILES'].split()

result = []

# Always add original master files with empty CRC (allows Steam + GOG + any edition)
for orig in original_files:
    result.append({orig: []})

# Collect .esp/.esm files (mods)
files = []
for pattern in ('*.esp', '*.ESP', '*.esm', '*.ESM'):
    files.extend(sorted(glob.glob(os.path.join(data_dir, pattern))))

for filepath in files:
    basename = os.path.basename(filepath)

    # Skip originals — already added above
    if basename in original_files:
        continue

    # For mods compute CRC32
    with open(filepath, 'rb') as f:
        data = f.read()
    crc = zlib.crc32(data) & 0xFFFFFFFF
    result.append({basename: [f"0x{crc:08X}"]})

# Write output
output_path = os.path.join(data_dir, "requiredDataFiles.json")
with open(output_path, 'w') as f:
    json.dump(result, f, indent=4)
    f.write('\n')

print(f"  Generated file: {output_path}")
print(f"  Records: {len(result)}")
for entry in result:
    for name, crcs in entry.items():
        print(f"    - {name}: {crcs}")
PYEOF

echo ""
echo "[5/6] Creating mods.zip for distribution to players..."

# Collect mods (all .esp/.esm except originals)
mods_to_zip=()
for file in "$DATA_DIR"/*.esp "$DATA_DIR"/*.ESP "$DATA_DIR"/*.esm "$DATA_DIR"/*.ESM; do
    [ -f "$file" ] || continue
    basename="$(basename "$file")"

    skip=0
    for orig in "${ORIGINAL_FILES[@]}"; do
        if [ "$basename" = "$orig" ]; then
            skip=1
            break
        fi
    done

    if [ "$skip" -eq 0 ]; then
        mods_to_zip+=("$file")
    fi
done

if [ ${#mods_to_zip[@]} -gt 0 ]; then
    rm -f "$DATA_DIR/mods.zip"
    zip -j "$DATA_DIR/mods.zip" "${mods_to_zip[@]}"
    echo "  Created: $DATA_DIR/mods.zip (${#mods_to_zip[@]} files)"
else
    echo "  No mods to archive"
fi

echo ""
echo "[6/6] Rebuilding and restarting Docker container..."

if [ ! -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    echo "  Error: docker-compose.yml not found in $SCRIPT_DIR"
    exit 1
fi

cd "$SCRIPT_DIR"
docker compose up -d --build

echo ""
echo "=== Done! ==="
echo "Check logs: docker compose logs 2>&1 | grep -E 'requiredDataFiles|Data file'"
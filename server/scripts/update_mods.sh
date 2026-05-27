#!/bin/bash
#
# update_mods.sh — automatic mod & script updater for TES3MP server
#
# What it does:
#   1. Removes all .esp/.esm/.omwaddon/.omwscripts/.omwgame from server/data/
#      except original ones (Morrowind, Tribunal, Bloodmoon)
#   2. Copies all .esp/.esm/.omwaddon/.omwscripts/.omwgame from mods/ to server/data/
#   3. Synchronises .lua scripts from scripts/ to server/scripts/custom/ (removes stale scripts)
#   4. Generates server/scripts/customScripts.lua with script names
#   5. Patches server/scripts/serverCore.lua to load customScripts.lua
#   6. Computes CRC32 for all mod files in server/data/
#   7. Generates server/data/requiredDataFiles.json (for TES3MP) and
#      requiredDataFiles.json (for nginx /get-required-data endpoint)
#   8. Creates mods.zip from server/data/ at data/mods.zip for /get-mods
#   9. Creates scripts.zip at data/scripts.zip for /get-scripts
#  10. Restarts the Docker container
#
# Usage:
#   Place .esp/.esm/.omwaddon/.omwscripts/.omwgame files in mods/
#   Place .lua files in scripts/
#   Run: bash update_mods.sh
#
# Removing a mod/script:
#   Delete the file from mods/ or scripts/ and run the script again
#
# Requirements: bash, rhash, rsync, zip, docker, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
MODS_DIR="$SCRIPT_DIR/mods"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# TES3MP paths inside the container (data/ is mounted at /tes3mp)
# TES3MP runs with home=./server, so it looks for mods in server/data/
SERVER_DATA_DIR="$DATA_DIR/server/data"
SERVER_SCRIPTS_DIR="$DATA_DIR/server/scripts"

# Original Morrowind files — NOT touched or deleted
ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")

echo "=== TES3MP Mod & Script Updater ==="
echo "Data directory:    $DATA_DIR"
echo "Server data:       $SERVER_DATA_DIR"
echo "Mods directory:    $MODS_DIR"
echo "Scripts directory: $SCRIPTS_DIR"
echo ""

# --- Dependency check ---
for cmd in rhash rsync zip docker; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' not found. Install it and try again."
        exit 1
    fi
done

# --- Ensure server/data/ exists ---
mkdir -p "$SERVER_DATA_DIR"

# --- Step 1: Remove mods from server/data/ (keep only originals) ---
echo "[1/8] Removing old mods from server/data/..."
for file in "$SERVER_DATA_DIR"/*.esp "$SERVER_DATA_DIR"/*.ESP "$SERVER_DATA_DIR"/*.esm "$SERVER_DATA_DIR"/*.ESM \
            "$SERVER_DATA_DIR"/*.omwaddon "$SERVER_DATA_DIR"/*.OMWADDON \
            "$SERVER_DATA_DIR"/*.omwscripts "$SERVER_DATA_DIR"/*.OMWSCRIPTS \
            "$SERVER_DATA_DIR"/*.omwgame "$SERVER_DATA_DIR"/*.OMWGAME; do
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

# --- Step 2: Copy mods to server/data/ ---
echo ""
echo "[2/8] Copying mods from mods/ to server/data/..."
if [ ! -d "$MODS_DIR" ]; then
    echo "  mods/ directory does not exist. Creating..."
    mkdir -p "$MODS_DIR"
fi

copied=0
for file in "$MODS_DIR"/*.esp "$MODS_DIR"/*.ESp "$MODS_DIR"/*.esm "$MODS_DIR"/*.ESM "$MODS_DIR"/*.ESP "$MODS_DIR"/*.EsM \
            "$MODS_DIR"/*.omwaddon "$MODS_DIR"/*.OMWADDON "$MODS_DIR"/*.Omwaddon "$MODS_DIR"/*.oMwAddon \
            "$MODS_DIR"/*.omwscripts "$MODS_DIR"/*.OMWSCRIPTS \
            "$MODS_DIR"/*.omwgame "$MODS_DIR"/*.OMWGAME; do
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

    cp "$file" "$SERVER_DATA_DIR/"
    echo "  - Copied: $basename"
    ((copied++)) || true
done

if [ "$copied" -eq 0 ]; then
    echo "  (no mods to copy)"
fi

# --- Step 3: Sync scripts ---
echo ""
echo "[3/8] Syncing scripts to server/scripts/custom/..."
CUSTOM_SCRIPTS_DIR="$SERVER_SCRIPTS_DIR/custom"
mkdir -p "$CUSTOM_SCRIPTS_DIR"

# Remove all existing custom scripts (clean sync)
rm -f "$CUSTOM_SCRIPTS_DIR"/*.lua

script_copied=0
if [ -d "$SCRIPTS_DIR" ]; then
    for file in "$SCRIPTS_DIR"/*.lua "$SCRIPTS_DIR"/*.LUA; do
        [ -f "$file" ] || continue
        cp "$file" "$CUSTOM_SCRIPTS_DIR/"
        echo "  - Copied: $(basename "$file")"
        ((script_copied++)) || true
    done
fi

if [ "$script_copied" -eq 0 ]; then
    echo "  (no scripts to copy)"
fi

# --- Step 4: Generate customScripts.lua ---
echo ""
echo "[4/8] Generating customScripts.lua..."

CUSTOM_SCRIPTS_LUA="$SERVER_SCRIPTS_DIR/customScripts.lua"

# Generate customScripts.lua that requires each custom script
# The server calls require("customScripts"), so the file must load the scripts
echo "-- This file is auto-generated by update_mods.sh" > "$CUSTOM_SCRIPTS_LUA"
echo "-- Do not edit manually — changes will be overwritten" >> "$CUSTOM_SCRIPTS_LUA"

# Using dofile because require caches modules (require won't load scripts more than once)
# dofile on the other hand always executes the file each time it's called,
# but here it's only called once during server startup via require("customScripts")
# so dofile is the correct approach to avoid caching issues
for file in "$CUSTOM_SCRIPTS_DIR"/*.lua; do
    [ -f "$file" ] || continue
    basename="$(basename "$file" .lua)"
    echo "require(\"custom.$basename\")" >> "$CUSTOM_SCRIPTS_LUA"
done

echo "  Generated: $(basename "$CUSTOM_SCRIPTS_LUA") ($(ls -1 "$CUSTOM_SCRIPTS_DIR"/*.lua 2>/dev/null | wc -l) scripts)"

# --- Step 5: Check serverCore.lua ---
echo ""
echo "[5/8] Checking serverCore.lua..."

SERVER_CORE_LUA="$SERVER_SCRIPTS_DIR/serverCore.lua"

if [ ! -f "$SERVER_CORE_LUA" ]; then
    echo "  Warning: serverCore.lua not found at $SERVER_CORE_LUA"
    echo "  customScripts.lua will be available but not auto-loaded."
    echo "  Make sure your serverCore.lua contains:"
    echo "    customScripts = require(\"customScripts\")"
else
    if grep -q "require.*customScripts" "$SERVER_CORE_LUA" 2>/dev/null; then
        echo "  serverCore.lua already has require(\"customScripts\") — no changes needed"
    elif grep -q "customScripts" "$SERVER_CORE_LUA" 2>/dev/null; then
        echo "  Note: serverCore.lua has customScripts but no require('customScripts')"
        echo "  customScripts.lua is generated but needs manual require in serverCore.lua:"
        echo "    customScripts = require(\"customScripts\")"
    else
        echo "  Note: customScripts.lua is generated but serverCore.lua needs:"
        echo "    customScripts = require(\"customScripts\")"
    fi

    # Remove any dofile patches we might have added in previous versions
    if grep -q "dofile.*customScripts" "$SERVER_CORE_LUA" 2>/dev/null; then
        sed -i '/dofile.*customScripts/d' "$SERVER_CORE_LUA"
        echo "  Cleaned up: removed legacy dofile patch"
    fi
fi

# --- Step 6: Generate requiredDataFiles.json ---
echo ""
echo "[6/8] Generating requiredDataFiles.json..."

# Generate for TES3MP (in server/data/)
REQ_JSON="$SERVER_DATA_DIR/requiredDataFiles.json"

# Start JSON array
printf "[\n" > "$REQ_JSON"

# Add original master files with empty CRC (allows Steam + GOG + any edition)
for orig in "${ORIGINAL_FILES[@]}"; do
    printf '  {\n    "%s": []\n  },\n' "$orig" >> "$REQ_JSON"
done

# Collect and sort mod files from server/data/
mod_files=()
for pattern in *.esp *.ESP *.esm *.ESM \
               *.omwaddon *.OMWADDON \
               *.omwscripts *.OMWSCRIPTS \
               *.omwgame *.OMWGAME; do
    for file in "$SERVER_DATA_DIR"/$pattern; do
        [ -f "$file" ] || continue
        basename="$(basename "$file")"

        # Skip originals
        skip=0
        for orig in "${ORIGINAL_FILES[@]}"; do
            if [ "$basename" = "$orig" ]; then
                skip=1
                break
            fi
        done
        [ "$skip" -eq 1 ] && continue

        mod_files+=("$file")
    done
done

# Sort by filename
IFS=$'\n' mod_files=($(sort <<<"${mod_files[*]}"))
unset IFS

for filepath in "${mod_files[@]}"; do
    basename="$(basename "$filepath")"
    crc=$(rhash --crc32 --simple "$filepath" | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')
    printf '  {\n    "%s": ["0x%s"]\n  },\n' "$basename" "$crc" >> "$REQ_JSON"
done

# Remove trailing comma from last entry and close JSON array
sed -i '$ s/,$//' "$REQ_JSON"
printf "]\n" >> "$REQ_JSON"

echo "  Generated: $REQ_JSON (for TES3MP)"
echo "  Records: $(( ${#ORIGINAL_FILES[@]} + ${#mod_files[@]} ))"

# Also copy to data/ root for nginx /get-required-data endpoint
cp "$REQ_JSON" "$DATA_DIR/requiredDataFiles.json"
echo "  Copied to $DATA_DIR/requiredDataFiles.json (for nginx)"

# --- Step 7: Create mods.zip ---
echo ""
echo "[7/8] Creating mods.zip for distribution to players..."

# Collect mods from server/data/
mods_to_zip=()
for file in "$SERVER_DATA_DIR"/*.esp "$SERVER_DATA_DIR"/*.ESP "$SERVER_DATA_DIR"/*.esm "$SERVER_DATA_DIR"/*.ESM \
            "$SERVER_DATA_DIR"/*.omwaddon "$SERVER_DATA_DIR"/*.OMWADDON \
            "$SERVER_DATA_DIR"/*.omwscripts "$SERVER_DATA_DIR"/*.OMWSCRIPTS \
            "$SERVER_DATA_DIR"/*.omwgame "$SERVER_DATA_DIR"/*.OMWGAME; do
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

rm -f "$DATA_DIR/mods.zip"
if [ ${#mods_to_zip[@]} -gt 0 ]; then
    zip -j "$DATA_DIR/mods.zip" "${mods_to_zip[@]}"
    echo "  Created: $DATA_DIR/mods.zip (${#mods_to_zip[@]} files)"
fi

# Include requiredDataFiles.json for client to know load order
if [ -f "$DATA_DIR/requiredDataFiles.json" ]; then
    cp "$DATA_DIR/requiredDataFiles.json" "$SCRIPT_DIR/tmp_req.json"
    zip -j "$DATA_DIR/mods.zip" "$SCRIPT_DIR/tmp_req.json"
    rm -f "$SCRIPT_DIR/tmp_req.json"
    echo "  Added to archive: requiredDataFiles.json"
fi

if [ ! -f "$DATA_DIR/mods.zip" ]; then
    echo "  No mods to archive"
fi

# --- Step 8: Create scripts.zip ---
echo ""
echo "[8/8] Creating scripts.zip for distribution..."

rm -f "$DATA_DIR/scripts.zip"
if [ "$script_copied" -gt 0 ]; then
    scripts_to_zip=()
    for file in "$CUSTOM_SCRIPTS_DIR"/*.lua; do
        [ -f "$file" ] || continue
        scripts_to_zip+=("$file")
    done

    if [ ${#scripts_to_zip[@]} -gt 0 ]; then
        zip -j "$DATA_DIR/scripts.zip" "${scripts_to_zip[@]}"
        echo "  Created: $DATA_DIR/scripts.zip (${#scripts_to_zip[@]} files)"
    fi
fi

if [ ! -f "$DATA_DIR/scripts.zip" ]; then
    echo "  No scripts to archive"
fi

echo ""
echo "=== Restarting Docker container... ==="

if command -v docker &>/dev/null && [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    cd "$SCRIPT_DIR"
    docker compose restart
    echo ""
    echo "=== Done! ==="
else
    echo ""
    echo "=== Done! ==="
    echo "Restart the Docker container manually:"
    echo "  cd $SCRIPT_DIR && docker compose restart"
fi
#!/bin/bash
#
# update_mods.sh — automatic mod & script updater for TES3MP server
#
# What it does:
#   1. Removes all .esp/.esm/.omwaddon/.omwscripts/.omwgame from data/ except original ones (Morrowind, Tribunal, Bloodmoon)
#   2. Copies all .esp/.esm/.omwaddon/.omwscripts/.omwgame from mods/ to data/
#   3. Synchronises .lua scripts from scripts/ to data/server/scripts/custom/ (removes stale scripts)
#   4. Generates data/server/scripts/customScripts.lua with script names
#   5. Patches data/server/scripts/serverCore.lua to load customScripts.lua
#   6. Computes CRC32 for all mod files in data/
#   7. Generates data/requiredDataFiles.json
#   8. Creates mods.zip for distribution to players
#   9. Creates scripts.zip for web endpoint
#  10. Rebuilds and restarts the Docker container
#
# Usage:
#   Place .esp/.esm/.omwaddon/.omwscripts/.omwgame files in mods/
#   Place .lua files in scripts/
#   Run: bash update_mods.sh
#
# Removing a mod/script:
#   Delete the file from mods/ or scripts/ and run the script again
#
# Requirements: bash, python3, rsync, zip, docker, docker compose

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="$SCRIPT_DIR/data"
MODS_DIR="$SCRIPT_DIR/mods"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"

# Original Morrowind files — NOT touched or deleted
ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")

echo "=== TES3MP Mod & Script Updater ==="
echo "Data directory:    $DATA_DIR"
echo "Mods directory:    $MODS_DIR"
echo "Scripts directory: $SCRIPTS_DIR"
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
echo "[1/8] Removing old mods from data/..."
for file in "$DATA_DIR"/*.esp "$DATA_DIR"/*.ESP "$DATA_DIR"/*.esm "$DATA_DIR"/*.ESM \
            "$DATA_DIR"/*.omwaddon "$DATA_DIR"/*.OMWADDON \
            "$DATA_DIR"/*.omwscripts "$DATA_DIR"/*.OMWSCRIPTS \
            "$DATA_DIR"/*.omwgame "$DATA_DIR"/*.OMWGAME; do
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
echo "[2/8] Copying mods from mods/ to data/..."
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

    cp "$file" "$DATA_DIR/"
    echo "  - Copied: $basename"
    ((copied++)) || true
done

if [ "$copied" -eq 0 ]; then
    echo "  (no mods to copy)"
fi

# --- Step 3: Sync scripts ---
echo ""
echo "[3/8] Syncing scripts to data/server/scripts/custom/..."
CUSTOM_SCRIPTS_DIR="$DATA_DIR/server/scripts/custom"
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

CUSTOM_SCRIPTS_LUA="$DATA_DIR/server/scripts/customScripts.lua"
echo "return {" > "$CUSTOM_SCRIPTS_LUA"

script_names=()
for file in "$CUSTOM_SCRIPTS_DIR"/*.lua; do
    [ -f "$file" ] || continue
    basename="$(basename "$file" .lua)"
    # Convert module name: replace / with ., remove extension
    script_names+=("$basename")
done

for name in "${script_names[@]}"; do
    echo "    \"custom.$name\"," >> "$CUSTOM_SCRIPTS_LUA"
done

echo "}" >> "$CUSTOM_SCRIPTS_LUA"
echo "  Generated: $(basename "$CUSTOM_SCRIPTS_LUA") (${#script_names[@]} scripts)"

# --- Step 5: Patch serverCore.lua ---
echo ""
echo "[5/8] Patching serverCore.lua to load custom scripts..."

SERVER_CORE_LUA="$DATA_DIR/server/scripts/serverCore.lua"

if [ ! -f "$SERVER_CORE_LUA" ]; then
    echo "  Warning: serverCore.lua not found at $SERVER_CORE_LUA"
    echo "  customScripts.lua will be available but not auto-loaded."
    echo "  Add the following to your serverCore.lua manually:"
    echo "    customScripts = dofile(\"customScripts.lua\")"
else
    # Check if already patched
    if grep -q "dofile(\"customScripts.lua\")" "$SERVER_CORE_LUA" 2>/dev/null; then
        echo "  serverCore.lua already patched — skipping"
    else
        # Replace customScripts = {} with dofile version
        if grep -q "customScripts\s*=" "$SERVER_CORE_LUA" 2>/dev/null; then
            sed -i 's/customScripts\s*=\s*{.*}/customScripts = dofile("customScripts.lua")/' "$SERVER_CORE_LUA"
            echo "  Patched: replaced customScripts = {...} with dofile(\"customScripts.lua\")"
        else
            # If no customScripts line exists, prepend it at the beginning
            sed -i '1i customScripts = dofile("customScripts.lua")' "$SERVER_CORE_LUA"
            echo "  Patched: prepended customScripts = dofile(\"customScripts.lua\")"
        fi
    fi
fi

# --- Step 6: Compute CRC32 ---
echo ""
echo "[6/8] Generating requiredDataFiles.json..."

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

# Collect mod files (esp, esm, omwaddon, omwscripts, omwgame)
files = []
for pattern in ('*.esp', '*.ESP', '*.esm', '*.ESM',
                '*.omwaddon', '*.OMWADDON',
                '*.omwscripts', '*.OMWSCRIPTS',
                '*.omwgame', '*.OMWGAME'):
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

# --- Step 7: Create mods.zip ---
echo ""
echo "[7/8] Creating mods.zip for distribution to players..."

# Collect mods (all .esp/.esm/.omwaddon/.omwscripts/.omwgame except originals)
mods_to_zip=()
for file in "$DATA_DIR"/*.esp "$DATA_DIR"/*.ESP "$DATA_DIR"/*.esm "$DATA_DIR"/*.ESM \
            "$DATA_DIR"/*.omwaddon "$DATA_DIR"/*.OMWADDON \
            "$DATA_DIR"/*.omwscripts "$DATA_DIR"/*.OMWSCRIPTS \
            "$DATA_DIR"/*.omwgame "$DATA_DIR"/*.OMWGAME; do
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
    echo "  Added mods: ${#mods_to_zip[@]} files"
fi

# Include requiredDataFiles.json for client to know load order
if [ -f "$DATA_DIR/requiredDataFiles.json" ]; then
    cp "$DATA_DIR/requiredDataFiles.json" "$SCRIPT_DIR/tmp_req.json"
    zip -j "$DATA_DIR/mods.zip" "$SCRIPT_DIR/tmp_req.json"
    rm -f "$SCRIPT_DIR/tmp_req.json"
    echo "  Added: requiredDataFiles.json"
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
        echo "  Added scripts: ${#scripts_to_zip[@]} files"
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

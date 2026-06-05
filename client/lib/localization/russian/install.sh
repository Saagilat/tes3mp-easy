#!/bin/bash
# install.sh — Install Morrowind Russian localization for OpenMW/TES3MP (Steam + Proton/Linux)
#
# Usage:
#   ./install.sh [path_to_Morrowind_folder]
#
# If the path is not provided, the script will ask for it interactively.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Determine the Morrowind folder
if [ $# -ge 1 ]; then
    MORROWIND_DIR="$1"
else
    read -r -p "Enter the path to the Morrowind folder (where Morrowind.exe is located): " MORROWIND_DIR
fi

MORROWIND_DIR="$(realpath "$MORROWIND_DIR")"

if [ ! -f "$MORROWIND_DIR/Morrowind.exe" ]; then
    echo "Error: Morrowind.exe not found in '$MORROWIND_DIR'"
    exit 1
fi

echo "Installing Russian localization in: $MORROWIND_DIR"
echo

# ---- Helper: remove case-sensitive duplicates before extraction ----
# Reads a tar archive, finds files that already exist in the target directory
# with the same name (case-insensitive) but different case, and deletes them.
# This prevents "found duplicate file" warnings in OpenMW/TES3MP on Linux.
remove_case_sensitive_duplicates() {
    local archive="$1"
    local target="$2"

    # For each file in the archive, resolve its actual path on disk
    # case-insensitively. If it exists with a different case, remove it.
    while IFS= read -r arc_path; do
        local rel="${arc_path#./}"
        # Skip directories and empty paths
        [[ "$rel" == */ ]] && continue
        [[ -z "$rel" ]] && continue

        # Walk the path components case-insensitively
        local current="$target"
        local found_mismatch=false
        local found_path=""
        local IFS='/'
        read -ra parts <<< "$rel"
        unset IFS

        for ((idx=0; idx<${#parts[@]}; idx++)); do
            local seg="${parts[$idx]}"
            # Check exact match first
            if [[ -e "$current/$seg" ]]; then
                current="$current/$seg"
            else
                # Case-insensitive search
                local found
                found="$(find "$current" -maxdepth 1 -iname "$seg" -print -quit 2>/dev/null)"
                if [[ -n "$found" ]]; then
                    current="$found"
                    found_mismatch=true
                else
                    current=""
                    break
                fi
            fi
        done

        # If we found something with a different case path, remove it
        if [[ -n "$current" && "$found_mismatch" == true ]]; then
            echo "  Removing duplicate: $current"
            rm -rf "$current"
        fi
    done < <(tar -tf "$archive")
}

# 1. Extract localization archive
echo "[1/4] Looking for localization archive..."
RUSSIFIER_TAR="${2:-$SCRIPT_DIR/russifier.tar}"
if [ ! -f "$RUSSIFIER_TAR" ]; then
    echo "Error: file '$RUSSIFIER_TAR' not found."
    echo "Download russifier.tar from GitHub Releases and place it next to the script:"
    echo "  https://github.com/Saagilat/tes3mp-easy/releases"
    exit 1
fi
echo "Removing case-sensitive duplicates from existing files..."
remove_case_sensitive_duplicates "$RUSSIFIER_TAR" "$MORROWIND_DIR"
echo "Extracting localization files (Data Files only)..."
tar -xvf "$RUSSIFIER_TAR" -C "$MORROWIND_DIR" "Data Files/"

# 2. Copy video files into Data Files (if Video folder exists)
if [ -d "$MORROWIND_DIR/Video" ]; then
    echo "[2/4] Copying videos to Data Files/Video..."
    cp -r "$MORROWIND_DIR/Video" "$MORROWIND_DIR/Data Files/"
    rm -rf "$MORROWIND_DIR/Video"
fi

# 3. Create placeholders for missing videos
echo "[3/4] Creating placeholders for missing videos..."
VIDEO_DIR="$MORROWIND_DIR/Data Files/Video"
mkdir -p "$VIDEO_DIR"

for video in \
    "bethesda logo.bik" "bm_bearhunt1.bik" "bm_bearhunt2.bik" \
    "bm_ceremony1.bik" "bm_ceremony2.bik" "bm_endgame.bik" \
    "bm_frostgiant1.bik" "bm_frostgiant2.bik" "bm_wereend.bik" \
    "bm_werewolf1.bik" "bm_werewolf2.bik" "mw_cavern.bik" \
    "mw_credits.bik" "mw_end.bik" "mw_intro.bik" "mw_logo.bik" "mw_menu.bik"; do
    if [ ! -f "$VIDEO_DIR/$video" ]; then
        touch "$VIDEO_DIR/$video"
    fi
done

# 4. Extract Russian voiceover (optional)
echo "[4/4] Looking for Russian voiceover archive..."
VOICES_TAR="${3:-$SCRIPT_DIR/voices_russian.tar}"
if [ -f "$VOICES_TAR" ]; then
    echo "Removing case-sensitive duplicates from existing files..."
    remove_case_sensitive_duplicates "$VOICES_TAR" "$MORROWIND_DIR"
    echo "Extracting Russian voiceover..."
    tar -xvf "$VOICES_TAR" -C "$MORROWIND_DIR"
else
    echo "Archive voices_russian.tar not found — Russian voiceover not installed."
    echo "If you want to install voiceover, download voices_russian.tar from GitHub Releases"
    echo "and place it next to the script, then run the script again."
fi

# 5. Merge case-sensitive directory duplicates (e.g. Sound/ vs SOUND/)
# After extraction, some dirs may exist with different case.
# We merge them into one, preferring the one with more files.
echo "[5/4] Merging case-sensitive directory duplicates..."
merge_case_sensitive_dirs() {
    local base="$1/Data Files"
    [[ ! -d "$base" ]] && return 0

    # Get a unique list of lowercase basenames that appear more than once
    local lower_names
    lower_names="$(find "$base" -maxdepth 1 -printf '%f\n' 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort | uniq -d)"

    while IFS= read -r lower_name; do
        [[ -z "$lower_name" ]] && continue

        # Find all real entries matching this lowercase name
        local matches=()
        while IFS= read -r -d $'\0' match; do
            matches+=("$match")
        done < <(find "$base" -maxdepth 1 -iname "$lower_name" -print0 2>/dev/null)

        if [[ ${#matches[@]} -lt 2 ]]; then
            continue
        fi

        # Pick the target: prefer the one that already has existing content,
        # or the first alphabetically if equal
        local target=""
        local target_count=0
        local src
        for match in "${matches[@]}"; do
            local count
            count="$(find "$match" -type f 2>/dev/null | wc -l)"
            if [[ -z "$target" || "$count" -gt "$target_count" ]]; then
                target="$match"
                target_count="$count"
            fi
        done

        # Merge all others into target
        for match in "${matches[@]}"; do
            if [[ "$match" == "$target" ]]; then
                continue
            fi
            echo "  Merging $match -> $target"
            if [[ -d "$match" ]]; then
                cp -r "$match"/. "$target"/ 2>/dev/null || true
            fi
            rm -rf "$match"
        done
    done <<< "$lower_names"
}
merge_case_sensitive_dirs "$MORROWIND_DIR"

echo
echo "✅ Russian localization installed!"
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

# 1. Extract localization archive
echo "[1/4] Looking for localization archive..."
RUSSIFIER_TAR="$SCRIPT_DIR/russifier.tar"
if [ ! -f "$RUSSIFIER_TAR" ]; then
    echo "Error: file '$RUSSIFIER_TAR' not found."
    echo "Download russifier.tar from GitHub Releases and place it next to the script:"
    echo "  https://github.com/Saagilat/tes3mp-easy-setup/releases"
    exit 1
fi
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
VOICES_TAR="$SCRIPT_DIR/voices_russian.tar"
if [ -f "$VOICES_TAR" ]; then
    echo "Extracting Russian voiceover..."
    tar -xvf "$VOICES_TAR" -C "$MORROWIND_DIR"
else
    echo "Archive voices_russian.tar not found — Russian voiceover not installed."
    echo "If you want to install voiceover, download voices_russian.tar from GitHub Releases"
    echo "and place it next to the script, then run the script again."
fi

echo
echo "✅ Russian localization installed!"
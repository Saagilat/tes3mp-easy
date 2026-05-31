#!/bin/bash
#
# install-player.sh — download and start TES3MP player menu
#
# Usage:  curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/install-player.sh | bash
#
# Downloads all scripts to ~/.local/share/tes3mp-easy/ and opens
# the player menu.

set -euo pipefail

UPDATE_DIR="${HOME}/.local/share/tes3mp-easy"
PLAYER_CONFIG="${HOME}/.tes3mp-easy-player.conf"
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required. Install it and try again." >&2
    exit 1
fi

echo ""
echo "Downloading TES3MP Easy player scripts..."
mkdir -p "$UPDATE_DIR/lib" "$UPDATE_DIR/menu"

total=10
count=0

download() {
    local src="$1"
    local dst="$2"
    count=$((count + 1))
    printf "  [%2d/%d] %s " "$count" "$total" "$(basename "$src")"
    if curl -fsSL "$GITHUB_RAW/$src" -o "$dst" 2>/dev/null; then
        chmod +x "$dst" 2>/dev/null || true
        echo "✓"
    else
        echo "✗"
    fi
}

# Player-related lib files (8)
download "lib/common.sh"          "$UPDATE_DIR/lib/common.sh"
download "lib/config.sh"          "$UPDATE_DIR/lib/config.sh"
download "lib/import-client.sh"   "$UPDATE_DIR/lib/import-client.sh"
download "lib/client-install.sh"  "$UPDATE_DIR/lib/client-install.sh"
download "lib/client-configs.sh"  "$UPDATE_DIR/lib/client-configs.sh"
download "lib/localization.sh"    "$UPDATE_DIR/lib/localization.sh"
download "lib/required-data.sh"   "$UPDATE_DIR/lib/required-data.sh"
download "lib/self-update.sh"     "$UPDATE_DIR/lib/self-update.sh"

# Menu files (2)
download "menu/player.sh"         "$UPDATE_DIR/menu/player.sh"
download "menu/admin.sh"          "$UPDATE_DIR/menu/admin.sh"

echo ""
echo "✓ Scripts downloaded to $UPDATE_DIR"
echo ""

# Preset player config
{
    echo "# TES3MP Easy player configuration"
    echo "ROLE=player"
} > "$PLAYER_CONFIG"

echo "Starting player menu..."
echo ""

exec bash "$UPDATE_DIR/menu/player.sh"
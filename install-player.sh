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
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required. Install it and try again." >&2
    exit 1
fi

echo "Downloading TES3MP Easy player scripts to $UPDATE_DIR..."
mkdir -p "$UPDATE_DIR/lib" "$UPDATE_DIR/menu"

# Download player-related lib files
for f in common.sh config.sh import-client.sh client-install.sh \
         client-configs.sh localization.sh required-data.sh self-update.sh; do
    curl -fsSL "$GITHUB_RAW/lib/$f" -o "$UPDATE_DIR/lib/$f" 2>/dev/null || true
    chmod +x "$UPDATE_DIR/lib/$f" 2>/dev/null || true
done

# Download both menus (player main, admin for switch)
curl -fsSL "$GITHUB_RAW/menu/player.sh" -o "$UPDATE_DIR/menu/player.sh"
chmod +x "$UPDATE_DIR/menu/player.sh"
curl -fsSL "$GITHUB_RAW/menu/admin.sh" -o "$UPDATE_DIR/menu/admin.sh" 2>/dev/null || true
chmod +x "$UPDATE_DIR/menu/admin.sh" 2>/dev/null || true

echo "✓ Scripts downloaded"
echo "Starting player menu..."
echo ""

exec bash "$UPDATE_DIR/menu/player.sh"
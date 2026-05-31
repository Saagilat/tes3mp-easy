#!/bin/bash
#
# install-admin.sh — download and start TES3MP admin menu
#
# Usage:  curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/install-admin.sh | bash
#
# Downloads all scripts to ~/.local/share/tes3mp-easy/ and opens
# the admin menu.

set -euo pipefail

UPDATE_DIR="${HOME}/.local/share/tes3mp-easy"
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"

# Check curl
if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required. Install it and try again." >&2
    exit 1
fi

echo "Downloading TES3MP Easy admin scripts to $UPDATE_DIR..."
mkdir -p "$UPDATE_DIR/lib" "$UPDATE_DIR/menu"

# Download bootstrap lib files
for f in common.sh config.sh server-install.sh server-control.sh \
         server-configs.sh export-mods.sh export-players.sh export-world.sh \
         import-server.sh import-client.sh required-data.sh client-install.sh \
         client-configs.sh localization.sh player-roles.sh self-update.sh; do
    curl -fsSL "$GITHUB_RAW/lib/$f" -o "$UPDATE_DIR/lib/$f" 2>/dev/null || true
    chmod +x "$UPDATE_DIR/lib/$f" 2>/dev/null || true
done

# Download menu
curl -fsSL "$GITHUB_RAW/menu/admin.sh" -o "$UPDATE_DIR/menu/admin.sh"
chmod +x "$UPDATE_DIR/menu/admin.sh"
curl -fsSL "$GITHUB_RAW/menu/player.sh" -o "$UPDATE_DIR/menu/player.sh"
chmod +x "$UPDATE_DIR/menu/player.sh"

echo "✓ Scripts downloaded"
echo "Starting admin menu..."
echo ""

exec bash "$UPDATE_DIR/menu/admin.sh"
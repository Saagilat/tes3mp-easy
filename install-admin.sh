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
ADMIN_CONFIG="${HOME}/.tes3mp-easy-admin.conf"
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required. Install it and try again." >&2
    exit 1
fi

echo ""
echo "Downloading TES3MP Easy admin scripts..."
mkdir -p "$UPDATE_DIR/lib" "$UPDATE_DIR/menu"

total=18
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

# lib files (16)
download "lib/common.sh"          "$UPDATE_DIR/lib/common.sh"
download "lib/config.sh"          "$UPDATE_DIR/lib/config.sh"
download "lib/server-install.sh"  "$UPDATE_DIR/lib/server-install.sh"
download "lib/server-control.sh"  "$UPDATE_DIR/lib/server-control.sh"
download "lib/server-configs.sh"  "$UPDATE_DIR/lib/server-configs.sh"
download "lib/export-mods.sh"     "$UPDATE_DIR/lib/export-mods.sh"
download "lib/export-players.sh"  "$UPDATE_DIR/lib/export-players.sh"
download "lib/export-world.sh"    "$UPDATE_DIR/lib/export-world.sh"
download "lib/import-server.sh"   "$UPDATE_DIR/lib/import-server.sh"
download "lib/import-client.sh"   "$UPDATE_DIR/lib/import-client.sh"
download "lib/required-data.sh"   "$UPDATE_DIR/lib/required-data.sh"
download "lib/client-install.sh"  "$UPDATE_DIR/lib/client-install.sh"
download "lib/client-configs.sh"  "$UPDATE_DIR/lib/client-configs.sh"
download "lib/localization.sh"    "$UPDATE_DIR/lib/localization.sh"
download "lib/player-roles.sh"    "$UPDATE_DIR/lib/player-roles.sh"
download "lib/self-update.sh"     "$UPDATE_DIR/lib/self-update.sh"

# Menu files (2)
download "menu/admin.sh"          "$UPDATE_DIR/menu/admin.sh"
download "menu/player.sh"         "$UPDATE_DIR/menu/player.sh"

echo ""
echo "✓ Scripts downloaded to $UPDATE_DIR"
echo ""

# Preset admin config
{
    echo "# TES3MP Easy admin configuration"
    echo "ROLE=admin"
} > "$ADMIN_CONFIG"

echo "Starting admin menu..."
echo ""

exec bash "$UPDATE_DIR/menu/admin.sh"
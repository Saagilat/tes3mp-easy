#!/bin/bash
#
# install-player.sh — download TES3MP Easy player tools
#
# Usage:  curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/install-player.sh | bash
#
# Downloads all scripts to ~/.local/share/tes3mp-easy/.
# Existing configuration is never overwritten.
# Full uninstall via: tes3mp-easy-player uninstall

set -euo pipefail

UPDATE_DIR="${HOME}/.local/share/tes3mp-easy"
PLAYER_CONFIG="${HOME}/.tes3mp-easy-player.ini"
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required. Install it and try again." >&2
    exit 1
fi

echo ""
echo "Downloading TES3MP Easy player scripts..."
mkdir -p "$UPDATE_DIR/lib" "$UPDATE_DIR/menu" "$UPDATE_DIR/lang"

total=13
count=0

download() {
    local src="$1" dst="$2"
    count=$((count + 1))
    printf "  [%2d/%d] %s " "$count" "$total" "$(basename "$src")"
    if curl -fsSL "$GITHUB_RAW/$src" -o "$dst" 2>/dev/null; then
        chmod +x "$dst" 2>/dev/null || true
        echo "✓"
    else
        echo "✗"
    fi
}

download "lib/common.sh"          "$UPDATE_DIR/lib/common.sh"
download "lib/lang.sh"            "$UPDATE_DIR/lib/lang.sh"
download "lib/config.sh"          "$UPDATE_DIR/lib/config.sh"
download "lib/menu-nav.sh"        "$UPDATE_DIR/lib/menu-nav.sh"
download "lib/import-client.sh"   "$UPDATE_DIR/lib/import-client.sh"
download "lib/client-install.sh"  "$UPDATE_DIR/lib/client-install.sh"
download "lib/client-configs.sh"  "$UPDATE_DIR/lib/client-configs.sh"
download "lib/localization.sh"    "$UPDATE_DIR/lib/localization.sh"
download "lib/required-data.sh"   "$UPDATE_DIR/lib/required-data.sh"
download "lib/self-update.sh"     "$UPDATE_DIR/lib/self-update.sh"
download "menu/player.sh"         "$UPDATE_DIR/menu/player.sh"
download "menu/admin.sh"          "$UPDATE_DIR/menu/admin.sh"

count=$((count + 1))
printf "  [%2d/%d] localization (en, ru) " "$count" "$total"
err=false
curl -fsSL "$GITHUB_RAW/lang/en" -o "$UPDATE_DIR/lang/en" 2>/dev/null || err=true
curl -fsSL "$GITHUB_RAW/lang/ru" -o "$UPDATE_DIR/lang/ru" 2>/dev/null || err=true
$err && echo "✗" || echo "✓"

echo ""
echo "✓ Scripts downloaded to $UPDATE_DIR"

# Create config only if it doesn't exist
if [[ ! -f "$PLAYER_CONFIG" ]]; then
    cat > "$PLAYER_CONFIG" << 'INI'
; TES3MP Easy player configuration

; Language (available: en, ru)
LANG_CODE = en

; Server URL of the TES3MP server (e.g. http://192.168.1.100:8085)
SERVER_URL = 

; Directory containing your Morrowind Data Files
DATA_FILES = 

; Path to your openmw.cfg (in openmw-profile)
OPENMW_CFG = 

; Path to your tes3mp-client-default.cfg (in tes3mp folder)
CLIENT_DEFAULT = 

; Preferred editor (auto-detected)
EDITOR = 
INI
    echo "✓ Player config created: $PLAYER_CONFIG"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  To start the player menu:"
echo "    bash $UPDATE_DIR/menu/player.sh"
echo ""
echo "  Alias (add to ~/.bashrc):"
echo "    alias tes3mp-easy-player='bash $UPDATE_DIR/menu/player.sh'"
echo ""
echo "  All commands:"
echo "    tes3mp-easy-player help"
echo ""
echo "  To remove completely:"
echo "    tes3mp-easy-player uninstall"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
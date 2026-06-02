#!/bin/bash
#
# install-admin.sh — download TES3MP Easy admin tools
#
# Usage:  curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/install-admin.sh | bash
#
# Downloads all scripts to ~/.local/share/tes3mp-easy/.
# Existing configuration is never overwritten.
# Full uninstall via: tes3mp-easy-admin uninstall

set -euo pipefail

UPDATE_DIR="${HOME}/.local/share/tes3mp-easy"
ADMIN_CONFIG="${HOME}/.tes3mp-easy-admin.ini"
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required. Install it and try again." >&2
    exit 1
fi

echo ""
echo "Downloading TES3MP Easy admin scripts..."
mkdir -p "$UPDATE_DIR/lib" "$UPDATE_DIR/menu" "$UPDATE_DIR/lang" "$UPDATE_DIR/server/scripts"

total=22
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

download "client/lib/common"           "$UPDATE_DIR/lib/common"
download "client/lib/lang"             "$UPDATE_DIR/lib/lang"
download "client/lib/config"           "$UPDATE_DIR/lib/config"
download "client/lib/menu-nav"         "$UPDATE_DIR/lib/menu-nav"
download "client/lib/server-install"   "$UPDATE_DIR/lib/server-install"
download "client/lib/server-control"   "$UPDATE_DIR/lib/server-control"
download "client/lib/server-configs"   "$UPDATE_DIR/lib/server-configs"
download "client/lib/export-mods"      "$UPDATE_DIR/lib/export-mods"
download "client/lib/export-players"   "$UPDATE_DIR/lib/export-players"
download "client/lib/export-world"     "$UPDATE_DIR/lib/export-world"
download "client/lib/import-server"    "$UPDATE_DIR/lib/import-server"
download "client/lib/import-client"    "$UPDATE_DIR/lib/import-client"
download "client/lib/required-data"    "$UPDATE_DIR/lib/required-data"
download "client/lib/client-install"   "$UPDATE_DIR/lib/client-install"
download "client/lib/client-configs"   "$UPDATE_DIR/lib/client-configs"
download "client/lib/localization"     "$UPDATE_DIR/lib/localization"
download "client/lib/player-roles"     "$UPDATE_DIR/lib/player-roles"
download "client/lib/theme.ini"        "$UPDATE_DIR/lib/theme.ini"
download "server/scripts/package.sh"   "$UPDATE_DIR/server/scripts/package.sh"
download "client/menu/admin.sh"        "$UPDATE_DIR/menu/admin.sh"
download "client/menu/player.sh"       "$UPDATE_DIR/menu/player.sh"

count=$((count + 1))
printf "  [%2d/%d] localization (en, ru) " "$count" "$total"
err=false
curl -fsSL "$GITHUB_RAW/client/lang/en" -o "$UPDATE_DIR/lang/en" 2>/dev/null || err=true
curl -fsSL "$GITHUB_RAW/client/lang/ru" -o "$UPDATE_DIR/lang/ru" 2>/dev/null || err=true
$err && echo "✗" || echo "✓"

echo ""
echo "✓ Scripts downloaded to $UPDATE_DIR"

# Create config only if it doesn't exist
if [[ ! -f "$ADMIN_CONFIG" ]]; then
    cat > "$ADMIN_CONFIG" << 'INI'
; TES3MP Easy admin configuration

; Language (available: en, ru)
LANG_CODE = en

; SSH host of your VPS (from ~/.ssh/config)
SSH_HOST = 

; --- Server modpack ---
; Root directory of your server modpack.
; Must contain: plugins/ (for .esp/.esm files) and scripts/ (for Lua scripts)
MODPACK_DIR = 

; Preferred editor (auto-detected)
EDITOR = 
INI
    echo "✓ Admin config created: $ADMIN_CONFIG"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  To start the admin menu:"
echo "    bash $UPDATE_DIR/menu/admin.sh"
echo ""
echo "  Alias (add to ~/.bashrc):"
echo "    alias tes3mp-easy-admin='bash $UPDATE_DIR/menu/admin.sh'"
echo ""
echo "  All commands:"
echo "    tes3mp-easy-admin help"
echo ""
echo "  To remove completely:"
echo "    tes3mp-easy-admin uninstall"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
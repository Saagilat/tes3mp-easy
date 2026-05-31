#!/bin/bash
#
# install-admin.sh — download TES3MP Easy admin tools
#
# Usage:  curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/install-admin.sh | bash
#
# Downloads all scripts to ~/.local/share/tes3mp-easy/ and exits.
# Then run:  bash ~/.local/share/tes3mp-easy/menu/admin.sh

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
mkdir -p "$UPDATE_DIR/lib" "$UPDATE_DIR/menu" "$UPDATE_DIR/lang"

total=20
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

# lib files (17)
download "lib/common.sh"          "$UPDATE_DIR/lib/common.sh"
download "lib/lang.sh"            "$UPDATE_DIR/lib/lang.sh"
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

# Language files (en, ru)
count=$((count + 1))
printf "  [%2d/%d] localization (en, ru) " "$count" "$total"
err=false
curl -fsSL "$GITHUB_RAW/lang/en" -o "$UPDATE_DIR/lang/en" 2>/dev/null || err=true
curl -fsSL "$GITHUB_RAW/lang/ru" -o "$UPDATE_DIR/lang/ru" 2>/dev/null || err=true
if $err; then echo "✗"; else echo "✓"; fi

echo ""
echo "✓ Scripts downloaded to $UPDATE_DIR"
echo ""

# ─── Configuration ───
need_config=false
lang_choice="en"

if [[ -f "$ADMIN_CONFIG" ]]; then
    # Existing config — ask to overwrite if TTY available
    if [[ -t 0 ]]; then
        printf "Overwrite configuration? [y/N]: " > /dev/tty
        read -r user_input < /dev/tty || true
        case "${user_input:-}" in
            y|Y|yes|YES) need_config=true ;;
        esac
    fi
else
    need_config=true
fi

if $need_config; then
    # Ask language if TTY available
    if [[ -t 0 ]]; then
        printf "Language (en/ru) [en]: " > /dev/tty
        read -r lang_input < /dev/tty || true
        case "${lang_input:-}" in
            ru|RU|рус|Рус) lang_choice="ru" ;;
        esac
    fi

    {
        echo "# TES3MP Easy admin configuration"
        echo "ROLE = admin"
        echo "LANG_CODE = $lang_choice"
    } > "$ADMIN_CONFIG"
    echo "Configuration created."
else
    echo "Keeping existing configuration."
fi

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
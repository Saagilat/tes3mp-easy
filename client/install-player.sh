#!/bin/bash
#
# install-player.sh — download TES3MP Easy player tools
#
# Usage:  curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/client/install-player.sh | bash
#
# Downloads all scripts to ~/.local/share/tes3mp-easy/.
# Existing configuration is never overwritten.
# Full uninstall via: tes3mp-easy-player uninstall

set -euo pipefail

UPDATE_DIR="${HOME}/.local/share/tes3mp-easy"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
CONFIG="$CONFIG_DIR/tes3mp-easy.ini"
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required. Install it and try again." >&2
    exit 1
fi

echo ""
echo "Downloading TES3MP Easy player scripts..."

mkdir -p "$UPDATE_DIR"/{lib/localization/russian,layer1/player,layer2,layer3,lang} "$CONFIG_DIR"

download() {
    local src="$1" dst="$2"
    if curl -fsSL "$GITHUB_RAW/$src" -o "$dst" 2>/dev/null; then
        chmod +x "$dst" 2>/dev/null || true
        printf "  ✓ %s\n" "$(basename "$src")"
    else
        printf "  ✗ %s\n" "$(basename "$src")" >&2
    fi
}

echo "  ── lib ──"
download "client/lib/common"           "$UPDATE_DIR/lib/common"
download "client/lib/log"              "$UPDATE_DIR/lib/log"
download "client/lib/config"           "$UPDATE_DIR/lib/config"
download "client/lib/menu-nav"         "$UPDATE_DIR/lib/menu-nav"
download "client/lib/lang"             "$UPDATE_DIR/lib/lang"
download "client/lib/theme.ini"            "$UPDATE_DIR/lib/theme.ini"
download "client/lib/settings.cfg.example" "$UPDATE_DIR/lib/settings.cfg.example"

echo "  ── layer1 (non-interactive) ──"
download "client/layer1/player/show-backups-mods"        "$UPDATE_DIR/layer1/player/show-backups-mods"
download "client/layer1/player/show-backups-players"     "$UPDATE_DIR/layer1/player/show-backups-players"
download "client/layer1/player/show-backups-world"       "$UPDATE_DIR/layer1/player/show-backups-world"
download "client/layer1/player/download-backup-mods"     "$UPDATE_DIR/layer1/player/download-backup-mods"
download "client/layer1/player/download-backup-players"  "$UPDATE_DIR/layer1/player/download-backup-players"
download "client/layer1/player/download-backup-world"    "$UPDATE_DIR/layer1/player/download-backup-world"

echo "  ── setup wizard ──"
download "client/layer1/player/set-morrowind-path"  "$UPDATE_DIR/layer1/player/set-morrowind-path"
download "client/layer1/player/set-tes3mp-dir"      "$UPDATE_DIR/layer1/player/set-tes3mp-dir"
download "client/layer1/player/set-proton-path"     "$UPDATE_DIR/layer1/player/set-proton-path"

echo "  ── install ──"
download "client/layer1/player/install-client"  "$UPDATE_DIR/layer1/player/install-client"
download "client/layer1/player/run-client"      "$UPDATE_DIR/layer1/player/run-client"
download "client/layer1/player/run-openmw-cs"   "$UPDATE_DIR/layer1/player/run-openmw-cs"

echo "  ── mods ──"
download "client/layer1/player/install-mods"    "$UPDATE_DIR/layer1/player/install-mods"
download "client/layer1/player/install-localization" "$UPDATE_DIR/layer1/player/install-localization"

echo "  ── fonts & ui ──"
download "client/layer1/player/install-fonts"   "$UPDATE_DIR/layer1/player/install-fonts"
download "client/layer1/player/configure-ui"    "$UPDATE_DIR/layer1/player/configure-ui"

echo "  ── config ──"
download "client/layer1/player/edit-client-cfg"  "$UPDATE_DIR/layer1/player/edit-client-cfg"

echo "  ── settings ──"
download "client/layer1/player/edit-config"      "$UPDATE_DIR/layer1/player/edit-config"

echo "  ── layer2 (interactive wrappers) ──"
download "client/layer2/player/interactive-install-fonts"    "$UPDATE_DIR/layer2/player/interactive-install-fonts"
download "client/layer2/player/interactive-install-localization" "$UPDATE_DIR/layer2/player/interactive-install-localization"
download "client/layer2/player/interactive-configure-ui"     "$UPDATE_DIR/layer2/player/interactive-configure-ui"
download "client/layer2/player/interactive-setup-wizard"     "$UPDATE_DIR/layer2/player/interactive-setup-wizard"
download "client/layer2/player/interactive-download-mods"    "$UPDATE_DIR/layer2/player/interactive-download-mods"
download "client/layer2/player/interactive-download-players" "$UPDATE_DIR/layer2/player/interactive-download-players"
download "client/layer2/player/interactive-download-world"   "$UPDATE_DIR/layer2/player/interactive-download-world"

echo "  ── layer3 (menu) ──"
download "client/layer3/player.sh"        "$UPDATE_DIR/layer3/player.sh"

echo "  ── localization ──"
download "client/lib/localization/russian/install.sh"  "$UPDATE_DIR/lib/localization/russian/install.sh"

printf "  lang/en "
curl -fsSL "$GITHUB_RAW/client/lang/en" -o "$UPDATE_DIR/lang/en" 2>/dev/null \
    && echo "✓" || echo "✗"
printf "  lang/ru "
curl -fsSL "$GITHUB_RAW/client/lang/ru" -o "$UPDATE_DIR/lang/ru" 2>/dev/null \
    && echo "✓" || echo "✗"

echo ""
echo "✓ Scripts downloaded to $UPDATE_DIR"

# Create config if it doesn't exist
if [[ ! -f "$CONFIG" ]]; then
    cat > "$CONFIG" << 'INI'
; TES3MP Easy configuration (all settings)

; Language (available: en, ru)
LANG_CODE = en

; Preferred editor (auto-detected if empty)
EDITOR = 

; Directory for downloaded backup archives
BACKUP_DIR = 

; Path to Morrowind installation directory (where Data Files folder is located)
; Example: /home/user/.steam/steam/steamapps/common/Morrowind
MORROWIND_PATH = 

; Path to TES3MP installation directory (relative to home or absolute)
; Example: games/tes3mp  →  /home/user/games/tes3mp
TES3MP_DIR = 

; Path to Proton installation (auto-detected on first install)
; Example: /home/user/.steam/steam/steamapps/common/Proton 9.0
PROTON_PATH = 
INI
    echo "✓ Config created: $CONFIG"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  To reset configs to defaults, delete and re-run:"
echo "    rm -f $CONFIG"
echo "    curl -fsSL $GITHUB_RAW/client/install-player.sh | bash"
echo ""
echo "  Config file:"
echo "    $CONFIG"
echo ""
echo "  To start the player menu:"
echo "    bash $UPDATE_DIR/layer3/player.sh"
echo ""
echo "  Alias (add to ~/.bashrc):"
echo "    alias tes3mp-easy-player='bash $UPDATE_DIR/layer3/player.sh'"
echo ""
echo "  All commands:"
echo "    tes3mp-easy-player help"
echo ""
echo "  To remove completely:"
echo "    tes3mp-easy-player uninstall"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
SHARED_CONFIG="${HOME}/.tes3mp-easy.ini"
PLAYER_CONFIG="${HOME}/.tes3mp-easy-player.ini"
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required. Install it and try again." >&2
    exit 1
fi

echo ""
echo "Downloading TES3MP Easy player scripts..."

mkdir -p "$UPDATE_DIR"/{lib/localization/russian,bin/player,bin/common,menu,lang}

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
download "client/lib/config"           "$UPDATE_DIR/lib/config"
download "client/lib/menu-nav"         "$UPDATE_DIR/lib/menu-nav"
download "client/lib/lang"             "$UPDATE_DIR/lib/lang"
download "client/lib/theme.ini"        "$UPDATE_DIR/lib/theme.ini"

echo "  ── backup ──"
download "client/bin/player/show-backups-mods"        "$UPDATE_DIR/bin/player/show-backups-mods"
download "client/bin/player/show-backups-players"     "$UPDATE_DIR/bin/player/show-backups-players"
download "client/bin/player/show-backups-world"       "$UPDATE_DIR/bin/player/show-backups-world"
download "client/bin/player/download-backup-mods"     "$UPDATE_DIR/bin/player/download-backup-mods"
download "client/bin/player/download-backup-players"  "$UPDATE_DIR/bin/player/download-backup-players"
download "client/bin/player/download-backup-world"    "$UPDATE_DIR/bin/player/download-backup-world"

echo "  ── setup wizard ──"
download "client/bin/player/setup-wizard"    "$UPDATE_DIR/bin/player/setup-wizard"

echo "  ── install ──"
download "client/bin/player/install-client"  "$UPDATE_DIR/bin/player/install-client"
download "client/bin/player/run-client"      "$UPDATE_DIR/bin/player/run-client"

echo "  ── mods ──"
download "client/bin/player/install-mods"    "$UPDATE_DIR/bin/player/install-mods"
download "client/bin/player/install-localization" "$UPDATE_DIR/bin/player/install-localization"

echo "  ── fonts & ui ──"
download "client/bin/player/install-fonts"   "$UPDATE_DIR/bin/player/install-fonts"
download "client/bin/player/configure-ui"    "$UPDATE_DIR/bin/player/configure-ui"

echo "  ── config ──"
download "client/bin/player/edit-client-cfg"  "$UPDATE_DIR/bin/player/edit-client-cfg"

echo "  ── settings ──"
download "client/bin/player/edit-config"      "$UPDATE_DIR/bin/player/edit-config"
download "client/bin/common/edit-config"      "$UPDATE_DIR/bin/common/edit-config"

echo "  ── localization ──"
download "client/lib/localization/russian/install.sh"  "$UPDATE_DIR/lib/localization/russian/install.sh"

echo "  ── menu ──"
download "client/menu/player.sh"        "$UPDATE_DIR/menu/player.sh"

printf "  lang/en "
curl -fsSL "$GITHUB_RAW/client/lang/en" -o "$UPDATE_DIR/lang/en" 2>/dev/null \
    && echo "✓" || echo "✗"
printf "  lang/ru "
curl -fsSL "$GITHUB_RAW/client/lang/ru" -o "$UPDATE_DIR/lang/ru" 2>/dev/null \
    && echo "✓" || echo "✗"

echo ""
echo "✓ Scripts downloaded to $UPDATE_DIR"

# Create shared config if it doesn't exist
if [[ ! -f "$SHARED_CONFIG" ]]; then
    cat > "$SHARED_CONFIG" << 'INI'
; TES3MP Easy shared configuration (applies to admin and player)

; Language (available: en, ru)
LANG_CODE = en

; Preferred editor (auto-detected if empty)
EDITOR = 

; Directory for downloaded backup archives
BACKUP_DIR = 
INI
    echo "✓ Shared config created: $SHARED_CONFIG"
fi

# Create player config if it doesn't exist
if [[ ! -f "$PLAYER_CONFIG" ]]; then
    cat > "$PLAYER_CONFIG" << 'INI'
; TES3MP Easy player configuration

; Path to Morrowind Data Files (where Morrowind.esm is located)
; Example: /home/user/.steam/steam/steamapps/common/Morrowind/Data Files
DATA_FILES = 

; Path to TES3MP installation directory (relative to home or absolute)
; Example: games/tes3mp  →  /home/user/games/tes3mp
TES3MP_DIR = 

; Path to Proton installation (auto-detected on first install)
; Example: /home/user/.steam/steam/steamapps/common/Proton 9.0
PROTON_PATH = 
INI
    echo "✓ Player config created: $PLAYER_CONFIG"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  To reset configs to defaults, delete and re-run:"
echo "    rm -f ~/.tes3mp-easy.ini ~/.tes3mp-easy-player.ini"
echo "    curl -fsSL $GITHUB_RAW/client/install-player.sh | bash"
echo ""
echo "  Config file:"
echo "    $PLAYER_CONFIG"
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
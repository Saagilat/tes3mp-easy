#!/bin/bash
#
# install-admin.sh — download TES3MP Easy admin tools
#
# Usage:  curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/client/install-admin.sh | bash
#
# Downloads all scripts to ~/.local/share/tes3mp-easy/.
# Existing configuration is never overwritten.
# Full uninstall via: tes3mp-easy-admin uninstall

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
echo "Downloading TES3MP Easy admin scripts..."

mkdir -p "$UPDATE_DIR"/{lib,layer1/admin,layer2,layer3,lang,server/scripts} "$CONFIG_DIR"

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
download "client/lib/theme.ini"        "$UPDATE_DIR/lib/theme.ini"

echo "  ── setup wizard ──"
download "client/layer1/admin/set-ssh-host"    "$UPDATE_DIR/layer1/admin/set-ssh-host"
download "client/layer1/admin/set-export-dir"  "$UPDATE_DIR/layer1/admin/set-export-dir"

echo "  ── server control ──"
download "client/layer1/admin/install-server"    "$UPDATE_DIR/layer1/admin/install-server"
download "client/layer1/admin/start-server"      "$UPDATE_DIR/layer1/admin/start-server"
download "client/layer1/admin/stop-server"       "$UPDATE_DIR/layer1/admin/stop-server"
download "client/layer1/admin/restart-server"    "$UPDATE_DIR/layer1/admin/restart-server"
download "client/layer1/admin/server-status"     "$UPDATE_DIR/layer1/admin/server-status"
download "client/layer1/admin/server-logs"       "$UPDATE_DIR/layer1/admin/server-logs"

echo "  ── export ──"
download "client/layer1/admin/export-mods"       "$UPDATE_DIR/layer1/admin/export-mods"
download "client/layer1/admin/export-players"    "$UPDATE_DIR/layer1/admin/export-players"
download "client/layer1/admin/export-world"      "$UPDATE_DIR/layer1/admin/export-world"
download "client/layer1/admin/generate-data"     "$UPDATE_DIR/layer1/admin/generate-data"

echo "  ── deploy ──"
download "client/layer1/admin/deploy-mods"       "$UPDATE_DIR/layer1/admin/deploy-mods"
download "client/layer1/admin/deploy-players"    "$UPDATE_DIR/layer1/admin/deploy-players"
download "client/layer1/admin/deploy-world"      "$UPDATE_DIR/layer1/admin/deploy-world"

echo "  ── backup ──"
download "client/layer1/admin/download-backup-mods"       "$UPDATE_DIR/layer1/admin/download-backup-mods"
download "client/layer1/admin/download-backup-players"    "$UPDATE_DIR/layer1/admin/download-backup-players"
download "client/layer1/admin/download-backup-world"      "$UPDATE_DIR/layer1/admin/download-backup-world"
download "client/layer1/admin/show-backups-mods" "$UPDATE_DIR/layer1/admin/show-backups-mods"
download "client/layer1/admin/show-backups-players" "$UPDATE_DIR/layer1/admin/show-backups-players"
download "client/layer1/admin/show-backups-world" "$UPDATE_DIR/layer1/admin/show-backups-world"

echo "  ── config edit ──"
download "client/layer1/admin/edit-server-cfg"   "$UPDATE_DIR/layer1/admin/edit-server-cfg"
download "client/layer1/admin/edit-lua"          "$UPDATE_DIR/layer1/admin/edit-lua"
download "client/layer1/admin/edit-banlist"      "$UPDATE_DIR/layer1/admin/edit-banlist"
download "client/layer1/admin/edit-config"       "$UPDATE_DIR/layer1/admin/edit-config"

echo "  ── layer2 (interactive wrappers) ──"
download "client/layer2/admin/interactive-server-start"        "$UPDATE_DIR/layer2/admin/interactive-server-start"
download "client/layer2/admin/interactive-server-stop"         "$UPDATE_DIR/layer2/admin/interactive-server-stop"
download "client/layer2/admin/interactive-server-restart"      "$UPDATE_DIR/layer2/admin/interactive-server-restart"
download "client/layer2/admin/interactive-server-status"       "$UPDATE_DIR/layer2/admin/interactive-server-status"
download "client/layer2/admin/interactive-server-logs"         "$UPDATE_DIR/layer2/admin/interactive-server-logs"
download "client/layer2/admin/interactive-install-server"      "$UPDATE_DIR/layer2/admin/interactive-install-server"
download "client/layer2/admin/interactive-generate-data"       "$UPDATE_DIR/layer2/admin/interactive-generate-data"
download "client/layer2/admin/interactive-export-mods"         "$UPDATE_DIR/layer2/admin/interactive-export-mods"
download "client/layer2/admin/interactive-export-players"      "$UPDATE_DIR/layer2/admin/interactive-export-players"
download "client/layer2/admin/interactive-export-world"        "$UPDATE_DIR/layer2/admin/interactive-export-world"
download "client/layer2/admin/interactive-deploy-mods"         "$UPDATE_DIR/layer2/admin/interactive-deploy-mods"
download "client/layer2/admin/interactive-deploy-players"      "$UPDATE_DIR/layer2/admin/interactive-deploy-players"
download "client/layer2/admin/interactive-deploy-world"        "$UPDATE_DIR/layer2/admin/interactive-deploy-world"
download "client/layer2/admin/interactive-download-mods"       "$UPDATE_DIR/layer2/admin/interactive-download-mods"
download "client/layer2/admin/interactive-download-players"    "$UPDATE_DIR/layer2/admin/interactive-download-players"
download "client/layer2/admin/interactive-download-world"      "$UPDATE_DIR/layer2/admin/interactive-download-world"
download "client/layer2/admin/interactive-show-backups-mods"    "$UPDATE_DIR/layer2/admin/interactive-show-backups-mods"
download "client/layer2/admin/interactive-show-backups-players" "$UPDATE_DIR/layer2/admin/interactive-show-backups-players"
download "client/layer2/admin/interactive-show-backups-world"   "$UPDATE_DIR/layer2/admin/interactive-show-backups-world"
download "client/layer2/admin/interactive-edit-server-cfg"     "$UPDATE_DIR/layer2/admin/interactive-edit-server-cfg"
download "client/layer2/admin/interactive-edit-lua"            "$UPDATE_DIR/layer2/admin/interactive-edit-lua"
download "client/layer2/admin/interactive-edit-banlist"        "$UPDATE_DIR/layer2/admin/interactive-edit-banlist"
download "client/layer2/admin/interactive-edit-config"         "$UPDATE_DIR/layer2/admin/interactive-edit-config"
download "client/layer2/admin/interactive-setup-wizard"        "$UPDATE_DIR/layer2/admin/interactive-setup-wizard"
download "client/layer2/admin/interactive-configure-server"    "$UPDATE_DIR/layer2/admin/interactive-configure-server"
download "client/layer2/admin/interactive-check-restart-flag"  "$UPDATE_DIR/layer2/admin/interactive-check-restart-flag"
download "client/layer2/admin/interactive-check-server-status" "$UPDATE_DIR/layer2/admin/interactive-check-server-status"

echo "  ── layer3 (menu) ──"
download "client/layer3/admin.sh"         "$UPDATE_DIR/layer3/admin.sh"

echo "  ── extras ──"
download "server/scripts/package.sh"    "$UPDATE_DIR/server/scripts/package.sh"

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

; SSH host of your VPS (from ~/.ssh/config)
SSH_HOST = 

; --- Local export directory ---
; Export will upload data from subdirectories:
;   $EXPORT_DIR/mods/plugins/     — .esp/.esm files
;   $EXPORT_DIR/mods/scripts/     — Lua scripts
;   $EXPORT_DIR/players/player/   — player JSON files
;   $EXPORT_DIR/world/cell/       — world data
;   $EXPORT_DIR/world/world/
;   $EXPORT_DIR/world/map/
;   $EXPORT_DIR/world/recordstore/
;   $EXPORT_DIR/world/custom/
EXPORT_DIR = 
INI
    echo "✓ Config created: $CONFIG"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  To reset configs to defaults, delete and re-run:"
echo "    rm -f $CONFIG"
echo "    curl -fsSL $GITHUB_RAW/client/install-admin.sh | bash"
echo ""
echo "  Config file:"
echo "    $CONFIG"
echo ""
echo "  To start the admin menu:"
echo "    bash $UPDATE_DIR/layer3/admin.sh"
echo ""
echo "  Alias (add to ~/.bashrc):"
echo "    alias tes3mp-easy-admin='bash $UPDATE_DIR/layer3/admin.sh'"
echo ""
echo "  All commands:"
echo "    tes3mp-easy-admin help"
echo ""
echo "  To remove completely:"
echo "    tes3mp-easy-admin uninstall"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
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
SHARED_CONFIG="${HOME}/.tes3mp-easy.ini"
ADMIN_CONFIG="${HOME}/.tes3mp-easy-admin.ini"
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required. Install it and try again." >&2
    exit 1
fi

echo ""
echo "Downloading TES3MP Easy admin scripts..."

mkdir -p "$UPDATE_DIR"/{lib,bin/admin,bin/common,menu,lang,server/scripts}

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

echo "  ── setup wizard ──"
download "client/bin/admin/setup-wizard"      "$UPDATE_DIR/bin/admin/setup-wizard"

echo "  ── server control ──"
download "client/bin/admin/install-server"    "$UPDATE_DIR/bin/admin/install-server"
download "client/bin/admin/start-server"      "$UPDATE_DIR/bin/admin/start-server"
download "client/bin/admin/stop-server"       "$UPDATE_DIR/bin/admin/stop-server"
download "client/bin/admin/restart-server"    "$UPDATE_DIR/bin/admin/restart-server"
download "client/bin/admin/server-status"     "$UPDATE_DIR/bin/admin/server-status"
download "client/bin/admin/server-logs"       "$UPDATE_DIR/bin/admin/server-logs"

echo "  ── export ──"
download "client/bin/admin/export-mods"       "$UPDATE_DIR/bin/admin/export-mods"
download "client/bin/admin/export-players"    "$UPDATE_DIR/bin/admin/export-players"
download "client/bin/admin/export-world"      "$UPDATE_DIR/bin/admin/export-world"
download "client/bin/admin/generate-data"     "$UPDATE_DIR/bin/admin/generate-data"

echo "  ── deploy ──"
download "client/bin/admin/deploy-mods"       "$UPDATE_DIR/bin/admin/deploy-mods"
download "client/bin/admin/deploy-players"    "$UPDATE_DIR/bin/admin/deploy-players"
download "client/bin/admin/deploy-world"      "$UPDATE_DIR/bin/admin/deploy-world"

echo "  ── backup ──"
download "client/bin/admin/backup-mods"       "$UPDATE_DIR/bin/admin/backup-mods"
download "client/bin/admin/backup-players"    "$UPDATE_DIR/bin/admin/backup-players"
download "client/bin/admin/backup-world"      "$UPDATE_DIR/bin/admin/backup-world"
download "client/bin/admin/show-backups-mods" "$UPDATE_DIR/bin/admin/show-backups-mods"
download "client/bin/admin/show-backups-players" "$UPDATE_DIR/bin/admin/show-backups-players"
download "client/bin/admin/show-backups-world" "$UPDATE_DIR/bin/admin/show-backups-world"

echo "  ── config edit ──"
download "client/bin/admin/edit-server-cfg"   "$UPDATE_DIR/bin/admin/edit-server-cfg"
download "client/bin/admin/edit-lua"          "$UPDATE_DIR/bin/admin/edit-lua"
download "client/bin/admin/edit-banlist"      "$UPDATE_DIR/bin/admin/edit-banlist"
download "client/bin/admin/edit-config"       "$UPDATE_DIR/bin/admin/edit-config"
download "client/bin/common/edit-config"      "$UPDATE_DIR/bin/common/edit-config"

echo "  ── menu ──"
download "client/menu/admin.sh"         "$UPDATE_DIR/menu/admin.sh"

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

# Create admin config if it doesn't exist
if [[ ! -f "$ADMIN_CONFIG" ]]; then
    cat > "$ADMIN_CONFIG" << 'INI'
; TES3MP Easy admin configuration

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
    echo "✓ Admin config created: $ADMIN_CONFIG"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  To reset configs to defaults, delete and re-run:"
echo "    rm -f ~/.tes3mp-easy.ini ~/.tes3mp-easy-admin.ini"
echo "    curl -fsSL $GITHUB_RAW/client/install-admin.sh | bash"
echo ""
echo "  Config file:"
echo "    $ADMIN_CONFIG"
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
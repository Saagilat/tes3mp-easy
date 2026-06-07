#!/bin/bash
#
# install.sh — download TES3MP Easy scripts (admin + player)
#
# Usage:  curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/client/install.sh | bash
#
# Downloads ALL scripts to ~/.local/share/tes3mp-easy/.
# Always performs a clean install (removes previous scripts).
# Existing configuration is never overwritten.
# Full uninstall via: tes3mp-easy-admin uninstall  or  tes3mp-easy-player uninstall
#

set -euo pipefail

UPDATE_DIR="${HOME}/.local/share/tes3mp-easy"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
CONFIG="$CONFIG_DIR/tes3mp-easy.json"
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"

if ! command -v curl &>/dev/null; then
    echo "ERROR: curl is required. Install it and try again." >&2
    exit 1
fi

echo ""
echo "Downloading TES3MP Easy scripts (admin + player)..."
echo ""

# ── Clean install: remove old scripts, keep config ──
if [[ -d "$UPDATE_DIR" ]]; then
    echo "  Removing previous scripts..."
    rm -rf "$UPDATE_DIR"
fi

mkdir -p "$UPDATE_DIR"/{lib/localization/russian,layer1/shared,layer1/admin,layer1/player,layer2/admin,layer2/player,layer3,server/scripts} "$CONFIG_DIR"

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
download "client/lib/menu-strings"     "$UPDATE_DIR/lib/menu-strings"
download "client/lib/theme.ini"        "$UPDATE_DIR/lib/theme.ini"
download "client/lib/settings.cfg.example" "$UPDATE_DIR/lib/settings.cfg.example"

echo "  ── shared ──"
download "client/layer1/shared/edit-config-record" "$UPDATE_DIR/layer1/shared/edit-config-record"
download "client/layer1/shared/run-openmw-cs"      "$UPDATE_DIR/layer1/shared/run-openmw-cs"

echo "  ── layer1 admin (non-interactive) ──"
echo "  ── setup wizard ──"
download "client/layer1/admin/check-restart-flag"    "$UPDATE_DIR/layer1/admin/check-restart-flag"
download "client/layer1/admin/check-server-status"   "$UPDATE_DIR/layer1/admin/check-server-status"
download "client/layer1/admin/check-server-installed" "$UPDATE_DIR/layer1/admin/check-server-installed"
download "client/layer1/admin/read-config-lua"  "$UPDATE_DIR/layer1/admin/read-config-lua"
download "client/layer1/admin/write-config-lua" "$UPDATE_DIR/layer1/admin/write-config-lua"

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

echo "  ── layer1 player (non-interactive) ──"
echo "  ── backup ──"
download "client/layer1/player/show-backups-mods"        "$UPDATE_DIR/layer1/player/show-backups-mods"
download "client/layer1/player/show-backups-players"     "$UPDATE_DIR/layer1/player/show-backups-players"
download "client/layer1/player/show-backups-world"       "$UPDATE_DIR/layer1/player/show-backups-world"
download "client/layer1/player/download-backup-mods"     "$UPDATE_DIR/layer1/player/download-backup-mods"
download "client/layer1/player/download-backup-players"  "$UPDATE_DIR/layer1/player/download-backup-players"
download "client/layer1/player/download-backup-world"    "$UPDATE_DIR/layer1/player/download-backup-world"

echo "  ── setup wizard ──"
# (paths set via shared/edit-config-record)

echo "  ── install, run, mods ──"
download "client/layer1/player/install-client"  "$UPDATE_DIR/layer1/player/install-client"
download "client/layer1/player/run-client"      "$UPDATE_DIR/layer1/player/run-client"
download "client/layer1/player/install-mods-and-play" "$UPDATE_DIR/layer1/player/install-mods-and-play"
download "client/layer1/player/install-mods"    "$UPDATE_DIR/layer1/player/install-mods"
download "client/layer1/player/install-localization" "$UPDATE_DIR/layer1/player/install-localization"

echo "  ── fonts & ui ──"
download "client/layer1/player/install-fonts"   "$UPDATE_DIR/layer1/player/install-fonts"
download "client/layer1/player/configure-ui"    "$UPDATE_DIR/layer1/player/configure-ui"

echo "  ── config ──"
download "client/layer1/player/edit-client-cfg"  "$UPDATE_DIR/layer1/player/edit-client-cfg"
download "client/layer1/player/edit-client-cfg-record" "$UPDATE_DIR/layer1/player/edit-client-cfg-record"
download "client/layer1/player/edit-config"      "$UPDATE_DIR/layer1/player/edit-config"

echo "  ── layer2 admin (interactive wrappers) ──"
download "client/layer2/admin/interactive-deploy-mods"         "$UPDATE_DIR/layer2/admin/interactive-deploy-mods"
download "client/layer2/admin/interactive-deploy-players"      "$UPDATE_DIR/layer2/admin/interactive-deploy-players"
download "client/layer2/admin/interactive-deploy-world"        "$UPDATE_DIR/layer2/admin/interactive-deploy-world"
download "client/layer2/admin/interactive-download-mods"       "$UPDATE_DIR/layer2/admin/interactive-download-mods"
download "client/layer2/admin/interactive-download-players"    "$UPDATE_DIR/layer2/admin/interactive-download-players"
download "client/layer2/admin/interactive-download-world"      "$UPDATE_DIR/layer2/admin/interactive-download-world"
download "client/layer2/admin/interactive-setup-wizard"        "$UPDATE_DIR/layer2/admin/interactive-setup-wizard"
download "client/layer2/admin/interactive-configure-server"    "$UPDATE_DIR/layer2/admin/interactive-configure-server"

echo "  ── layer2 player (interactive wrappers) ──"
download "client/layer2/player/interactive-install-fonts"    "$UPDATE_DIR/layer2/player/interactive-install-fonts"
download "client/layer2/player/interactive-install-localization" "$UPDATE_DIR/layer2/player/interactive-install-localization"
download "client/layer2/player/interactive-configure-ui"     "$UPDATE_DIR/layer2/player/interactive-configure-ui"
download "client/layer2/player/interactive-setup-wizard"     "$UPDATE_DIR/layer2/player/interactive-setup-wizard"
download "client/layer2/player/interactive-download-mods"    "$UPDATE_DIR/layer2/player/interactive-download-mods"
download "client/layer2/player/interactive-download-players" "$UPDATE_DIR/layer2/player/interactive-download-players"
download "client/layer2/player/interactive-download-world"   "$UPDATE_DIR/layer2/player/interactive-download-world"
download "client/layer2/player/interactive-install-mods-and-play" "$UPDATE_DIR/layer2/player/interactive-install-mods-and-play"

echo "  ── layer3 (menus) ──"
download "client/layer3/admin.sh"         "$UPDATE_DIR/layer3/admin.sh"
download "client/layer3/player.sh"        "$UPDATE_DIR/layer3/player.sh"

echo "  ── extras ──"
download "server/scripts/package.sh"    "$UPDATE_DIR/server/scripts/package.sh"

echo "  ── localization ──"
download "client/lib/localization/russian/install.sh"  "$UPDATE_DIR/lib/localization/russian/install.sh"

echo ""
echo "✓ Scripts downloaded to $UPDATE_DIR"

# Create config if it doesn't exist
if [[ ! -f "$CONFIG" ]]; then
    cat > "$CONFIG" << 'JSON'
{
  "EDITOR": "",
  "BACKUP_DIR": "",
  "SSH_HOST": "",
  "EXPORT_DIR": "",
  "MORROWIND_PATH": "",
  "TES3MP_DIR": "",
  "PROTON_PATH": ""
}
JSON
    echo "✓ Config created: $CONFIG"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  To reset configs to defaults, delete and re-run:"
echo "    rm -f $CONFIG"
echo "    curl -fsSL $GITHUB_RAW/client/install.sh | bash"
echo ""
echo "  Config file:"
echo "    $CONFIG"
echo ""
echo "  To start the admin menu:"
echo "    bash $UPDATE_DIR/layer3/admin.sh"
echo ""
echo "  To start the player menu:"
echo "    bash $UPDATE_DIR/layer3/player.sh"
echo ""
echo "  Aliases (add to ~/.bashrc):"
echo "    alias tes3mp-easy-admin='bash $UPDATE_DIR/layer3/admin.sh'"
echo "    alias tes3mp-easy-player='bash $UPDATE_DIR/layer3/player.sh'"
echo ""
echo "  All commands:"
echo "    tes3mp-easy-admin help"
echo "    tes3mp-easy-player help"
echo ""
echo "  To remove completely:"
echo "    tes3mp-easy-admin uninstall"
echo "    tes3mp-easy-player uninstall"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
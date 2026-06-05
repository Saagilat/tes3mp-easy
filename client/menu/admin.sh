#!/bin/bash
#
# menu-admin.sh — interactive menu for TES3MP server administrators
#
# Layer 2: wraps layer 1 (bin/admin-*) with interactive features
# (archive selection, server status display, etc.)
#

if [[ -z "${LIB_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    BIN_DIR="$SCRIPT_DIR/bin/admin"
    LIB_DIR="$SCRIPT_DIR/lib"
    source "$LIB_DIR/common"
    source "$LIB_DIR/config"
    source "$LIB_DIR/lang"
    source "$LIB_DIR/menu-nav"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
ADMIN_CONFIG="$CONFIG_DIR/tes3mp-easy-admin.ini"
CONFIG_FILE="$ADMIN_CONFIG"

# ────────────────────────────────────────────────────────────
# dispatch — handle direct command line arguments
# ────────────────────────────────────────────────────────────
dispatch_admin() {
    case "${1:-}" in
        install-server) bash "$BIN_DIR/install-server" ;;
        start-server) bash "$BIN_DIR/start-server" ;;
        stop-server) bash "$BIN_DIR/stop-server" ;;
        restart-server) bash "$BIN_DIR/restart-server" ;;
        server-logs) bash "$BIN_DIR/server-logs" ;;
        server-status) bash "$BIN_DIR/server-status" ;;
        export-mods) bash "$BIN_DIR/export-mods" ;;
        export-players) bash "$BIN_DIR/export-players" ;;
        export-world) bash "$BIN_DIR/export-world" ;;
        setup-wizard) bash "$BIN_DIR/setup-wizard" ;;
        generate-required-data) bash "$BIN_DIR/generate-data" ;;
        deploy-mods) bash "$BIN_DIR/deploy-mods" ;;
        deploy-players) bash "$BIN_DIR/deploy-players" ;;
        deploy-world) bash "$BIN_DIR/deploy-world" ;;
        show-backups-mods) bash "$BIN_DIR/show-backups-mods" ;;
        show-backups-players) bash "$BIN_DIR/show-backups-players" ;;
        show-backups-world) bash "$BIN_DIR/show-backups-world" ;;
        edit-config) bash "$BIN_DIR/edit-config" ;;
        edit-server-cfg) bash "$BIN_DIR/edit-server-cfg" ;;
        edit-lua) bash "$BIN_DIR/edit-lua" ;;
        edit-banlist) bash "$BIN_DIR/edit-banlist" ;;
        help|--help|-h)
            echo "Admin subcommands: install-server, start-server, stop-server, restart-server,"
            echo "  server-logs, server-status, export-mods, export-players, export-world,"
            echo "  generate-required-data, deploy-mods, deploy-players, deploy-world,"
            echo "  show-backups-mods, show-backups-players, show-backups-world,"
            echo "  edit-config, edit-server-cfg, edit-lua, edit-banlist, setup-wizard, menu"
            ;;
        menu|"") show_admin_menu ;;
        *) echo "Unknown command: $1"; echo "Run 'menu/admin.sh help' for available commands."; exit 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────
# Simple wrappers — just call bin/
# ────────────────────────────────────────────────────────────
menu_server_start()   { bash "$BIN_DIR/start-server"; }
menu_server_stop()    { bash "$BIN_DIR/stop-server"; }
menu_server_restart() { bash "$BIN_DIR/restart-server"; }
menu_server_status()  { bash "$BIN_DIR/server-status"; }
menu_server_logs()    { bash "$BIN_DIR/server-logs"; }
menu_install_server() { bash "$BIN_DIR/install-server"; }
menu_setup_wizard()   { bash "$BIN_DIR/setup-wizard"; }
menu_generate_data()  { bash "$BIN_DIR/generate-data"; }
menu_export_mods()    { bash "$BIN_DIR/export-mods"; }
menu_export_players() { bash "$BIN_DIR/export-players"; }
menu_export_world()   { bash "$BIN_DIR/export-world"; }
menu_show_backups_mods() { bash "$BIN_DIR/show-backups-mods"; }
menu_show_backups_players() { bash "$BIN_DIR/show-backups-players"; }
menu_show_backups_world() { bash "$BIN_DIR/show-backups-world"; }
menu_edit_server_cfg() { bash "$BIN_DIR/edit-server-cfg"; }
menu_edit_lua()       { bash "$BIN_DIR/edit-lua"; }
menu_edit_banlist()   { bash "$BIN_DIR/edit-banlist"; }
menu_common_settings() {
    bash "$SCRIPT_DIR/bin/common/edit-config"
    exec bash "$0" menu
}
menu_edit_config() {
    bash "$BIN_DIR/edit-config"
    # Restart menu so lang/editor changes take effect on fresh state
    exec bash "$0" menu
}

# ────────────────────────────────────────────────────────────
# Helper: list backups via SSH (returns newline-separated names)
# ────────────────────────────────────────────────────────────
_list_backups() {
    local type="$1"
    require_ssh_host || return 1
    ssh "$SSH_HOST" "ls -t /tes3mp-easy/backups/$type/*.tar.gz 2>/dev/null | xargs -n1 basename" 2>/dev/null
}

# ────────────────────────────────────────────────────────────
# Helper: require SSH_HOST
# ────────────────────────────────────────────────────────────
require_ssh_host() {
    load_config "$ADMIN_CONFIG" 2>/dev/null || true
    if [[ -z "${SSH_HOST:-}" ]]; then
        err "SSH_HOST is not set."
        err "Run 'Admin Menu Settings' first."
        return 1
    fi
}

# ────────────────────────────────────────────────────────────
# Download backup menu — list via HTTP, select, download via curl
# ────────────────────────────────────────────────────────────
_download_backup_menu() {
    local type="$1"
    local label="$2"

    if [[ -z "${SERVER_URL:-}" ]] && [[ -n "${SSH_HOST:-}" ]]; then
        SERVER_URL="http://${SSH_HOST}:8085"
    fi

    if [[ -z "${SERVER_URL:-}" ]]; then
        err "SERVER_URL is not set."
        err "Set it in Admin Menu Settings or ensure SSH_HOST is configured."
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Download $label Backup"
    echo "═══════════════════════════════════════════════"
    echo ""

    # Fetch JSON list from server
    local json
    json=$(curl -sf "$SERVER_URL/list-backups/$type" 2>/dev/null || echo "")
    if [[ -z "$json" || "$json" == "[]" ]]; then
        warn "No $label backups available on server."
        return
    fi

    # Parse names from JSON
    local names=()
    while IFS= read -r line; do
        if [[ "$line" =~ \"name\":[[:space:]]*\"([^\"]+) ]]; then
            names+=("${BASH_REMATCH[1]}")
        fi
    done < <(echo "$json")

    if [[ ${#names[@]} -eq 0 ]]; then
        warn "No $label backups found."
        return
    fi

    # Show numbered list
    local i=1
    for name in "${names[@]}"; do
        echo "  $i) $name"
        ((i++)) || true
    done
    echo ""

    local choice
    read -r -p "  Select number (empty = cancel): " choice
    if [[ -z "$choice" ]]; then
        info "Cancelled."
        return
    fi

    local selected
    selected="${names[$((choice - 1))]}"
    if [[ -z "$selected" ]]; then
        err "Invalid selection."
        return
    fi

    local dest="$PWD/$selected"
    echo ""
    info "Downloading $selected..."
    curl -sfL "$SERVER_URL/download/$type/$selected" -o "$dest" || {
        err "Download failed."
        return
    }
    ok "Saved to: $dest"
}

# ────────────────────────────────────────────────────────────
# Deploy menu — list via SSH, select, call bin/admin-deploy-*
# ────────────────────────────────────────────────────────────
_deploy_menu() {
    local type="$1"
    local label="$2"
    local deploy_bin="$3"  # path to bin/admin-deploy-*

    require_ssh_host || return 1

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Deploy $label"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  Choose archive to deploy (or press Enter for latest):"
    echo ""

    local archives
    archives=$(ssh "$SSH_HOST" "ls -t /tes3mp-easy/backups/$type/*.tar.gz 2>/dev/null | head -10 | xargs -n1 basename" 2>/dev/null)
    if [[ -z "$archives" ]]; then
        warn "No archives found on server."
        return
    fi

    # Show numbered list
    local names=()
    while IFS= read -r name; do
        names+=("$name")
    done <<< "$archives"

    local i=1
    for name in "${names[@]}"; do
        echo "  $i) $name"
        ((i++)) || true
    done
    echo ""

    local choice
    read -r -p "  Select number (empty = latest): " choice

    local archive
    if [[ -z "$choice" ]]; then
        archive="${names[0]}"
    else
        archive="${names[$((choice - 1))]}"
    fi

    if [[ -z "$archive" ]]; then
        err "Invalid selection."
        return
    fi

    info "Deploying: $archive"
    bash "$deploy_bin" "$archive" || {
        err "Deploy failed."
        return
    }
    ok "Deploy queued. Use RESTART to apply."
}

# ────────────────────────────────────────────────────────────
# Deploy wrappers
# ────────────────────────────────────────────────────────────
menu_deploy_mods()    { _deploy_menu "mods" "Mods" "$BIN_DIR/deploy-mods"; }
menu_deploy_players() { _deploy_menu "players" "Players" "$BIN_DIR/deploy-players"; }
menu_deploy_world()   { _deploy_menu "world" "World" "$BIN_DIR/deploy-world"; }

# ────────────────────────────────────────────────────────────
# Download wrappers
# ────────────────────────────────────────────────────────────
menu_download_mods()    { _download_backup_menu "mods" "Mods"; }
menu_download_players() { _download_backup_menu "players" "Players"; }
menu_download_world()   { _download_backup_menu "world" "World"; }

# ────────────────────────────────────────────────────────────
# check_restart_flag — query server via SSH
# ────────────────────────────────────────────────────────────
check_restart_flag() {
    load_config "$ADMIN_CONFIG" 2>/dev/null || true
    if [[ -n "${SSH_HOST:-}" ]]; then
        local running
        running=$(ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose ps --format '{{.State}}' 2>/dev/null | head -1" 2>/dev/null)
        if [[ "$running" == "running" ]]; then
            if ssh "$SSH_HOST" "test -f /tes3mp-easy/needs_restart.flag" 2>/dev/null; then
                echo "1"
            fi
        fi
    fi
    echo ""
}

# ────────────────────────────────────────────────────────────
# check_server_status — check via SSH
# ────────────────────────────────────────────────────────────
check_server_status() {
    load_config "$ADMIN_CONFIG" 2>/dev/null || true
    if [[ -n "${SSH_HOST:-}" ]]; then
        local state
        state=$(ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose ps --format '{{.State}}' 2>/dev/null | head -1" 2>/dev/null || echo "")
        if [[ "$state" == "running" ]]; then
            echo "Running"
        else
            echo "Stopped"
        fi
    else
        echo ""
    fi
}

# ────────────────────────────────────────────────────────────
# show_admin_menu — entry point for interactive menu
# ────────────────────────────────────────────────────────────
show_admin_menu() {
    load_config "$ADMIN_CONFIG" 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"

    # Define menu items after load_lang so localization applies
    local admin_menu=(
        "${MENU_ADMIN_SEP_SERVER_CONTROL}|sep|"
        "${MENU_ADMIN_START_SERVER}|fn|menu_server_start"
        "${MENU_ADMIN_STOP_SERVER}|fn|menu_server_stop"
        "${MENU_ADMIN_RESTART_SERVER}|fn|menu_server_restart"
        "${MENU_ADMIN_SERVER_STATUS}|fn|menu_server_status"
        "${MENU_ADMIN_SERVER_LOGS}|fn|menu_server_logs"
        "${MENU_ADMIN_SETUP_WIZARD}|fn|menu_setup_wizard"

        "${MENU_ADMIN_SEP_MODDING}|sep|"
        "${MENU_ADMIN_GENERATE_DATA}|fn|menu_generate_data"
        "${MENU_ADMIN_EXPORT_MODS}|fn|menu_export_mods"
        "${MENU_ADMIN_DEPLOY_MODS}|fn|menu_deploy_mods"
        "${MENU_ADMIN_SHOW_BACKUPS_MODS}|fn|menu_show_backups_mods"
        "${MENU_ADMIN_DOWNLOAD_BACKUP_MODS}|fn|menu_download_mods"

        "${MENU_ADMIN_SEP_SNAPSHOTS}|sep|"
        "${MENU_ADMIN_EXPORT_PLAYERS}|fn|menu_export_players"
        "${MENU_ADMIN_EXPORT_WORLD}|fn|menu_export_world"
        "${MENU_ADMIN_DEPLOY_PLAYERS}|fn|menu_deploy_players"
        "${MENU_ADMIN_DEPLOY_WORLD}|fn|menu_deploy_world"
        "${MENU_ADMIN_SHOW_BACKUPS_PLAYERS}|fn|menu_show_backups_players"
        "${MENU_ADMIN_SHOW_BACKUPS_WORLD}|fn|menu_show_backups_world"
        "${MENU_ADMIN_DOWNLOAD_BACKUP_PLAYERS}|fn|menu_download_players"
        "${MENU_ADMIN_DOWNLOAD_BACKUP_WORLD}|fn|menu_download_world"

        "${MENU_ADMIN_SEP_CONFIGS}|sep|"
        "${MENU_ADMIN_EDIT_SERVER_CFG}|fn|menu_edit_server_cfg"
        "${MENU_ADMIN_EDIT_LUA}|fn|menu_edit_lua"
        "${MENU_ADMIN_EDIT_BANLIST}|fn|menu_edit_banlist"

        "${MENU_ADMIN_SEP_SYSTEM}|sep|"
        "${MENU_COMMON_EDIT_CONFIG}|fn|menu_common_settings"
        "${MENU_ADMIN_EDIT_CONFIG}|fn|menu_edit_config"
    )

    local restart_flag
    restart_flag=$(check_restart_flag)
    local server_status
    server_status=$(check_server_status)

    run_menu \
        "${MENU_TITLE_ADMIN}" \
        "${SSH_HOST:-}" \
        "${EXPORT_DIR:-}" \
        "$ADMIN_CONFIG" \
        "$restart_flag" \
        "$server_status" \
        "${admin_menu[@]}"
}

# ────────────────────────────────────────────────────────────
# Entry
# ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_config "$ADMIN_CONFIG" 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"
    dispatch_admin "$@"
fi
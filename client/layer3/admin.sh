#!/bin/bash
#
# layer3/admin.sh — Interactive menu for TES3MP server administrators
#
# Layer 3: Pure TUI menu. Each menu item calls layer1 or layer2.
#   - layer1 — for non-interactive operations
#   - layer2 — for interactive operations (deploy picker, backup picker, wizards)
# No business logic here.
#

if [[ -z "${LIB_DIR:-}" ]]; then
    PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    LAYER1_DIR="$PROJECT_DIR/layer1"
    LAYER2_DIR="$PROJECT_DIR/layer2"
    LIB_DIR="$PROJECT_DIR/lib"
    source "$LIB_DIR/common"
    source "$LIB_DIR/config"
    source "$LIB_DIR/lang"
    source "$LIB_DIR/menu-nav"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
CONFIG_FILE="$CONFIG_DIR/tes3mp-easy.ini"

LAYER1_ADMIN="$LAYER1_DIR/admin"
LAYER2_ADMIN="$LAYER2_DIR/admin"

# ────────────────────────────────────────────────────────────
# dispatch — handle direct command line arguments
# ────────────────────────────────────────────────────────────
dispatch_admin() {
    case "${1:-}" in
        # layer1 (non-interactive)
        install-server)         bash "$LAYER1_ADMIN/install-server" ;;
        start-server)           bash "$LAYER1_ADMIN/start-server" ;;
        stop-server)            bash "$LAYER1_ADMIN/stop-server" ;;
        restart-server)         bash "$LAYER1_ADMIN/restart-server" ;;
        server-logs)            bash "$LAYER1_ADMIN/server-logs" ;;
        server-status)          bash "$LAYER1_ADMIN/server-status" ;;
        export-mods)            bash "$LAYER1_ADMIN/export-mods" ;;
        export-players)         bash "$LAYER1_ADMIN/export-players" ;;
        export-world)           bash "$LAYER1_ADMIN/export-world" ;;
        generate-required-data) bash "$LAYER1_ADMIN/generate-data" ;;
        show-backups-mods)      bash "$LAYER1_ADMIN/show-backups-mods" ;;
        show-backups-players)   bash "$LAYER1_ADMIN/show-backups-players" ;;
        show-backups-world)     bash "$LAYER1_ADMIN/show-backups-world" ;;
        edit-config)            bash "$LAYER1_ADMIN/edit-config" ;;
        edit-server-cfg)        bash "$LAYER1_ADMIN/edit-server-cfg" ;;
        edit-lua)               bash "$LAYER1_ADMIN/edit-lua" ;;
        edit-banlist)           bash "$LAYER1_ADMIN/edit-banlist" ;;
        # layer2 (interactive)
        setup-wizard)           bash "$LAYER2_ADMIN/interactive-setup-wizard" ;;
        deploy-mods)            bash "$LAYER2_ADMIN/interactive-deploy-mods" ;;
        deploy-players)         bash "$LAYER2_ADMIN/interactive-deploy-players" ;;
        deploy-world)           bash "$LAYER2_ADMIN/interactive-deploy-world" ;;
        download-backup-mods)   bash "$LAYER2_ADMIN/interactive-download-mods" ;;
        download-backup-players) bash "$LAYER2_ADMIN/interactive-download-players" ;;
        download-backup-world)  bash "$LAYER2_ADMIN/interactive-download-world" ;;
        help|--help|-h)
            echo "Admin subcommands: install-server, start-server, stop-server, restart-server,"
            echo "  server-logs, server-status, export-mods, export-players, export-world,"
            echo "  generate-required-data, deploy-mods, deploy-players, deploy-world,"
            echo "  show-backups-mods, show-backups-players, show-backups-world,"
            echo "  download-backup-mods, download-backup-players, download-backup-world,"
            echo "  edit-config, edit-server-cfg, edit-lua, edit-banlist, setup-wizard, menu"
            ;;
        menu|"") show_admin_menu ;;
        *) echo "Unknown command: $1"; echo "Run 'layer3/admin.sh help' for available commands."; exit 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────
# Status checks (used by run_menu framework for display)
# These must be bash functions, called by run_menu during refresh.
# ────────────────────────────────────────────────────────────
check_restart_flag()  { bash "$LAYER1_ADMIN/check-restart-flag"; }
check_server_status() { bash "$LAYER1_ADMIN/check-server-status"; }

# ────────────────────────────────────────────────────────────
# Function wrappers for run_menu
# ────────────────────────────────────────────────────────────
# layer1 calls
menu_server_start()      { bash "$LAYER1_ADMIN/start-server"; }
menu_server_stop()       { bash "$LAYER1_ADMIN/stop-server"; }
menu_server_restart()    { bash "$LAYER1_ADMIN/restart-server"; }
menu_server_status()     { bash "$LAYER1_ADMIN/server-status"; }
menu_server_logs()       { bash "$LAYER1_ADMIN/server-logs"; }
menu_generate_data()     { bash "$LAYER1_ADMIN/generate-data"; }
menu_export_mods()       { bash "$LAYER1_ADMIN/export-mods"; }
menu_export_players()    { bash "$LAYER1_ADMIN/export-players"; }
menu_export_world()      { bash "$LAYER1_ADMIN/export-world"; }
menu_show_backups_mods()    { bash "$LAYER1_ADMIN/show-backups-mods"; }
menu_show_backups_players() { bash "$LAYER1_ADMIN/show-backups-players"; }
menu_show_backups_world()   { bash "$LAYER1_ADMIN/show-backups-world"; }
menu_edit_server_cfg()   { bash "$LAYER1_ADMIN/edit-server-cfg"; }
menu_edit_lua()          { bash "$LAYER1_ADMIN/edit-lua"; }
menu_edit_banlist()      { bash "$LAYER1_ADMIN/edit-banlist"; }
menu_edit_config() {
    bash "$LAYER1_ADMIN/edit-config"
    exec bash "$0" menu
}

# layer2 calls
menu_setup_wizard()   { bash "$LAYER2_ADMIN/interactive-setup-wizard"; }
menu_deploy_mods()    { bash "$LAYER2_ADMIN/interactive-deploy-mods"; }
menu_deploy_players() { bash "$LAYER2_ADMIN/interactive-deploy-players"; }
menu_deploy_world()   { bash "$LAYER2_ADMIN/interactive-deploy-world"; }
menu_download_mods()  { bash "$LAYER2_ADMIN/interactive-download-mods"; }
menu_download_players() { bash "$LAYER2_ADMIN/interactive-download-players"; }
menu_download_world() { bash "$LAYER2_ADMIN/interactive-download-world"; }

# ────────────────────────────────────────────────────────────
# Menu entry point — only defines structure, no logic.
# ────────────────────────────────────────────────────────────
show_admin_menu() {
    load_config 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"

    local restart_flag
    restart_flag=$(check_restart_flag)
    local server_status
    server_status=$(check_server_status)

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
        "${MENU_ADMIN_EDIT_CONFIG}|fn|menu_edit_config"
    )

    run_menu \
        "${MENU_TITLE_ADMIN}" \
        "${SSH_HOST:-}" \
        "${EXPORT_DIR:-}" \
        "$CONFIG_FILE" \
        "$restart_flag" \
        "$server_status" \
        "${admin_menu[@]}"
}

# ────────────────────────────────────────────────────────────
# Entry
# ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_config 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"
    dispatch_admin "$@"
fi
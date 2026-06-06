#!/bin/bash
#
# layer3/admin.sh — Interactive menu for TES3MP server administrators
#
# Layer 3: Pure TUI menu. Each menu item is just a call to a layer2 file.
# No business logic here.
#

if [[ -z "${LIB_DIR:-}" ]]; then
    PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    LAYER2_DIR="$PROJECT_DIR/layer2"
    LIB_DIR="$PROJECT_DIR/lib"
    source "$LIB_DIR/common"
    source "$LIB_DIR/config"
    source "$LIB_DIR/lang"
    source "$LIB_DIR/menu-nav"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
CONFIG_FILE="$CONFIG_DIR/tes3mp-easy.ini"

LAYER2_ADMIN="$LAYER2_DIR/admin"

# ────────────────────────────────────────────────────────────
# dispatch — handle direct command line arguments
# All dispatch entries just call layer2 files.
# ────────────────────────────────────────────────────────────
dispatch_admin() {
    case "${1:-}" in
        install-server)         bash "$LAYER2_ADMIN/interactive-install-server" ;;
        start-server)           bash "$LAYER2_ADMIN/interactive-server-start" ;;
        stop-server)            bash "$LAYER2_ADMIN/interactive-server-stop" ;;
        restart-server)         bash "$LAYER2_ADMIN/interactive-server-restart" ;;
        server-logs)            bash "$LAYER2_ADMIN/interactive-server-logs" ;;
        server-status)          bash "$LAYER2_ADMIN/interactive-server-status" ;;
        export-mods)            bash "$LAYER2_ADMIN/interactive-export-mods" ;;
        export-players)         bash "$LAYER2_ADMIN/interactive-export-players" ;;
        export-world)           bash "$LAYER2_ADMIN/interactive-export-world" ;;
        setup-wizard)           bash "$LAYER2_ADMIN/interactive-setup-wizard" ;;
        generate-required-data) bash "$LAYER2_ADMIN/interactive-generate-data" ;;
        deploy-mods)            bash "$LAYER2_ADMIN/interactive-deploy-mods" ;;
        deploy-players)         bash "$LAYER2_ADMIN/interactive-deploy-players" ;;
        deploy-world)           bash "$LAYER2_ADMIN/interactive-deploy-world" ;;
        download-backup-mods)   bash "$LAYER2_ADMIN/interactive-download-mods" ;;
        download-backup-players) bash "$LAYER2_ADMIN/interactive-download-players" ;;
        download-backup-world)  bash "$LAYER2_ADMIN/interactive-download-world" ;;
        show-backups-mods)      bash "$LAYER2_ADMIN/interactive-show-backups-mods" ;;
        show-backups-players)   bash "$LAYER2_ADMIN/interactive-show-backups-players" ;;
        show-backups-world)     bash "$LAYER2_ADMIN/interactive-show-backups-world" ;;
        edit-config)            bash "$LAYER2_ADMIN/interactive-edit-config" ;;
        edit-server-cfg)        bash "$LAYER2_ADMIN/interactive-edit-server-cfg" ;;
        edit-lua)               bash "$LAYER2_ADMIN/interactive-edit-lua" ;;
        edit-banlist)           bash "$LAYER2_ADMIN/interactive-edit-banlist" ;;
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
# Function wrappers for run_menu — each just calls a layer2 script
# ────────────────────────────────────────────────────────────
interactive_server_start()      { bash "$LAYER2_ADMIN/interactive-server-start"; }
interactive_server_stop()       { bash "$LAYER2_ADMIN/interactive-server-stop"; }
interactive_server_restart()    { bash "$LAYER2_ADMIN/interactive-server-restart"; }
interactive_server_status()     { bash "$LAYER2_ADMIN/interactive-server-status"; }
interactive_server_logs()       { bash "$LAYER2_ADMIN/interactive-server-logs"; }
interactive_setup_wizard()      { bash "$LAYER2_ADMIN/interactive-setup-wizard"; }
interactive_generate_data()     { bash "$LAYER2_ADMIN/interactive-generate-data"; }
interactive_export_mods()       { bash "$LAYER2_ADMIN/interactive-export-mods"; }
interactive_export_players()    { bash "$LAYER2_ADMIN/interactive-export-players"; }
interactive_export_world()      { bash "$LAYER2_ADMIN/interactive-export-world"; }
interactive_deploy_mods()       { bash "$LAYER2_ADMIN/interactive-deploy-mods"; }
interactive_deploy_players()    { bash "$LAYER2_ADMIN/interactive-deploy-players"; }
interactive_deploy_world()      { bash "$LAYER2_ADMIN/interactive-deploy-world"; }
interactive_show_backups_mods() { bash "$LAYER2_ADMIN/interactive-show-backups-mods"; }
interactive_show_backups_players() { bash "$LAYER2_ADMIN/interactive-show-backups-players"; }
interactive_show_backups_world() { bash "$LAYER2_ADMIN/interactive-show-backups-world"; }
interactive_download_mods()     { bash "$LAYER2_ADMIN/interactive-download-mods"; }
interactive_download_players()  { bash "$LAYER2_ADMIN/interactive-download-players"; }
interactive_download_world()    { bash "$LAYER2_ADMIN/interactive-download-world"; }
interactive_edit_server_cfg()   { bash "$LAYER2_ADMIN/interactive-edit-server-cfg"; }
interactive_edit_lua()          { bash "$LAYER2_ADMIN/interactive-edit-lua"; }
interactive_edit_banlist()      { bash "$LAYER2_ADMIN/interactive-edit-banlist"; }
interactive_edit_config() {
    bash "$LAYER2_ADMIN/interactive-edit-config"
    exec bash "$0" menu
}

# ────────────────────────────────────────────────────────────
# Status checks for menu display
# ────────────────────────────────────────────────────────────
interactive_check_restart_flag() { bash "$LAYER2_ADMIN/interactive-check-restart-flag"; }
interactive_check_server_status() { bash "$LAYER2_ADMIN/interactive-check-server-status"; }

# ────────────────────────────────────────────────────────────
# Menu entry point — only defines structure, no logic.
# ────────────────────────────────────────────────────────────
show_admin_menu() {
    load_config 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"

    local restart_flag
    restart_flag=$(interactive_check_restart_flag)
    local server_status
    server_status=$(interactive_check_server_status)

    local admin_menu=(
        "${MENU_ADMIN_SEP_SERVER_CONTROL}|sep|"
        "${MENU_ADMIN_START_SERVER}|fn|interactive_server_start"
        "${MENU_ADMIN_STOP_SERVER}|fn|interactive_server_stop"
        "${MENU_ADMIN_RESTART_SERVER}|fn|interactive_server_restart"
        "${MENU_ADMIN_SERVER_STATUS}|fn|interactive_server_status"
        "${MENU_ADMIN_SERVER_LOGS}|fn|interactive_server_logs"
        "${MENU_ADMIN_SETUP_WIZARD}|fn|interactive_setup_wizard"

        "${MENU_ADMIN_SEP_MODDING}|sep|"
        "${MENU_ADMIN_GENERATE_DATA}|fn|interactive_generate_data"
        "${MENU_ADMIN_EXPORT_MODS}|fn|interactive_export_mods"
        "${MENU_ADMIN_DEPLOY_MODS}|fn|interactive_deploy_mods"
        "${MENU_ADMIN_SHOW_BACKUPS_MODS}|fn|interactive_show_backups_mods"
        "${MENU_ADMIN_DOWNLOAD_BACKUP_MODS}|fn|interactive_download_mods"

        "${MENU_ADMIN_SEP_SNAPSHOTS}|sep|"
        "${MENU_ADMIN_EXPORT_PLAYERS}|fn|interactive_export_players"
        "${MENU_ADMIN_EXPORT_WORLD}|fn|interactive_export_world"
        "${MENU_ADMIN_DEPLOY_PLAYERS}|fn|interactive_deploy_players"
        "${MENU_ADMIN_DEPLOY_WORLD}|fn|interactive_deploy_world"
        "${MENU_ADMIN_SHOW_BACKUPS_PLAYERS}|fn|interactive_show_backups_players"
        "${MENU_ADMIN_SHOW_BACKUPS_WORLD}|fn|interactive_show_backups_world"
        "${MENU_ADMIN_DOWNLOAD_BACKUP_PLAYERS}|fn|interactive_download_players"
        "${MENU_ADMIN_DOWNLOAD_BACKUP_WORLD}|fn|interactive_download_world"

        "${MENU_ADMIN_SEP_CONFIGS}|sep|"
        "${MENU_ADMIN_EDIT_SERVER_CFG}|fn|interactive_edit_server_cfg"
        "${MENU_ADMIN_EDIT_LUA}|fn|interactive_edit_lua"
        "${MENU_ADMIN_EDIT_BANLIST}|fn|interactive_edit_banlist"

        "${MENU_ADMIN_SEP_SYSTEM}|sep|"
        "${MENU_ADMIN_EDIT_CONFIG}|fn|interactive_edit_config"
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
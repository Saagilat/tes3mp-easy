#!/bin/bash
#
# layer3/admin.sh — Interactive menu for TES3MP server administrators
#
# Layer 3: Pure TUI menu. Each menu item is just a call to a layer2 function.
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
    source "$LAYER2_DIR/admin.sh"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
CONFIG_FILE="$CONFIG_DIR/tes3mp-easy.ini"

# ────────────────────────────────────────────────────────────
# dispatch — handle direct command line arguments
# All dispatch entries just call layer2 functions.
# ────────────────────────────────────────────────────────────
dispatch_admin() {
    case "${1:-}" in
        install-server)         interactive_install_server ;;
        start-server)           interactive_server_start ;;
        stop-server)            interactive_server_stop ;;
        restart-server)         interactive_server_restart ;;
        server-logs)            interactive_server_logs ;;
        server-status)          interactive_server_status ;;
        export-mods)            interactive_export_mods ;;
        export-players)         interactive_export_players ;;
        export-world)           interactive_export_world ;;
        setup-wizard)           interactive_setup_wizard ;;
        generate-required-data) interactive_generate_data ;;
        deploy-mods)            interactive_deploy_mods ;;
        deploy-players)         interactive_deploy_players ;;
        deploy-world)           interactive_deploy_world ;;
        download-backup-mods)   interactive_download_mods ;;
        download-backup-players) interactive_download_players ;;
        download-backup-world)  interactive_download_world ;;
        show-backups-mods)      interactive_show_backups_mods ;;
        show-backups-players)   interactive_show_backups_players ;;
        show-backups-world)     interactive_show_backups_world ;;
        edit-config)            interactive_edit_config ;;
        edit-server-cfg)        interactive_edit_server_cfg ;;
        edit-lua)               interactive_edit_lua ;;
        edit-banlist)           interactive_edit_banlist ;;
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
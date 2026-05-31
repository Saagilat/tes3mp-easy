#!/bin/bash
#
# menu-admin.sh — interactive menu for TES3MP server administrators
#
# Usage: bash menu-admin.sh
# Can be called directly or via tes3mp-easy (bootstrap)
#

# ────────────────────────────────────────────────────────────
# Ensure we're being sourced from tes3mp-easy or have deps
# ────────────────────────────────────────────────────────────
if [[ -z "${LIB_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    LIB_DIR="$SCRIPT_DIR/lib"
    source "$LIB_DIR/common.sh"
    source "$LIB_DIR/i18n.sh"
    source "$LIB_DIR/config.sh"
    source "$LIB_DIR/server-install.sh"
    source "$LIB_DIR/server-control.sh"
    source "$LIB_DIR/server-configs.sh"
    source "$LIB_DIR/export-mods.sh"
    source "$LIB_DIR/export-players.sh"
    source "$LIB_DIR/export-world.sh"
    source "$LIB_DIR/import-server.sh"
    source "$LIB_DIR/player-roles.sh"
    source "$LIB_DIR/required-data.sh"
    source "$LIB_DIR/self-update.sh"
fi

ADMIN_CONFIG="${HOME}/.tes3mp-easy-admin.conf"
CONFIG_FILE="$ADMIN_CONFIG"

# ────────────────────────────────────────────────────────────
# Show Admin Menu
# ────────────────────────────────────────────────────────────
show_admin_menu() {
    local choice

    while true; do
        clear_screen
        print_header "$MENU_TITLE_ADMIN"

        local host_display="${SSH_HOST:-${MSG_HOST_UNSET:-Host: <not set>}}"
        echo "  $host_display"
        echo ""

        echo "  $ADMIN_INSTALL_INTER"
        echo "  $ADMIN_INSTALL_DEFAULT"
        echo "  $ADMIN_CONFIGURE"
        echo ""
        echo "  $ADMIN_START"
        echo "  $ADMIN_STOP"
        echo "  $ADMIN_RESTART"
        echo "  $ADMIN_LOGS"
        echo "  $ADMIN_STATUS"
        echo ""
        echo "  $ADMIN_EDIT_CONFIGS"
        echo ""
        echo "  $ADMIN_EXPORT_MODS"
        echo "  $ADMIN_EXPORT_PLAYERS"
        echo "  $ADMIN_EXPORT_WORLD"
        echo "  $ADMIN_MANAGE_ROLES"
        echo ""
        echo "  $ADMIN_IMPORT_SERVER"
        echo ""
        echo "  $ADMIN_GENERATE_DATA"
        echo ""
        echo "  $MENU_SWITCH_PLAYER"
        echo "  $MENU_UPDATE"
        echo "  $MENU_SETTINGS"
        echo "  $MENU_QUIT"
        echo ""
        read -r -p "  ${MSG_PROMPT:-Select option:} " choice

        case "$choice" in
            1) install_server interactive ;;
            2) install_server --default ;;
            3) configure_server ;;
            4) server_start ;;
            5) server_stop ;;
            6) server_restart ;;
            7) server_logs ;;
            8) server_status ;;
            9) edit_configs_menu ;;
            10) export_mods ;;
            11) export_players ;;
            12) export_world ;;
            13) player_roles_menu ;;
            14) import_server_menu ;;
            15) generate_required_data ;;
            p|P)
                local player_menu="$SCRIPT_DIR/menu/player.sh"
                if [[ -f "$player_menu" ]]; then
                    info "${MSG_SWITCHING_PLAYER:-Switching to player menu...}"
                    sleep 1
                    exec bash "$player_menu"
                else
                    err "menu/player.sh not found at $player_menu"
                fi
                ;;
            u|U) self_update ;;
            s|S) edit_config ; show_config ;;
            q|Q)
                echo ""
                info "${MSG_BYE:-Bye!}"
                exit 0
                ;;
            *) echo "  ${MSG_INVALID:-Invalid option.}" ;;
        esac

        echo ""
        read -r -p "  ${MSG_PRESS_ENTER:-Press Enter to continue...}"
    done
}

# ────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────
clear_screen() {
    printf "\033c" 2>/dev/null || clear 2>/dev/null || true
}

print_header() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))

    echo ""
    printf "╔"
    printf '═%.0s' $(seq 1 $width)
    printf "╗\n"
    printf "║%*s %s %*s║\n" $padding "" "$title" $padding ""
    printf "╚"
    printf '═%.0s' $(seq 1 $width)
    printf "╝\n"
}

# ────────────────────────────────────────────────────────────
# Subcommand dispatcher
# ────────────────────────────────────────────────────────────
dispatch_admin() {
    case "${1:-}" in
        install-server) shift; install_server "${1:-interactive}" ;;
        configure-server) shift; configure_server "${1:-interactive}" ;;
        start) server_start ;;
        stop) server_stop ;;
        restart) server_restart ;;
        logs) server_logs ;;
        export-mods) export_mods ;;
        export-players) export_players ;;
        export-world) export_world ;;
        import-server) import_server_menu ;;
        generate-required-data) generate_required_data ;;
        config) edit_config "$ADMIN_CONFIG" ;;
        player-menu)
            local pm="${SCRIPT_DIR}/menu/player.sh"
            [[ -f "$pm" ]] && exec bash "$pm" || err "menu/player.sh not found"
            ;;
        uninstall)
            echo ""
            echo "This will remove: $ADMIN_CONFIG and $UPDATE_DIR"
            if confirm "${MSG_UNINSTALL_CONFIRM:-Remove tes3mp-easy completely?}"; then
                rm -rf "$UPDATE_DIR" "$ADMIN_CONFIG"
                ok "${MSG_UNINSTALL_DONE:-tes3mp-easy removed.}"
                echo "Also remove the alias from ~/.bashrc if you added it."
            else
                info "${MSG_UNINSTALL_CANCELLED:-Cancelled.}"
            fi
            ;;
        self-update) self_update ;;
        help|--help|-h)
            echo "Admin subcommands: install-server, configure-server, start, stop, restart,"
            echo "  logs, export-mods, export-players, export-world, import-server,"
            echo "  generate-required-data, config, player-menu, self-update, uninstall, menu"
            ;;
        menu|"") show_admin_menu ;;
        *) echo "Unknown command: $1"; echo "Run 'menu/admin.sh help' for available commands."; exit 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────
# Entry point
# ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -gt 0 ]]; then
        load_config 2>/dev/null || true
        load_lang "${LANG_CODE:-en}"
        dispatch_admin "$@"
    else
        load_config "$ADMIN_CONFIG" || {
            load_lang "en"
            wizard_admin true
            load_config "$ADMIN_CONFIG"
        }
        load_lang "${LANG_CODE:-en}"
        dispatch_admin "$@"
    fi
fi
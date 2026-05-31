#!/bin/bash
#
# menu-player.sh — interactive menu for TES3MP players
#
# Usage: bash menu-player.sh
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
    source "$LIB_DIR/import-client.sh"
    source "$LIB_DIR/client-install.sh"
    source "$LIB_DIR/client-configs.sh"
    source "$LIB_DIR/localization.sh"
    source "$LIB_DIR/required-data.sh"
    source "$LIB_DIR/self-update.sh"
fi

PLAYER_CONFIG="${HOME}/.tes3mp-easy-player.conf"
CONFIG_FILE="$PLAYER_CONFIG"

# ────────────────────────────────────────────────────────────
# Show Player Menu
# ────────────────────────────────────────────────────────────
show_player_menu() {
    local choice

    while true; do
        clear_screen
        print_header "$MENU_TITLE_PLAYER"

        echo ""
        echo "  $PLAYER_INSTALL_CLIENT"
        echo "  $PLAYER_SETUP_FONTS"
        echo "  $PLAYER_SET_ADDRESS"
        echo ""
        echo "  $PLAYER_DOWNLOAD_MODS"
        echo "  $PLAYER_UPDATE_MODS"
        echo ""
        echo "  $PLAYER_DOWNLOAD_PLAYERS"
        echo "  $PLAYER_DOWNLOAD_WORLD"
        echo ""
        echo "  $PLAYER_GENERATE_DATA"
        echo "  $PLAYER_INSTALL_LANG"
        echo ""
        echo "  $MENU_SETTINGS"
        echo "  $MENU_UPDATE"
        echo "  $MENU_QUIT"
        echo ""
        read -r -p "  ${MSG_PROMPT:-Select option:} " choice

        case "$choice" in
            1) install_client ;;
            2) setup_fonts ;;
            3) set_server_address ;;
            4|5) download_mods ;;
            6) download_players ;;
            7) download_world ;;
            8) generate_required_data ;;
            9) install_localization ;;
            s|S) edit_config ; show_config ;;
            u|U) self_update ;;
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
dispatch_player() {
    case "${1:-}" in
        download-mods) download_mods ;;
        download-players) download_players ;;
        download-world) download_world ;;
        install-client) install_client ;;
        install-localization) install_localization ;;
        generate-required-data) generate_required_data ;;
        config) edit_config "$PLAYER_CONFIG" ;;
        admin-menu)
            local am="${SCRIPT_DIR}/menu/admin.sh"
            [[ -f "$am" ]] && exec bash "$am" || err "menu/admin.sh not found"
            ;;
        uninstall)
            echo ""
            echo "This will remove: $PLAYER_CONFIG and $UPDATE_DIR"
            if confirm "${MSG_UNINSTALL_CONFIRM:-Remove tes3mp-easy completely?}"; then
                rm -rf "$UPDATE_DIR" "$PLAYER_CONFIG"
                ok "${MSG_UNINSTALL_DONE:-tes3mp-easy removed.}"
                echo "Also remove the alias from ~/.bashrc if you added it."
            else
                info "${MSG_UNINSTALL_CANCELLED:-Cancelled.}"
            fi
            ;;
        self-update) self_update ;;
        help|--help|-h)
            echo "Player subcommands: download-mods, download-players, download-world,"
            echo "  install-client, install-localization, generate-required-data,"
            echo "  config, admin-menu, self-update, uninstall, menu"
            ;;
        menu|"") show_player_menu ;;
        *) echo "Unknown command: $1"; echo "Run 'menu/player.sh help' for available commands."; exit 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────
# Entry point
# ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -gt 0 ]]; then
        load_config 2>/dev/null || true
        load_lang "${LANG_CODE:-en}"
        dispatch_player "$@"
    else
        load_config "$PLAYER_CONFIG" || {
            load_lang "en"
            wizard_player true
            load_config "$PLAYER_CONFIG"
        }
        load_lang "${LANG_CODE:-en}"
        dispatch_player "$@"
    fi
fi
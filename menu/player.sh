#!/bin/bash
#
# menu-player.sh — interactive menu for TES3MP players
#

if [[ -z "${LIB_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    LIB_DIR="$SCRIPT_DIR/lib"
    source "$LIB_DIR/common.sh"
    source "$LIB_DIR/lang.sh"
    source "$LIB_DIR/config.sh"
    source "$LIB_DIR/menu-nav.sh"
    source "$LIB_DIR/import-client.sh"
    source "$LIB_DIR/client-install.sh"
    source "$LIB_DIR/client-configs.sh"
    source "$LIB_DIR/localization.sh"
    source "$LIB_DIR/required-data.sh"
    source "$LIB_DIR/self-update.sh"
fi

PLAYER_CONFIG="${HOME}/.tes3mp-easy-player.ini"
CONFIG_FILE="$PLAYER_CONFIG"

# ────────────────────────────────────────────────────────────
# Submenu definitions
# ────────────────────────────────────────────────────────────

player_client_menu=(
    "INSTALL CLIENT|fn|install_client"
    "CONFIGURE FONTS|fn|setup_fonts"
    "SET SERVER ADDRESS|fn|set_server_address"
    "─|sep|"
    "BACK|back|"
)

player_data_menu=(
    "DOWNLOAD MODS|fn|download_mods"
    "UPDATE MODS|fn|download_mods"
    "─|sep|"
    "DOWNLOAD PLAYERS|fn|download_players"
    "DOWNLOAD WORLD|fn|download_world"
    "─|sep|"
    "GENERATE REQUIRED DATA|fn|generate_required_data"
    "─|sep|"
    "BACK|back|"
)

player_lang_menu=(
    "INSTALL LOCALIZATION|fn|install_localization"
    "─|sep|"
    "BACK|back|"
)

player_system_menu=(
    "SWITCH TO ADMIN MENU|fn|switch_to_admin"
    "─|sep|"
    "UPDATE TES3MP-EASY|fn|self_update"
    "SETTINGS|fn|edit_player_config"
    "─|sep|"
    "EXIT|fn|menu_exit"
    "BACK|back|"
)

player_main_menu=(
    "CLIENT|menu|player_client_menu"
    "DATA|menu|player_data_menu"
    "LOCALIZATION|menu|player_lang_menu"
    "TES3MP-EASY|menu|player_system_menu"
)

# ────────────────────────────────────────────────────────────
# dispatch_player — handle direct command line arguments
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
# Helper functions
# ────────────────────────────────────────────────────────────
switch_to_admin() {
    local am="${SCRIPT_DIR}/menu/admin.sh"
    if [[ -f "$am" ]]; then
        info "${MSG_SWITCHING_ADMIN:-Switching to admin menu...}"
        sleep 1
        exec bash "$am"
    else
        err "menu/admin.sh not found at $am"
    fi
}

edit_player_config() {
    edit_config "$PLAYER_CONFIG" || true
}

menu_exit() {
    echo ""
    info "${MSG_BYE:-Bye!}"
    exit 0
}

# ────────────────────────────────────────────────────────────
# show_player_menu — entry point for interactive menu
# ────────────────────────────────────────────────────────────
show_player_menu() {
    load_config "$PLAYER_CONFIG" 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"

    while true; do
        run_menu "${MENU_TITLE_PLAYER:-TES3MP Easy — Player}" "${player_main_menu[@]}"
    done
}

# ────────────────────────────────────────────────────────────
# Entry
# ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_config "$PLAYER_CONFIG" 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"
    dispatch_player "$@"
fi
#!/bin/bash
#
# layer3/player.sh — Interactive menu for TES3MP player
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
    source "$LAYER2_DIR/player.sh"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
CONFIG_FILE="$CONFIG_DIR/tes3mp-easy.ini"

# ────────────────────────────────────────────────────────────
# dispatch — handle direct command line arguments
# All dispatch entries just call layer2 functions.
# ────────────────────────────────────────────────────────────
dispatch_player() {
    case "${1:-}" in
        install-client)         interactive_install_client ;;
        install-mods)           interactive_install_mods ;;
        install-fonts)          interactive_install_fonts ;;
        configure-ui)           interactive_configure_ui ;;
        install-localization)   interactive_install_localization ;;
        setup-wizard)           interactive_setup_wizard ;;
        download-backup-mods)   interactive_download_mods ;;
        download-backup-players) interactive_download_players ;;
        download-backup-world)  interactive_download_world ;;
        show-backups-mods)      interactive_show_backups_mods ;;
        show-backups-players)   interactive_show_backups_players ;;
        show-backups-world)     interactive_show_backups_world ;;
        run-openmw-cs)          interactive_run_openmw_cs ;;
        run-client)             interactive_run_client ;;
        edit-config)            interactive_edit_config ;;
        edit-client-cfg)        interactive_edit_client_cfg ;;
        uninstall)
            echo ""
            echo "This will remove: $CONFIG_FILE"
            if confirm "Remove tes3mp-easy completely?"; then
                rm -rf "$UPDATE_DIR" "$CONFIG_FILE"
                ok "tes3mp-easy removed."
                echo "Also remove the alias from ~/.bashrc if you added it."
            else
                info "Cancelled."
            fi
            ;;
        help|--help|-h)
            echo "Player subcommands: install-client, run-client, install-mods, install-fonts,"
            echo "  configure-ui, install-localization, download-backup-mods,"
            echo "  download-backup-players, download-backup-world,"
            echo "  show-backups-mods, show-backups-players, show-backups-world,"
            echo "  edit-config, edit-client-cfg, setup-wizard, uninstall, menu"
            ;;
        menu|"") show_player_menu ;;
        *) echo "Unknown command: $1"; echo "Run 'layer3/player.sh help' for available commands."; exit 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────
# Menu entry point — only defines structure, no logic.
# ────────────────────────────────────────────────────────────
show_player_menu() {
    load_config 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"

    local player_menu=(
        "${MENU_PLAYER_SEP_PLAY}|sep|"
        "${MENU_PLAYER_RUN_CLIENT}|fn|interactive_run_client"
        "${MENU_PLAYER_RUN_OPENMW_CS}|fn|interactive_run_openmw_cs"
        "${MENU_PLAYER_SETUP_WIZARD}|fn|interactive_setup_wizard"
        "${MENU_PLAYER_INSTALL_MODS}|fn|interactive_install_mods"
        "${MENU_PLAYER_SEP_LOCALIZATION}|sep|"
        "${MENU_PLAYER_INSTALL_LOCALIZATION}|fn|interactive_install_localization"
        "${MENU_PLAYER_INSTALL_FONTS}|fn|interactive_install_fonts"
        "${MENU_PLAYER_CONFIGURE_UI}|fn|interactive_configure_ui"

        "${MENU_PLAYER_SEP_BACKUPS}|sep|"
        "${MENU_PLAYER_SHOW_BACKUPS_MODS}|fn|interactive_show_backups_mods"
        "${MENU_PLAYER_SHOW_BACKUPS_PLAYERS}|fn|interactive_show_backups_players"
        "${MENU_PLAYER_SHOW_BACKUPS_WORLD}|fn|interactive_show_backups_world"
        "${MENU_PLAYER_DOWNLOAD_BACKUP_MODS}|fn|interactive_download_mods"
        "${MENU_PLAYER_DOWNLOAD_BACKUP_PLAYERS}|fn|interactive_download_players"
        "${MENU_PLAYER_DOWNLOAD_BACKUP_WORLD}|fn|interactive_download_world"

        "${MENU_PLAYER_SEP_CONFIGS}|sep|"
        "${MENU_PLAYER_EDIT_CLIENT_CFG}|fn|interactive_edit_client_cfg"

        "${MENU_PLAYER_SEP_SYSTEM}|sep|"
        "${MENU_PLAYER_EDIT_CONFIG}|fn|interactive_edit_config"
    )

    run_menu \
        "${MENU_TITLE_PLAYER}" \
        "" \
        "" \
        "$CONFIG_FILE" \
        "" \
        "" \
        "${player_menu[@]}"
}

# ────────────────────────────────────────────────────────────
# Entry
# ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_config 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"
    dispatch_player "$@"
fi
#!/bin/bash
#
# layer3/player.sh — Interactive menu for TES3MP player
#
# Layer 3: Pure TUI menu. Each menu item calls layer1 or layer2.
#   - layer1 — for non-interactive operations (just runs, no questions)
#   - layer2 — for interactive operations (font selection, backup picker, wizards)
# No business logic here.
#

if [[ -z "${LIB_DIR:-}" ]]; then
    PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    LAYER1_DIR="$PROJECT_DIR/layer1"
    LAYER2_DIR="$PROJECT_DIR/layer2"
    LIB_DIR="$PROJECT_DIR/lib"
    source "$LIB_DIR/common"
    source "$LIB_DIR/config"
    source "$LIB_DIR/menu-strings"
    source "$LIB_DIR/menu-nav"
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
CONFIG_FILE="$CONFIG_DIR/tes3mp-easy.json"

LAYER1_PLAYER="$LAYER1_DIR/player"
LAYER1_SHARED="$LAYER1_DIR/shared"
LAYER2_PLAYER="$LAYER2_DIR/player"

# ────────────────────────────────────────────────────────────
# dispatch — handle direct command line arguments
# ────────────────────────────────────────────────────────────
dispatch_player() {
    case "${1:-}" in
        install-client)         bash "$LAYER1_PLAYER/install-client" ;;
        install-mods-and-play)  bash "$LAYER2_PLAYER/interactive-install-mods-and-play" ;;
        install-mods)           bash "$LAYER1_PLAYER/install-mods" ;;
        install-fonts)          bash "$LAYER2_PLAYER/interactive-install-fonts" ;;
        configure-ui)           bash "$LAYER2_PLAYER/interactive-configure-ui" ;;
        install-localization)   bash "$LAYER2_PLAYER/interactive-install-localization" ;;
        setup-wizard)           bash "$LAYER2_PLAYER/interactive-setup-wizard" ;;
        download-backup-mods)   bash "$LAYER2_PLAYER/interactive-download-mods" ;;
        download-backup-state)  bash "$LAYER2_PLAYER/interactive-download-state" ;;
        show-backups-mods)      bash "$LAYER1_PLAYER/show-backups-mods" ;;
        show-backups-state)     bash "$LAYER1_PLAYER/show-backups-state" ;;
        run-openmw-cs)          bash "$LAYER1_SHARED/run-openmw-cs" ;;
        run-client)             bash "$LAYER1_PLAYER/run-client" ;;
        edit-config)            bash "$LAYER1_PLAYER/edit-config" ;;
        edit-client-cfg)        bash "$LAYER1_PLAYER/edit-client-cfg" ;;
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
            echo "Player subcommands: install-client, run-client, install-mods-and-play, install-mods,"
            echo "  install-fonts, configure-ui, install-localization,"
            echo "  download-backup-mods, download-backup-state,"
            echo "  show-backups-mods, show-backups-state,"
            echo "  run-openmw-cs, edit-config, edit-client-cfg, setup-wizard, uninstall, menu"
            ;;
        menu|"") show_player_menu ;;
        *) echo "Unknown command: $1"; echo "Run 'layer3/player.sh help' for available commands."; exit 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────
# Function wrappers for run_menu
# ────────────────────────────────────────────────────────────
# layer1 calls (simple — just run)
menu_install_mods_and_play()     { bash "$LAYER2_PLAYER/interactive-install-mods-and-play"; }
menu_run_client()        { bash "$LAYER1_PLAYER/run-client"; }
menu_run_openmw_cs()     { bash "$LAYER1_SHARED/run-openmw-cs"; }
menu_install_mods()      { bash "$LAYER1_PLAYER/install-mods"; }
menu_show_backups_mods()    { bash "$LAYER1_PLAYER/show-backups-mods"; }
menu_show_backups_state()   { bash "$LAYER1_PLAYER/show-backups-state"; }
menu_edit_client_cfg()   { bash "$LAYER1_PLAYER/edit-client-cfg"; }
menu_edit_config() {
    bash "$LAYER1_PLAYER/edit-config"
    exec bash "$0" menu
}

# layer2 calls (interactive — menus, prompts)
menu_install_fonts()          { bash "$LAYER2_PLAYER/interactive-install-fonts"; }
menu_install_localization()   { bash "$LAYER2_PLAYER/interactive-install-localization"; }
menu_configure_ui()           { bash "$LAYER2_PLAYER/interactive-configure-ui"; }
menu_setup_wizard()           { bash "$LAYER2_PLAYER/interactive-setup-wizard"; }
menu_download_mods()          { bash "$LAYER2_PLAYER/interactive-download-mods"; }
menu_download_state()         { bash "$LAYER2_PLAYER/interactive-download-state"; }

# ────────────────────────────────────────────────────────────
# Menu entry point — only defines structure, no logic.
# ────────────────────────────────────────────────────────────
show_player_menu() {
    load_config 2>/dev/null || true

    local player_menu=(
        "${MENU_PLAYER_SEP_PLAY}|sep|"
        "${MENU_PLAYER_INSTALL_MODS_AND_PLAY}|fn|menu_install_mods_and_play"
        "${MENU_PLAYER_RUN_OPENMW_CS}|fn|menu_run_openmw_cs"
        "${MENU_PLAYER_SETUP_WIZARD}|fn|menu_setup_wizard"
        "${MENU_PLAYER_SEP_LOCALIZATION}|sep|"
        "${MENU_PLAYER_INSTALL_LOCALIZATION}|fn|menu_install_localization"
        "${MENU_PLAYER_INSTALL_FONTS}|fn|menu_install_fonts"
        "${MENU_PLAYER_CONFIGURE_UI}|fn|menu_configure_ui"

        "${MENU_PLAYER_SEP_BACKUPS}|sep|"
        "${MENU_PLAYER_SHOW_BACKUPS_MODS}|fn|menu_show_backups_mods"
        "${MENU_PLAYER_SHOW_BACKUPS_STATE}|fn|menu_show_backups_state"
        "${MENU_PLAYER_DOWNLOAD_BACKUP_MODS}|fn|menu_download_mods"
        "${MENU_PLAYER_DOWNLOAD_BACKUP_STATE}|fn|menu_download_state"

        "${MENU_PLAYER_SEP_CONFIGS}|sep|"
        "${MENU_PLAYER_EDIT_CLIENT_CFG}|fn|menu_edit_client_cfg"

        "${MENU_PLAYER_SEP_SYSTEM}|sep|"
        "${MENU_PLAYER_EDIT_CONFIG}|fn|menu_edit_config"
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
    dispatch_player "$@"
fi
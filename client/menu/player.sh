#!/bin/bash
#
# menu-player.sh — interactive menu for TES3MP player
#
# Layer 2: wraps layer 1 (bin/player-*) with interactive features
# (backup browsing, download selection, etc.)
#

if [[ -z "${LIB_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    BIN_DIR="$SCRIPT_DIR/bin/player"
    LIB_DIR="$SCRIPT_DIR/lib"
    source "$LIB_DIR/common"
    source "$LIB_DIR/config"
    source "$LIB_DIR/lang"
    source "$LIB_DIR/menu-nav"
fi

PLAYER_CONFIG="${HOME}/.tes3mp-easy-player.ini"
CONFIG_FILE="$PLAYER_CONFIG"

# ────────────────────────────────────────────────────────────
# dispatch — handle direct command line arguments
# ────────────────────────────────────────────────────────────
dispatch_player() {
    case "${1:-}" in
        install-client) bash "$BIN_DIR/install-client" ;;
        install-mods) bash "$BIN_DIR/install-mods" ;;
        install-fonts) bash "$BIN_DIR/install-fonts" ;;
        configure-ui) bash "$BIN_DIR/configure-ui" ;;
        install-localization) bash "$BIN_DIR/install-localization" ;;
        setup-wizard) bash "$BIN_DIR/setup-wizard" ;;
        download-backup-mods) menu_download_backup "mods" ;;
        download-backup-players) menu_download_backup "players" ;;
        download-backup-world) menu_download_backup "world" ;;
        show-backups-mods) bash "$BIN_DIR/show-backups-mods" ;;
        show-backups-players) bash "$BIN_DIR/show-backups-players" ;;
        show-backups-world) bash "$BIN_DIR/show-backups-world" ;;
        run-openmw-cs) bash "$BIN_DIR/run-openmw-cs" ;;
        run-client) bash "$BIN_DIR/run-client" ;;
        edit-config) bash "$BIN_DIR/edit-config" ;;
        edit-client-cfg) bash "$BIN_DIR/edit-client-cfg" ;;
        uninstall)
            echo ""
            echo "This will remove: $PLAYER_CONFIG and $UPDATE_DIR"
            if confirm "Remove tes3mp-easy completely?"; then
                rm -rf "$UPDATE_DIR" "$PLAYER_CONFIG"
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
        *) echo "Unknown command: $1"; echo "Run 'menu/player.sh help' for available commands."; exit 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────
# Simple wrappers
# ────────────────────────────────────────────────────────────
menu_run_openmw_cs() { bash "$BIN_DIR/run-openmw-cs"; }
menu_run_client() { bash "$BIN_DIR/run-client"; }
menu_install_mods() { bash "$BIN_DIR/install-mods"; }
menu_install_client() { bash "$BIN_DIR/install-client"; }
menu_install_fonts() { bash "$BIN_DIR/install-fonts"; }
menu_configure_ui() { bash "$BIN_DIR/configure-ui"; }
menu_install_localization() { bash "$BIN_DIR/install-localization"; }
menu_setup_wizard()  { bash "$BIN_DIR/setup-wizard"; }
menu_edit_client_cfg() { bash "$BIN_DIR/edit-client-cfg"; }
menu_show_backups_mods() { bash "$BIN_DIR/show-backups-mods"; }
menu_show_backups_players() { bash "$BIN_DIR/show-backups-players"; }
menu_show_backups_world() { bash "$BIN_DIR/show-backups-world"; }
menu_common_settings() {
    bash "$BIN_DIR/../common/edit-config"
    exec bash "$0" menu
}
menu_edit_config() {
    bash "$BIN_DIR/edit-config"
    # Restart menu so lang/editor changes take effect on fresh state
    exec bash "$0" menu
}

# ────────────────────────────────────────────────────────────
# Download backup menu — list via HTTP, select, download via curl
# ────────────────────────────────────────────────────────────
menu_download_backup() {
    local type="$1"
    local SERVER_URL

    SERVER_URL=$(_get_server_url) || {
        err "Could not determine server URL."
        err "Set TES3MP_DIR in config or check tes3mp-client-default.cfg."
        return 1
    }

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Download ${type^} Backup"
    echo "═══════════════════════════════════════════════"
    echo ""

    local json
    json=$(curl -sf "$SERVER_URL/list-backups/$type" 2>/dev/null || echo "")
    if [[ -z "$json" || "$json" == "[]" ]]; then
        warn "No ${type^} backups available on server."
        return
    fi

    local names=()
    while IFS= read -r line; do
        if [[ "$line" =~ \"name\":[[:space:]]*\"([^\"]+) ]]; then
            names+=("${BASH_REMATCH[1]}")
        fi
    done < <(echo "$json")

    if [[ ${#names[@]} -eq 0 ]]; then
        warn "No ${type^} backups found."
        return
    fi

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

    local dest="$HOME/Downloads/$selected"
    mkdir -p "$(dirname "$dest")"
    echo ""
    info "Downloading $selected..."
    curl -sfL "$SERVER_URL/download/$type/$selected" -o "$dest" || {
        err "Download failed."
        return
    }
    ok "Saved to: $dest"
}

menu_download_mods()    { menu_download_backup "mods"; }
menu_download_players() { menu_download_backup "players"; }
menu_download_world()   { menu_download_backup "world"; }

# ────────────────────────────────────────────────────────────
# show_player_menu — entry point for interactive menu
# ────────────────────────────────────────────────────────────
show_player_menu() {
    load_config "$PLAYER_CONFIG" 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"

    # Define menu items after load_lang so localization applies
    local player_menu=(
        "${MENU_PLAYER_SEP_PLAY}|sep|"
        "${MENU_PLAYER_RUN_CLIENT}|fn|menu_run_client"
        "${MENU_PLAYER_RUN_OPENMW_CS}|fn|menu_run_openmw_cs"
        "${MENU_PLAYER_SETUP_WIZARD}|fn|menu_setup_wizard"
        "${MENU_PLAYER_INSTALL_MODS}|fn|menu_install_mods"
        "${MENU_PLAYER_SEP_LOCALIZATION}|sep|"
        "${MENU_PLAYER_INSTALL_LOCALIZATION}|fn|menu_install_localization"
        "${MENU_PLAYER_INSTALL_FONTS}|fn|menu_install_fonts"
        "${MENU_PLAYER_CONFIGURE_UI}|fn|menu_configure_ui"

        "${MENU_PLAYER_SEP_BACKUPS}|sep|"
        "${MENU_PLAYER_SHOW_BACKUPS_MODS}|fn|menu_show_backups_mods"
        "${MENU_PLAYER_SHOW_BACKUPS_PLAYERS}|fn|menu_show_backups_players"
        "${MENU_PLAYER_SHOW_BACKUPS_WORLD}|fn|menu_show_backups_world"
        "${MENU_PLAYER_DOWNLOAD_BACKUP_MODS}|fn|menu_download_mods"
        "${MENU_PLAYER_DOWNLOAD_BACKUP_PLAYERS}|fn|menu_download_players"
        "${MENU_PLAYER_DOWNLOAD_BACKUP_WORLD}|fn|menu_download_world"

        "${MENU_PLAYER_SEP_CONFIGS}|sep|"
        "${MENU_PLAYER_EDIT_CLIENT_CFG}|fn|menu_edit_client_cfg"

        "${MENU_PLAYER_SEP_SYSTEM}|sep|"
        "${MENU_COMMON_EDIT_CONFIG}|fn|menu_common_settings"
        "${MENU_PLAYER_EDIT_CONFIG}|fn|menu_edit_config"
    )

    run_menu \
        "${MENU_TITLE_PLAYER}" \
        "" \
        "" \
        "$PLAYER_CONFIG" \
        "" \
        "" \
        "${player_menu[@]}"
}

# ────────────────────────────────────────────────────────────
# Entry
# ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_config "$PLAYER_CONFIG" 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"
    dispatch_player "$@"
fi
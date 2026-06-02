#!/bin/bash
#
# menu-admin.sh — interactive menu for TES3MP server administrators
#

if [[ -z "${LIB_DIR:-}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    LIB_DIR="$SCRIPT_DIR/lib"
    source "$LIB_DIR/common.sh"
    source "$LIB_DIR/lang.sh"
    source "$LIB_DIR/config.sh"
    source "$LIB_DIR/menu-nav.sh"
    source "$LIB_DIR/server-install.sh"
    source "$LIB_DIR/server-control.sh"
    source "$LIB_DIR/server-configs.sh"
    source "$LIB_DIR/export-mods.sh"
    source "$LIB_DIR/export-players.sh"
    source "$LIB_DIR/export-world.sh"
    source "$LIB_DIR/import-server.sh"
    source "$LIB_DIR/player-roles.sh"
    source "$LIB_DIR/required-data.sh"
fi

ADMIN_CONFIG="${HOME}/.tes3mp-easy-admin.ini"
CONFIG_FILE="$ADMIN_CONFIG"

# ────────────────────────────────────────────────────────────
# Submenu definitions
# ────────────────────────────────────────────────────────────

control_menu=(
    "START|fn|server_start"
    "STOP|fn|server_stop"
    "RESTART|fn|server_restart"
    "STATUS|fn|server_status"
    "LOGS|fn|server_logs"
    "─|sep|"
    "BACK|back|"
)

modding_menu=(
    "GENERATE REQUIRED DATA|fn|generate_required_data"
    "─|sep|"
    "EXPORT MODS|fn|export_mods"
    "DEPLOY MODS|fn|deploy_mods_menu"
    "DOWNLOAD MOD BACKUP|fn|download_mod_backup"
    "─|sep|"
    "BACK|back|"
)

snapshots_menu=(
    "EXPORT PLAYERS|fn|export_players"
    "EXPORT WORLD|fn|export_world"
    "─|sep|"
    "DEPLOY PLAYERS|fn|deploy_players_menu"
    "DEPLOY WORLD|fn|deploy_world_menu"
    "─|sep|"
    "DOWNLOAD PLAYERS BACKUP|fn|download_players_backup"
    "DOWNLOAD WORLD BACKUP|fn|download_world_backup"
    "─|sep|"
    "BACK|back|"
)

settings_menu=(
    "EDIT CONFIGS|fn|edit_configs_menu"
    "─|sep|"
    "MANAGE ROLES|fn|player_roles_menu"
    "─|sep|"
    "BACK|back|"
)

install_menu=(
    "INSTALL SERVER|fn|install_server"
    "─|sep|"
    "UNINSTALL SERVER|fn|uninstall_server"
    "─|sep|"
    "BACK|back|"
)

system_menu=(
    "SWITCH TO PLAYER MENU|fn|switch_to_player"
    "─|sep|"
    "SETTINGS|fn|edit_admin_config"
    "─|sep|"
    "EXIT|fn|menu_exit"
    "BACK|back|"
)

# ────────────────────────────────────────────────────────────
# Admin main menu
# ────────────────────────────────────────────────────────────
admin_menu=(
    "CONTROL|menu|control_menu"
    "MODDING|menu|modding_menu"
    "SNAPSHOTS|menu|snapshots_menu"
    "SETTINGS|menu|settings_menu"
    "INSTALL|menu|install_menu"
    "TES3MP-EASY|menu|system_menu"
)

# ────────────────────────────────────────────────────────────
# dispatch — handle direct command line arguments
# ────────────────────────────────────────────────────────────
dispatch_admin() {
    case "${1:-}" in
        install-server) install_server ;;
        configure-server) configure_server "${2:-interactive}" ;;
        start) server_start ;;
        stop) server_stop ;;
        restart) server_restart ;;
        logs) server_logs ;;
        status) server_status ;;
        export-mods) export_mods ;;
        export-players) export_players ;;
        export-world) export_world ;;
        generate-required-data) generate_required_data ;;
        config) edit_config "$ADMIN_CONFIG" ;;
        player-menu)
            local pm="${SCRIPT_DIR}/menu/player.sh"
            [[ -f "$pm" ]] && exec bash "$pm" || err "menu/player.sh not found"
            ;;
        uninstall-server) uninstall_server ;;
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
        help|--help|-h)
            echo "Admin subcommands: install-server, configure-server, start, stop, restart,"
            echo "  logs, status, export-mods, export-players, export-world,"
            echo "  generate-required-data, uninstall-server, config, player-menu,"
            echo "  uninstall, menu"
            ;;
        menu|"") show_admin_menu ;;
        *) echo "Unknown command: $1"; echo "Run 'menu/admin.sh help' for available commands."; exit 1 ;;
    esac
}

# ────────────────────────────────────────────────────────────
# Deploy menu wrappers
# ────────────────────────────────────────────────────────────
deploy_mods_menu() {
    require_ssh_host || return 1
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Deploy Mods"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  Choose archive to deploy (or press Enter for latest):"
    echo ""
    local archives
    archives=$(ssh "$SSH_HOST" "ls -t /tes3mp-easy/backups/mods/import-*.tar.gz /tes3mp-easy/backups/mods/init-*.tar.gz 2>/dev/null | head -10" 2>/dev/null)
    if [[ -z "$archives" ]]; then
        warn "No archives found on server."
        press_enter
        return
    fi
    echo "$archives" | nl -w2 -s') '
    echo ""
    read -r -p "  Select number (empty = latest): " choice
    local archive
    if [[ -z "$choice" ]]; then
        archive=$(echo "$archives" | head -1)
        archive=$(basename "$archive")
    else
        archive=$(echo "$archives" | sed -n "${choice}p")
        archive=$(basename "$archive")
    fi
    if [[ -z "$archive" ]]; then
        err "Invalid selection."
        press_enter
        return
    fi
    info "Deploying: $archive"
    ssh "$SSH_HOST" "cd /tes3mp-easy && bash scripts/deploy_mods.sh '$archive'" || {
        err "Deploy failed."
        press_enter
        return
    }
    needs_restart_set
    ok "Deploy queued. Use RESTART to apply."
    press_enter
}

deploy_players_menu() {
    require_ssh_host || return 1
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Deploy Players"
    echo "═══════════════════════════════════════════════"
    echo ""
    local archives
    archives=$(ssh "$SSH_HOST" "ls -t /tes3mp-easy/backups/players/import-*.tar.gz /tes3mp-easy/backups/players/init-*.tar.gz 2>/dev/null | head -10" 2>/dev/null)
    if [[ -z "$archives" ]]; then
        warn "No archives found on server."
        press_enter
        return
    fi
    echo "$archives" | nl -w2 -s') '
    echo ""
    read -r -p "  Select number (empty = latest): " choice
    local archive
    if [[ -z "$choice" ]]; then
        archive=$(echo "$archives" | head -1)
        archive=$(basename "$archive")
    else
        archive=$(echo "$archives" | sed -n "${choice}p")
        archive=$(basename "$archive")
    fi
    if [[ -z "$archive" ]]; then
        err "Invalid selection."
        press_enter
        return
    fi
    info "Deploying: $archive"
    ssh "$SSH_HOST" "cd /tes3mp-easy && bash scripts/deploy_players.sh '$archive'" || {
        err "Deploy failed."
        press_enter
        return
    }
    needs_restart_set
    ok "Deploy queued. Use RESTART to apply."
    press_enter
}

deploy_world_menu() {
    require_ssh_host || return 1
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Deploy World"
    echo "═══════════════════════════════════════════════"
    echo ""
    local archives
    archives=$(ssh "$SSH_HOST" "ls -t /tes3mp-easy/backups/world/import-*.tar.gz /tes3mp-easy/backups/world/init-*.tar.gz 2>/dev/null | head -10" 2>/dev/null)
    if [[ -z "$archives" ]]; then
        warn "No archives found on server."
        press_enter
        return
    fi
    echo "$archives" | nl -w2 -s') '
    echo ""
    read -r -p "  Select number (empty = latest): " choice
    local archive
    if [[ -z "$choice" ]]; then
        archive=$(echo "$archives" | head -1)
        archive=$(basename "$archive")
    else
        archive=$(echo "$archives" | sed -n "${choice}p")
        archive=$(basename "$archive")
    fi
    if [[ -z "$archive" ]]; then
        err "Invalid selection."
        press_enter
        return
    fi
    info "Deploying: $archive"
    ssh "$SSH_HOST" "cd /tes3mp-easy && bash scripts/deploy_world.sh '$archive'" || {
        err "Deploy failed."
        press_enter
        return
    }
    needs_restart_set
    ok "Deploy queued. Use RESTART to apply."
    press_enter
}

# ────────────────────────────────────────────────────────────
# Download backup functions
# ────────────────────────────────────────────────────────────
download_backup() {
    local remote_dir="$1"
    local local_dir="$2"
    local label="$3"

    require_ssh_host || return 1

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Download $label Backup"
    echo "═══════════════════════════════════════════════"
    echo ""

    local archives
    archives=$(ssh "$SSH_HOST" "ls -t $remote_dir/*.tar.gz 2>/dev/null | head -10" 2>/dev/null)
    if [[ -z "$archives" ]]; then
        warn "No archives found on server."
        press_enter
        return
    fi

    echo "$archives" | nl -w2 -s') '
    echo ""
    read -r -p "  Select number (empty = latest): " choice

    local archive
    if [[ -z "$choice" ]]; then
        archive=$(echo "$archives" | head -1)
    else
        archive=$(echo "$archives" | sed -n "${choice}p")
    fi

    if [[ -z "$archive" ]]; then
        err "Invalid selection."
        press_enter
        return
    fi

    local basename
    basename=$(basename "$archive")
    local dest="$local_dir/$basename"
    mkdir -p "$local_dir"

    info "Downloading: $archive"
    scp "$SSH_HOST:$archive" "$dest" || {
        err "Download failed."
        press_enter
        return
    }
    ok "Downloaded to: $dest"
    press_enter
}

download_mod_backup() {
    local local_dir="${MODPACK_DIR:-$HOME/Downloads}"
    download_backup "/tes3mp-easy/backups/mods" "$local_dir" "Mods"
}

download_players_backup() {
    local local_dir="${MODPACK_DIR:-$HOME/Downloads}"
    download_backup "/tes3mp-easy/backups/players" "$local_dir" "Players"
}

download_world_backup() {
    local local_dir="${MODPACK_DIR:-$HOME/Downloads}"
    download_backup "/tes3mp-easy/backups/world" "$local_dir" "World"
}

# ────────────────────────────────────────────────────────────
# Menu transitions
# ────────────────────────────────────────────────────────────
switch_to_player() {
    local player_menu="$SCRIPT_DIR/menu/player.sh"
    if [[ -f "$player_menu" ]]; then
        info "${MSG_SWITCHING_PLAYER:-Switching to player menu...}"
        sleep 1
        exec bash "$player_menu"
    else
        err "menu/player.sh not found at $player_menu"
    fi
}

edit_admin_config() {
    edit_config "$ADMIN_CONFIG" || true
    # Reload config after editing so new values take effect immediately
    load_config "$ADMIN_CONFIG" 2>/dev/null || true
}

menu_exit() {
    echo ""
    info "${MSG_BYE:-Bye!}"
    exit 0
}

# ────────────────────────────────────────────────────────────
# show_admin_menu — entry point for interactive menu
# ────────────────────────────────────────────────────────────
show_admin_menu() {
    load_lang "${LANG_CODE:-en}"

    # Loop forever so menu reopens after each action
    while true; do
        load_config "$ADMIN_CONFIG" 2>/dev/null || true
        run_menu "${MENU_TITLE_ADMIN:-TES3MP Easy — Admin}" "${admin_menu[@]}"
    done
}

# ────────────────────────────────────────────────────────────
# Entry
# ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_config "$ADMIN_CONFIG" 2>/dev/null || true
    load_lang "${LANG_CODE:-en}"
    dispatch_admin "$@"
fi
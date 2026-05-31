#!/bin/bash
#
# import-server.sh — server-side import of mods/players/world backups
#
# Provides:
#   - import_mods_server()    — import mods archive on server
#   - import_players_server() — import players archive on server
#   - import_world_server()   — import world archive on server
#   - import_server_menu()    — interactive submenu
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before import-server.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# Helper
# ────────────────────────────────────────────────────────────
require_ssh_host() {
    if [[ -z "${SSH_HOST:-}" ]]; then
        err "SSH_HOST is not set."
        err "Run './tes3mp-easy config' to set it."
        return 1
    fi
}

ssh_script() {
    local script="$1"
    local desc="$2"
    require_ssh_host || return 1
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  $desc"
    echo "═══════════════════════════════════════════════"
    echo ""
    info "Running on $SSH_HOST: bash scripts/$script"
    echo ""
    ssh "$SSH_HOST" "cd /tes3mp-easy && bash scripts/$script" || {
        err "$script failed on server — check server logs"
        return 1
    }
    ok "$desc completed"
}

# ────────────────────────────────────────────────────────────
# import_mods_server
# ────────────────────────────────────────────────────────────
import_mods_server() {
    ssh_script "import_mods.sh" "Import Mods (server-side)"
}

# ────────────────────────────────────────────────────────────
# import_players_server
# ────────────────────────────────────────────────────────────
import_players_server() {
    ssh_script "import_players.sh" "Import Players (server-side)"
}

# ────────────────────────────────────────────────────────────
# import_world_server
# ────────────────────────────────────────────────────────────
import_world_server() {
    ssh_script "import_world.sh" "Import World (server-side)"
}

# ────────────────────────────────────────────────────────────
# import_server_menu — interactive submenu
# ────────────────────────────────────────────────────────────
import_server_menu() {
    local choice

    while true; do
        echo ""
        echo "───────────────────────────────────────────"
        echo "  Import backup to server"
        echo "───────────────────────────────────────────"
        echo ""
        echo "  1) Import mods (validate + save archive)"
        echo "  2) Import players (hot-add, no restart)"
        echo "  3) Import world (saves archive, restarts TES3MP)"
        echo ""
        echo "  b) Back to main menu"
        echo ""
        read -r -p "Select [1-3, b]: " choice

        case "$choice" in
            1) import_mods_server ;;
            2) import_players_server ;;
            3) import_world_server ;;
            b|B) break ;;
            *) echo "Invalid choice." ;;
        esac

        echo ""
        read -r -p "Press Enter to continue..."
    done
}
#!/bin/bash
#
# import-server.sh — server-side import of mods/players/world backups
#
# Provides:
#   - import_mods_server()    — import mods archive on server
#   - import_players_server() — import players archive on server
#   - import_world_server()   — import world archive on server
#   - import_server_menu()    — interactive submenu via run_menu()
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
        return 1
    fi
}

ssh_script() {
    local script="$1"
    local desc="$2"
    require_ssh_host || return 1
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
# import_server_menu — whiptail submenu
# ────────────────────────────────────────────────────────────
import_items=(
    "IMPORT MODS|fn|import_mods_server"
    "IMPORT PLAYERS|fn|import_players_server"
    "IMPORT WORLD|fn|import_world_server"
    "─|sep|"
    "BACK|back|"
)

import_server_menu() {
    run_menu "IMPORT BACKUPS" "${import_items[@]}"
}
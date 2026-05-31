#!/bin/bash
#
# server-configs.sh — edit TES3MP server configuration files
#
# Provides:
#   - edit_server_cfg()
#   - edit_lua_config()
#   - edit_banlist()
#   - edit_configs_menu() — submenu for choosing which config
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before server-configs.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# Helper: check SSH_HOST
# ────────────────────────────────────────────────────────────
require_ssh_host() {
    if [[ -z "${SSH_HOST:-}" ]]; then
        err "SSH_HOST is not set."
        err "Run './tes3mp-easy config' to set it."
        return 1
    fi
}

# ────────────────────────────────────────────────────────────
# ssh_nano — open a remote file in nano via SSH with TTY
# ────────────────────────────────────────────────────────────
ssh_nano() {
    local remote_path="$1"
    require_ssh_host || return 1
    check_deps nano
    ssh -t "$SSH_HOST" "nano $remote_path"
    ok "File saved (if you saved it)."
}

# ────────────────────────────────────────────────────────────
# edit_server_cfg — edit tes3mp-server-default.cfg
# ────────────────────────────────────────────────────────────
edit_server_cfg() {
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Editing tes3mp-server-default.cfg"
    echo "═══════════════════════════════════════════════"
    echo ""
    info "Opening remote file on $SSH_HOST..."
    echo ""
    ssh_nano "/tes3mp-easy/configs/tes3mp-server-default.cfg"
}

# ────────────────────────────────────────────────────────────
# edit_lua_config — edit config.lua
# ────────────────────────────────────────────────────────────
edit_lua_config() {
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Editing config.lua"
    echo "═══════════════════════════════════════════════"
    echo ""
    info "Opening remote file on $SSH_HOST..."
    echo ""
    ssh_nano "/tes3mp-easy/configs/config.lua"
}

# ────────────────────────────────────────────────────────────
# edit_banlist — edit banlist.json
# ────────────────────────────────────────────────────────────
edit_banlist() {
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Editing banlist.json"
    echo "═══════════════════════════════════════════════"
    echo ""
    info "Opening remote file on $SSH_HOST..."
    echo ""
    ssh_nano "/tes3mp-easy/configs/banlist.json"
}

# ────────────────────────────────────────────────────────────
# edit_configs_menu — interactive submenu
# ────────────────────────────────────────────────────────────
edit_configs_menu() {
    local choice

    while true; do
        echo ""
        echo "───────────────────────────────────────────"
        echo "  Select configuration file to edit:"
        echo "───────────────────────────────────────────"
        echo ""
        echo "  1) tes3mp-server-default.cfg  — main server config"
        echo "  2) config.lua                 — Lua game settings"
        echo "  3) banlist.json               — player/IP ban list"
        echo ""
        echo "  b) Back to main menu"
        echo ""
        read -r -p "Select [1-3, b]: " choice

        case "$choice" in
            1) edit_server_cfg ;;
            2) edit_lua_config ;;
            3) edit_banlist ;;
            b|B) break ;;
            *) echo "Invalid choice." ;;
        esac

        echo ""
        read -r -p "Press Enter to continue..."
    done
}
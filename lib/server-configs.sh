#!/bin/bash
#
# server-configs.sh — edit TES3MP server configuration files
#
# Provides:
#   - edit_server_cfg()
#   - edit_lua_config()
#   - edit_banlist()
#   - edit_configs_menu() — submenu using run_menu()
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
    info "Opening remote file on $SSH_HOST..."
    ssh_nano "/tes3mp-easy/configs/tes3mp-server-default.cfg"
}

# ────────────────────────────────────────────────────────────
# edit_lua_config — edit config.lua
# ────────────────────────────────────────────────────────────
edit_lua_config() {
    info "Opening remote file on $SSH_HOST..."
    ssh_nano "/tes3mp-easy/configs/config.lua"
}

# ────────────────────────────────────────────────────────────
# edit_banlist — edit banlist.json
# ────────────────────────────────────────────────────────────
edit_banlist() {
    info "Opening remote file on $SSH_HOST..."
    ssh_nano "/tes3mp-easy/configs/banlist.json"
}

# ────────────────────────────────────────────────────────────
# edit_configs_menu — whiptail submenu
# ────────────────────────────────────────────────────────────
config_items=(
    "SERVER CONFIG|fn|edit_server_cfg"
    "LUA SETTINGS|fn|edit_lua_config"
    "BAN LIST|fn|edit_banlist"
    "─|sep|"
    "BACK|back|"
)

edit_configs_menu() {
    run_menu "EDIT CONFIGS" "${config_items[@]}"
}
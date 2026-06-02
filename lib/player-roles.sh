#!/bin/bash
#
# player-roles.sh — manage player roles (staffRank)
#
# Provides:
#   - list_players()        — list players on server
#   - set_player_role()     — set staffRank for a player
#   - player_roles_menu()   — interactive submenu via run_menu()
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before player-roles.sh" >&2
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

# ────────────────────────────────────────────────────────────
# list_players — list player files on server
# ────────────────────────────────────────────────────────────
list_players() {
    require_ssh_host || return 1

    local player_list
    player_list=$(ssh "$SSH_HOST" "ls -1 /tes3mp-easy/players/*.json 2>/dev/null" || echo "")

    if [[ -z "$player_list" ]]; then
        echo "No players found on server."
        return 0
    fi

    echo "  Account Name                     | StaffRank"
    echo "  ───────────────────────────────────┼──────────"
    while IFS= read -r file; do
        local account
        account=$(basename "$file" .json)
        local rank
        rank=$(ssh "$SSH_HOST" "grep -oP '\"staffRank\"\s*:\s*\K[0-9]+' \"$file\" 2>/dev/null | head -1" || echo "0")
        rank="${rank:-0}"
        local rank_name="Player"
        case "$rank" in
            1) rank_name="Moderator" ;;
            2) rank_name="Admin" ;;
            3) rank_name="ServerOwner" ;;
        esac
        printf "  %-40s | %s (%s)\n" "$account" "$rank_name" "$rank"
    done <<< "$player_list"
}

# ────────────────────────────────────────────────────────────
# set_player_role — change staffRank for a player
# ────────────────────────────────────────────────────────────
set_player_role() {
    local account="${1:-}"
    local new_rank="${2:-}"

    require_ssh_host || return 1

    # Show current players
    list_players
    echo ""
    read -r -p "Enter account name: " account
    if [[ -z "$account" ]]; then
        echo "Account name is required."
        return 1
    fi

    local player_file="/tes3mp-easy/players/$account.json"

    if ! ssh "$SSH_HOST" "test -f '$player_file'" 2>/dev/null; then
        echo "Player '$account' not found on server."
        return 1
    fi

    echo ""
    echo "  Available ranks:"
    echo "    0 = Regular player"
    echo "    1 = Moderator"
    echo "    2 = Admin"
    echo "    3 = Server owner"
    echo ""
    read -r -p "Enter new rank [0-3]: " new_rank

    case "$new_rank" in
        0|1|2|3) ;;
        *) echo "Invalid rank. Use 0-3."; return 1 ;;
    esac

    # Stop server
    ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose down" 2>/dev/null || true

    # Modify staffRank
    if ssh "$SSH_HOST" "grep -q '\"staffRank\"' '$player_file'" 2>/dev/null; then
        ssh "$SSH_HOST" "sed -i 's/\"staffRank\": [0-9]/\"staffRank\": $new_rank/' '$player_file'"
    else
        ssh "$SSH_HOST" "sed -i '/\"settings\": {/a \"staffRank\": $new_rank,' '$player_file'"
    fi

    echo "Player '$account' rank set to $new_rank"

    # Start server
    ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose up -d" 2>/dev/null || true
}

# ────────────────────────────────────────────────────────────
# player_roles_menu — whiptail submenu
# ────────────────────────────────────────────────────────────
roles_items=(
    "LIST PLAYERS|fn|list_players"
    "SET PLAYER ROLE|fn|set_player_role"
    "─|sep|"
    "BACK|back|"
)

player_roles_menu() {
    run_menu "MANAGE ROLES" "${roles_items[@]}"
}
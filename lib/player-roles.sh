#!/bin/bash
#
# player-roles.sh — manage player roles (staffRank)
#
# Provides:
#   - list_players()        — list players on server
#   - set_player_role()     — set staffRank for a player
#   - player_roles_menu()   — interactive submenu
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
        err "Run './tes3mp-easy config' to set it."
        return 1
    fi
}

# ────────────────────────────────────────────────────────────
# list_players — list player files on server
# ────────────────────────────────────────────────────────────
list_players() {
    require_ssh_host || return 1

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Players on $SSH_HOST"
    echo "═══════════════════════════════════════════════"
    echo ""

    # List .json files in players directory
    local player_list
    player_list=$(ssh "$SSH_HOST" "ls -1 /tes3mp-easy/players/*.json 2>/dev/null" || echo "")

    if [[ -z "$player_list" ]]; then
        info "No players found on server."
        return 0
    fi

    echo "  Account Name                     | StaffRank"
    echo "  ───────────────────────────────────┼──────────"
    while IFS= read -r file; do
        local account
        account=$(basename "$file" .json)

        # Extract staffRank (could be in settings or top-level)
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
    echo ""
}

# ────────────────────────────────────────────────────────────
# set_player_role — change staffRank for a player
# Usage: set_player_role <account_name> [rank 0-3]
# ────────────────────────────────────────────────────────────
set_player_role() {
    local account="$1"
    local new_rank="${2:-}"

    require_ssh_host || return 1

    # If no account provided, ask
    if [[ -z "$account" ]]; then
        echo ""
        echo "═══════════════════════════════════════════════"
        echo "  Set Player Role"
        echo "═══════════════════════════════════════════════"
        echo ""

        # List players first
        list_players

        read -r -p "Enter account name: " account
        if [[ -z "$account" ]]; then
            err "Account name is required."
            return 1
        fi
    fi

    local player_file="/tes3mp-easy/players/$account.json"

    # Check if player exists
    if ! ssh "$SSH_HOST" "test -f '$player_file'" 2>/dev/null; then
        err "Player '$account' not found on server."
        return 1
    fi

    # If no rank provided, ask
    if [[ -z "$new_rank" ]]; then
        echo ""
        echo "  Available ranks:"
        echo "    0 = Regular player"
        echo "    1 = Moderator"
        echo "    2 = Admin"
        echo "    3 = Server owner"
        echo ""
        read -r -p "Enter new rank [0-3]: " new_rank
    fi

    # Validate rank
    case "$new_rank" in
        0|1|2|3) ;;
        *)
            err "Invalid rank. Use 0-3."
            return 1
            ;;
    esac

    echo ""
    echo "  Player: $account"
    echo "  Rank:   $new_rank"

    if ! confirm "Apply this change?"; then
        info "Cancelled."
        return 0
    fi

    # Stop server
    info "Stopping server to modify player data..."
    ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose down" || {
        err "Failed to stop server."
        return 1
    }

    # Modify staffRank in player file
    # Try to find and replace staffRank in settings section
    local set_cmd=""
    set_cmd="sed -i 's/\"staffRank\": [0-9]/\"staffRank\": $new_rank/' '$player_file'"

    if ssh "$SSH_HOST" "grep -q '\"staffRank\"' '$player_file'" 2>/dev/null; then
        ssh "$SSH_HOST" "sed -i 's/\"staffRank\": [0-9]/\"staffRank\": $new_rank/' '$player_file'"
    else
        # Add staffRank to settings section
        ssh "$SSH_HOST" "sed -i '/\"settings\": {/a \"staffRank\": $new_rank,' '$player_file'"
    fi

    ok "Player '$account' rank set to $new_rank"

    # Start server
    info "Restarting server..."
    ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose up -d" && {
        ok "Server restarted."
    } || {
        err "Failed to start server."
        err "Start it manually: ./tes3mp-easy start"
    }
}

# ────────────────────────────────────────────────────────────
# player_roles_menu — interactive submenu
# ────────────────────────────────────────────────────────────
player_roles_menu() {
    local choice

    while true; do
        echo ""
        echo "───────────────────────────────────────────"
        echo "  Player Role Management"
        echo "───────────────────────────────────────────"
        echo ""
        echo "  1) List players on server"
        echo "  2) Set player role"
        echo ""
        echo "  b) Back to main menu"
        echo ""
        read -r -p "Select [1-2, b]: " choice

        case "$choice" in
            1) list_players ;;
            2) set_player_role ;;
            b|B) break ;;
            *) echo "Invalid choice." ;;
        esac

        echo ""
        read -r -p "Press Enter to continue..."
    done
}
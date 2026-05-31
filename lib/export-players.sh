#!/bin/bash
#
# export-players.sh — package and upload player data to TES3MP server
#
# Migrated from tools/linux/tes3mp-easy-export-players
#
# Provides:
#   - export_players()    — full pipeline (package + scp + import + deploy)
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before export-players.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# export_players — full players export pipeline
# ────────────────────────────────────────────────────────────
export_players() {
    check_deps tar ssh scp

    if [[ -z "${SSH_HOST:-}" ]]; then
        err "SSH_HOST is not set."
        err "Run './tes3mp-easy config' to set it."
        return 1
    fi

    # Player directory needs to be set — could be a local copy or detected
    local player_dir="${PLAYER_DIR:-}"
    if [[ -z "$player_dir" ]]; then
        # Fallback: use the project's players directory
        local detected
        detected=$(find_project_file "players" 2>/dev/null || echo "")
        if [[ -n "$detected" ]]; then
            player_dir="$detected"
        fi
    fi

    if [[ -z "$player_dir" || ! -d "$player_dir" ]]; then
        err "Player directory not found."
        err "Set PLAYER_DIR in your config or ensure a 'players' directory exists locally."
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  TES3MP Export Players"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  SSH host:            $SSH_HOST"
    echo "  Player dir:          $player_dir"
    echo ""

    # ─── Step 1: Package players ───
    echo "[1/5] Packaging player data..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    local output_archive="$tmp_dir/players.tar.gz"

    export PLAYER_DIR="$player_dir"

    local package_script
    package_script=$(find_project_file "server_setup/scripts/package.sh")
    if [[ -z "$package_script" ]]; then
        err "Could not find server_setup/scripts/package.sh"
        return 1
    fi

    source "$package_script"
    package_players "$output_archive"

    if [[ ! -f "$output_archive" ]]; then
        err "Failed to create archive"
        return 1
    fi
    ok "Archive created: $output_archive"

    # ─── Step 2: Transfer to server ───
    echo ""
    echo "[2/5] Transferring to server..."

    ssh "$SSH_HOST" "mkdir -p /tes3mp-easy/import-players" || {
        err "Failed to create remote directory"
        return 1
    }

    scp "$output_archive" "$SSH_HOST":/tes3mp-easy/import-players/players.tar.gz || {
        err "Failed to transfer archive to server"
        return 1
    }
    ok "Archive transferred to $SSH_HOST:/tes3mp-easy/import-players/"

    # ─── Step 3: Import on server ───
    echo ""
    echo "[3/5] Running import_players.sh on server..."
    echo "  (import saves archive without stopping server)"

    ssh "$SSH_HOST" "cd /tes3mp-easy && bash scripts/import_players.sh" || {
        err "import_players.sh failed on server — check server logs"
        return 1
    }
    ok "Server import completed"

    # ─── Step 4: Deploy on server ───
    echo ""
    echo "[4/5] Running deploy_players.sh --latest on server..."
    echo "  (This will stop TES3MP, deploy players, and restart)"

    ssh "$SSH_HOST" "cd /tes3mp-easy && bash scripts/deploy_players.sh --latest" || {
        err "deploy_players.sh failed on server — check server logs"
        return 1
    }
    ok "Server deploy completed"

    # ─── Step 5: Clean up ───
    echo ""
    echo "[5/5] Cleaning up..."
    rm -f "$output_archive"
    ok "Local archive cleaned up"

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Export complete!"
    echo "═══════════════════════════════════════════════"
    echo ""
}
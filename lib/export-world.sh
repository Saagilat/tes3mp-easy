#!/bin/bash
#
# export-world.sh — package and upload world data to TES3MP server
#
# Migrated from tools/linux/tes3mp-easy-export-world
#
# Provides:
#   - export_world()      — full pipeline (package + scp + import + deploy)
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before export-world.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# export_world — full world export pipeline
# ────────────────────────────────────────────────────────────
export_world() {
    check_deps tar ssh scp

    if [[ -z "${SSH_HOST:-}" ]]; then
        err "SSH_HOST is not set."
        err "Run './tes3mp-easy config' to set it."
        return 1
    fi

    # World directory — use WORLD_DIR from config or detect
    local world_dir="${WORLD_DIR:-}"
    if [[ -z "$world_dir" ]]; then
        local detected
        detected=$(find_project_file "world" 2>/dev/null || echo "")
        if [[ -n "$detected" ]]; then
            world_dir="$detected"
        fi
    fi

    if [[ -z "$world_dir" || ! -d "$world_dir" ]]; then
        err "World directory not found."
        err "Set WORLD_DIR in your config or ensure a 'world' directory exists locally."
        return 1
    fi

    # Validate subdirectories
    local subdirs=("cell" "world" "map" "recordstore" "custom")
    for sub in "${subdirs[@]}"; do
        local sub_path="$world_dir/$sub"
        if [[ ! -d "$sub_path" ]]; then
            warn "World subdirectory $sub/ not found at $sub_path — will be packaged as empty"
        fi
    done

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  TES3MP Export World"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  SSH host:            $SSH_HOST"
    echo "  World dir:           $world_dir"
    echo ""

    # ─── Step 1: Package world ───
    echo "[1/5] Packaging world data..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    local output_archive="$tmp_dir/world.tar.gz"

    export WORLD_CELL_DIR="$world_dir/cell"
    export WORLD_WORLD_DIR="$world_dir/world"
    export WORLD_MAP_DIR="$world_dir/map"
    export WORLD_RECORDSTORE_DIR="$world_dir/recordstore"
    export WORLD_CUSTOM_DIR="$world_dir/custom"

    local package_script
    package_script=$(find_project_file "server/scripts/package.sh")
    if [[ -z "$package_script" ]]; then
        err "Could not find server/scripts/package.sh"
        return 1
    fi

    source "$package_script"
    package_world "$output_archive"

    if [[ ! -f "$output_archive" ]]; then
        err "Failed to create archive"
        return 1
    fi
    ok "Archive created: $output_archive"

    # ─── Step 2: Transfer to server ───
    echo ""
    echo "[2/5] Transferring to server..."

    ssh "$SSH_HOST" "mkdir -p /tes3mp-easy/import-world" || {
        err "Failed to create remote directory"
        return 1
    }

    scp "$output_archive" "$SSH_HOST":/tes3mp-easy/import-world/world.tar.gz || {
        err "Failed to transfer archive to server"
        return 1
    }
    ok "Archive transferred to $SSH_HOST:/tes3mp-easy/import-world/"

    # ─── Step 3: Import on server ───
    echo ""
    echo "[3/5] Running import_world.sh on server..."
    echo "  (This only saves the archive — server keeps running)"

    ssh "$SSH_HOST" "cd /tes3mp-easy && bash scripts/import_world.sh" || {
        err "import_world.sh failed on server — check server logs"
        return 1
    }
    ok "Server import completed"

    # ─── Step 4: Deploy on server ───
    echo ""
    echo "[4/5] Running deploy_world.sh --latest on server..."
    echo "  (This will stop TES3MP, deploy world, and restart)"

    ssh "$SSH_HOST" "cd /tes3mp-easy && bash scripts/deploy_world.sh --latest" || {
        err "deploy_world.sh failed on server — check server logs"
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
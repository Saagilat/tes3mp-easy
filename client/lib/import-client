#!/bin/bash
#
# import-client.sh — download mods/players/world from server (HTTP)
#
# Migrated from tools/linux/tes3mp-easy-import-mods
#
# Provides:
#   - download_mods()       — download & install server mods
#   - download_players()    — download player data
#   - download_world()      — download world data
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before import-client.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# Helper: check SERVER_URL
# ────────────────────────────────────────────────────────────
require_server_url() {
    if [[ -z "${SERVER_URL:-}" ]]; then
        err "SERVER_URL is not set."
        err "Run './tes3mp-easy config' to set it."
        return 1
    fi
}

# ────────────────────────────────────────────────────────────
# Helper: check DATA_FILES and OPENMW_CFG
# ────────────────────────────────────────────────────────────
require_client_paths() {
    if [[ -z "${DATA_FILES:-}" || ! -d "${DATA_FILES:-}" ]]; then
        err "DATA_FILES is not set or does not exist: ${DATA_FILES:-}"
        err "Run './tes3mp-easy config' to set it."
        return 1
    fi

    if [[ -z "${OPENMW_CFG:-}" || ! -f "${OPENMW_CFG:-}" ]]; then
        warn "OPENMW_CFG is not set or not found: ${OPENMW_CFG:-}"
        warn "Mods will be downloaded but openmw.cfg won't be updated."
    fi
}

# ────────────────────────────────────────────────────────────
# download_mods — download mods from server, install them
# ────────────────────────────────────────────────────────────
download_mods() {
    require_server_url || return 1
    require_client_paths || return 1
    check_deps wget tar

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Downloading Mods from Server"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  Server URL:      $SERVER_URL/get-mods"
    echo "  Data Files:      $DATA_FILES"
    echo "  OpenMW config:   $OPENMW_CFG"
    echo ""

    # ─── Step 1: Download ───
    echo "[1/3] Downloading mods archive..."

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    local archive="$tmp_dir/mods.tar.gz"

    wget -q --show-progress "$SERVER_URL/get-mods" -O "$archive" || {
        err "Failed to download mods from $SERVER_URL/get-mods"
        err "Check that the server endpoint is enabled and accessible."
        return 1
    }
    ok "Archive downloaded"

    # ─── Step 2: Extract ───
    echo ""
    echo "[2/3] Extracting mods into $DATA_FILES..."

    tar -xzf "$archive" -C "$DATA_FILES" || {
        err "Failed to extract mods archive"
        return 1
    }
    ok "Mods extracted to $DATA_FILES"

    # ─── Step 3: Update openmw.cfg ───
    echo ""
    echo "[3/3] Updating openmw.cfg..."

    if [[ -n "$OPENMW_CFG" && -f "$OPENMW_CFG" ]]; then
        # Get list of .esp/.esm files that were in the archive
        local plugin_list
        plugin_list=$(tar -tzf "$archive" 2>/dev/null | grep -iE '\.(esp|esm|omwaddon)$' || echo "")

        if [[ -n "$plugin_list" ]]; then
            local added=0
            while IFS= read -r plugin; do
                # Add data= entry pointing to plugin
                local data_line="data=\"$DATA_FILES/$plugin\""
                if ! grep -Fxq "$data_line" "$OPENMW_CFG" 2>/dev/null; then
                    echo "$data_line" >> "$OPENMW_CFG"
                    added=$((added + 1))
                fi
            done <<< "$plugin_list"

            if [[ "$added" -gt 0 ]]; then
                ok "Added $added new plugin entries to openmw.cfg"
            else
                info "All plugins already registered in openmw.cfg"
            fi
        else
            warn "No plugin files (.esp/.esm/.omwaddon) found in the archive"
        fi

        # Check and remove conflicting data/ folder
        local openmw_profile
        openmw_profile="$(dirname "$OPENMW_CFG")"
        local data_folder="$openmw_profile/data"
        if [[ -d "$data_folder" ]]; then
            warn "OpenMW 'data/' folder detected: $data_folder"
            warn "This folder has higher priority than 'data=' paths and may cause CRC mismatches."
            if confirm "Remove this folder?"; then
                rm -rf "$data_folder"
                ok "Removed $data_folder"
            fi
        fi

    else
        warn "openmw.cfg not found — plugins installed but not registered."
        warn "Add them manually or set OPENMW_CFG in config."
    fi

    rm -f "$archive"
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Download complete!"
    echo "═══════════════════════════════════════════════"
    echo ""
}

# ────────────────────────────────────────────────────────────
# download_players — download player data from server
# ────────────────────────────────────────────────────────────
download_players() {
    require_server_url || return 1
    check_deps wget

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Downloading Player Data from Server"
    echo "═══════════════════════════════════════════════"
    echo ""

    wget -q --show-progress "$SERVER_URL/get-players" -O ./players.tar.gz || {
        err "Failed to download players from $SERVER_URL/get-players"
        return 1
    }
    ok "Player data saved to ./players.tar.gz"
}

# ────────────────────────────────────────────────────────────
# download_world — download world data from server
# ────────────────────────────────────────────────────────────
download_world() {
    require_server_url || return 1
    check_deps wget

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Downloading World Data from Server"
    echo "═══════════════════════════════════════════════"
    echo ""

    wget -q --show-progress "$SERVER_URL/get-world" -O ./world.tar.gz || {
        err "Failed to download world from $SERVER_URL/get-world"
        return 1
    }
    ok "World data saved to ./world.tar.gz"
}
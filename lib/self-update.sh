#!/bin/bash
#
# self-update.sh — update tes3mp-easy scripts from GitHub
#
# Provides:
#   - self_update()    — download latest version of all scripts
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before self-update.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# Configuration
# ────────────────────────────────────────────────────────────
GITHUB_RAW="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master"
UPDATE_DIR="${HOME}/.local/share/tes3mp-easy"
BOOTSTRAP_SCRIPT="${UPDATE_DIR}/tes3mp-easy"

# ────────────────────────────────────────────────────────────
# self_update — download latest scripts from GitHub
# ────────────────────────────────────────────────────────────
self_update() {
    check_deps wget

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Updating tes3mp-easy"
    echo "═══════════════════════════════════════════════"
    echo ""

    # Files to update
    local files_to_update=(
        "tes3mp-easy"
        "menu/player.sh"
        "menu/admin.sh"
        "lib/common.sh"
        "lib/i18n.sh"
        "lib/config.sh"
        "lib/server-install.sh"
        "lib/server-control.sh"
        "lib/server-configs.sh"
        "lib/export-mods.sh"
        "lib/export-players.sh"
        "lib/export-world.sh"
        "lib/import-server.sh"
        "lib/import-client.sh"
        "lib/required-data.sh"
        "lib/client-install.sh"
        "lib/client-configs.sh"
        "lib/localization.sh"
        "lib/player-roles.sh"
        "lib/self-update.sh"
        "lang/en"
        "lang/ru"
    )

    info "Downloading updates from $GITHUB_RAW"

    local updated=0
    local failed=0

    for file in "${files_to_update[@]}"; do
        local url="$GITHUB_RAW/$file"
        local dest="$UPDATE_DIR/$file"

        mkdir -p "$(dirname "$dest")"

        info "  Downloading: $file"
        if wget -q "$url" -O "$dest" 2>/dev/null; then
            chmod +x "$dest" 2>/dev/null || true
            updated=$((updated + 1))
        else
            # Some files may not exist yet (client-install, etc. are new)
            # Only error if it's a core file
            case "$file" in
                tes3mp-easy|menu/player.sh|menu/admin.sh|lib/common.sh|lib/i18n.sh|lib/config.sh)
                    warn "  Failed to download $file"
                    failed=$((failed + 1))
                    ;;
                *)
                    # New files — warn but don't fail
                    info "  (skipping new/non-existent: $file)"
                    ;;
            esac
        fi
    done

    if [[ "$failed" -gt 0 ]]; then
        err "Failed to update $failed file(s)."
        err "Check your internet connection."
        return 1
    fi

    echo ""
    ok "Updated $updated files in $UPDATE_DIR"
    echo ""
    info "If the bootstrap script (tes3mp-easy) was updated,"
    info "please restart it to use the new version."
    echo ""
    info "If you see any errors, make sure you have the latest"
    info "version of the script from the repository."
}

# ────────────────────────────────────────────────────────────
# first_time_download — download all scripts on first launch
# ────────────────────────────────────────────────────────────
first_time_download() {
    check_deps wget

    mkdir -p "$UPDATE_DIR"
    mkdir -p "$UPDATE_DIR/lib"
    mkdir -p "$UPDATE_DIR/menu"

    info "Downloading tes3mp-easy scripts to $UPDATE_DIR..."

    # Download bootstrap first
    if ! wget -q "$GITHUB_RAW/tes3mp-easy" -O "$UPDATE_DIR/tes3mp-easy" 2>/dev/null; then
        err "Failed to download tes3mp-easy bootstrap."
        exit 1
    fi
    chmod +x "$UPDATE_DIR/tes3mp-easy"

    # Download menu files
    for file in "menu/player.sh" "menu/admin.sh"; do
        wget -q "$GITHUB_RAW/$file" -O "$UPDATE_DIR/$file" 2>/dev/null || true
        chmod +x "$UPDATE_DIR/$file" 2>/dev/null || true
    done

    # Download lib files
    local lib_files=(
        "common.sh" "config.sh" "server-install.sh" "server-control.sh"
        "server-configs.sh" "export-mods.sh" "export-players.sh"
        "export-world.sh" "import-server.sh" "import-client.sh"
        "required-data.sh" "client-install.sh" "client-configs.sh"
        "localization.sh" "player-roles.sh" "self-update.sh"
    )
    for file in "${lib_files[@]}"; do
        wget -q "$GITHUB_RAW/lib/$file" -O "$UPDATE_DIR/lib/$file" 2>/dev/null || true
        chmod +x "$UPDATE_DIR/lib/$file" 2>/dev/null || true
    done

    ok "Scripts downloaded to $UPDATE_DIR"
}
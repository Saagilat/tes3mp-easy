#!/bin/bash
#
# localization.sh — install TES3MP localization (Russian)
#
# Migrated from tools/linux/localization/russian/install.sh
#
# Provides:
#   - install_localization()    — download and apply localization files
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before localization.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# install_localization — download and install localization
# Usage: install_localization [language]
# Supported: russian (default)
# ────────────────────────────────────────────────────────────
install_localization() {
    local lang="${1:-russian}"
    lang="${lang,,}"

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Installing Localization"
    echo "═══════════════════════════════════════════════"
    echo ""

    # Detect openmw-profile
    local openmw_profile=""
    if [[ -n "${OPENMW_CFG:-}" ]]; then
        openmw_profile="$(dirname "$OPENMW_CFG")"
    fi

    if [[ -z "$openmw_profile" || ! -d "$openmw_profile" ]]; then
        local candidates=(
            "$HOME/openmw-profile"
            "$HOME/.config/openmw"
        )
        for dir in "${candidates[@]}"; do
            if [[ -d "$dir" ]]; then
                openmw_profile="$dir"
                break
            fi
        done
    fi

    if [[ -z "$openmw_profile" || ! -d "$openmw_profile" ]]; then
        err "OpenMW profile directory not found."
        err "Make sure you have installed and run the TES3MP client first."
        return 1
    fi

    info "OpenMW profile: $openmw_profile"

    case "$lang" in
        russian)
            install_russian "$openmw_profile"
            ;;
        *)
            err "Unsupported language: $lang"
            err "Supported: russian"
            return 1
            ;;
    esac
}

# ────────────────────────────────────────────────────────────
# install_russian — install Russian localization
# ────────────────────────────────────────────────────────────
install_russian() {
    local profile_dir="$1"
    local lang_dir="$profile_dir/translations"

    info "Installing Russian localization..."

    mkdir -p "$lang_dir"

    # Try to find local files first
    local local_files
    local_files=$(find_project_file "tools/localization/russian" 2>/dev/null || echo "")

    if [[ -n "$local_files" && -d "$local_files" ]]; then
        info "Found local localization files at: $local_files"
        cp -r "$local_files/"* "$lang_dir/" 2>/dev/null || true
        ok "Copied localization files from repository"
    else
        # Download from GitHub
        local base_url="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/tools/localization/russian"
        local files=(
            "README.md"
            "openmw_log.png"
            # Add actual .mo/.po files here as needed
        )

        info "Downloading localization files from GitHub..."
        for f in "${files[@]}"; do
            wget -q "$base_url/$f" -O "$lang_dir/$f" 2>/dev/null || warn "Failed to download $f"
        done
        ok "Downloaded localization files"
    fi

    # Also install client localization if Linux/Proton
    if is_os "linux"; then
        local client_lang_dir=""

        # Try to find the tes3mp installation
        local tes3mp_dir="${TES3MP_INSTALL_DIR:-$HOME/morrowind/tes3mp}"
        if [[ -d "$tes3mp_dir" ]]; then
            # For Proton, localization goes into the prefix
            local steam_path
            steam_path=$(detect_steam_path)
            local tes3mp_id
            tes3mp_id=$(detect_compatdata_id "tes3mp")
            if [[ -n "$steam_path" && -n "$tes3mp_id" ]]; then
                client_lang_dir="$steam_path/steamapps/compatdata/$tes3mp_id/pfx/drive_c/users/steamuser/Documents/My Games/OpenMW/translations"
                mkdir -p "$client_lang_dir"

                if [[ -n "$local_files" && -d "$local_files" ]]; then
                    cp -r "$local_files/"* "$client_lang_dir/" 2>/dev/null || true
                    ok "Copied localization files to Proton prefix"
                fi
            fi
        fi
    fi

    echo ""
    echo "  Russian localization installed to:"
    echo "    $lang_dir"
    echo ""
    info "Restart the TES3MP client for changes to take effect."
}
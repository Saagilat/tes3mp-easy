#!/bin/bash
#
# client-install.sh — install TES3MP client via Proton
#
# Automates the steps from docs/player/linux/proton/install.md
#
# Provides:
#   - install_client()          — full interactive installation
#   - detect_compatdata_id()    — find Steam compatdata for a given exe
#   - detect_morrowind_steam()  — find Morrowind in Steam library
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before client-install.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# Configuration
# ────────────────────────────────────────────────────────────
TES3MP_VERSION="0.8.1"
TES3MP_ZIP="tes3mp.Win64.release.${TES3MP_VERSION}.zip"
TES3MP_URL="https://github.com/TES3MP/TES3MP/releases/download/tes3mp-${TES3MP_VERSION}/${TES3MP_ZIP}"
TES3MP_INSTALL_DIR="${HOME}/morrowind/tes3mp"

# ────────────────────────────────────────────────────────────
# install_client — full interactive installation
# ────────────────────────────────────────────────────────────
install_client() {
    if ! is_os "linux"; then
        err "Client installation is currently supported only on Linux via Proton."
        err "For Windows, download the TES3MP client manually from GitHub."
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  TES3MP Client Installation (Proton)"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  This will install the TES3MP client to: $TES3MP_INSTALL_DIR"
    echo ""

    if ! confirm "Proceed with installation?"; then
        info "Installation cancelled."
        return 0
    fi

    echo ""

    # ─── Step 1: Check dependencies ───
    echo "[1] Checking dependencies..."
    check_deps wget unzip find grep ln
    ok "Dependencies OK"

    # ─── Step 2: Detect Morrowind in Steam ───
    echo ""
    echo "[2] Detecting Morrowind installation..."

    local mw_path
    mw_path=$(detect_morrowind_steam)

    if [[ -z "$mw_path" ]]; then
        err "Morrowind not found in Steam library."
        err "Make sure Morrowind is installed in Steam."
        return 1
    fi
    ok "Morrowind found at: $mw_path"

    # Create symlink in home for Proton visibility
    local mw_link="$HOME/morrowind"
    if [[ ! -L "$mw_link" ]]; then
        if [[ -d "$mw_link" ]]; then
            warn "Directory $mw_link already exists and is not a symlink."
            if ! confirm "Recreate it as a symlink?"; then
                info "Skipping symlink creation."
            else
                rm -rf "$mw_link"
                ln -s "$mw_path" "$mw_link"
                ok "Created symlink: $mw_link → $mw_path"
            fi
        else
            ln -s "$mw_path" "$mw_link"
            ok "Created symlink: $mw_link → $mw_path"
        fi
    else
        ok "Symlink already exists: $mw_link"
    fi

    # ─── Step 3: Download TES3MP ───
    echo ""
    echo "[3] Downloading TES3MP client..."

    mkdir -p "$TES3MP_INSTALL_DIR" 2>/dev/null || true

    if [[ -f "$TES3MP_INSTALL_DIR/tes3mp.exe" ]]; then
        info "TES3MP already installed at $TES3MP_INSTALL_DIR"
        if ! confirm "Re-download and overwrite?"; then
            info "Skipping download."
        else
            download_tes3mp
        fi
    else
        download_tes3mp
    fi

    # ─── Step 4: Find or prompt to add to Steam ───
    echo ""
    echo "[4] Checking Steam integration..."

    local wizard_id
    wizard_id=$(detect_compatdata_id "openmw-wizard")

    local tes3mp_id
    tes3mp_id=$(detect_compatdata_id "tes3mp")

    if [[ -z "$wizard_id" || -z "$tes3mp_id" ]]; then
        echo ""
        echo "───────────────────────────────────────────"
        echo "  Steam Setup Required"
        echo "───────────────────────────────────────────"
        echo ""
        echo "  To complete the installation, you need to:"
        echo ""
        echo "  1. Add these programs as non-Steam games in Steam:"
        echo "     - $TES3MP_INSTALL_DIR/openmw-wizard.exe"
        echo "     - $TES3MP_INSTALL_DIR/tes3mp.exe"
        echo ""
        echo "  2. Assign Proton (11.0 or Experimental) to both"
        echo ""
        echo "  3. Run openmw-wizard.exe through Steam once,"
        echo "     select your Morrowind files, then close it."
        echo ""
        echo "  4. Run tes3mp.exe through Steam once, then close it."
        echo ""
        echo "  After that, re-run this script to finish setup."
        echo ""
        press_enter
        return 0
    fi

    ok "Steam compatdata found:"
    ok "  openmw-wizard: $wizard_id"
    ok "  tes3mp:        $tes3mp_id"

    # ─── Step 5: Symlink pfx ───
    echo ""
    echo "[5] Setting up Proton prefix..."

    local steam_path
    steam_path=$(detect_steam_path)
    local wizard_pfx="$steam_path/steamapps/compatdata/$wizard_id/pfx"
    local tes3mp_pfx="$steam_path/steamapps/compatdata/$tes3mp_id/pfx"

    if [[ -L "$tes3mp_pfx" ]]; then
        local current_target
        current_target=$(readlink "$tes3mp_pfx")
        if [[ "$current_target" == "$wizard_pfx" ]]; then
            ok "Symlink already correctly set: $tes3mp_pfx → $wizard_pfx"
        else
            warn "Symlink points to $current_target instead of $wizard_pfx"
            if confirm "Fix symlink?"; then
                rm -f "$tes3mp_pfx"
                ln -s "$wizard_pfx" "$tes3mp_pfx"
                ok "Symlink fixed"
            fi
        fi
    elif [[ -d "$tes3mp_pfx" ]]; then
        warn "tes3mp pfx is a real directory ($tes3mp_pfx)"
        if confirm "Replace with symlink to wizard's pfx?"; then
            rm -rf "$tes3mp_pfx"
            ln -s "$wizard_pfx" "$tes3mp_pfx"
            ok "Symlink created"
        fi
    else
        info "Creating symlink: $tes3mp_pfx → $wizard_pfx"
        mkdir -p "$(dirname "$tes3mp_pfx")"
        ln -s "$wizard_pfx" "$tes3mp_pfx"
        ok "Symlink created"
    fi

    # ─── Step 6: Set up openmw-profile symlink ───
    echo ""
    echo "[6] Setting up OpenMW profile symlink..."

    local openmw_profile_link="$HOME/openmw-profile"
    local openmw_profile_real="$wizard_pfx/drive_c/users/steamuser/Documents/My Games/OpenMW"

    if [[ -L "$openmw_profile_link" ]]; then
        ok "OpenMW profile symlink already exists: $openmw_profile_link"
    elif [[ -d "$openmw_profile_link" ]]; then
        warn "Directory $openmw_profile_link exists and is not a symlink."
        if confirm "Replace with symlink?"; then
            rm -rf "$openmw_profile_link"
            ln -s "$openmw_profile_real" "$openmw_profile_link"
            ok "Symlink created"
        fi
    else
        ln -s "$openmw_profile_real" "$openmw_profile_link"
        ok "Created symlink: $openmw_profile_link → $openmw_profile_real"
    fi

    # ─── Step 7: Install MangoHud (optional) ───
    echo ""
    echo "[7] FPS limiter (MangoHud)..."

    if ! command -v mangohud &>/dev/null; then
        info "MangoHud is recommended for FPS limiting with Proton."
        if confirm "Install MangoHud?"; then
            install_mangohud
        else
            info "Skipping MangoHud. You can install it later."
            info "Then add to Steam launch options:"
            info '  MANGOHUD_CONFIG=fps_limit=120,no_display mangohud %command%'
        fi
    else
        ok "MangoHud already installed"
        info "Add to Steam launch options:"
        info '  MANGOHUD_CONFIG=fps_limit=120,no_display mangohud %command%'
    fi

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Installation complete!"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  TES3MP client installed at: $TES3MP_INSTALL_DIR"
    echo ""
    echo "  Next steps:"
    echo "  1. Configure server address in tes3mp-client-default.cfg"
    echo "     → ./tes3mp-easy config-client"
    echo "  2. Download server mods"
    echo "     → ./tes3mp-easy download-mods"
    echo "  3. Launch tes3mp.exe via Steam"
    echo ""
}

# ────────────────────────────────────────────────────────────
# download_tes3mp — download and extract TES3MP client
# ────────────────────────────────────────────────────────────
download_tes3mp() {
    check_deps wget unzip

    local tmp_dir
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    local zip_path="$tmp_dir/$TES3MP_ZIP"

    info "Downloading TES3MP $TES3MP_VERSION..."
    info "  URL: $TES3MP_URL"
    echo ""

    wget -q --show-progress "$TES3MP_URL" -O "$zip_path" || {
        err "Failed to download TES3MP from $TES3MP_URL"
        err "Download it manually and extract to $TES3MP_INSTALL_DIR"
        return 1
    }

    ok "Downloaded $TES3MP_ZIP"

    info "Extracting to $TES3MP_INSTALL_DIR..."
    mkdir -p "$TES3MP_INSTALL_DIR"
    unzip -q -o "$zip_path" -d "$TES3MP_INSTALL_DIR" || {
        err "Failed to extract TES3MP"
        return 1
    }

    chmod +x "$TES3MP_INSTALL_DIR"/*.exe 2>/dev/null || true
    ok "Extracted to $TES3MP_INSTALL_DIR"

    rm -f "$zip_path"
}

# ────────────────────────────────────────────────────────────
# detect_compatdata_id — find Steam compatdata ID for a given exe
# Usage: detect_compatdata_id "tes3mp" → 1234567
# ────────────────────────────────────────────────────────────
detect_compatdata_id() {
    local exe_name="$1"
    local steam_path
    steam_path=$(detect_steam_path)

    if [[ -z "$steam_path" || ! -d "$steam_path/steamapps/compatdata" ]]; then
        echo ""
        return 1
    fi

    local compat_id
    compat_id=$(find "$steam_path/steamapps/compatdata" -maxdepth 2 -name "*.reg" -exec grep -l "$exe_name" {} \; 2>/dev/null | head -1 | grep -oP 'compatdata/\K[0-9]+')

    if [[ -z "$compat_id" ]]; then
        echo ""
        return 1
    fi

    echo "$compat_id"
}

# ────────────────────────────────────────────────────────────
# detect_morrowind_steam — find Morrowind in Steam library
# ────────────────────────────────────────────────────────────
detect_morrowind_steam() {
    local steam_path
    steam_path=$(detect_steam_path)

    if [[ -z "$steam_path" ]]; then
        return 1
    fi

    # Check library folders
    local library_file="$steam_path/steamapps/libraryfolders.vdf"
    if [[ -f "$library_file" ]]; then
        # Search the main Steam path
        local mw_path="$steam_path/steamapps/common/Morrowind"
        if [[ -f "$mw_path/Data Files/Morrowind.esm" ]]; then
            echo "$mw_path"
            return 0
        fi

        # Search other library folders
        while IFS= read -r line; do
            if [[ "$line" =~ \"path\"[[:space:]]*\"(.*)\" ]]; then
                local lib_path="${BASH_REMATCH[1]}"
                mw_path="$lib_path/steamapps/common/Morrowind"
                if [[ -f "$mw_path/Data Files/Morrowind.esm" ]]; then
                    echo "$mw_path"
                    return 0
                fi
            fi
        done < <(grep '"path"' "$library_file" 2>/dev/null)
    fi

    return 1
}

# ────────────────────────────────────────────────────────────
# install_mangohud — install MangoHud via package manager
# ────────────────────────────────────────────────────────────
install_mangohud() {
    info "Installing MangoHud..."

    if command -v pacman &>/dev/null; then
        if sudo pacman -S --noconfirm mangohud; then
            ok "MangoHud installed via pacman"
            return 0
        fi
    elif command -v apt-get &>/dev/null; then
        # MangoHud is in Ubuntu repos from 22.04+
        if sudo apt-get install -y mangohud; then
            ok "MangoHud installed via apt"
            return 0
        fi
        # Fallback: try the official PPA or manual install
        warn "MangoHud not available via apt. Try:"
        warn "  sudo add-apt-repository ppa:flexiondotorg/mangohud && sudo apt update && sudo apt install mangohud"
    elif command -v dnf &>/dev/null; then
        if sudo dnf install -y mangohud; then
            ok "MangoHud installed via dnf"
            return 0
        fi
    else
        warn "Unknown package manager. Install MangoHud manually:"
        warn "  https://github.com/flightlessmango/MangoHud"
    fi
}
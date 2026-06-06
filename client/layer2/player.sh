#!/bin/bash
#
# layer2/player.sh — Interactive wrappers for player operations
#
# Layer 2: Each function wraps one or more Layer 1 calls,
# adding human-friendly output and user interaction.
#
# All Layer 1 paths are in LAYER1_DIR="$PROJECT_DIR/layer1/player"
#

if [[ -z "${LIB_DIR:-}" ]]; then
    PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    LAYER1_DIR="$PROJECT_DIR/layer1/player"
    LIB_DIR="$PROJECT_DIR/lib"
    source "$LIB_DIR/common"
    source "$LIB_DIR/config"
    source "$LIB_DIR/lang"
fi

LAYER1_DIR="${LAYER1_DIR:-$PROJECT_DIR/layer1/player}"

# ────────────────────────────────────────────────────────────
# Simple wrappers — just call layer1 with no extra logic
# ────────────────────────────────────────────────────────────
interactive_install_client()       { bash "$LAYER1_DIR/install-client"; }
interactive_run_client()           { bash "$LAYER1_DIR/run-client"; }
interactive_run_openmw_cs()        { bash "$LAYER1_DIR/run-openmw-cs"; }
interactive_install_mods()         { bash "$LAYER1_DIR/install-mods"; }
interactive_edit_config()          { bash "$LAYER1_DIR/edit-config"; }
interactive_edit_client_cfg()      { bash "$LAYER1_DIR/edit-client-cfg"; }
interactive_show_backups_mods()    { bash "$LAYER1_DIR/show-backups-mods"; }
interactive_show_backups_players() { bash "$LAYER1_DIR/show-backups-players"; }
interactive_show_backups_world()   { bash "$LAYER1_DIR/show-backups-world"; }

# ────────────────────────────────────────────────────────────
# Install fonts — show menu, then call layer1 with selection
# ────────────────────────────────────────────────────────────
interactive_install_fonts() {
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Install Fonts"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  Each option installs a set of 3 fonts:"
    echo "    Sans (Magic Cards)  |  Serif (Daedric)  |  Mono (MonoFont)"
    echo ""
    echo "  1)  IBM Plex Sans    + IBM Plex Serif    + IBM Plex Mono"
    echo "  2)  Noto Sans        + Noto Serif        + Roboto Mono"
    echo "  3)  Roboto           + Lora              + Cousine"
    echo "  4)  Open Sans        + Noto Serif        + Source Code Pro"
    echo "  5)  Montserrat       + Playfair Display  + Space Mono"
    echo "  6)  Fira Sans        + Lora              + Fira Mono"
    echo "  7)  Arimo            + Noto Serif        + Red Hat Mono"
    echo "  8)  Source Sans 3    + Playfair Display  + Roboto Mono"
    echo "  9)  Noto Sans        + Lora              + Cousine"
    echo " 10)  Roboto           + Playfair Display  + Source Code Pro"
    echo " 11)  Open Sans        + Noto Serif        + Space Mono"
    echo " 12)  Show Nexus Mods link (Morrowind-style fonts)"
    echo ""
    input "Select option [1-12] (empty = skip)" "" FONT_OPT
    [[ -z "${FONT_OPT:-}" ]] && { info "Skipped."; return; }
    bash "$LAYER1_DIR/install-fonts" "$FONT_OPT"
}

# ────────────────────────────────────────────────────────────
# Install localization — list available, then call layer1
# ────────────────────────────────────────────────────────────
interactive_install_localization() {
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Install Localization"
    echo "═══════════════════════════════════════════════"
    echo ""

    LOCALES=()
    LOCALE_NAMES=()
    for dir in "$LIB_DIR/../lib/localization"/*/; do
        [[ -d "$dir" ]] || continue
        name="$(basename "$dir")"
        install_script="$dir/install.sh"
        if [[ -f "$install_script" ]]; then
            LOCALES+=("$name")
            LOCALE_NAMES+=("$(tr '[:lower:]' '[:upper:]' <<< "${name:0:1}")${name:1}")
        fi
    done

    if [[ ${#LOCALES[@]} -eq 0 ]]; then
        warn "No localizations found."
        return
    fi

    echo "  Available localizations:"
    for i in "${!LOCALES[@]}"; do
        printf "  %d) %s\n" $((i+1)) "${LOCALE_NAMES[$i]}"
    done
    echo "  $((${#LOCALES[@]}+1))) Skip"
    echo ""
    input "Select option [1-$((${#LOCALES[@]}+1))]" "" LOCALE_CHOICE

    if [[ -z "${LOCALE_CHOICE:-}" ]] || [[ "$LOCALE_CHOICE" -eq $((${#LOCALES[@]}+1)) ]]; then
        info "No localization selected. Skipping."
        return
    fi

    LOCALE_IDX=$((LOCALE_CHOICE - 1))
    if [[ "$LOCALE_IDX" -lt 0 || "$LOCALE_IDX" -ge "${#LOCALES[@]}" ]]; then
        warn "Invalid selection. Skipping."
        return
    fi

    LOCALE="${LOCALES[$LOCALE_IDX]}"

    # Ask about voices if not already cached
    if [[ ! -f "$HOME/.config/tes3mp-easy/localizations/voices_${LOCALE}.tar" ]]; then
        if confirm "Download voices for ${LOCALE} (~150 MB)?" "n"; then
            export DOWNLOAD_VOICES="true"
        fi
    fi

    bash "$LAYER1_DIR/install-localization" "$LOCALE"
}

# ────────────────────────────────────────────────────────────
# Configure UI — prompt for values, then call layer1
# ────────────────────────────────────────────────────────────
interactive_configure_ui() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
    local config="$config_dir/tes3mp-easy.ini"
    local TES3MP_DIR
    TES3MP_DIR=$(grep "^TES3MP_DIR" "$config" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d '\r')
    TES3MP_DIR="${TES3MP_DIR/#\~/$HOME}"

    if [[ -z "$TES3MP_DIR" ]]; then
        err "TES3MP_DIR is not set. Run setup-wizard first."
        return
    fi

    local SETTINGS_CFG="$TES3MP_DIR/prefix/pfx/drive_c/users/steamuser/Documents/My Games/OpenMW/settings.cfg"
    if [[ ! -f "$SETTINGS_CFG" ]]; then
        err "settings.cfg not found. Run client at least once first."
        return
    fi

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Configure UI"
    echo "═══════════════════════════════════════════════"
    echo ""

    local CURRENT_TTF CURRENT_FONT CURRENT_SCALE
    CURRENT_TTF=$(grep "^ttf resolution" "$SETTINGS_CFG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d '\r') || CURRENT_TTF=""
    CURRENT_FONT=$(grep "^font size" "$SETTINGS_CFG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d '\r') || CURRENT_FONT=""
    CURRENT_SCALE=$(grep "^scaling factor" "$SETTINGS_CFG" 2>/dev/null | head -1 | sed 's/.*=[[:space:]]*//' | tr -d '\r') || CURRENT_SCALE=""

    echo "  Current settings:"
    echo "    ttf resolution = ${CURRENT_TTF:-not set}"
    echo "    font size      = ${CURRENT_FONT:-not set}"
    echo "    scaling factor = ${CURRENT_SCALE:-not set}"
    echo ""
    input "ttf resolution" "${CURRENT_TTF:-96}" TTF_RES
    input "font size" "${CURRENT_FONT:-16}" FONT_SIZE
    input "scaling factor" "${CURRENT_SCALE:-1.0}" SCALING

    bash "$LAYER1_DIR/configure-ui" "$TTF_RES" "$FONT_SIZE" "$SCALING"
}

# ────────────────────────────────────────────────────────────
# Setup wizard — interactive guided setup
# ────────────────────────────────────────────────────────────
interactive_setup_wizard() {
    local TOTAL=7
    local CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
    local CONFIG="$CONFIG_DIR/tes3mp-easy.ini"

    echo ""
    echo "  ${T_LABEL}╔══════════════════════════════════════════════════╗${NC}"
    echo "  ${T_LABEL}║      TES3MP Easy — Player Setup Wizard          ║${NC}"
    echo "  ${T_LABEL}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    info "This wizard will guide you through setting up the client."
    info "Press Ctrl+C at any time to exit."
    echo ""

    load_config 2>/dev/null || true

    # Step 1: MORROWIND_PATH
    step_header() {
        local num="$1" total="$2" title="$3"
        echo ""; echo "  ${T_LABEL}━━━ [${num}/${total}] ${title} ━━━${NC}"; echo ""
    }
    step_header 1 $TOTAL "Morrowind Directory"
    while true; do
        input "Enter path to Morrowind directory" "${MORROWIND_PATH:-}" MW_PATH
        if [[ -z "$MW_PATH" ]]; then
            warn "Skipping."
            break
        fi
        if bash "$LAYER1_DIR/set-morrowind-path" "$MW_PATH"; then
            break
        else
            confirm "Try again?" "y" || { warn "Skipping."; break; }
        fi
    done
    load_config 2>/dev/null || true

    # Step 2: TES3MP_DIR
    step_header 2 $TOTAL "TES3MP Directory"
    input "Enter TES3MP directory" "${TES3MP_DIR:-games/tes3mp}" T_DIR
    if [[ -n "$T_DIR" ]]; then
        bash "$LAYER1_DIR/set-tes3mp-dir" "$T_DIR"
    fi
    load_config 2>/dev/null || true

    # Step 3: PROTON_PATH
    step_header 3 $TOTAL "Proton Path"
    while true; do
        echo ""
        echo "  Enter the path to your Proton installation."
        echo "  Example: /home/user/.steam/steam/steamapps/common/Proton 9.0"
        echo ""
        input "Enter path to Proton directory" "${PROTON_PATH:-}" P_PATH
        if [[ -z "$P_PATH" ]]; then
            warn "Skipping."
            break
        fi
        if bash "$LAYER1_DIR/set-proton-path" "$P_PATH"; then
            break
        else
            confirm "Try again?" "y" || { warn "Skipping."; break; }
        fi
    done
    load_config 2>/dev/null || true

    # Step 4: Install client
    step_header 4 $TOTAL "Client Installation"
    load_config 2>/dev/null || true
    if [[ -z "${MORROWIND_PATH:-}" ]]; then
        err "MORROWIND_PATH is not set."
    elif [[ -z "${TES3MP_DIR:-}" ]]; then
        err "TES3MP_DIR is not set."
    else
        if confirm "Install / update client now?" "y"; then
            bash "$LAYER1_DIR/install-client" || err "Client installation failed."
        fi
    fi

    # Step 5: Install fonts
    step_header 5 $TOTAL "Fonts"
    if confirm "Install fonts?" "y"; then
        interactive_install_fonts
    fi

    # Step 6: Configure UI
    step_header 6 $TOTAL "UI Configuration"
    interactive_configure_ui

    # Step 7: Localization
    step_header 7 $TOTAL "Finish"
    if confirm "Install localization?" "y"; then
        interactive_install_localization
    fi

    echo ""
    echo "  ${T_LABEL}╔══════════════════════════════════════════════════╗${NC}"
    echo "  ${T_LABEL}║            Setup Wizard Complete!                ║${NC}"
    echo "  ${T_LABEL}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  ${T_LABEL}Next steps from the menu:${NC}"
    echo "    1) Client config — set server IP address"
    echo "    2) Install mods — download and install mods"
    echo "    3) Launch client — run the game"
    echo ""
}

# ────────────────────────────────────────────────────────────
# Download backup — list via layer1 show-backups, prompt, call layer1 download
# ────────────────────────────────────────────────────────────
_interactive_download_backup() {
    local type="$1"
    local label="${type^}"

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Download $label Backup"
    echo "═══════════════════════════════════════════════"
    echo ""

    local json
    json=$(bash "$LAYER1_DIR/show-backups-${type}")
    if [[ -z "$json" ]]; then
        warn "No $label backups available on server."
        return
    fi

    local current_sha256
    current_sha256=$(echo "$json" | grep -o '"current":"[^"]*"' | head -1 | sed 's/"current":"//;s/"//')

    local names=() sha256s=()
    local files_part
    files_part=$(echo "$json" | grep -o '"files":\[.*\]' | sed 's/"files":\[//;s/\]$//')
    if [[ -z "$files_part" ]]; then
        warn "No $label backups available on server."
        return
    fi

    IFS="}" read -ra objects <<< "$files_part"
    for obj in "${objects[@]}"; do
        obj="${obj#\{}"
        obj="${obj#,}"
        obj="${obj%,}"
        obj="${obj%\]}"
        [[ -z "$obj" ]] && continue
        local name="" sha256=""
        if [[ "$obj" =~ \"name\":[[:space:]]*\"([^\"]+)\" ]]; then name="${BASH_REMATCH[1]}"; fi
        if [[ "$obj" =~ \"sha256\":[[:space:]]*\"([^\"]+)\" ]]; then sha256="${BASH_REMATCH[1]}"; fi
        [[ -z "$name" ]] && continue
        names+=("$name")
        sha256s+=("$sha256")
    done

    if [[ ${#names[@]} -eq 0 ]]; then
        warn "No $label backups available on server."
        return
    fi

    local i=1
    for name in "${names[@]}"; do
        local idx=$((i - 1))
        if [[ -n "$current_sha256" && "${sha256s[$idx]}" == "$current_sha256" ]]; then
            echo "  $i) $name  (current)"
        else
            echo "  $i) $name"
        fi
        ((i++)) || true
    done
    echo ""

    local choice
    read -r -p "  Select number (empty = cancel): " choice
    if [[ -z "$choice" ]]; then
        info "Cancelled."
        return
    fi

    local selected="${names[$((choice - 1))]}"
    if [[ -z "$selected" ]]; then
        err "Invalid selection."
        return
    fi

    echo ""
    info "Downloading $selected..."
    bash "$LAYER1_DIR/download-backup-${type}" "$selected" || { err "Download failed."; }
    ok "Done."
}

interactive_download_mods()    { _interactive_download_backup "mods"; }
interactive_download_players() { _interactive_download_backup "players"; }
interactive_download_world()   { _interactive_download_backup "world"; }
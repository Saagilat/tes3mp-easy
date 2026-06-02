#!/bin/bash
#
# client-configs.sh — configure TES3MP client (fonts, settings, server address)
#
# Provides:
#   - setup_fonts()           — copy example-settings.cfg for TrueType fonts
#   - set_server_address()    — set server IP in tes3mp-client-default.cfg
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before client-configs.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# setup_fonts — copy example-settings.cfg 
# ────────────────────────────────────────────────────────────
setup_fonts() {
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Font Configuration"
    echo "═══════════════════════════════════════════════"
    echo ""

    local settings_source
    settings_source=$(find_project_file "tools/example-settings.cfg" 2>/dev/null || echo "")

    if [[ -z "$settings_source" ]]; then
        err "Could not find tools/example-settings.cfg"
        err "Make sure you're running from the tes3mp-easy repository."
        return 1
    fi

    # Detect openmw-profile directory
    local openmw_profile=""
    if [[ -n "${OPENMW_CFG:-}" ]]; then
        openmw_profile="$(dirname "$OPENMW_CFG")"
    fi

    # Try common locations
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

    info "Detected OpenMW profile: $openmw_profile"

    local settings_dest="$openmw_profile/settings.cfg"

    if [[ -f "$settings_dest" ]]; then
        warn "settings.cfg already exists at $settings_dest"
        if ! confirm "Overwrite?"; then
            info "Skipping."
            return 0
        fi
    fi

    cp "$settings_source" "$settings_dest"
    ok "Copied settings.cfg to $settings_dest"
    echo ""
    echo "  The file includes TrueType font settings."
    echo "  Make sure you have TTF fonts installed in your openmw-profile:"
    echo "  https://www.nexusmods.com/morrowind/mods/46854"
    echo ""
}

# ────────────────────────────────────────────────────────────
# set_server_address — set server IP in tes3mp-client-default.cfg
# Usage: set_server_address <ip-or-host> [port]
# ────────────────────────────────────────────────────────────
set_server_address() {
    local server_addr="${1:-}"
    local server_port="${2:-25565}"

    # If no address provided, ask
    if [[ -z "$server_addr" ]]; then
        echo ""
        echo "═══════════════════════════════════════════════"
        echo "  Set Server Address"
        echo "═══════════════════════════════════════════════"
        echo ""
        read -r -p "Server IP or hostname: " server_addr
        read -r -p "Server port [default: 25565]: " server_port
        server_port="${server_port:-25565}"

        if [[ -z "$server_addr" ]]; then
            err "Server address is required."
            return 1
        fi
    fi

    # Locate tes3mp-client-default.cfg
    local client_cfg="${CLIENT_DEFAULT:-}"

    if [[ -z "$client_cfg" || ! -f "$client_cfg" ]]; then
        # Try to find it next to tes3mp.exe
        local tes3mp_dir="${TES3MP_INSTALL_DIR:-$HOME/morrowind/tes3mp}"
        if [[ -f "$tes3mp_dir/tes3mp-client-default.cfg" ]]; then
            client_cfg="$tes3mp_dir/tes3mp-client-default.cfg"
        else
            err "tes3mp-client-default.cfg not found."
            err "Set CLIENT_DEFAULT in config or provide the path."
            return 1
        fi
    fi

    info "Updating $client_cfg..."

    # Backup original
    cp "$client_cfg" "$client_cfg.backup.$(date +%s)"
    ok "Backup created"

    # Set destinationAddress
    if grep -qi "^destinationAddress" "$client_cfg" 2>/dev/null; then
        sed -i "s/^[[:space:]]*destinationAddress[[:space:]]*=.*/destinationAddress = $server_addr/i" "$client_cfg"
    else
        echo "destinationAddress = $server_addr" >> "$client_cfg"
    fi

    # Set destinationPort if not default
    if [[ "$server_port" != "25565" ]]; then
        if grep -qi "^destinationPort" "$client_cfg" 2>/dev/null; then
            sed -i "s/^[[:space:]]*destinationPort[[:space:]]*=.*/destinationPort = $server_port/i" "$client_cfg"
        else
            echo "destinationPort = $server_port" >> "$client_cfg"
        fi
    fi

    ok "Server address set to $server_addr${server_port:+:$server_port}"
}
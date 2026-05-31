#!/bin/bash
#
# config.sh — tes3mp-easy configuration (INI format)
#
# Two separate config files:
#   ~/.tes3mp-easy-admin.conf   — for admins
#   ~/.tes3mp-easy-player.conf  — for players
#
# Format:
#   ; comment
#   KEY = value
#
# Loaded via parse_ini (safe, no bash execution).
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before config.sh" >&2
    exit 1
fi

ADMIN_CONFIG="${HOME}/.tes3mp-easy-admin.conf"
PLAYER_CONFIG="${HOME}/.tes3mp-easy-player.conf"

# ────────────────────────────────────────────────────────────
# parse_ini — parse key=value from a file (safe, no source)
# Usage: parse_ini <file> [prefix]
# Sets variables like: KEY="value"
# ────────────────────────────────────────────────────────────
parse_ini() {
    local file="$1"
    local prefix="${2:-}"
    local key value

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    while IFS= read -r line; do
        # Strip whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip empty lines and comments
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[#;] ]] && continue
        # Skip section headers
        [[ "$line" =~ ^\[ ]] && continue

        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            # Strip quotes if present
            case "$value" in
                \"*\") value="${value#\"}"; value="${value%\"}" ;;
                \'*\') value="${value#\'}"; value="${value%\'}" ;;
            esac
            printf -v "${prefix}${key}" "%s" "$value"
        fi
    done < "$file"
}

# ────────────────────────────────────────────────────────────
# load_config — load config file into environment
# Usage: load_config [path]
# If no path given, tries admin, then player
# Returns 0 if loaded, 1 if missing
# ────────────────────────────────────────────────────────────
load_config() {
    local file="${1:-}"

    if [[ -z "$file" ]]; then
        if [[ -f "$ADMIN_CONFIG" ]]; then
            file="$ADMIN_CONFIG"
        elif [[ -f "$PLAYER_CONFIG" ]]; then
            file="$PLAYER_CONFIG"
        else
            return 1
        fi
    fi

    if parse_ini "$file"; then
        return 0
    fi
    return 1
}

# ────────────────────────────────────────────────────────────
# save_ini — write variables to an INI file
# Usage: save_ini <file> VAR1 VAR2 VAR3
# ────────────────────────────────────────────────────────────
save_ini() {
    local file="$1"
    shift
    local vars=("$@")
    local tmp_file
    tmp_file=$(mktemp)

    cat > "$tmp_file" << 'EOF'
# TES3MP Easy configuration
# This file is generated — edit with: nano ~/.tes3mp-easy-admin.conf
# or via the settings menu.

EOF

    for var in "${vars[@]}"; do
        local value="${!var:-}"
        echo "${var} = ${value}" >> "$tmp_file"
    done

    awk '!NF { if (++n <= 1) print; next } { n=0; print }' "$tmp_file" > "$file"
    rm -f "$tmp_file"
    chmod 600 "$file"
    ok "Configuration saved to $file"
}

# ────────────────────────────────────────────────────────────
# edit_config — open config in nano
# Usage: edit_config [file]
# ────────────────────────────────────────────────────────────
edit_config() {
    check_deps nano

    local file="${1:-}"
    if [[ -z "$file" ]]; then
        if [[ -f "$ADMIN_CONFIG" ]]; then
            file="$ADMIN_CONFIG"
        elif [[ -f "$PLAYER_CONFIG" ]]; then
            file="$PLAYER_CONFIG"
        else
            err "No config file found. Run install script first."
            return 1
        fi
    fi

    if [[ ! -f "$file" ]]; then
        err "Config file not found: $file"
        return 1
    fi
    nano "$file"
    ok "Config file saved."
}

# ────────────────────────────────────────────────────────────
# show_config — display current configuration
# Usage: show_config [file]
# ────────────────────────────────────────────────────────────
show_config() {
    local file="${1:-}"
    if [[ -z "$file" ]]; then
        file="$ADMIN_CONFIG"
        [[ -f "$file" ]] || file="$PLAYER_CONFIG"
    fi

    if [[ ! -f "$file" ]]; then
        warn "Config file not found."
        return 1
    fi

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  TES3MP Easy Configuration"
    echo "═══════════════════════════════════════════════"
    echo ""
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$line" || "$line" =~ ^[#;] || "$line" =~ ^\[ ]] && continue
        echo "  $line"
    done < "$file"
    echo ""
}

# ────────────────────────────────────────────────────────────
# select_language — let user pick a language
# ────────────────────────────────────────────────────────────
select_language() {
    local langs=($(lang_available 2>/dev/null))
    if [[ ${#langs[@]} -le 1 ]]; then
        LANG_CODE="en"
        return
    fi

    echo ""
    echo "--- Language / Язык ---"
    echo ""
    PS3="${LANG_SELECT:-Select language / Выберите язык: }"
    select l in "${langs[@]}"; do
        if [[ -n "$l" ]]; then
            LANG_CODE="$l"
            break
        fi
    done
    echo ""
}

# ────────────────────────────────────────────────────────────
# wizard_admin — interactive setup for admin
# ────────────────────────────────────────────────────────────
wizard_admin() {
    local first_run="${1:-false}"

    if [[ "$first_run" == "true" ]]; then
        echo ""
        echo "╔══════════════════════════════════════════════════╗"
        echo "║     ${WIZARD_ADMIN_WELCOME:-Welcome to TES3MP Easy! Admin profile — let's configure.}"
        echo "╚══════════════════════════════════════════════════╝"
        echo ""
    fi

    # Language selection
    select_language

    # SSH_HOST
    echo ""
    echo "${WIZARD_SSH_HOST:---- SSH Host ---}"
    echo ""
    read -r -p "${WIZARD_SSH_PROMPT:-SSH host: }" SSH_HOST
    SSH_HOST="${SSH_HOST:-}"
    if [[ -z "$SSH_HOST" ]]; then
        warn "${WIZARD_SSH_EMPTY:-SSH host is empty. You can set it later in the config.}"
    fi
    echo ""

    # PLUGINS_DIR
    local detected_mw
    detected_mw=$(detect_morrowind_path 2>/dev/null || echo "")
    local plugins_default=""
    detected_mw && plugins_default="$detected_mw/Data Files"

    echo "${WIZARD_PLUGINS:---- Plugins Directory ---}"
    echo ""
    read -r -p "${WIZARD_PLUGINS_PROMPT:-Plugins dir}${plugins_default:+ [$plugins_default]}: " input
    PLUGINS_DIR="${input:-$plugins_default}"
    PLUGINS_DIR="${PLUGINS_DIR:-}"
    echo ""

    # SERVER_SCRIPTS_DIR
    local scripts_default=""
    local candidates=("$PWD/mods/scripts" "$PWD/server/mods/scripts")
    for d in "${candidates[@]}"; do
        if [[ -d "$d" ]]; then
            scripts_default="$d"
            break
        fi
    done

    echo "${WIZARD_SCRIPTS:---- Server Scripts Directory ---}"
    echo ""
    read -r -p "${WIZARD_SCRIPTS_PROMPT:-Server scripts dir}${scripts_default:+ [$scripts_default]}: " input
    SERVER_SCRIPTS_DIR="${input:-$scripts_default}"
    SERVER_SCRIPTS_DIR="${SERVER_SCRIPTS_DIR:-}"

    # Save
    save_ini "$ADMIN_CONFIG" ROLE LANG_CODE SSH_HOST PLUGINS_DIR SERVER_SCRIPTS_DIR
    ok "${WIZARD_ADMIN_DONE:-Admin configuration saved.}"
    echo ""
}

# ────────────────────────────────────────────────────────────
# wizard_player — interactive setup for player
# ────────────────────────────────────────────────────────────
wizard_player() {
    local first_run="${1:-false}"

    if [[ "$first_run" == "true" ]]; then
        echo ""
        echo "╔══════════════════════════════════════════════════╗"
        echo "║     ${WIZARD_PLAYER_WELCOME:-Welcome to TES3MP Easy! Player profile — let's configure.}"
        echo "╚══════════════════════════════════════════════════╝"
        echo ""
    fi

    # Language selection
    local LANG_CODE="en"
    select_language

    # SERVER_URL
    echo "${WIZARD_SERVER_URL:---- Server URL ---}"
    echo ""
    read -r -p "${WIZARD_URL_PROMPT:-Server URL: }" SERVER_URL
    SERVER_URL="${SERVER_URL:-}"
    echo ""

    # DATA_FILES
    local detected_mw
    detected_mw=$(detect_morrowind_path 2>/dev/null || echo "")
    local data_default=""
    if [[ -n "$detected_mw" ]]; then
        data_default="$detected_mw/Data Files"
    fi

    echo "${WIZARD_DATA_FILES:---- Data Files Directory ---}"
    echo ""
    read -r -p "${WIZARD_DATA_PROMPT:-Data Files dir}${data_default:+ [$data_default]}: " input
    DATA_FILES="${input:-$data_default}"
    DATA_FILES="${DATA_FILES:-}"
    echo ""

    # OPENMW_CFG
    local openmw_default=""
    if is_os "linux"; then
        local steam_path
        steam_path=$(detect_steam_path 2>/dev/null || echo "")
        if [[ -n "$steam_path" ]]; then
            local compat_wizard
            compat_wizard=$(find "$steam_path/steamapps/compatdata" -maxdepth 2 -name "*.reg" -exec grep -l "openmw-wizard" {} \; 2>/dev/null | head -1)
            if [[ -n "$compat_wizard" ]]; then
                local compat_id
                compat_id=$(echo "$compat_wizard" | grep -oP 'compatdata/\K[0-9]+')
                if [[ -n "$compat_id" ]]; then
                    openmw_default="$HOME/.steam/steam/steamapps/compatdata/$compat_id/pfx/drive_c/users/steamuser/Documents/My Games/OpenMW/openmw.cfg"
                fi
            fi
        fi
    fi

    echo "${WIZARD_OPENMW:---- OpenMW Config ---}"
    echo ""
    read -r -p "${WIZARD_OPENMW_PROMPT:-openmw.cfg path}${openmw_default:+ [$openmw_default]}: " input
    OPENMW_CFG="${input:-$openmw_default}"
    OPENMW_CFG="${OPENMW_CFG:-}"
    echo ""

    # CLIENT_DEFAULT
    local client_default=""
    if is_os "linux"; then
        local steam_path
        steam_path=$(detect_steam_path 2>/dev/null || echo "")
        if [[ -n "$steam_path" ]]; then
            local compat_tes3mp
            compat_tes3mp=$(find "$steam_path/steamapps/compatdata" -maxdepth 2 -name "*.reg" -exec grep -l "tes3mp" {} \; 2>/dev/null | head -1)
            if [[ -n "$compat_tes3mp" ]]; then
                local compat_id
                compat_id=$(echo "$compat_tes3mp" | grep -oP 'compatdata/\K[0-9]+')
                if [[ -n "$compat_id" ]]; then
                    local tes3mp_dir
                    tes3mp_dir=$(find "$steam_path/steamapps/compatdata/$compat_id/pfx/drive_c" -name "tes3mp.exe" 2>/dev/null | head -1)
                    if [[ -n "$tes3mp_dir" ]]; then
                        client_default="$(dirname "$tes3mp_dir")/tes3mp-client-default.cfg"
                    fi
                fi
            fi
        fi
    fi

    echo "${WIZARD_CLIENT_CFG:---- TES3MP Client Config ---}"
    echo ""
    read -r -p "${WIZARD_CLIENT_PROMPT:-Client config path}${client_default:+ [$client_default]}: " input
    CLIENT_DEFAULT="${input:-$client_default}"
    CLIENT_DEFAULT="${CLIENT_DEFAULT:-}"

    save_ini "$PLAYER_CONFIG" ROLE LANG_CODE SERVER_URL DATA_FILES OPENMW_CFG CLIENT_DEFAULT
    ok "${WIZARD_PLAYER_DONE:-Player configuration saved.}"
    echo ""
}

# ────────────────────────────────────────────────────────────
# OS compatibility check
# ────────────────────────────────────────────────────────────
if is_os "windows"; then
    warn "Windows detected. Some features require Git Bash or WSL."
    warn "The menu uses 'select' which works in Git Bash."
fi
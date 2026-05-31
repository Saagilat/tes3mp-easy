#!/bin/bash
#
# config.sh — tes3mp-easy configuration (INI format)
#
# Two separate config files:
#   ~/.tes3mp-easy-admin.ini   — for admins
#   ~/.tes3mp-easy-player.ini  — for players
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

ADMIN_CONFIG="${HOME}/.tes3mp-easy-admin.ini"
PLAYER_CONFIG="${HOME}/.tes3mp-easy-player.ini"

# ────────────────────────────────────────────────────────────
# parse_ini — parse key=value from a file (safe, no source)
# Usage: parse_ini <file> [prefix]
# ────────────────────────────────────────────────────────────
parse_ini() {
    local file="$1"
    local prefix="${2:-}"
    local key value

    [[ -f "$file" ]] || return 1

    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* || "$line" == \;* ]] && continue
        [[ "$line" == \[* ]] && continue

        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
            key="${BASH_REMATCH[1]}"
            value="${BASH_REMATCH[2]}"
            case "$value" in
                \"*\") value="${value#\"}"; value="${value%\"}" ;;
                \'*\') value="${value#\'}"; value="${value%\'}" ;;
            esac
            printf -v "${prefix}${key}" "%s" "$value"
        fi
    done < "$file"
}

# ────────────────────────────────────────────────────────────
# load_config — load config file
# Usage: load_config [path]
# ────────────────────────────────────────────────────────────
load_config() {
    local file="${1:-}"
    [[ -n "$file" ]] || { [[ -f "$ADMIN_CONFIG" ]] && file="$ADMIN_CONFIG"; } || file="$PLAYER_CONFIG"
    [[ -f "$file" ]] || return 1
    parse_ini "$file"
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
# find_editor — detect available text editor
# Order: EDITOR env → VISUAL → EDITOR var → nano → vim → vi
# ────────────────────────────────────────────────────────────
find_editor() {
    # Check config variable first
    local cfg_editor="${EDITOR:-}"
    if [[ -n "$cfg_editor" ]] && command -v "$cfg_editor" &>/dev/null; then
        echo "$cfg_editor"
        return 0
    fi
    # Check environment
    for e in "$VISUAL" "$EDITOR" nano vim vi; do
        if [[ -n "$e" ]] && command -v "$e" &>/dev/null; then
            echo "$e"
            return 0
        fi
    done
    echo "vi"
}

# ────────────────────────────────────────────────────────────
# edit_config — open config in detected editor
# Usage: edit_config [file]
# ────────────────────────────────────────────────────────────
edit_config() {
    local file="${1:-}"
    if [[ -z "$file" ]]; then
        [[ -f "$ADMIN_CONFIG" ]] && file="$ADMIN_CONFIG" || file="$PLAYER_CONFIG"
    fi

    if [[ ! -f "$file" ]]; then
        err "Config file not found. Re-run the install script."
        return 1
    fi

    local editor
    editor=$(find_editor)
    info "Opening with: $editor"
    "$editor" "$file"
    ok "Config file saved."
}

# ────────────────────────────────────────────────────────────
# show_config — display current configuration
# Usage: show_config [file]
# ────────────────────────────────────────────────────────────
show_config() {
    local file="${1:-}"
    [[ -f "$file" ]] || file="$ADMIN_CONFIG"
    [[ -f "$file" ]] || file="$PLAYER_CONFIG"
    [[ -f "$file" ]] || { warn "Config file not found."; return 1; }

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  TES3MP Easy Configuration"
    echo "═══════════════════════════════════════════════"
    echo ""
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$line" || "$line" == \#* || "$line" == \;* || "$line" == \[* ]] && continue
        echo "  $line"
    done < "$file"
    echo ""
}

# ────────────────────────────────────────────────────────────
# OS compatibility check
# ────────────────────────────────────────────────────────────
if is_os "windows"; then
    warn "Windows detected. Some features require Git Bash or WSL."
    warn "The menu uses 'select' which works in Git Bash."
fi
#!/bin/bash
#
# menu-nav.sh — TUI menu navigation engine (pure bash, no whiptail)
#
# Provides:
#   run_menu()      — display an interactive menu (arrow keys via select)
#   reorder_list()  — reorder items (numbered checklist)
#
# Usage:
#   source "$(dirname "$0")/lib/menu-nav.sh"
#
#   main_menu=(
#     "START|fn|server_start"
#     "STOP|fn|server_stop"
#     "─|sep|"
#     "ADVANCED|menu|advanced_menu"
#     "BACK|back|"
#   )
#   run_menu "MY TITLE" "${main_menu[@]}"
#

[ -z "${LIB_DIR:-}" ] && LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 2>/dev/null || true

# ────────────────────────────────────────────────────────────
# Color definitions (self-contained, no dependency on common.sh)
# ────────────────────────────────────────────────────────────
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_CYAN='\033[0;36m'
readonly C_RED='\033[0;31m'
readonly C_NC='\033[0m'

# ────────────────────────────────────────────────────────────
# run_menu — display an interactive menu (arrow keys via select)
#
# Item format: "LABEL|type|action"
#   fn    — run bash function (in real terminal, no subshell)
#   menu  — open submenu (action = array name)
#   sep   — divider line (ignored)
#   back  — return to previous menu
# ────────────────────────────────────────────────────────────
run_menu() {
    local title="$1"
    shift
    local items=("$@")

    # Check needs_restart once per menu open — cached, no SSH on every render
    local restart_warn=""
    if [[ -n "${SSH_HOST:-}" ]]; then
        if ssh "$SSH_HOST" "test -f /tes3mp-easy/needs_restart.flag" 2>/dev/null; then
            restart_warn="[RESTART REQUIRED]"
        fi
    fi

    while true; do
        clear_screen
        print_header "$title"

        # Header line
        local header="${SSH_HOST:-<not set>}"
        [[ -n "$restart_warn" ]] && header="$restart_warn — $header"
        echo ""
        echo -e "  ${C_CYAN}${header}${C_NC}"
        echo ""

        # Build select options (skip separators)
        local -a options=()
        local -a indices=()
        local i
        for ((i=0; i<${#items[@]}; i++)); do
            local item="${items[$i]}"
            local label="${item%%|*}"
            local rest="${item#*|}"
            local type="${rest%%|*}"
            [[ "$type" == "sep" ]] && continue

            local display="$label"
            [[ "$type" == "menu" ]] && display="$label →"
            [[ "$type" == "back" ]] && display="← Back"

            options+=("$display")
            indices[${#options[@]}]=$i
        done

        local saved_ps3="$PS3"
        saved_columns="${COLUMNS:-80}"
        COLUMNS=1
        PS3="  → "

        select opt in "${options[@]}"; do
            COLUMNS="$saved_columns"
            # Empty = Ctrl+D / invalid — stay in select
            [[ -z "$opt" ]] && continue

            local sel_idx="${indices[$REPLY]:-}"
            if [[ -z "$sel_idx" ]]; then
                # Should not happen for valid indices, but safety check
                continue
            fi

            local sel_item="${items[$sel_idx]}"
            local sel_label="${sel_item%%|*}"
            local sel_rest="${sel_item#*|}"
            local sel_type="${sel_rest%%|*}"
            local sel_action="${sel_rest#*|}"

            case "$sel_type" in
                fn)
                    echo ""
                    # Run function directly in real terminal —
                    # no subshell capture, so ssh -t / nano etc work fine
                    "$sel_action"
                    echo ""
                    press_enter
                    # break from select → while loop continues → redraw
                    break
                    ;;
                menu)
                    local -a submenu=()
                    eval 'submenu=("${'"$sel_action"'[@]}")'
                    if [[ ${#submenu[@]} -gt 0 ]]; then
                        run_menu "$sel_label" "${submenu[@]}"
                    fi
                    # break from select → redraw
                    break
                    ;;
                back|"")
                    # break from select AND while loop → return to parent
                    PS3="$saved_ps3"
                    break 2
                    ;;
            esac
            break
        done

        PS3="$saved_ps3"
    done
}

# ────────────────────────────────────────────────────────────
# reorder_list — display numbered items for multi-select
# ────────────────────────────────────────────────────────────
reorder_list() {
    local title="$1"
    shift
    local -a items=("$@")

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  $title"
    echo "═══════════════════════════════════════════════"
    echo ""

    local i
    for ((i=0; i<${#items[@]}; i++)); do
        printf "  %2d) %s\n" $((i+1)) "${items[$i]}"
    done

    echo ""
    echo "  Enter numbers separated by space, or empty for all:"
    read -r -p "  > " raw_selection

    if [[ -z "$raw_selection" ]]; then
        local output=""
        for item in "${items[@]}"; do
            output="$output \"$item\""
        done
        echo "$output"
        return 0
    fi

    local -a selected=()
    for num in $raw_selection; do
        [[ "$num" =~ ^[0-9]+$ ]] || continue
        local idx=$((num - 1))
        [[ $idx -ge 0 && $idx -lt ${#items[@]} ]] || continue
        selected+=("${items[$idx]}")
    done

    if [[ ${#selected[@]} -eq 0 ]]; then
        echo "  No valid selection."
        return 1
    fi

    local output=""
    for item in "${selected[@]}"; do
        output="$output \"$item\""
    done
    echo "$output"
    return 0
}

# ────────────────────────────────────────────────────────────
# Screen utilities
# ────────────────────────────────────────────────────────────
clear_screen() { printf "\033c" 2>/dev/null || clear 2>/dev/null || true; }

print_header() {
    local title="$1" width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))
    local i
    echo ""
    printf "╔"
    for ((i=0; i<width; i++)); do printf "═"; done
    printf "╗\n"
    printf "║%*s %s %*s║\n" $padding "" "$title" $padding ""
    printf "╚"
    for ((i=0; i<width; i++)); do printf "═"; done
    printf "╝\n"
}
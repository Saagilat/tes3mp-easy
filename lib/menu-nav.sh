#!/bin/bash
#
# menu-nav.sh — TUI menu navigation engine using whiptail
#
# Provides:
#   run_menu()      — display an interactive menu
#   reorder_list()  — reorder items with whiptail
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
# run_menu — display an interactive menu
#
# Item format: "LABEL|type|action"
#   fn    — run bash function
#   menu  — open submenu (action = array name)
#   sep   — divider line (ignored)
#   back  — return to previous menu
# ────────────────────────────────────────────────────────────
run_menu() {
    local title="$1"
    shift
    local items=("$@")

    # Check needs_restart once
    local restart_warn=""
    if [[ -n "${SSH_HOST:-}" ]]; then
        if ssh "$SSH_HOST" "test -f /tes3mp-easy/needs_restart.flag" 2>/dev/null; then
            restart_warn="[RESTART REQUIRED]"
        fi
    fi

    while true; do
        # Build whiptail arguments dynamically
        local whiptail_items=()
        local indices=()
        local tag=1
        local i
        for ((i=0; i<${#items[@]}; i++)); do
            local item="${items[$i]}"
            local label="${item%%|*}"
            local rest="${item#*|}"
            local type="${rest%%|*}"
            [[ "$type" == "sep" ]] && continue
            indices[tag]=$i
            local display="$label"
            [[ "$type" == "menu" ]] && display="$label →"
            [[ "$type" == "back" ]] && display="← Back"
            whiptail_items+=("$tag" "$display")
            ((tag++))
        done

        local count=${#whiptail_items[@]}
        local height=$(( (count / 2) + 7 ))
        [[ "$height" -lt 10 ]] && height=10
        [[ "$height" -gt 25 ]] && height=25
        local width=65

        local header="${SSH_HOST:-<not set>}"
        [[ -n "$restart_warn" ]] && header="$restart_warn — $header"

        # Use positional parameters to pass items to whiptail
        local old_ifs="$IFS"
        IFS='|'
        # Build a string with | separator, then use eval to call whiptail
        IFS="$old_ifs"

        local choice
        choice=$(whiptail --title "$title" --menu "$header" \
            "$height" "$width" 0 \
            "${whiptail_items[@]}" \
            3>&1 1>&2 2>&3)
        local rc=$?

        # ESC/Cancel
        [[ $rc -ne 0 ]] && break

        # Resolve selected item
        local idx="${indices[$choice]}"
        local sel_item="${items[$idx]}"
        local sel_label="${sel_item%%|*}"
        local sel_rest="${sel_item#*|}"
        local sel_type="${sel_rest%%|*}"
        local sel_action="${sel_rest#*|}"

        case "$sel_type" in
            fn)
                clear
                if type "$sel_action" &>/dev/null 2>&1; then
                    "$sel_action"
                fi
                read -r -p "Press Enter to continue..." dummy 2>/dev/null || true
                clear
                ;;
            menu)
                local submenu=()
                eval 'submenu=("${'"$sel_action"'[@]}")'
                if [[ ${#submenu[@]} -gt 0 ]]; then
                    run_menu "$sel_label" "${submenu[@]}"
                fi
                ;;
            back|"")
                break
                ;;
        esac
    done
}

# ────────────────────────────────────────────────────────────
# reorder_list — display items in a checklist
# ────────────────────────────────────────────────────────────
reorder_list() {
    local title="$1"
    shift
    local items=("$@")

    local result
    result=$(whiptail --title "$title" --checklist \
        "SPACE toggle  ENTER confirm  ESC cancel" \
        20 60 10 \
        $(for i in "${!items[@]}"; do echo "$((i+1)) ${items[$i]} ON"; done) \
        3>&1 1>&2 2>&3)
    [[ $? -ne 0 ]] && return 1

    local output=""
    for item in "${items[@]}"; do
        output="$output \"$item\""
    done
    echo "$output"
    return 0
}

# ────────────────────────────────────────────────────────────
# Screen utilities (kept for compatibility)
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
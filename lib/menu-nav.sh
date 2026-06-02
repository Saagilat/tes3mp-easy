#!/bin/bash
#
# menu-nav.sh — TUI menu navigation engine (pure bash, no whiptail)
#
# Provides:
#   run_menu()      — display an interactive menu (arrow key navigation)
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
readonly C_BG_BLUE='\033[44m'
readonly C_NC='\033[0m'

# ────────────────────────────────────────────────────────────
# Key codes (for arrow key detection)
# ────────────────────────────────────────────────────────────
readonly KEY_UP=$'\e[A'
readonly KEY_DOWN=$'\e[B'
readonly KEY_ENTER=$'\n'
readonly KEY_ESC=$'\e'

# ────────────────────────────────────────────────────────────
# _draw_item — write a single item line at current cursor position
# $1 = index in vis_items
# $2 = 1 for highlighted, 0 for normal
# ────────────────────────────────────────────────────────────
_draw_item() {
    local idx="$1"
    local hl="$2"
    local num=$((idx + 1))
    local text="${M_items[$idx]}"
    printf "\r\033[K  "
    if [[ "$hl" == "1" ]]; then
        printf "${C_BG_BLUE}${C_YELLOW}%2d) %s${C_NC}" "$num" "$text"
    else
        printf "${C_GREEN}%2d)${C_NC} %s" "$num" "$text"
    fi
}

# ────────────────────────────────────────────────────────────
# _draw_all — full menu render from top
# Uses globals set up by run_menu: M_title, M_items, M_count, M_cursor
# ────────────────────────────────────────────────────────────
_draw_all() {
    clear_screen
    print_header "$M_title"

    local header="${SSH_HOST:-<not set>}"
    [[ -n "$M_restart" ]] && header="$M_restart — $header"
    echo ""
    echo -e "  ${C_CYAN}${header}${C_NC}"
    echo ""

    local j
    for ((j=0; j<M_count; j++)); do
        local hl=0
        [[ $j -eq $M_cursor ]] && hl=1
        _draw_item "$j" "$hl"
        echo ""
    done

    echo ""
    printf "  Arrow keys to move, Enter to select\n"
}

# ────────────────────────────────────────────────────────────
# run_menu — display an interactive menu (arrow key navigation)
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

    # Build visible items (skip separators), store index mapping
    local -a vis_items=()
    local -a vis_indices=()
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

        vis_items+=("$display")
        vis_indices+=($i)
    done

    # Make these available as pseudo-globals for _draw_item / _draw_all
    M_title="$title"
    M_items=("${vis_items[@]}")
    M_count=${#vis_items[@]}
    M_restart="$restart_warn"

    local vis_count=${#vis_items[@]}
    local cursor=0
    local first_pass=true

    # Lines below header for cursor arithmetic:
    # 1 blank line + 1 header + 1 blank line + vis_count items + 1 blank line + 1 hint = vis_count + 4
    # But we only need to move up from the bottom of the menu
    local menu_lines=$((vis_count + 2))  # items + blank + hint, excluding header area

    while true; do
        M_cursor=$cursor

        if $first_pass; then
            _draw_all
            first_pass=false
        else
            # Incremental update: move up to old cursor line,
            # redraw it as normal, then move to new cursor line,
            # redraw it as highlighted.

            # From the hint line (bottom of menu), move up to the correct lines
            # The hint is at line (vis_count + 1) below the blank after items.
            # Item 0 is at row 1 from top of item list.
            # From hint row, moving up: hint=1, blank=1, then items.
            # So up to old: (vis_count - old) + 1 (blank) + 1 (hint) = vis_count - old + 2
            local up_to_old=$((vis_count - prev_cursor + 2))
            printf "\033[%dA" "$up_to_old"
            _draw_item "$prev_cursor" "0"

            # Now move to new cursor line
            if [[ $prev_cursor -lt $cursor ]]; then
                # new is below old — move down
                local down=$((cursor - prev_cursor))
                printf "\033[%dB" "$down"
            else
                # new is above old — move up
                local up=$((prev_cursor - cursor))
                printf "\033[%dA" "$up"
            fi
            _draw_item "$cursor" "1"

            # Move cursor back to the prompt line (bottom of menu)
            local back_to_prompt=$((vis_count - cursor + 2))
            printf "\033[%dB" "$back_to_prompt"
            printf "\r\033[K  Arrow keys to move, Enter to select\n"
        fi

        # Read a single keypress
        local key
        IFS= read -s -n1 key 2>/dev/null || true

        # If it's an escape sequence, read two more bytes for arrow code
        if [[ "$key" == $KEY_ESC ]]; then
            local seq
            IFS= read -s -n2 -t 0.1 seq 2>/dev/null || true
            key="$key$seq"
        fi

        # If Enter (empty key)
        if [[ -z "$key" ]]; then
            key=$KEY_ENTER
        fi

        prev_cursor=$cursor

        case "$key" in
            $KEY_UP)
                cursor=$((cursor - 1))
                [[ $cursor -lt 0 ]] && cursor=$((vis_count - 1))
                ;;
            $KEY_DOWN)
                cursor=$((cursor + 1))
                [[ $cursor -ge $vis_count ]] && cursor=0
                ;;
            $KEY_ENTER|"")
                first_pass=true

                # Resolve selected item
                local sel_idx="${vis_indices[$cursor]}"
                local sel_item="${items[$sel_idx]}"
                local sel_label="${sel_item%%|*}"
                local sel_rest="${sel_item#*|}"
                local sel_type="${sel_rest%%|*}"
                local sel_action="${sel_rest#*|}"

                case "$sel_type" in
                    fn)
                        echo ""
                        # Run function directly in real terminal
                        "$sel_action"
                        echo ""
                        press_enter
                        ;;
                    menu)
                        local -a submenu=()
                        eval 'submenu=("${'"$sel_action"'[@]}")'
                        if [[ ${#submenu[@]} -gt 0 ]]; then
                            run_menu "$sel_label" "${submenu[@]}"
                        fi
                        ;;
                    back|"")
                        return 0
                        ;;
                esac
                ;;
            # Any other key — ignore (stay in menu)
        esac
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
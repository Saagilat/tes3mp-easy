#!/bin/bash
#
# menu-nav.sh — Arrow key menu navigation engine for bash
#
# Provides:
#   run_menu()      — render an interactive menu with arrow keys
#   reorder_list()  — reorder items with left/right arrows
#
# Usage:
#   source "$(dirname "$0")/lib/menu-nav.sh"
#
#   main_menu=(
#     "START SERVER|fn|server_start"
#     "STOP SERVER|fn|server_stop"
#     "━|sep|"
#     "ADVANCED|menu|advanced_menu"
#     "BACK|back|"
#   )
#   run_menu "MY TITLE" "${main_menu[@]}"
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before menu-nav.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# Internal: read a single keypress
# Returns: KEY_UP, KEY_DOWN, KEY_RIGHT, KEY_LEFT, KEY_ENTER,
#          KEY_Q, or raw character
# ────────────────────────────────────────────────────────────
_read_key() {
    # Save terminal settings — handle empty output from stty -g
    local old_settings
    old_settings=$(stty -g 2>/dev/null) || true
    if [[ -z "$old_settings" ]]; then
        old_settings="sane"
    fi

    # Restore terminal on exit
    trap 'stty "$old_settings" 2>/dev/null; stty echo 2>/dev/null || true' RETURN

    # Set raw mode — properly
    stty -icanon -echo min 1 time 0 2>/dev/null || true

    local char=""
    
    # Read one byte
    read -r -s -n1 char 2>/dev/null || true
    # Wait a tiny bit for more bytes (escape sequences)
    if [[ "$char" == $'\e' ]]; then
        local seq=""
        read -r -s -n1 -t 0.01 seq 2>/dev/null || true
        if [[ "$seq" == "[" ]]; then
            local dir=""
            read -r -s -n1 -t 0.01 dir 2>/dev/null || true
            case "$dir" in
                A) echo "KEY_UP" ;;
                B) echo "KEY_DOWN" ;;
                C) echo "KEY_RIGHT" ;;
                D) echo "KEY_LEFT" ;;
                *) echo "KEY_UNKNOWN" ;;
            esac
            return
        fi
        echo "KEY_UNKNOWN"
        return
    fi

    case "$char" in
        "")    echo "KEY_ENTER" ;;
        $'\n') echo "KEY_ENTER" ;;
        $'\r') echo "KEY_ENTER" ;;
        q|Q)   echo "KEY_Q" ;;
        *)     echo "$char" ;;
    esac
}

# ────────────────────────────────────────────────────────────
# run_menu — display an interactive menu
#
# Usage:
#   run_menu "TITLE" "ITEM1|type|action" "ITEM2|type|action" ...
#
# Item types:
#   fn    — run bash function (action = function name)
#   menu  — open submenu (action = array name with items)
#   sep   — divider line (label used as text)
#   back  — "go back" item
#
# Returns when user selects "back" or presses q.
# Selected action is executed by calling the function.
# ────────────────────────────────────────────────────────────
run_menu() {
    local title="$1"
    shift
    local items=("$@")
    local selected=0
    local key=""
    local running=true

    # Save terminal settings
    local old_settings
    old_settings=$(stty -g 2>/dev/null || echo "")

    while $running; do
        # Render menu
        clear_screen
        _render_menu "$title" "$selected" "${items[@]}"

        # Read key
        stty -icanon -echo 2>/dev/null || true
        key=$(_read_key)

        case "$key" in
            KEY_UP)
                local new_sel=$selected
                while [[ $new_sel -gt 0 ]]; do
                    new_sel=$((new_sel - 1))
                    local item_type="${items[$new_sel]#*|}"
                    item_type="${item_type%%|*}"
                    [[ "$item_type" != "sep" ]] && break
                done
                selected=$new_sel
                ;;
            KEY_DOWN)
                local new_sel=$selected
                while [[ $new_sel -lt $((${#items[@]} - 1)) ]]; do
                    new_sel=$((new_sel + 1))
                    local item_type="${items[$new_sel]#*|}"
                    item_type="${item_type%%|*}"
                    [[ "$item_type" != "sep" ]] && break
                done
                selected=$new_sel
                ;;
            KEY_RIGHT|KEY_ENTER)
                local item="${items[$selected]}"
                local label="${item%%|*}"
                local rest="${item#*|}"
                local item_type="${rest%%|*}"
                local action="${rest#*|}"

                case "$item_type" in
                    fn)
                        stty "$old_settings" 2>/dev/null || true
                        clear_screen
                        if type "$action" &>/dev/null 2>&1; then
                            "$action"
                        fi
                        stty "$old_settings" 2>/dev/null || true
                        # After function, wait for key then return to menu
                        echo ""
                        read -r -p "  Press Enter to continue..." dummy 2>/dev/null || true
                        ;;
                    menu)
                        stty "$old_settings" 2>/dev/null || true
                        _run_submenu "$title" "$label" "$action"
                        stty "$old_settings" 2>/dev/null || true
                        ;;
                    back|"")
                        running=false
                        ;;
                esac
                ;;
            KEY_LEFT)
                running=false
                ;;
            KEY_Q)
                running=false
                ;;
        esac
    done

    stty "$old_settings" 2>/dev/null || true
}

# ────────────────────────────────────────────────────────────
# _run_submenu — run a submenu defined by a variable name
# ────────────────────────────────────────────────────────────
_run_submenu() {
    local parent_title="$1"
    local menu_label="$2"
    local array_name="$3"

    # Get the array by name
    local submenu=()
    eval 'submenu=("${'"$array_name"'[@]}")'

    if [[ ${#submenu[@]} -eq 0 ]]; then
        err "Submenu '$menu_label' is empty or not found."
        press_enter
        return
    fi

    run_menu "$menu_label" "${submenu[@]}"
}

# ────────────────────────────────────────────────────────────
# _render_menu — draw the menu on screen
# ────────────────────────────────────────────────────────────
_render_menu() {
    local title="$1"
    local selected="$2"
    shift 2
    local items=("$@")

    # Header
    print_header "$title"

    # Info line
    local host_display="${SSH_HOST:-<not set>}"
    local modpack_display="${MODPACK_DIR:--}"
    echo "  HOST: $host_display"
    echo "  MODPACK: $modpack_display"
    echo ""

    # Check for needs_restart
    if [[ -n "${SSH_HOST:-}" ]]; then
        if ssh "$SSH_HOST" "test -f /tes3mp-easy/needs_restart.flag" 2>/dev/null; then
            echo -e "  ${RED}⚠ RESTART REQUIRED — USE RESTART TO APPLY${NC}"
            echo ""
        fi
    fi

    # Render items
    local idx=0
    for item in "${items[@]}"; do
        local label="${item%%|*}"
        local rest="${item#*|}"
        local item_type="${rest%%|*}"
        local item_action="${rest#*|}"

        local cursor="  "
        local prefix=""
        local suffix=""

        if [[ "$idx" -eq "$selected" ]]; then
            cursor="${GREEN}▸ ${NC}"
        fi

        case "$item_type" in
            sep)
                echo -e "  ${YELLOW}${label}${NC}"
                ;;
            menu)
                suffix=" →"
                if [[ "$idx" -eq "$selected" ]]; then
                    echo -e "  ${cursor}${label}${suffix}"
                else
                    echo -e "  ${cursor}${label}${suffix}"
                fi
                ;;
            back)
                echo "  ${cursor}${label}"
                ;;
            fn)
                echo -e "  ${cursor}${label}"
                ;;
        esac

        idx=$((idx + 1))
    done

    echo ""
    echo -e "  ${BLUE}↑/↓${NC} NAVIGATE  ${BLUE}→${NC} SELECT  ${BLUE}←${NC} BACK  ${BLUE}Q${NC} QUIT"
}

# ────────────────────────────────────────────────────────────
# reorder_list — interactive reordering of items
#
# Usage:
#   result=$(reorder_list "TITLE" "item1" "item2" ...)
#   eval "sorted=($result)"
#
# Controls:
#   ↑/↓ — move cursor
#   ←/→ — move item up/down one position
#   Enter — confirm
#   q — cancel (returns empty)
# ────────────────────────────────────────────────────────────
reorder_list() {
    local title="$1"
    shift
    local items=("$@")
    local selected=0
    local running=true

    local old_settings
    old_settings=$(stty -g 2>/dev/null || echo "")

    while $running; do
        # Render
        clear_screen
        echo ""
        echo "  ╔══════════════════════════════════════╗"
        printf "  ║  %-36s║\n" "$title"
        echo "  ╚══════════════════════════════════════╝"
        echo ""

        local idx=0
        for item in "${items[@]}"; do
            local num=$((idx + 1))
            if [[ "$idx" -eq "$selected" ]]; then
                echo -e "  ${GREEN}▸${NC} ${num}. ${item}"
            else
                echo "    ${num}. ${item}"
            fi
            idx=$((idx + 1))
        done

        echo ""
        echo -e "  ${BLUE}↑/↓${NC} NAVIGATE  ${BLUE}←/→${NC} MOVE  ${BLUE}ENTER${NC} CONFIRM  ${BLUE}Q${NC} CANCEL"

        # Read key
        stty -icanon -echo 2>/dev/null || true
        local key
        key=$(_read_key)

        case "$key" in
            KEY_UP)
                [[ $selected -gt 0 ]] && selected=$((selected - 1))
                ;;
            KEY_DOWN)
                [[ $selected -lt $((${#items[@]} - 1)) ]] && selected=$((selected + 1))
                ;;
            KEY_RIGHT)
                # Move item down (->)
                if [[ $selected -lt $((${#items[@]} - 1)) ]]; then
                    local tmp="${items[$selected]}"
                    items[$selected]="${items[$((selected + 1))]}"
                    items[$((selected + 1))]="$tmp"
                    selected=$((selected + 1))
                fi
                ;;
            KEY_LEFT)
                # Move item up (<-)
                if [[ $selected -gt 0 ]]; then
                    local tmp="${items[$selected]}"
                    items[$selected]="${items[$((selected - 1))]}"
                    items[$((selected - 1))]="$tmp"
                    selected=$((selected - 1))
                fi
                ;;
            KEY_ENTER)
                running=false
                stty "$old_settings" 2>/dev/null || true
                # Return the reordered list as quoted array
                local result=""
                for item in "${items[@]}"; do
                    result="$result \"$item\""
                done
                echo "$result"
                return 0
                ;;
            KEY_Q)
                running=false
                stty "$old_settings" 2>/dev/null || true
                return 1
                ;;
        esac
    done

    stty "$old_settings" 2>/dev/null || true
}

# ────────────────────────────────────────────────────────────
# Screen utilities (used by run_menu)
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

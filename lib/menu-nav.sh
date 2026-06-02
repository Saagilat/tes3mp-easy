#!/bin/bash
#
# menu-nav.sh — TUI menu navigation engine (pure bash, no whiptail)
#
# Provides:
#   run_menu() — flat interactive menu with section separators
#
# Item format:
#   "LABEL|fn|function_name"  — run bash function
#   "LABEL|sep|"              — section divider (label = section name)
#   "BACK|back|"              — exit menu
#
# Usage:
#   source lib/menu-nav.sh
#   run_menu "Title" "ssh_host" "modpack_dir" "needs_restart_flag" "${items[@]}"
#

[ -z "${LIB_DIR:-}" ] && LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 2>/dev/null || true

# ────────────────────────────────────────────────────────────
# Color definitions
# ────────────────────────────────────────────────────────────
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'
readonly C_REV='\033[7m'

readonly C_BLACK='\033[30m'
readonly C_RED='\033[31m'
readonly C_GREEN='\033[32m'
readonly C_YELLOW='\033[33m'
readonly C_BLUE='\033[34m'
readonly C_MAGENTA='\033[35m'
readonly C_CYAN='\033[36m'
readonly C_WHITE='\033[37m'
readonly C_GRAY='\033[90m'

readonly C_BG_BLUE='\033[44m'
readonly C_BG_CYAN='\033[46m'
readonly C_BG_GRAY='\033[100m'
readonly C_BG_WHITE='\033[107m'

# ────────────────────────────────────────────────────────────
# Key codes
# ────────────────────────────────────────────────────────────
readonly KEY_UP=$'\e[A'
readonly KEY_DOWN=$'\e[B'
readonly KEY_ENTER=$'\n'
readonly KEY_ESC=$'\e'

# ────────────────────────────────────────────────────────────
# print_boxed_header — draw fancy top header
# ────────────────────────────────────────────────────────────
print_boxed_header() {
    local title="$1"
    local width=64
    local title_len=${#title}
    local pad=$(( (width - title_len - 2) / 2 ))
    [[ $pad -lt 0 ]] && pad=0
    local right_pad=$((width - pad - title_len - 2))
    [[ $right_pad -lt 0 ]] && right_pad=0

    printf "\n"
    printf "${C_CYAN}╭"
    printf "─%.0s" $(seq 1 $width)
    printf "╮${C_RESET}\n"

    printf "${C_CYAN}│${C_RESET}"
    printf "%*s" $pad ""
    printf "${C_BOLD}${C_YELLOW} %s ${C_RESET}" "$title"
    printf "%*s" $right_pad ""
    printf "${C_CYAN}│${C_RESET}\n"

    printf "${C_CYAN}╰"
    printf "─%.0s" $(seq 1 $width)
    printf "╯${C_RESET}\n"
}

# ────────────────────────────────────────────────────────────
# run_menu — flat interactive menu with sections & info line
#
# Usage: run_menu "TITLE" "SSH_HOST" "MODPACK_DIR" "NEEDS_RESTART" item1 item2 ...
# ────────────────────────────────────────────────────────────
run_menu() {
    local menu_title="$1"
    shift
    local ssh_host="${1:-}"
    shift
    local modpack_dir="${1:-}"
    shift
    local needs_restart="${1:-}"
    shift
    local items=("$@")

    # Build visible arrays
    local -a v_labels=()
    local -a v_types=()
    local -a v_actions=()

    local i
    for ((i=0; i<${#items[@]}; i++)); do
        local item="${items[$i]}"
        local label="${item%%|*}"
        local rest="${item#*|}"
        local type="${rest%%|*}"
        local action="${rest#*|}"

        v_labels+=("$label")
        v_types+=("$type")
        v_actions+=("$action")
    done

    local count=${#v_labels[@]}
    local cursor=0

    # Count only selectable (fn) items for wrapping
    local fn_count=0
    for ((i=0; i<count; i++)); do
        [[ "${v_types[$i]}" == "fn" ]] && ((fn_count++))
    done

    # Build a mapping from fn-only index to actual index
    local -a fn_map=()
    for ((i=0; i<count; i++)); do
        [[ "${v_types[$i]}" == "fn" ]] && fn_map+=($i)
    done
    local fn_total=${#fn_map[@]}

    while true; do
        # Move to top, clear
        printf "\033[H\033[J"

        # ─── Header ───
        print_boxed_header "$menu_title"

        # Info line
        local info=""
        if [[ -n "$ssh_host" ]]; then
            info="${C_CYAN}Host:${C_RESET} ${C_BOLD}${ssh_host}${C_RESET}"
        fi
        if [[ -n "$modpack_dir" ]]; then
            [[ -n "$info" ]] && info="$info  "
            info="${info}${C_CYAN}Mods:${C_RESET} ${C_BOLD}${modpack_dir}${C_RESET}"
        fi
        if [[ "$needs_restart" == "1" ]]; then
            [[ -n "$info" ]] && info="$info  "
            info="${info}${C_RED}${C_BOLD}[!] Restart required${C_RESET}"
        fi
        if [[ -z "$info" ]]; then
            printf "${C_GRAY}  <not configured>${C_RESET}\n\n"
        else
            printf "  %s\n\n" "$info"
        fi

        # ─── Items ───
        for ((i=0; i<count; i++)); do
            local typ="${v_types[$i]}"
            local lbl="${v_labels[$i]}"

            if [[ "$typ" == "sep" ]]; then
                # Section divider
                printf "  ${C_GRAY}${C_DIM}─── ${lbl} ─────────────────────────────────────────────${C_RESET}\n"
            elif [[ "$typ" == "fn" ]]; then
                local num=$((i + 1))
                if [[ $i -eq $cursor ]]; then
                    printf "  ${C_BG_BLUE}${C_WHITE}${C_BOLD} %2d) %s${C_RESET}\n" "$num" "$lbl"
                else
                    printf "  ${C_GREEN}%2d)${C_RESET} %s\n" "$num" "$lbl"
                fi
            elif [[ "$typ" == "back" ]]; then
                if [[ $i -eq $cursor ]]; then
                    printf "  ${C_BG_BLUE}${C_WHITE}${C_BOLD}   %s${C_RESET}\n" "$lbl"
                else
                    printf "  ${C_GRAY}%s${C_RESET}\n" "$lbl"
                fi
            fi
        done

        printf "\n  ${C_DIM}${C_GRAY}↑↓ navigate  Enter select  q/ESC exit${C_RESET}\n"

        # ─── Key input ───
        local key
        IFS= read -s -n1 key 2>/dev/null || true

        if [[ "$key" == $KEY_ESC ]]; then
            local seq
            IFS= read -s -n2 -t 0.1 seq 2>/dev/null || true
            key="$key$seq"
        fi
        if [[ -z "$key" ]]; then
            key=$KEY_ENTER
        fi

        case "$key" in
            $KEY_UP|k|K)
                # Move to previous fn item
                if [[ $fn_total -gt 0 ]]; then
                    local cur_fn_idx=0
                    for ((i=0; i<fn_total; i++)); do
                        if [[ ${fn_map[$i]} -eq $cursor ]]; then
                            cur_fn_idx=$i
                            break
                        fi
                    done
                    cur_fn_idx=$((cur_fn_idx - 1))
                    [[ $cur_fn_idx -lt 0 ]] && cur_fn_idx=$((fn_total - 1))
                    cursor=${fn_map[$cur_fn_idx]}
                fi
                ;;
            $KEY_DOWN|j|J)
                # Move to next fn item
                if [[ $fn_total -gt 0 ]]; then
                    local cur_fn_idx=0
                    for ((i=0; i<fn_total; i++)); do
                        if [[ ${fn_map[$i]} -eq $cursor ]]; then
                            cur_fn_idx=$i
                            break
                        fi
                    done
                    cur_fn_idx=$((cur_fn_idx + 1))
                    [[ $cur_fn_idx -ge $fn_total ]] && cur_fn_idx=0
                    cursor=${fn_map[$cur_fn_idx]}
                fi
                ;;
            q|Q)
                return 0
                ;;
            $KEY_ENTER|"")
                local typ="${v_types[$cursor]}"
                local action="${v_actions[$cursor]}"

                if [[ "$typ" == "fn" ]]; then
                    echo ""
                    # Run the function
                    "$action"
                    echo ""
                    press_enter

                    # After any fn, refresh needs_restart from server
                    if [[ -n "$ssh_host" ]]; then
                        if ssh "$ssh_host" "test -f /tes3mp-easy/needs_restart.flag" 2>/dev/null; then
                            needs_restart="1"
                        else
                            needs_restart=""
                        fi
                    fi

                elif [[ "$typ" == "back" ]]; then
                    return 0
                fi
                ;;
        esac
    done
}
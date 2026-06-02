#!/bin/bash
#
# menu-nav.sh — TUI menu navigation engine (pure bash, no whiptail)
#
# Provides:
#   run_menu() — flat interactive menu with section separators
#

[ -z "${LIB_DIR:-}" ] && LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" 2>/dev/null || true

# ────────────────────────────────────────────────────────────
# Color definitions (ANSI-C quoted $'...' — contains real ESC byte)
# ────────────────────────────────────────────────────────────
readonly C_RESET=$'\033[0m'
readonly C_BOLD=$'\033[1m'

readonly C_RED=$'\033[31m'
readonly C_GREEN=$'\033[32m'
readonly C_YELLOW=$'\033[33m'
readonly C_CYAN=$'\033[36m'
readonly C_WHITE=$'\033[37m'
readonly C_GRAY=$'\033[90m'

readonly C_BG_BLUE=$'\033[44m'

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

    local line
    printf -v line "%64s" ""
    line="${line// /─}"

    printf "\n${C_CYAN}╭${line}╮${C_RESET}\n"
    printf "${C_CYAN}│${C_RESET}%*s${C_BOLD}${C_YELLOW} %s ${C_RESET}%*s${C_CYAN}│${C_RESET}\n" \
        $(( (width - title_len - 2) / 2 )) "" \
        "$title" \
        $(( width - (width - title_len - 2) / 2 - title_len - 2 )) ""
    printf "${C_CYAN}╰${line}╯${C_RESET}\n"
}

# ────────────────────────────────────────────────────────────
# run_menu — flat interactive menu with sections & info line
#
# Usage: run_menu "TITLE" "SSH_HOST" "MODPACK_DIR" "NEEDS_RESTART" item1 item2 ...
#   After each fn action, the function source() the config to refresh
#   ssh_host and modpack_dir from CONFIG_FILE.
# ────────────────────────────────────────────────────────────
run_menu() {
    local menu_title="$1"
    shift
    local ssh_host_def="${1:-}"
    shift
    local modpack_dir_def="${1:-}"
    shift
    local config_file="${1:-}"
    shift
    local needs_restart="${1:-}"
    shift
    local items=("$@")

    local ssh_host="$ssh_host_def"
    local modpack="$modpack_dir_def"

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
        local info_parts=""
        if [[ -n "$ssh_host" ]]; then
            info_parts="${C_CYAN}Host:${C_RESET} ${C_BOLD}${ssh_host}${C_RESET}"
        fi
        if [[ -n "$modpack" ]]; then
            [[ -n "$info_parts" ]] && info_parts="${info_parts}  "
            info_parts="${info_parts}${C_CYAN}Mods:${C_RESET} ${C_BOLD}${modpack}${C_RESET}"
        fi
        if [[ "$needs_restart" == "1" ]]; then
            [[ -n "$info_parts" ]] && info_parts="${info_parts}  "
            info_parts="${info_parts}${C_RED}${C_BOLD}[!] Restart required${C_RESET}"
        fi
        if [[ -z "$info_parts" ]]; then
            printf "${C_GRAY}  <not configured>${C_RESET}\n\n"
        else
            printf "  ${info_parts}\n\n"
        fi

        # ─── Items ───
        for ((i=0; i<count; i++)); do
            local typ="${v_types[$i]}"
            local lbl="${v_labels[$i]}"

            if [[ "$typ" == "sep" ]]; then
                # Section divider — bright cyan, no dim
                printf "  ${C_CYAN}${C_BOLD}─── ${lbl} ───────────────────────────────────────${C_RESET}\n"
            elif [[ "$typ" == "fn" ]]; then
                local num=$((i + 1))
                if [[ $i -eq $cursor ]]; then
                    printf "  ${C_BG_BLUE}${C_WHITE}${C_BOLD} %2d) %s${C_RESET}\n" "$num" "$lbl"
                else
                    printf "  ${C_GREEN}%2d)${C_RESET} %s\n" "$num" "$lbl"
                fi
            fi
        done

        printf "\n  ${C_WHITE}↑↓ navigate · Enter select · q/ESC exit${C_RESET}\n"

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

                    # After any fn action — refresh config and restart flag
                    if [[ -n "$config_file" && -f "$config_file" ]]; then
                        source "$config_file" 2>/dev/null || true
                        ssh_host="${SSH_HOST:-}"
                        modpack="${MODPACK_DIR:-}"
                    fi
                    if [[ -n "$ssh_host" ]]; then
                        if ssh "$ssh_host" "test -f /tes3mp-easy/needs_restart.flag" 2>/dev/null; then
                            needs_restart="1"
                        else
                            needs_restart=""
                        fi
                    fi
                fi
                ;;
        esac
    done
}
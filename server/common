#!/bin/bash
#
# common.sh — shared functions for TES3MP server scripts
#
# Source this file at the top of any script in server/scripts/.
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$(dirname "$SCRIPT_DIR")/common.sh"
#
# Provides:
#   - Colors and logging (info, ok, warn, err, fatal)
#   - read_input()     — interactive input (handles pipe, SSH -t, direct)
#   - confirm()        — yes/no prompt via read_input
#   - check_root()     — exit if not root
#

# ────────────────────────────────────────────────────────────
# Guard — prevent double-sourcing
# ────────────────────────────────────────────────────────────
if [[ -n "${TES3MP_COMMON_SOURCED:-}" ]]; then
    return 0
fi
TES3MP_COMMON_SOURCED=1

# ────────────────────────────────────────────────────────────
# Colors
# ────────────────────────────────────────────────────────────
RED='\033[0;31m'
BOLD_RED='\033[1;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ────────────────────────────────────────────────────────────
# Logging
# ────────────────────────────────────────────────────────────
info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()     { echo -e "${RED}[ERROR]${NC} $*" >&2; }
fatal()   { echo -e "${BOLD_RED}⚠ $* ⚠${NC}"; }

# ────────────────────────────────────────────────────────────
# check_root — exit if not root
# ────────────────────────────────────────────────────────────
check_root() {
    if [[ $EUID -ne 0 ]]; then
        err "This script must be run as root (or via sudo)."
        exit 1
    fi
}

# ────────────────────────────────────────────────────────────
# read_input — portable interactive input
#
# Reads from /dev/tty if available (works with SSH -t and
# curl ... | bash), otherwise falls back to stdin.
# Exits with error if neither is available.
#
# Usage:
#   read_input "Prompt: " MY_VAR "default_value"
#
# Sets MY_VAR to the user's input, or to "default_value" if
# the user pressed Enter with an empty input.
# ────────────────────────────────────────────────────────────
read_input() {
    local prompt="$1"
    local var_name="$2"
    local default_value="${3:-}"

    local input=""

    # Try /dev/tty first (works with SSH -t, curl | bash)
    if [[ -c /dev/tty ]]; then
        read -r -p "$prompt" input </dev/tty || true
    # Fallback to stdin (works when run directly)
    elif [[ -t 0 ]]; then
        read -r -p "$prompt" input || true
    else
        echo ""
        err "Interactive input required but no TTY available."
        err "Run with SSH -t, or use non-interactive mode if available."
        return 1
    fi

    printf -v "$var_name" "%s" "${input:-$default_value}"
}

# ────────────────────────────────────────────────────────────
# confirm — yes/no prompt via read_input
#
# Returns: 0 if yes, 1 if no
# Usage:
#   confirm "Continue?" && do_something
# ────────────────────────────────────────────────────────────
confirm() {
    local prompt="${1:-Are you sure?}"
    local response=""

    read_input "$prompt [y/N]: " response "n"
    case "${response,,}" in
        y|yes) return 0 ;;
        *)     return 1 ;;
    esac
}
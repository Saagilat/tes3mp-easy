#!/bin/bash
#
# configure.sh — wrapper that runs all configuration steps
#
# Delegates to:
#   configure-basic.sh  — server name, password, port, endpoints, container
#   configure-lua.sh    — config.lua settings
#
# Usage:
#   bash configure.sh               # interactive
#   bash configure.sh --default     # non-interactive with defaults
#   bash configure.sh --test        # test mode
#   bash configure.sh --help        # show help
#

set -euo pipefail

# ────────────────────────────────────────────────────────────
# Source shared library (installed at /tes3mp-easy by install.sh)
# ────────────────────────────────────────────────────────────
source /tes3mp-easy/common.sh
DEST="/tes3mp-easy"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--default | --test]

Runs all configuration steps in order:
  configure-basic.sh   — server name, password, port, endpoints
  configure-lua.sh     — config.lua (sharing, collisions, time, etc.)

Options:
  --default   Non-interactive with all default values.
  --test      Like --default but password=1234, all endpoints.
  --help      Show this help message.
EOF
}

main() {
    local args=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --default|--test) args="$1"; shift ;;
            --help) usage; exit 0 ;;
            *) err "Unknown option: $1"; usage; exit 1 ;;
        esac
    done

    if [[ ! -d "$DEST" ]]; then
        err "$DEST does not exist. Run install.sh first."
        exit 1
    fi

    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   TES3MP Server Configuration        ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    # Run sub-scripts
    local scripts_dir="$DEST/scripts"

    if [[ -f "$scripts_dir/configure-basic.sh" ]]; then
        bash "$scripts_dir/configure-basic.sh" $args || {
            err "configure-basic.sh failed."
            exit 1
        }
    else
        warn "configure-basic.sh not found — skipping."
    fi

    if [[ -f "$scripts_dir/configure-lua.sh" ]]; then
        bash "$scripts_dir/configure-lua.sh" $args || {
            err "configure-lua.sh failed."
            exit 1
        }
    else
        warn "configure-lua.sh not found — skipping."
    fi
}

main "$@"

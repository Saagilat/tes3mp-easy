#!/bin/bash
#
# server-control.sh — start, stop, restart, logs for TES3MP server
#
# Provides:
#   - server_start()
#   - server_stop()
#   - server_restart()
#   - server_logs()
#   - server_status()
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before server-control.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# Helper: check SSH_HOST
# ────────────────────────────────────────────────────────────
require_ssh_host() {
    if [[ -z "${SSH_HOST:-}" ]]; then
        err "SSH_HOST is not set."
        err "Run './tes3mp-easy config' to set it."
        return 1
    fi
}

# ────────────────────────────────────────────────────────────
# Helper: run docker compose command
# ────────────────────────────────────────────────────────────
docker_compose() {
    local action="$1"
    local tty_flag="${2:-}"
    local cmd="cd /tes3mp-easy && docker compose $action"

    echo ""
    info "Running on $SSH_HOST: $cmd"
    echo ""

    if [[ -n "$tty_flag" ]]; then
        ssh -t "$SSH_HOST" "$cmd"
    else
        ssh "$SSH_HOST" "$cmd"
    fi
}

# ────────────────────────────────────────────────────────────
# server_start — start TES3MP containers
# ────────────────────────────────────────────────────────────
server_start() {
    require_ssh_host || return 1
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Starting TES3MP Server"
    echo "═══════════════════════════════════════════════"
    echo ""
    docker_compose "up -d"
    ok "Server started on $SSH_HOST"
}

# ────────────────────────────────────────────────────────────
# server_stop — stop TES3MP containers
# ────────────────────────────────────────────────────────────
server_stop() {
    require_ssh_host || return 1
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Stopping TES3MP Server"
    echo "═══════════════════════════════════════════════"
    echo ""
    docker_compose "down"
    ok "Server stopped on $SSH_HOST"
}

# ────────────────────────────────────────────────────────────
# server_restart — restart TES3MP containers
# ────────────────────────────────────────────────────────────
server_restart() {
    require_ssh_host || return 1
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Restarting TES3MP Server"
    echo "═══════════════════════════════════════════════"
    echo ""
    docker_compose "restart"
    ok "Server restarted on $SSH_HOST"
}

# ────────────────────────────────────────────────────────────
# server_logs — follow TES3MP container logs
# ────────────────────────────────────────────────────────────
server_logs() {
    require_ssh_host || return 1
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  TES3MP Server Logs (press Ctrl+C to stop)"
    echo "═══════════════════════════════════════════════"
    echo ""
    info "Connecting to $SSH_HOST..."
    echo ""
    docker_compose "logs -f" "-t"
}

# ────────────────────────────────────────────────────────────
# server_status — show container status
# ────────────────────────────────────────────────────────────
server_status() {
    require_ssh_host || return 1
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  TES3MP Server Status"
    echo "═══════════════════════════════════════════════"
    echo ""
    docker_compose "ps"
}
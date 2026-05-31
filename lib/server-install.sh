#!/bin/bash
#
# server-install.sh — install and configure TES3MP server on VPS
#
# Provides:
#   - install_server()      — run install.sh on remote VPS
#   - configure_server()    — run configure.sh on remote VPS
#

# ────────────────────────────────────────────────────────────
# Guard
# ────────────────────────────────────────────────────────────
if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before server-install.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# install_server — run install.sh on remote host via SSH
# Usage: install_server [--default | --test]
# ────────────────────────────────────────────────────────────
install_server() {
    local mode="${1:-interactive}"

    if [[ -z "${SSH_HOST:-}" ]]; then
        err "SSH_HOST is not set."
        err "Run './tes3mp-easy config' to set it."
        return 1
    fi

    # Determine install flags
    local install_flags=""
    case "$mode" in
        --default) install_flags="--default" ;;
        --test)    install_flags="--test" ;;
    esac

    # Construct the install command
    local install_url="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server/scripts/install.sh"
    local cmd="curl -fsSL '$install_url' | bash${install_flags:+ -s -- $install_flags}"

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  TES3MP Server Installation"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  This will install TES3MP server on: $SSH_HOST"
    echo ""
    echo "  Command:"
    echo "    ssh $SSH_HOST \"$cmd\""
    echo ""
    echo "  What it does:"
    echo "    - Installs Docker and docker compose plugin"
    echo "    - Installs system utilities (nano, rhash, tar, zip)"
    echo "    - Downloads TES3MP server files"
    echo "    - Builds the Docker image"
    echo "    - Runs configuration (interactive or automated)"
    echo ""

    if [[ "$mode" == "interactive" ]]; then
        info "Running in INTERACTIVE mode."
        info "Make sure your SSH connection supports TTY (-t flag)."
        echo ""
    else
        info "Running in NON-INTERACTIVE mode (--default or --test)."
        echo ""
    fi

    # Confirm
    if ! confirm "Proceed with installation?"; then
        info "Installation cancelled."
        return 0
    fi

    echo ""

    # Run the install
    if [[ "$mode" == "interactive" ]]; then
        # Interactive: need -t flag for TTY
        info "Starting interactive installation (SSH -t)..."
        ssh -t "$SSH_HOST" "$cmd" || {
            err "Installation failed on $SSH_HOST"
            err "Check the output above for details."
            return 1
        }
    else
        # Non-interactive
        info "Starting non-interactive installation..."
        ssh "$SSH_HOST" "$cmd" || {
            err "Installation failed on $SSH_HOST"
            err "Check the output above for details."
            return 1
        }
    fi

    ok "TES3MP server installation completed on $SSH_HOST"
    echo ""
    info "Next steps:"
    info "  1. If not already done, the configure.sh script should have run."
    info "  2. You can reconfigure later with:  ./tes3mp-easy configure-server"
    info "  3. Add your mods with:              ./tes3mp-easy export-mods"
    echo ""
}

# ────────────────────────────────────────────────────────────
# configure_server — re-run configure.sh on remote VPS
# Usage: configure_server [--default | --test]
# ────────────────────────────────────────────────────────────
configure_server() {
    local mode="${1:-interactive}"

    if [[ -z "${SSH_HOST:-}" ]]; then
        err "SSH_HOST is not set."
        err "Run './tes3mp-easy config' to set it."
        return 1
    fi

    local configure_flags=""
    case "$mode" in
        --default) configure_flags="--default" ;;
        --test)    configure_flags="--test" ;;
    esac

    local cmd="bash /tes3mp-easy/scripts/configure.sh${configure_flags:+ $configure_flags}"

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  TES3MP Server Reconfiguration"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  This will reconfigure the TES3MP server on: $SSH_HOST"
    echo ""
    echo "  Command:"
    echo "    ssh $SSH_HOST \"$cmd\""
    echo ""
    echo "  What it does:"
    echo "    - Asks (or uses defaults for) server name, password, ports"
    echo "    - Configures Lua settings (sharing, permissions, collisions, etc.)"
    echo "    - Configures nginx and docker-compose for endpoints"
    echo "    - Configures firewall"
    echo "    - Restarts containers and creates init backups"
    echo ""
    info "Note: Existing player/world/mod data will NOT be lost."
    echo ""

    if [[ "$mode" == "interactive" ]]; then
        info "Running in INTERACTIVE mode."
        echo ""
    else
        info "Running in NON-INTERACTIVE mode (--default or --test)."
        echo ""
    fi

    if ! confirm "Proceed with reconfiguration?"; then
        info "Reconfiguration cancelled."
        return 0
    fi

    echo ""

    if [[ "$mode" == "interactive" ]]; then
        ssh -t "$SSH_HOST" "$cmd" || {
            err "Reconfiguration failed on $SSH_HOST"
            return 1
        }
    else
        ssh "$SSH_HOST" "$cmd" || {
            err "Reconfiguration failed on $SSH_HOST"
            return 1
        }
    fi

    ok "TES3MP server reconfiguration completed on $SSH_HOST"
}
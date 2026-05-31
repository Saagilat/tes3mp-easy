#!/bin/bash
#
# uninstall.sh — completely remove TES3MP server from VPS
#
# Removes:
#   - Docker containers, images, volumes for TES3MP
#   - All server files at /tes3mp-easy
#   - Optionally removes firewall rules
#
# Does NOT remove:
#   - Docker engine
#   - System packages (nano, rhash, tar, zip, etc.)
#   - SSH users or keys
#
# Usage:
#   bash uninstall.sh          # interactive with warnings
#

set -euo pipefail

# ────────────────────────────────────────────────────────────
# Colors (inline — works when piped via curl | bash)
# ────────────────────────────────────────────────────────────
RED='\033[0;31m'
BOLD_RED='\033[1;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()     { echo -e "${RED}[ERROR]${NC} $*" >&2; }
fatal()   { echo -e "${BOLD_RED}⚠ $* ⚠${NC}"; }

# ────────────────────────────────────────────────────────────
# Root check
# ────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (or via sudo)."
    exit 1
fi

DEST="/tes3mp-easy"

# ────────────────────────────────────────────────────────────
# Try to source common.sh (may not exist on first install)
# Falls back to inline functions if not found
# ────────────────────────────────────────────────────────────
if [[ -f "$DEST/common.sh" ]]; then
    source "$DEST/common.sh"
else
    # Inline read_input fallback
    read_input() {
        local prompt="$1"
        local var_name="$2"
        local default_value="${3:-}"
        local input=""

        if [[ -c /dev/tty ]]; then
            read -r -p "$prompt" input </dev/tty 2>/dev/null || true
        elif [[ -t 0 ]]; then
            read -r -p "$prompt" input 2>/dev/null || true
        else
            echo ""
            err "Interactive input required but no TTY available."
            err "Run with SSH -t, or use non-interactive mode if available."
            return 1
        fi

        printf -v "$var_name" "%s" "${input:-$default_value}"
    }

    # Inline confirm fallback
    confirm() {
        local prompt="${1:-Are you sure?}"
        local response=""

        read_input "$prompt [y/N]: " response "n"
        case "${response,,}" in
            y|yes) return 0 ;;
            *)     return 1 ;;
        esac
    }
fi

# ────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────
main() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║          TES3MP SERVER — FULL UNINSTALL                  ║"
    echo "║                                                          ║"
    echo "║  ${BOLD_RED}⚠  ALL SERVER DATA WILL BE PERMANENTLY DESTROYED  ║${NC}"
    echo "║                                                          ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo ""

    # Check if installed
    if [[ ! -d "$DEST" ]]; then
        info "TES3MP server is not installed ($DEST does not exist). Nothing to uninstall."
        exit 0
    fi

    # ── Step 1: Show what will be deleted ──
    fatal "The following will be PERMANENTLY DELETED:"
    echo ""
    echo "  📁  $DEST/players/        — ALL player saves (characters, inventories)"
    echo "  📁  $DEST/world/          — ALL world data (cells, map, records, custom)"
    echo "  📁  $DEST/mods/           — ALL uploaded mods (plugins and scripts)"
    echo "  📁  $DEST/configs/        — ALL server configs (tes3mp-server-default.cfg, config.lua)"
    echo "  📁  $DEST/backups/        — ALL backup archives"
    echo "  🐳  Docker containers     — tes3mp, nginx containers (and their images)"
    echo "  🔥  Firewall rules        — udp/25565, tcp/8085 (if you choose)"
    echo ""
    fatal "This action CANNOT be undone."
    echo ""
    fatal "System dependencies (Docker engine, nano, rhash, etc.) will NOT be removed."

    # ── Step 2: Offer data export ──
    echo ""
    echo "──────────────────────────────────────────────"
    echo "  Would you like to BACKUP your data first?"
    echo "──────────────────────────────────────────────"
    echo ""

    # Export players
    if [[ -d "$DEST/players" ]] && ls "$DEST/players/"*.json &>/dev/null 2>&1; then
        if confirm "Export player data before removal?"; then
            info "Exporting players..."
            bash "$DEST/scripts/deploy_players.sh" --latest 2>/dev/null && \
                ok "Players exported." || warn "Player export had issues."
        fi
    fi

    # Export world
    if [[ -d "$DEST/world" ]] && ls "$DEST/world/"*/*.json &>/dev/null 2>&1; then
        if confirm "Export world data before removal?"; then
            info "Exporting world..."
            bash "$DEST/scripts/deploy_world.sh" --latest 2>/dev/null && \
                ok "World exported." || warn "World export had issues."
        fi
    fi

    # Export mods
    if [[ -d "$DEST/mods/plugins" ]] || [[ -d "$DEST/mods/scripts" ]]; then
        if confirm "Export mods before removal?"; then
            info "Exporting mods..."
            bash "$DEST/scripts/deploy_mods.sh" --latest 2>/dev/null && \
                ok "Mods exported." || warn "Mods export had issues."
        fi
    fi

    # ── Step 3: Double confirmation ──
    echo ""
    fatal "Are you absolutely sure?"
    fatal "All TES3MP server data will be DESTROYED."
    echo ""

    local confirm_word=""
    read_input "Type YES (uppercase) to confirm: " confirm_word ""
    if [[ "$confirm_word" != "YES" ]]; then
        echo ""
        info "Uninstall cancelled."
        exit 0
    fi

    # ── Step 4: Stop and remove Docker resources ──
    echo ""
    info "Stopping and removing Docker containers, volumes, and images..."
    if [[ -f "$DEST/docker-compose.yml" ]]; then
        cd "$DEST"
        docker compose down -v --rmi all 2>/dev/null || true
        ok "Docker containers, volumes, and images removed."
    else
        warn "docker-compose.yml not found — skipping Docker cleanup."
    fi

    # ── Step 5: Remove all files ──
    info "Removing $DEST..."
    rm -rf "$DEST"
    ok "All TES3MP server files removed."

    # ── Step 6: Optional firewall cleanup ──
    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "active"; then
        echo ""
        if confirm "Remove TES3MP ports (25565/udp, 8085/tcp) from UFW?"; then
            ufw delete allow 25565/udp 2>/dev/null || true
            ufw delete allow 8085/tcp 2>/dev/null || true
            ok "UFW rules for TES3MP removed."
        fi
    fi

    if command -v firewall-cmd &>/dev/null && firewall-cmd --state 2>/dev/null | grep -q "running"; then
        echo ""
        if confirm "Remove TES3MP ports from firewalld?"; then
            firewall-cmd --permanent --remove-port="25565/udp" 2>/dev/null || true
            firewall-cmd --permanent --remove-port="8085/tcp" 2>/dev/null || true
            firewall-cmd --reload 2>/dev/null || true
            ok "firewalld rules for TES3MP removed."
        fi
    fi

    # ── Done ──
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  TES3MP server has been fully removed."
    echo ""
    echo "  Docker engine and system utilities"
    echo "  (nano, rhash, tar, zip) were kept."
    echo ""
    echo "  To reinstall, run install.sh then"
    echo "  configure.sh again."
    echo "═══════════════════════════════════════════"
    echo ""
}

main "$@"
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
# Source shared library (installed at /tes3mp-easy by install.sh)
# ────────────────────────────────────────────────────────────
source /tes3mp-easy/common.sh
check_root

DEST="/tes3mp-easy"

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
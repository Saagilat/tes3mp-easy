#!/bin/bash
#
# install.sh — TES3MP Docker server installer (infrastructure part)
#
# Installs Docker, utilities, downloads files, builds the Docker image.
# Then delegates configuration to configure.sh.
#
# Usage:
#   bash install.sh                     # interactive (via configure.sh)
#   bash install.sh --default           # non-interactive with defaults
#   bash install.sh --test              # test mode (password=1234, all endpoints)
#   bash install.sh --help              # show help
#

set -euo pipefail

# ────────────────────────────────────────────────────────────
# Colors
# ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()      { echo -e "${GREEN}[OK]${NC}   $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()     { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ────────────────────────────────────────────────────────────
# Root check
# ────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (or via sudo)."
    exit 1
fi

# ────────────────────────────────────────────────────────────
# Argument parsing — pass through to configure.sh
# ────────────────────────────────────────────────────────────
CONFIGURE_ARGS=()

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]
       bash $0 [OPTIONS]

Installs Docker and system dependencies, downloads TES3MP server files
from Saagilat/tes3mp-easy, builds the Docker image, then runs
configure.sh to set up the server interactively or non-interactively.

Options (passed through to configure.sh):
  --default   Non-interactive mode with all default values.
  --test      Like --default, but sets password to "1234" and
              enables all HTTP endpoints.
  --help      Show this help message and exit.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            usage
            exit 0
            ;;
        --default|--test)
            CONFIGURE_ARGS+=("$1")
            shift
            ;;
        *)
            err "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# ────────────────────────────────────────────────────────────
# Detect package manager
# ────────────────────────────────────────────────────────────
detect_pm() {
    if command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

PM=$(detect_pm)

# ────────────────────────────────────────────────────────────
# Install packages helper
# ────────────────────────────────────────────────────────────
install_packages() {
    case "$PM" in
        pacman) pacman -S --noconfirm --needed "$@" ;;
        apt)    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
        dnf)    dnf install -y "$@" ;;
        *)
            err "Unknown package manager. Install Docker and rsync manually, then re-run this script."
            exit 1
            ;;
    esac
}

# ────────────────────────────────────────────────────────────
# 1. Install Docker if missing
# ────────────────────────────────────────────────────────────
install_docker() {
    if command -v docker &>/dev/null; then
        if docker compose version &>/dev/null; then
            ok "Docker and docker compose are already installed"
            return 0
        fi
        warn "Docker found but docker compose plugin is missing — installing..."
    fi

    case "$PM" in
        pacman)
            pacman -Sy --noconfirm docker docker-compose
            systemctl enable --now docker
            ;;
        apt)
            warn "Installing Docker via official Docker repository..."
            DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl 2>&1
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            local deb_codename
            deb_codename=$(lsb_release -cs 2>/dev/null || grep -oP 'VERSION_CODENAME=\K.*' /etc/os-release)
            echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $deb_codename stable" \
                > /etc/apt/sources.list.d/docker.list
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>&1
            systemctl enable --now docker
            ;;
        dnf)
            dnf install -y dnf-plugins-core
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
            dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
            systemctl enable --now docker
            ;;
    esac

    if command -v docker &>/dev/null; then
        ok "Docker installed"
    else
        err "Failed to install Docker. Install it manually and re-run this script."
        exit 1
    fi
}

# ────────────────────────────────────────────────────────────
# 2. Install additional utilities
# ────────────────────────────────────────────────────────────
install_utils() {
    case "$PM" in
        pacman)
            install_packages nano rhash tar zip
            ;;
        apt)
            info "Updating package lists and installing utilities (nano, rhash, tar, zip)..."
            apt-get update
            install_packages nano rhash tar zip
            ;;
        dnf)
            install_packages nano rhash tar zip
            ;;
    esac
    ok "Utilities installed"
}

# ────────────────────────────────────────────────────────────
# 3. Create folder structure & download files
# ────────────────────────────────────────────────────────────
setup_files() {
    local dest="/tes3mp-easy"
    local script_dir

    mkdir -p "$dest/players" \
             "$dest/world/cell" "$dest/world/world" "$dest/world/map" "$dest/world/recordstore" "$dest/world/custom" \
             "$dest/mods/plugins" "$dest/mods/scripts" \
             "$dest/configs" \
             "$dest/backups/mods" "$dest/backups/players" "$dest/backups/world" \
             "$dest/import-mods" "$dest/import-players" "$dest/import-world" \
             "$dest/scripts"
    chown -R root:root "$dest"

    info "Downloading Dockerfile and configs from Saagilat/tes3mp-easy..."
    for f in tes3mp.dockerfile docker-compose.yml nginx.conf export.dockerfile export_server.sh entrypoint.sh; do
        wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server/docker/$f" -O "$dest/$f" || {
            err "Failed to download $f"
            exit 1
        }
    done
    chmod +x "$dest/entrypoint.sh"

    for f in package.sh import_mods.sh import_players.sh import_world.sh \
             deploy_mods.sh deploy_players.sh deploy_world.sh configure.sh; do
        wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server/scripts/$f" -O "$dest/scripts/$f" || {
            err "Failed to download $f"
            exit 1
        }
    done

    chmod +x "$dest/scripts/"*.sh

    # Download TES3MP version file and extract URL
    local TES3MP_URL=""
    local version_url="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server/tes3mp-version.txt"
    local version_file
    version_file=$(mktemp)
    if wget -q --show-progress "$version_url" -O "$version_file" 2>/dev/null; then
        TES3MP_URL=$(grep '^TES3MP_URL=' "$version_file" | head -1 | cut -d= -f2-)
    fi
    rm -f "$version_file"

    if [ -z "$TES3MP_URL" ]; then
        err "Failed to read TES3MP_URL from $version_url"
        exit 1
    fi

    echo "TES3MP_URL=$TES3MP_URL" > "$dest/.env"

    # Generate empty banlist.json
    cat > "$dest/configs/banlist.json" << 'BANEOF'
{
  "playerNames":[],
  "ipAddresses":[]
}
BANEOF

    # Generate empty customScripts.lua
    cat > "$dest/configs/customScripts.lua" << 'LUAEOF'
-- This file is auto-generated by install.sh
LUAEOF

    ok "All files installed — mount points are in $dest/"
}

# ────────────────────────────────────────────────────────────
# 4. Build Docker image
# ────────────────────────────────────────────────────────────
build_image() {
    local dest="/tes3mp-easy"

    info "Building Docker image (this may take a minute)..."
    docker compose -f "$dest/docker-compose.yml" build tes3mp 2>&1 || {
        err "Failed to build the Docker image. Check the output above."
        exit 1
    }
    ok "Docker image built"
}

# ────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────
main() {
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   TES3MP Docker Server Installation  ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    install_docker
    install_utils
    setup_files
    build_image

    info "Infrastructure ready. Running configuration..."
    bash "/tes3mp-easy/scripts/configure.sh" "${CONFIGURE_ARGS[@]}"
}

main "$@"
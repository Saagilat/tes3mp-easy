#!/bin/bash
#
# install.sh — TES3MP Docker server installer
#
# Installs Docker, utilities, downloads files, builds the Docker image,
# generates initial config files, and creates init backups.
#
# Usage:
#   bash install.sh                     # install everything
#   bash install.sh --help              # show help
#

set -euo pipefail

# ────────────────────────────────────────────────────────────
# Colors (inline — works when piped via curl | bash)
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
# Argument parsing
# ────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]
       bash $0 [OPTIONS]

Installs Docker and system dependencies, downloads TES3MP server files
from Saagilat/tes3mp-easy, builds the Docker image, and creates init backups.

Options:
  --help      Show this help message and exit.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            usage
            exit 0
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
            install_packages nano jq rhash tar zip
            ;;
        apt)
            info "Updating package lists and installing utilities (nano, jq, rhash, tar, zip)..."
            apt-get update
            install_packages nano jq rhash tar zip
            ;;
        dnf)
            install_packages nano jq rhash tar zip
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

    # Download common.sh to dest root (not scripts/)
    info "Downloading common.sh..."
    wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server/common" -O "$dest/common.sh" || {
        err "Failed to download common.sh"
        exit 1
    }

    for f in package.sh import_mods.sh import_players.sh import_world.sh \
             deploy_mods.sh deploy_players.sh deploy_world.sh list-backups.sh; do
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

    # Generate empty banlist.json (the only config not provided by the Docker image)
    cat > "$dest/configs/banlist.json" << 'BANEOF'
{
  "playerNames":[],
  "ipAddresses":[]
}
BANEOF

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
# 5. Extract default configs from Docker image
# ────────────────────────────────────────────────────────────
extract_configs() {
    local dest="$1"
    local image="tes3mp-tes3mp:latest"

    info "Extracting default config files from Docker image..."

    local temp_container
    temp_container=$(docker create "$image" 2>/dev/null) || {
        warn "Could not create temp container from $image — config files may be missing"
        return 1
    }

    local files=(
        "tes3mp-server-default.cfg:/tes3mp/tes3mp-server-default.cfg"
        "config.lua:/tes3mp/server/scripts/config.lua"
        "customScripts.lua:/tes3mp/server/scripts/customScripts.lua"
    )

    for entry in "${files[@]}"; do
        local local_name="${entry%%:*}"
        local container_path="${entry##*:}"
        local host_path="$dest/configs/$local_name"

        # Skip if file already exists (user may have customised it)
        [ -f "$host_path" ] && continue
        # Remove if a directory with the same name exists (from previous failed mount)
        [ -d "$host_path" ] && rm -rf "$host_path"

        if docker cp "$temp_container:$container_path" "$host_path" 2>/dev/null; then
            [ -f "$host_path" ] && ok "Extracted: configs/$local_name" || warn "Not a file: $container_path"
        else
            warn "Could not extract $container_path from image"
        fi
    done

    docker rm "$temp_container" >/dev/null 2>&1 || true
}

# ────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────
main() {
    local dest="/tes3mp-easy"

    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   TES3MP Docker Server Installation  ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    install_docker
    install_utils
    setup_files
    build_image
    extract_configs "$dest"

    # Create init backups (first snapshot of empty state)
    info "Creating initial backup archives..."
    if [[ -f "$dest/scripts/package.sh" ]]; then
        source "$dest/scripts/package.sh" 2>/dev/null || true
        export PLUGINS_DIR="$dest/mods/plugins"
        export SERVER_SCRIPTS_DIR="$dest/mods/scripts"
        export ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")
        export WORLD_CELL_DIR="$dest/world/cell"
        export WORLD_WORLD_DIR="$dest/world/world"
        export WORLD_MAP_DIR="$dest/world/map"
        export WORLD_RECORDSTORE_DIR="$dest/world/recordstore"
        export WORLD_CUSTOM_DIR="$dest/world/custom"
        export PLAYER_DIR="$dest/players"
        export BACKUPS_DIR="$dest/backups"

        package_init_mods "$dest/backups/mods/init-$(date +%F_%H-%M-%S)-mods.tar.gz" 2>/dev/null || true

        # Write current.txt from the init mods archive so _extract_required_json works
        local latest_mods init_mods_sha init_mods_name
        latest_mods=$(ls -t "$dest/backups/mods"/init-*.tar.gz 2>/dev/null | head -1) || true
        if [ -n "$latest_mods" ]; then
            init_mods_sha=$(sha256sum "$latest_mods" | cut -d' ' -f1)
            init_mods_name=$(basename "$latest_mods")
            echo "$init_mods_sha $init_mods_name" > "$dest/backups/mods/current.txt" 2>/dev/null || true
        fi

        bash "$dest/scripts/deploy_mods.sh" --latest 2>/dev/null || true

        package_init_world "$dest/backups/world/init-$(date +%F_%H-%M-%S)-world.tar.gz" 2>/dev/null || true
        package_init_players "$dest/backups/players/init-$(date +%F_%H-%M-%S)-players.tar.gz" 2>/dev/null || true

        bash "$dest/scripts/deploy_world.sh" --latest 2>/dev/null || true
        bash "$dest/scripts/deploy_players.sh" --latest 2>/dev/null || true

        ok "Initial backup archives created"
    fi

    info "Installation complete."
    echo ""
    echo "──────────────────────────────────────────"
    echo "  TES3MP server is ready."
    echo ""
    echo "  Start the server from the admin menu"
    echo "  or with:  docker compose -f $dest/docker-compose.yml up -d"
    echo "──────────────────────────────────────────"
    echo ""
}

main "$@"
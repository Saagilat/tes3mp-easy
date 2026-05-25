#!/bin/bash
#
# install.sh — Interactive TES3MP Docker server installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-guide/master/server/files/install.sh | bash
#
# Or download and run:
#   wget https://raw.githubusercontent.com/Saagilat/tes3mp-guide/master/server/files/install.sh
#   bash install.sh
#

set -euo pipefail

# ────────────────────────────────────────────────────────────
# Colors
# ────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
        ok "Docker is already installed"
        return 0
    fi

    case "$PM" in
        pacman)
            pacman -Sy --noconfirm docker docker-compose
            systemctl enable --now docker
            ;;
        apt)
            warn "Docker not found. Installing Docker via apt (docker.io, docker-compose)..."
            apt-get update
            DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io docker-compose
            systemctl enable --now docker
            ;;
        dnf)
            dnf install -y docker docker-compose
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
            install_packages rsync nano python tar zip
            ;;
        apt)
            info "Updating package lists and installing utilities (rsync, nano, python3, tar, zip)..."
            apt-get update
            install_packages rsync nano python3 tar zip
            ;;
        dnf)
            install_packages rsync nano python tar zip
            ;;
    esac
    ok "Utilities installed"
}

# ────────────────────────────────────────────────────────────
# 3. Interactive questionnaire
# ────────────────────────────────────────────────────────────
gather_options() {
    echo ""
    echo "========================================"
    echo "  TES3MP Server Setup"
    echo "========================================"
    echo ""

    read -r -p "Server name [default: tes3mp]: " SERVER_NAME </dev/tty
    SERVER_NAME="${SERVER_NAME:-tes3mp}"

    read -r -p "Password (leave empty to disable) [default: (empty)]: " SERVER_PASSWORD </dev/tty
    SERVER_PASSWORD="${SERVER_PASSWORD:-}"

    read -r -p "Max players [default: 4]: " MAX_PLAYERS </dev/tty
    MAX_PLAYERS="${MAX_PLAYERS:-4}"

    echo ""
    echo "--- Ports ---"
    echo "(If unsure, leave the default values)"
    echo ""

    read -r -p "TES3MP server port (UDP) [default: 25565]: " TES3MP_PORT </dev/tty
    TES3MP_PORT="${TES3MP_PORT:-25565}"

    read -r -p "HTTP endpoint port (TCP) [default: 8085]: " HTTP_PORT </dev/tty
    HTTP_PORT="${HTTP_PORT:-8085}"

    echo ""
    echo "--- Endpoints (HTTP port $HTTP_PORT) ---"
    echo ""
    echo "Endpoints are URLs that players can use from their browser to"
    echo "download mods, world state, or character data."
    echo ""

    # /get-mods
    echo "--- /get-mods ---"
    echo "Lets players download all server mods as a single archive."
    echo "Recommended to enable — safe and convenient."
    echo ""
    read -r -p "Enable /get-mods? [default: N]: " ENABLE_MODS </dev/tty
    ENABLE_MODS="${ENABLE_MODS:-n}"
    case "${ENABLE_MODS,,}" in
        y|yes) ENABLE_MODS="yes" ;;
        *)     ENABLE_MODS="no" ;;
    esac

    # /get-world
    echo ""
    echo "--- /get-world ---"
    echo "Serves the world state (all cells). Anyone who knows the server IP"
    echo "can download the location of all items, buildings, and changes."
    echo "Useful for co-op/RP servers. On PvP/competitive servers it may"
    echo "spoil surprises."
    echo ""
    read -r -p "Enable /get-world? [default: N]: " ENABLE_WORLD </dev/tty
    ENABLE_WORLD="${ENABLE_WORLD:-n}"
    case "${ENABLE_WORLD,,}" in
        y|yes) ENABLE_WORLD="yes" ;;
        *)     ENABLE_WORLD="no" ;;
    esac

    # /get-characters
    echo ""
    echo "--- /get-characters ---"
    echo "Serves ALL character data (inventory, skills, spells, quests)."
    echo "Anyone who knows the server IP can download this data."
    echo "On co-op/RP servers — transparency. On competitive servers — a risk."
    echo ""
    read -r -p "Enable /get-characters? [default: N]: " ENABLE_CHARACTERS </dev/tty
    ENABLE_CHARACTERS="${ENABLE_CHARACTERS:-n}"
    case "${ENABLE_CHARACTERS,,}" in
        y|yes) ENABLE_CHARACTERS="yes" ;;
        *)     ENABLE_CHARACTERS="no" ;;
    esac

    # ---- Rate limits ----
    echo ""
    echo "--- Rate limiting ---"
    echo "How many requests per minute can a single IP make to each endpoint."
    echo "Default: 5. Enter 0 to disable rate limiting."
    echo ""

    MODS_RATE="5"
    if [[ "$ENABLE_MODS" == "yes" ]]; then
        read -r -p "  /get-mods rate limit (req/min) [default: 5]: " input </dev/tty
        MODS_RATE="${input:-5}"
    fi

    WORLD_RATE="5"
    if [[ "$ENABLE_WORLD" == "yes" ]]; then
        read -r -p "  /get-world rate limit (req/min) [default: 5]: " input </dev/tty
        WORLD_RATE="${input:-5}"
    fi

    CHARACTERS_RATE="5"
    if [[ "$ENABLE_CHARACTERS" == "yes" ]]; then
        read -r -p "  /get-characters rate limit (req/min) [default: 5]: " input </dev/tty
        CHARACTERS_RATE="${input:-5}"
    fi
}

# ────────────────────────────────────────────────────────────
# 4. Create folder structure & download files
# ────────────────────────────────────────────────────────────
setup_files() {
    local dest="/opt/tes3mp"
    mkdir -p "$dest/data" "$dest/mods"
    chown -R root:root "$dest"

    cd "$dest"

    info "Downloading Dockerfile and configs from Saagilat/tes3mp-guide..."
    for f in Dockerfile docker-compose.yml nginx.conf export.dockerfile export_server.py update_mods.sh; do
        wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-guide/master/server/files/$f" -O "$dest/$f"
    done
    chmod +x "$dest/update_mods.sh"

    # Download management reference
    wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-guide/master/server/management.md" -O "$dest/management.md"

    # Download TES3MP server binary
    local TES3MP_URL="https://github.com/TES3MP/TES3MP/releases/download/tes3mp-0.8.1/tes3mp-server-GNU+Linux-x86_64-release-0.8.1-68954091c5-6da3fdea59.tar.gz"

    if [[ -f "$dest/data/tes3mp-server" ]]; then
        ok "TES3MP server binary already downloaded"
    else
        info "Downloading TES3MP server (~50 MB)..."
        wget -q --show-progress "$TES3MP_URL" -O /tmp/tes3mp.tar.gz
        tar --strip-components=1 -xzf /tmp/tes3mp.tar.gz -C "$dest/data/"
        rm -f /tmp/tes3mp.tar.gz
        ok "TES3MP server installed"
    fi
}

# ────────────────────────────────────────────────────────────
# 5. Generate server config from answers
# ────────────────────────────────────────────────────────────
write_config() {
    local dest="/opt/tes3mp/data"
    local cfg="$dest/tes3mp-server-default.cfg"
    local marker="# install.sh config"

    # If config already has our marker — user has edited it, skip
    if [[ -f "$cfg" ]] && tail -1 "$cfg" | grep -qF "$marker"; then
        warn "Config $cfg was already generated by install.sh — skipping."
        warn "Edit it manually: nano $cfg"
        return 0
    fi

    info "Generating $cfg from your answers..."

    # Force-rewrite the three fields that the installer asks about.
    # TES3MP's config uses these key names (not serverName/serverPassword/maxPlayers).
    sed -i \
        -e "/^hostname[[:space:]]*=/{s//hostname = $SERVER_NAME/;:a;n;ba}" \
        -e "/^password[[:space:]]*=/{s//password = $SERVER_PASSWORD/;:a;n;ba}" \
        -e "/^maximumPlayers[[:space:]]*=/{s//maximumPlayers = $MAX_PLAYERS/;:a;n;ba}" \
        "$cfg"

    # Append our marker so future runs know not to overwrite
    echo "$marker" >> "$cfg"

    ok "Config updated"
}

# ────────────────────────────────────────────────────────────
# 6. Configure nginx.conf and docker-compose.yml based on answers
# ────────────────────────────────────────────────────────────
configure_endpoints() {
    local dest="/opt/tes3mp"

    # docker-compose.yml
    local compose="$dest/docker-compose.yml"

    # Set TES3MP port
    sed -i "s/\"25565:25565\/udp\"/\"$TES3MP_PORT:25565\/udp\"/" "$compose"

    # Uncomment nginx service if at least one endpoint is enabled
    if [[ "$ENABLE_MODS" == "yes" || "$ENABLE_WORLD" == "yes" || "$ENABLE_CHARACTERS" == "yes" ]]; then
        sed -i 's/#\(nginx:\)/\1/' "$compose"
        sed -i 's/#\(  image: nginx:alpine\)/  image: nginx:alpine/' "$compose"
        sed -i 's/#\(  ports:\)/  ports:/' "$compose"
        sed -i "s/#\(    - \"8085:80\"\)/    - \"$HTTP_PORT:80\"/" "$compose"
        sed -i 's/#\(  volumes:\)/  volumes:/' "$compose"
        sed -i 's/#\(    - \.\/data:\/usr\/share\/nginx\/html:ro\)/    - .\/data:\/usr\/share\/nginx\/html:ro/' "$compose"
        sed -i 's/#\(    - \.\/nginx.conf:\/etc\/nginx\/conf\.d\/default\.conf:ro\)/    - .\/nginx.conf:\/etc\/nginx\/conf.d\/default.conf:ro/' "$compose"
        sed -i 's/#\(  restart: unless-stopped\)/  restart: unless-stopped/' "$compose"
    fi

    # Uncomment export service if /get-world or /get-characters are enabled
    if [[ "$ENABLE_WORLD" == "yes" || "$ENABLE_CHARACTERS" == "yes" ]]; then
        sed -i 's/#\(export:\)/\1/' "$compose"
        sed -i 's/#\(  build:\)/  build:/' "$compose"
        sed -i 's/#\(    context: \.\)/    context: ./' "$compose"
        sed -i 's/#\(    dockerfile: export\.dockerfile\)/    dockerfile: export.dockerfile/' "$compose"
        sed -i 's/#\(  volumes:\)/  volumes:/' "$compose"
        sed -i 's/#\(    - tes3mp-characters:\/mnt\/characters:ro\)/    - tes3mp-characters:\/mnt\/characters:ro/' "$compose"
        sed -i 's/#\(    - tes3mp-cells:\/mnt\/cells:ro\)/    - tes3mp-cells:\/mnt\/cells:ro/' "$compose"
        sed -i 's/#\(  restart: unless-stopped\)/  restart: unless-stopped/' "$compose"
    fi

    # nginx.conf — uncomment the required location blocks
    local nginx="$dest/nginx.conf"

    # Update rate limits in zone declarations
    sed -i "s/^limit_req_zone.*zone=mods:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=mods:10m rate=${MODS_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=world:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=world:10m rate=${WORLD_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=characters:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=characters:10m rate=${CHARACTERS_RATE}r\/m;/" "$nginx"

    if [[ "$ENABLE_MODS" == "yes" ]]; then
        sed -i 's/#\(location \/get-mods\)/\1/' "$nginx"
        sed -i 's/#\(    limit_req zone=mods burst=1 nodelay;\)/    limit_req zone=mods burst=1 nodelay;/' "$nginx"
        sed -i 's/#\(    alias \/usr\/share\/nginx\/html\/mods\.zip;\)/    alias \/usr\/share\/nginx\/html\/mods.zip;/' "$nginx"
        sed -i 's/#\(    default_type application\/zip;\)/    default_type application\/zip;/' "$nginx"
    fi

    if [[ "$ENABLE_WORLD" == "yes" ]]; then
        sed -i 's/#\(location \/get-world\)/\1/' "$nginx"
        sed -i 's/#\(    limit_req zone=world burst=1 nodelay;\)/    limit_req zone=world burst=1 nodelay;/' "$nginx"
        sed -i 's/#\(    proxy_pass http:\/\/export:5000\/get-world;\)/    proxy_pass http:\/\/export:5000\/get-world;/' "$nginx"
    fi

    if [[ "$ENABLE_CHARACTERS" == "yes" ]]; then
        sed -i 's/#\(location \/get-characters\)/\1/' "$nginx"
        sed -i 's/#\(    limit_req zone=characters burst=1 nodelay;\)/    limit_req zone=characters burst=1 nodelay;/' "$nginx"
        sed -i 's/#\(    proxy_pass http:\/\/export:5000\/get-characters;\)/    proxy_pass http:\/\/export:5000\/get-characters;/' "$nginx"
    fi
}

# ────────────────────────────────────────────────────────────
# 7. Configure firewall
# ────────────────────────────────────────────────────────────
configure_firewall() {
    local fw=""

    if command -v ufw &>/dev/null && ufw status 2>/dev/null | grep -q "Status: active"; then
        fw="ufw"
    elif command -v firewall-cmd &>/dev/null && firewall-cmd --state 2>/dev/null | grep -q "running"; then
        fw="firewall-cmd"
    fi

    if [[ -z "$fw" ]]; then
        info "Firewall not found or not active — skipping."
        return 0
    fi

    echo ""
    echo "--- Firewall ($fw is active) ---"
    echo "Ports need to be opened for the TES3MP server."
    echo ""

    read -r -p "Open ports in the firewall? [Y/n]: " OPEN_FW </dev/tty
    OPEN_FW="${OPEN_FW:-y}"
    case "${OPEN_FW,,}" in
        n|no|nope) return 0 ;;
    esac

    # Always open the TES3MP game port
    case "$fw" in
        ufw)
            ufw allow "$TES3MP_PORT/udp" comment "TES3MP"
            if [[ "$ENABLE_MODS" == "yes" || "$ENABLE_WORLD" == "yes" || "$ENABLE_CHARACTERS" == "yes" ]]; then
                ufw allow "$HTTP_PORT/tcp" comment "TES3MP HTTP endpoints"
            fi
            ;;
        firewall-cmd)
            firewall-cmd --permanent --add-port="$TES3MP_PORT/udp"
            if [[ "$ENABLE_MODS" == "yes" || "$ENABLE_WORLD" == "yes" || "$ENABLE_CHARACTERS" == "yes" ]]; then
                firewall-cmd --permanent --add-port="$HTTP_PORT/tcp"
            fi
            firewall-cmd --reload
            ;;
    esac

    ok "Ports opened in $fw"
}

# ────────────────────────────────────────────────────────────
# 8. Build Docker image and start
# ────────────────────────────────────────────────────────────
build_and_start() {
    local dest="/opt/tes3mp"
    cd "$dest"

    info "Building Docker image (this may take a minute)..."
    docker compose up -d --build 2>&1 || {
        err "Failed to start the container. Check the output above."
        exit 1
    }

    ok "Server started!"
    echo ""
    echo "=========================================="
    echo "  TES3MP server is ready!"
    echo "=========================================="
    echo ""
    echo "  Server name:     $SERVER_NAME"
    echo "  Server password: ${SERVER_PASSWORD:-(not set)}"
    echo "  Max players:     $MAX_PLAYERS"
    echo ""
    echo "  TES3MP port (UDP):  $TES3MP_PORT"
    echo ""
    echo "  Endpoints:"
    echo "    /get-mods:        $ENABLE_MODS"
    echo "    /get-world:       $ENABLE_WORLD"
    echo "    /get-characters:  $ENABLE_CHARACTERS"
    echo ""
    if [[ "$ENABLE_MODS" == "yes" || "$ENABLE_WORLD" == "yes" || "$ENABLE_CHARACTERS" == "yes" ]]; then
        echo "  HTTP port (endpoints): $HTTP_PORT"
    fi
    echo ""
    echo "  Logs:        docker compose -f $dest/docker-compose.yml logs -f"
    echo "  Stop:        docker compose -f $dest/docker-compose.yml down"
    echo "  Restart:     docker compose -f $dest/docker-compose.yml up -d --build"
    echo ""
    echo "  Config:      nano $dest/data/tes3mp-server-default.cfg"
    echo ""
    echo "  To install mods: bash $dest/update_mods.sh"
    echo ""
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
    gather_options
    setup_files
    write_config
    configure_endpoints
    configure_firewall
    build_and_start
}

main "$@"
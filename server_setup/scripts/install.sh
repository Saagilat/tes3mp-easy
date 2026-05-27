#!/bin/bash
#
# install.sh — Interactive TES3MP Docker server installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server_setup/scripts/install.sh | bash
#
# Or download and run:
#   wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server_setup/scripts/install.sh
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
        # Check if docker compose (plugin) is available
        if docker compose version &>/dev/null; then
            ok "Docker and docker compose are already installed"
            return 0
        fi
        # docker exists but without compose plugin — try to install it
        warn "Docker found but docker compose plugin is missing — installing..."
    fi

    case "$PM" in
        pacman)
            pacman -Sy --noconfirm docker docker-compose
            systemctl enable --now docker
            ;;
        apt)
            warn "Installing Docker via official Docker repository..."
            # Install prerequisites
            DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl 2>&1
            # Add Docker's official GPG key
            install -m 0755 -d /etc/apt/keyrings
            curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            # Add the repository (use Debian version codename)
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
            install_packages rsync nano rhash tar zip
            ;;
        apt)
            info "Updating package lists and installing utilities (rsync, nano, rhash, tar, zip)..."
            apt-get update
            install_packages rsync nano rhash tar zip
            ;;
        dnf)
            install_packages rsync nano rhash tar zip
            ;;
    esac
    ok "Utilities installed"
}

# ────────────────────────────────────────────────────────────
# 3. Interactive questionnaire (TES3MP core)
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
    echo "--- Port ---"
    echo "(If unsure, leave the default value)"
    echo ""

    read -r -p "TES3MP server port (UDP) [default: 25565]: " TES3MP_PORT </dev/tty
    TES3MP_PORT="${TES3MP_PORT:-25565}"

    echo ""
    echo "--- Endpoints ---"
    echo ""
    echo "The following optional HTTP endpoints give players access to"
    echo "server data. The HTTP port (8085) is only opened if at least"
    echo "one endpoint is enabled. Each endpoint is disabled by default."
    echo ""
    read -r -p "Enable /get-plugins? [y/N]: " ENABLE_PLUGINS </dev/tty
    ENABLE_PLUGINS="${ENABLE_PLUGINS:-n}"
    case "${ENABLE_PLUGINS,,}" in
        y|yes) ENABLE_PLUGINS="yes" ;;
        *)     ENABLE_PLUGINS="no" ;;
    esac

    read -r -p "Enable /get-server-scripts? [y/N]: " ENABLE_SERVER_SCRIPTS </dev/tty
    ENABLE_SERVER_SCRIPTS="${ENABLE_SERVER_SCRIPTS:-n}"
    case "${ENABLE_SERVER_SCRIPTS,,}" in
        y|yes) ENABLE_SERVER_SCRIPTS="yes" ;;
        *)     ENABLE_SERVER_SCRIPTS="no" ;;
    esac

    read -r -p "Enable /get-world? [y/N]: " ENABLE_WORLD </dev/tty
    ENABLE_WORLD="${ENABLE_WORLD:-n}"
    case "${ENABLE_WORLD,,}" in
        y|yes) ENABLE_WORLD="yes" ;;
        *)     ENABLE_WORLD="no" ;;
    esac

    read -r -p "Enable /get-characters? [y/N]: " ENABLE_CHARACTERS </dev/tty
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

    PLUGINS_RATE="5"
    if [[ "$ENABLE_PLUGINS" == "yes" ]]; then
        read -r -p "  /get-plugins rate limit (req/min) [default: 5]: " input </dev/tty
        PLUGINS_RATE="${input:-5}"
    fi

    SERVER_SCRIPTS_RATE="5"
    if [[ "$ENABLE_SERVER_SCRIPTS" == "yes" ]]; then
        read -r -p "  /get-server-scripts rate limit (req/min) [default: 5]: " input </dev/tty
        SERVER_SCRIPTS_RATE="${input:-5}"
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

    # ---- Example content ----
    echo ""
    echo "--- Example content ---"
    echo "Test server/client scripts to verify the setup works."
    echo ""
    read -r -p "Create example mods (scripts) to verify setup? [Y/n]: " ENABLE_EXAMPLE_MODS </dev/tty
    ENABLE_EXAMPLE_MODS="${ENABLE_EXAMPLE_MODS:-y}"
    case "${ENABLE_EXAMPLE_MODS,,}" in
        n|no)  ENABLE_EXAMPLE_MODS="no" ;;
        *)     ENABLE_EXAMPLE_MODS="yes" ;;
    esac
}

# ────────────────────────────────────────────────────────────
# 3b. Interactive questionnaire (config.lua)
# ────────────────────────────────────────────────────────────
gather_lua_options() {
    echo ""
    echo "========================================"
    echo "  Lua Config (config.lua) Settings"
    echo "========================================"
    echo ""

    # ---- Game settings ----
    echo "--- Game Settings ---"
    echo ""

    read -r -p "Game mode (displayed in server browser) [default: Default]: " LUA_GAME_MODE </dev/tty
    LUA_GAME_MODE="${LUA_GAME_MODE:-Default}"

    read -r -p "Difficulty (-100..100) [default: 0]: " LUA_DIFFICULTY </dev/tty
    LUA_DIFFICULTY="${LUA_DIFFICULTY:-0}"

    read -r -p "Login time (seconds) [default: 60]: " LUA_LOGIN_TIME </dev/tty
    LUA_LOGIN_TIME="${LUA_LOGIN_TIME:-60}"

    read -r -p "Max clients per IP [default: 3]: " LUA_MAX_CLIENTS_PER_IP </dev/tty
    LUA_MAX_CLIENTS_PER_IP="${LUA_MAX_CLIENTS_PER_IP:-3}"

    # ---- Sharing ----
    echo ""
    echo "--- Sharing ---"
    echo ""

    read -r -p "Share journal (quests are shared) [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_SHARE_JOURNAL="true" ;; *) LUA_SHARE_JOURNAL="false" ;; esac

    read -r -p "Share faction ranks [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_SHARE_FACTION_RANKS="true" ;; *) LUA_SHARE_FACTION_RANKS="false" ;; esac

    read -r -p "Share faction expulsion [y/N]: " input </dev/tty
    input="${input:-n}"
    case "${input,,}" in y|yes) LUA_SHARE_FACTION_EXPULSION="true" ;; *) LUA_SHARE_FACTION_EXPULSION="false" ;; esac

    read -r -p "Share faction reputation [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_SHARE_FACTION_REPUTATION="true" ;; *) LUA_SHARE_FACTION_REPUTATION="false" ;; esac

    read -r -p "Share dialogue topics [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_SHARE_TOPICS="true" ;; *) LUA_SHARE_TOPICS="false" ;; esac

    read -r -p "Share bounty [y/N]: " input </dev/tty
    input="${input:-n}"
    case "${input,,}" in y|yes) LUA_SHARE_BOUNTY="true" ;; *) LUA_SHARE_BOUNTY="false" ;; esac

    read -r -p "Share reputation [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_SHARE_REPUTATION="true" ;; *) LUA_SHARE_REPUTATION="false" ;; esac

    read -r -p "Share map exploration [y/N]: " input </dev/tty
    input="${input:-n}"
    case "${input,,}" in y|yes) LUA_SHARE_MAP_EXPLORATION="true" ;; *) LUA_SHARE_MAP_EXPLORATION="false" ;; esac

    read -r -p "Share videos [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_SHARE_VIDEOS="true" ;; *) LUA_SHARE_VIDEOS="false" ;; esac

    # ---- Permissions ----
    echo ""
    echo "--- Permissions ---"
    echo ""

    read -r -p "Allow console (~) [y/N]: " input </dev/tty
    input="${input:-n}"
    case "${input,,}" in y|yes) LUA_ALLOW_CONSOLE="true" ;; *) LUA_ALLOW_CONSOLE="false" ;; esac

    read -r -p "Allow bed rest [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_ALLOW_BED_REST="true" ;; *) LUA_ALLOW_BED_REST="false" ;; esac

    read -r -p "Allow wilderness rest [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_ALLOW_WILDERNESS_REST="true" ;; *) LUA_ALLOW_WILDERNESS_REST="false" ;; esac

    read -r -p "Allow wait [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_ALLOW_WAIT="true" ;; *) LUA_ALLOW_WAIT="false" ;; esac

    read -r -p "Allow /suicide command [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_ALLOW_SUICIDE_COMMAND="true" ;; *) LUA_ALLOW_SUICIDE_COMMAND="false" ;; esac

    read -r -p "Allow /fixme command [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_ALLOW_FIXME_COMMAND="true" ;; *) LUA_ALLOW_FIXME_COMMAND="false" ;; esac

    # ---- Respawn & Death ----
    echo ""
    echo "--- Respawn & Death ---"
    echo ""

    read -r -p "Players respawn on death [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_PLAYERS_RESPAWN="true" ;; *) LUA_PLAYERS_RESPAWN="false" ;; esac

    read -r -p "Death time (seconds) [default: 5]: " LUA_DEATH_TIME </dev/tty
    LUA_DEATH_TIME="${LUA_DEATH_TIME:-5}"

    read -r -p "Jail days on death [default: 5]: " LUA_DEATH_PENALTY_JAIL_DAYS </dev/tty
    LUA_DEATH_PENALTY_JAIL_DAYS="${LUA_DEATH_PENALTY_JAIL_DAYS:-5}"

    read -r -p "Reset bounty on death [y/N]: " input </dev/tty
    input="${input:-n}"
    case "${input,,}" in y|yes) LUA_BOUNTY_RESET_ON_DEATH="true" ;; *) LUA_BOUNTY_RESET_ON_DEATH="false" ;; esac

    read -r -p "Bounty-based jail time on death [y/N]: " input </dev/tty
    input="${input:-n}"
    case "${input,,}" in y|yes) LUA_BOUNTY_DEATH_PENALTY="true" ;; *) LUA_BOUNTY_DEATH_PENALTY="false" ;; esac

    read -r -p "Respawn at Imperial shrine [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_RESPAWN_AT_IMPERIAL_SHRINE="true" ;; *) LUA_RESPAWN_AT_IMPERIAL_SHRINE="false" ;; esac

    read -r -p "Respawn at Tribunal temple [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_RESPAWN_AT_TRIBUNAL_TEMPLE="true" ;; *) LUA_RESPAWN_AT_TRIBUNAL_TEMPLE="false" ;; esac

    # ---- Collisions ----
    echo ""
    echo "--- Collisions ---"
    echo ""

    read -r -p "Player-player collision [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_ENABLE_PLAYER_COLLISION="true" ;; *) LUA_ENABLE_PLAYER_COLLISION="false" ;; esac

    read -r -p "Actor-actor collision [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_ENABLE_ACTOR_COLLISION="true" ;; *) LUA_ENABLE_ACTOR_COLLISION="false" ;; esac

    read -r -p "Placed object collision [y/N]: " input </dev/tty
    input="${input:-n}"
    case "${input,,}" in y|yes) LUA_ENABLE_PLACED_OBJECT_COLLISION="true" ;; *) LUA_ENABLE_PLACED_OBJECT_COLLISION="false" ;; esac

    # ---- Time ----
    echo ""
    echo "--- Time ---"
    echo ""

    read -r -p "Pass time when server is empty [y/N]: " input </dev/tty
    input="${input:-n}"
    case "${input,,}" in y|yes) LUA_PASS_TIME_WHEN_EMPTY="true" ;; *) LUA_PASS_TIME_WHEN_EMPTY="false" ;; esac

    read -r -p "Night start hour [default: 20]: " LUA_NIGHT_START_HOUR </dev/tty
    LUA_NIGHT_START_HOUR="${LUA_NIGHT_START_HOUR:-20}"

    read -r -p "Night end hour [default: 6]: " LUA_NIGHT_END_HOUR </dev/tty
    LUA_NIGHT_END_HOUR="${LUA_NIGHT_END_HOUR:-6}"

    # ---- Stats Limits ----
    echo ""
    echo "--- Stats Limits ---"
    echo ""

    read -r -p "Max attribute value [default: 200]: " LUA_MAX_ATTRIBUTE_VALUE </dev/tty
    LUA_MAX_ATTRIBUTE_VALUE="${LUA_MAX_ATTRIBUTE_VALUE:-200}"

    read -r -p "Max Speed value [default: 365]: " LUA_MAX_SPEED_VALUE </dev/tty
    LUA_MAX_SPEED_VALUE="${LUA_MAX_SPEED_VALUE:-365}"

    read -r -p "Max skill value [default: 200]: " LUA_MAX_SKILL_VALUE </dev/tty
    LUA_MAX_SKILL_VALUE="${LUA_MAX_SKILL_VALUE:-200}"

    read -r -p "Max Acrobatics value [default: 1200]: " LUA_MAX_ACROBATICS_VALUE </dev/tty
    LUA_MAX_ACROBATICS_VALUE="${LUA_MAX_ACROBATICS_VALUE:-1200}"

    # ---- Safety ----
    echo ""
    echo "--- Safety ---"
    echo ""

    read -r -p "Enforce same data files for all clients [Y/n]: " input </dev/tty
    input="${input:-y}"
    case "${input,,}" in y|yes) LUA_ENFORCE_DATA_FILES="true" ;; *) LUA_ENFORCE_DATA_FILES="false" ;; esac

    read -r -p "Ignore Lua script errors (dangerous) [y/N]: " input </dev/tty
    input="${input:-n}"
    case "${input,,}" in y|yes) LUA_IGNORE_SCRIPT_ERRORS="true" ;; *) LUA_IGNORE_SCRIPT_ERRORS="false" ;; esac
}

# ────────────────────────────────────────────────────────────
# 4. Create folder structure & download files
# ────────────────────────────────────────────────────────────
setup_files() {
    local dest="/opt/tes3mp"
    mkdir -p "$dest/data" "$dest/data/players" "$dest/data/cells" \
             "$dest/data/server/data" \
             "$dest/plugins" "$dest/server-scripts" "$dest/client-scripts"
    chown -R root:root "$dest"

    cd "$dest"

    info "Downloading Dockerfile and configs from Saagilat/tes3mp-easy-setup..."
    for f in tes3mp.dockerfile docker-compose.yml nginx.conf export.dockerfile export_server.sh; do
        wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server_setup/docker/$f" -O "$dest/$f"
    done
    for f in update_mods.sh; do
        wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server_setup/scripts/$f" -O "$dest/$f"
    done
    chmod +x "$dest/update_mods.sh"

    # Download management reference
    wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/docs/admin/management.md" -O "$dest/management.md"

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

    if [[ "$ENABLE_EXAMPLE_MODS" == "yes" ]]; then
        info "Downloading example server script..."
        wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server_setup/example-mods/server-scripts/test_server.lua" \
            -O "$dest/server-scripts/test_server.lua"

        info "Downloading example client script..."
        wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server_setup/example-mods/client-scripts/test_client.lua" \
            -O "$dest/client-scripts/test_client.lua"

        ok "Example mods downloaded"
    fi

    ok "All files installed — configs are in data/, edit them directly on the host"
}
# ────────────────────────────────────────────────────────────
# 5. Generate server config from answers
# ────────────────────────────────────────────────────────────
write_config() {
    local dest="/opt/tes3mp/data"
    local cfg="$dest/tes3mp-server-default.cfg"

    info "Generating $cfg from your answers..."

    # Replace hostname (case-insensitive, allows any whitespace around =)
    sed -i 's/^[[:space:]]*hostname[[:space:]]*=.*/hostname = '"$SERVER_NAME"'/i' "$cfg"
    # Fallback: append if the key was not found at all
    if ! grep -qi '^[[:space:]]*hostname[[:space:]]*=' "$cfg" 2>/dev/null; then
        echo "hostname = $SERVER_NAME" >> "$cfg"
    fi

    # Replace password
    if [[ -z "$SERVER_PASSWORD" ]]; then
        sed -i 's/^[[:space:]]*password[[:space:]]*=.*/password =/i' "$cfg"
    else
        sed -i 's/^[[:space:]]*password[[:space:]]*=.*/password = '"$SERVER_PASSWORD"'/i' "$cfg"
    fi
    if ! grep -qi '^[[:space:]]*password[[:space:]]*=' "$cfg" 2>/dev/null; then
        if [[ -z "$SERVER_PASSWORD" ]]; then
            echo "password =" >> "$cfg"
        else
            echo "password = $SERVER_PASSWORD" >> "$cfg"
        fi
    fi

    # Replace maximumPlayers
    sed -i 's/^[[:space:]]*maximumPlayers[[:space:]]*=.*/maximumPlayers = '"$MAX_PLAYERS"'/i' "$cfg"
    if ! grep -qi '^[[:space:]]*maximumPlayers[[:space:]]*=' "$cfg" 2>/dev/null; then
        echo "maximumPlayers = $MAX_PLAYERS" >> "$cfg"
    fi

    ok "Config updated"
}

# ────────────────────────────────────────────────────────────
# 5b. Generate Lua config from answers
# ────────────────────────────────────────────────────────────
write_lua_config() {
    local dest="/opt/tes3mp/data/server/scripts"
    local cfg="$dest/config.lua"
    local marker="-- install.sh config"

    # If config already has our marker — user has edited it, skip
    if [[ -f "$cfg" ]] && tail -1 "$cfg" | grep -qF -- "$marker"; then
        warn "Lua config $cfg was already generated by install.sh — skipping."
        warn "Edit it manually: nano $cfg"
        return 0
    fi

    info "Generating $cfg from your answers..."

    # Game settings
    sed -i "s/^config\.gameMode = .*/config.gameMode = \"$LUA_GAME_MODE\"/" "$cfg"
    sed -i "s/^config\.difficulty = .*/config.difficulty = $LUA_DIFFICULTY/" "$cfg"
    sed -i "s/^config\.loginTime = .*/config.loginTime = $LUA_LOGIN_TIME/" "$cfg"
    sed -i "s/^config\.maxClientsPerIP = .*/config.maxClientsPerIP = $LUA_MAX_CLIENTS_PER_IP/" "$cfg"

    # Sharing
    sed -i "s/^config\.shareJournal = .*/config.shareJournal = $LUA_SHARE_JOURNAL/" "$cfg"
    sed -i "s/^config\.shareFactionRanks = .*/config.shareFactionRanks = $LUA_SHARE_FACTION_RANKS/" "$cfg"
    sed -i "s/^config\.shareFactionExpulsion = .*/config.shareFactionExpulsion = $LUA_SHARE_FACTION_EXPULSION/" "$cfg"
    sed -i "s/^config\.shareFactionReputation = .*/config.shareFactionReputation = $LUA_SHARE_FACTION_REPUTATION/" "$cfg"
    sed -i "s/^config\.shareTopics = .*/config.shareTopics = $LUA_SHARE_TOPICS/" "$cfg"
    sed -i "s/^config\.shareBounty = .*/config.shareBounty = $LUA_SHARE_BOUNTY/" "$cfg"
    sed -i "s/^config\.shareReputation = .*/config.shareReputation = $LUA_SHARE_REPUTATION/" "$cfg"
    sed -i "s/^config\.shareMapExploration = .*/config.shareMapExploration = $LUA_SHARE_MAP_EXPLORATION/" "$cfg"
    sed -i "s/^config\.shareVideos = .*/config.shareVideos = $LUA_SHARE_VIDEOS/" "$cfg"

    # Permissions
    sed -i "s/^config\.allowConsole = .*/config.allowConsole = $LUA_ALLOW_CONSOLE/" "$cfg"
    sed -i "s/^config\.allowBedRest = .*/config.allowBedRest = $LUA_ALLOW_BED_REST/" "$cfg"
    sed -i "s/^config\.allowWildernessRest = .*/config.allowWildernessRest = $LUA_ALLOW_WILDERNESS_REST/" "$cfg"
    sed -i "s/^config\.allowWait = .*/config.allowWait = $LUA_ALLOW_WAIT/" "$cfg"
    sed -i "s/^config\.allowSuicideCommand = .*/config.allowSuicideCommand = $LUA_ALLOW_SUICIDE_COMMAND/" "$cfg"
    sed -i "s/^config\.allowFixmeCommand = .*/config.allowFixmeCommand = $LUA_ALLOW_FIXME_COMMAND/" "$cfg"

    # Respawn & Death
    sed -i "s/^config\.playersRespawn = .*/config.playersRespawn = $LUA_PLAYERS_RESPAWN/" "$cfg"
    sed -i "s/^config\.deathTime = .*/config.deathTime = $LUA_DEATH_TIME/" "$cfg"
    sed -i "s/^config\.deathPenaltyJailDays = .*/config.deathPenaltyJailDays = $LUA_DEATH_PENALTY_JAIL_DAYS/" "$cfg"
    sed -i "s/^config\.bountyResetOnDeath = .*/config.bountyResetOnDeath = $LUA_BOUNTY_RESET_ON_DEATH/" "$cfg"
    sed -i "s/^config\.bountyDeathPenalty = .*/config.bountyDeathPenalty = $LUA_BOUNTY_DEATH_PENALTY/" "$cfg"
    sed -i "s/^config\.respawnAtImperialShrine = .*/config.respawnAtImperialShrine = $LUA_RESPAWN_AT_IMPERIAL_SHRINE/" "$cfg"
    sed -i "s/^config\.respawnAtTribunalTemple = .*/config.respawnAtTribunalTemple = $LUA_RESPAWN_AT_TRIBUNAL_TEMPLE/" "$cfg"

    # Collisions
    sed -i "s/^config\.enablePlayerCollision = .*/config.enablePlayerCollision = $LUA_ENABLE_PLAYER_COLLISION/" "$cfg"
    sed -i "s/^config\.enableActorCollision = .*/config.enableActorCollision = $LUA_ENABLE_ACTOR_COLLISION/" "$cfg"
    sed -i "s/^config\.enablePlacedObjectCollision = .*/config.enablePlacedObjectCollision = $LUA_ENABLE_PLACED_OBJECT_COLLISION/" "$cfg"

    # Time
    sed -i "s/^config\.passTimeWhenEmpty = .*/config.passTimeWhenEmpty = $LUA_PASS_TIME_WHEN_EMPTY/" "$cfg"
    sed -i "s/^config\.nightStartHour = .*/config.nightStartHour = $LUA_NIGHT_START_HOUR/" "$cfg"
    sed -i "s/^config\.nightEndHour = .*/config.nightEndHour = $LUA_NIGHT_END_HOUR/" "$cfg"

    # Stats Limits
    sed -i "s/^config\.maxAttributeValue = .*/config.maxAttributeValue = $LUA_MAX_ATTRIBUTE_VALUE/" "$cfg"
    sed -i "s/^config\.maxSpeedValue = .*/config.maxSpeedValue = $LUA_MAX_SPEED_VALUE/" "$cfg"
    sed -i "s/^config\.maxSkillValue = .*/config.maxSkillValue = $LUA_MAX_SKILL_VALUE/" "$cfg"
    sed -i "s/^config\.maxAcrobaticsValue = .*/config.maxAcrobaticsValue = $LUA_MAX_ACROBATICS_VALUE/" "$cfg"

    # Safety
    sed -i "s/^config\.enforceDataFiles = .*/config.enforceDataFiles = $LUA_ENFORCE_DATA_FILES/" "$cfg"
    sed -i "s/^config\.ignoreScriptErrors = .*/config.ignoreScriptErrors = $LUA_IGNORE_SCRIPT_ERRORS/" "$cfg"

    # Append our marker (before return config) so future runs know not to overwrite
    sed -i "/^return config$/i $marker" "$cfg"

    ok "Lua config updated"
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
    if [[ "$ENABLE_PLUGINS" == "yes" || "$ENABLE_SERVER_SCRIPTS" == "yes" || "$ENABLE_WORLD" == "yes" || "$ENABLE_CHARACTERS" == "yes" ]]; then
        sed -i 's/#\(nginx:\)/\1/' "$compose"
        sed -i 's/#\(  image: nginx:alpine\)/  image: nginx:alpine/' "$compose"
        sed -i 's/#\(  ports:\)/  ports:/' "$compose"
        sed -i "s/#\(    - \"8085:80\"\)/    - \"8085:80\"/" "$compose"
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
        sed -i 's/#\(    - \.\/data\/players:\/mnt\/characters:ro\)/    - .\/data\/players:\/mnt\/characters:ro/' "$compose"
        sed -i 's/#\(    - \.\/data\/player:\/mnt\/characters:ro\)/    - .\/data\/player:\/mnt\/characters:ro/' "$compose"
        sed -i 's/#\(    - \.\/data\/cells:\/mnt\/cells:ro\)/    - .\/data\/cells:\/mnt\/cells:ro/' "$compose"
        sed -i 's/#\(    - \.\/data\/cell:\/mnt\/cells:ro\)/    - .\/data\/cell:\/mnt\/cells:ro/' "$compose"
        sed -i 's/#\(  restart: unless-stopped\)/  restart: unless-stopped/' "$compose"
    fi

    # nginx.conf — uncomment the required location blocks
    local nginx="$dest/nginx.conf"

    # Helper: uncomment a block that starts with a marker comment
    # Usage: uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_PLUGINS"
    uncomment_nginx_block() {
        local file="$1"
        local marker="$2"
        # Remove the marker comment line
        sed -i "/^    #${marker}#$/d" "$file"
        # Uncomment the location block (4 lines starting with "    #")
        sed -i '/^    #location \/get-/,/^    #}/s/^    #/    /' "$file"
    }

    # Update rate limits in zone declarations
    sed -i "s/^limit_req_zone.*zone=plugins:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=plugins:10m rate=${PLUGINS_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=server-scripts:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=server-scripts:10m rate=${SERVER_SCRIPTS_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=world:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=world:10m rate=${WORLD_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=characters:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=characters:10m rate=${CHARACTERS_RATE}r\/m;/" "$nginx"

    if [[ "$ENABLE_PLUGINS" == "yes" ]]; then
        uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_PLUGINS"
    fi

    if [[ "$ENABLE_SERVER_SCRIPTS" == "yes" ]]; then
        uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_SERVER_SCRIPTS"
    fi

    if [[ "$ENABLE_WORLD" == "yes" ]]; then
        uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_WORLD"
    fi

    if [[ "$ENABLE_CHARACTERS" == "yes" ]]; then
        uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_CHARACTERS"
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
            if [[ "$ENABLE_PLUGINS" == "yes" || "$ENABLE_SERVER_SCRIPTS" == "yes" || "$ENABLE_WORLD" == "yes" || "$ENABLE_CHARACTERS" == "yes" ]]; then
                ufw allow "8085/tcp" comment "TES3MP HTTP endpoints"
            fi
            ;;
        firewall-cmd)
            firewall-cmd --permanent --add-port="$TES3MP_PORT/udp"
            if [[ "$ENABLE_PLUGINS" == "yes" || "$ENABLE_SERVER_SCRIPTS" == "yes" || "$ENABLE_WORLD" == "yes" || "$ENABLE_CHARACTERS" == "yes" ]]; then
                firewall-cmd --permanent --add-port="8085/tcp"
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
    docker compose -f "$dest/docker-compose.yml" up -d --build 2>&1 || {
        err "Failed to start the container. Check the output above."
        exit 1
    }

    ok "Docker container started"

    # Run update_mods.sh to sync mods/scripts and generate required files
    info "Running update_mods.sh to initialise mods and scripts..."
    bash "$dest/update_mods.sh" 2>&1 || {
        warn "update_mods.sh failed — check mods/ and scripts/ directories"
    }

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
    echo "    /get-plugins:        $ENABLE_PLUGINS"
    echo "    /get-server-scripts: $ENABLE_SERVER_SCRIPTS"
    echo "    /get-world:          $ENABLE_WORLD"
    echo "    /get-characters:     $ENABLE_CHARACTERS"
    echo ""
    if [[ "$ENABLE_PLUGINS" == "yes" || "$ENABLE_SERVER_SCRIPTS" == "yes" || "$ENABLE_WORLD" == "yes" || "$ENABLE_CHARACTERS" == "yes" ]]; then
        echo "  HTTP port (endpoints): 8085"
    fi
    echo ""
    echo "  Lua config:"
    echo "    Game mode:      $LUA_GAME_MODE"
    echo "    Difficulty:     $LUA_DIFFICULTY"
    echo "    Sharing:        shareJournal=$LUA_SHARE_JOURNAL, shareBounty=$LUA_SHARE_BOUNTY, shareMapExploration=$LUA_SHARE_MAP_EXPLORATION"
    echo "    Collisions:     player=$LUA_ENABLE_PLAYER_COLLISION, actor=$LUA_ENABLE_ACTOR_COLLISION"
    echo ""
    echo "  Logs:        docker compose -f $dest/docker-compose.yml logs -f"
    echo "  Stop:        docker compose -f $dest/docker-compose.yml down"
    echo "  Restart:     docker compose -f $dest/docker-compose.yml restart"
    echo ""
    echo "  Config:      nano $dest/data/tes3mp-server-default.cfg"
    echo "  Lua config:  nano $dest/data/server/scripts/config.lua"
    echo "  Ban list:    nano $dest/data/server/data/banlist.json"
    echo "  Required data files: nano $dest/data/requiredDataFiles.json"
    echo ""
    echo "  After editing any config: docker compose restart"
    echo ""
    echo "  To sync plugins and scripts: bash $dest/update_mods.sh"
    echo "  Place server scripts in: server-scripts/"
    echo "  Place client scripts in: client-scripts/"
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
    gather_lua_options
    setup_files
    write_config
    write_lua_config
    configure_endpoints
    configure_firewall
    build_and_start
}

main "$@"
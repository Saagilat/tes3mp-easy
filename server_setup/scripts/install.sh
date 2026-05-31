#!/bin/bash
#
# install.sh — Interactive TES3MP Docker server installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server_setup/scripts/install.sh | bash
#
# Or download and run:
#   wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server_setup/scripts/install.sh
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
    read -r -p "Enable /get-mods? [y/N]: " ENABLE_MODS </dev/tty
    ENABLE_MODS="${ENABLE_MODS:-n}"
    case "${ENABLE_MODS,,}" in
        y|yes) ENABLE_MODS="yes" ;;
        *)     ENABLE_MODS="no" ;;
    esac

    read -r -p "Enable /get-players? [y/N]: " ENABLE_PLAYERS </dev/tty
    ENABLE_PLAYERS="${ENABLE_PLAYERS:-n}"
    case "${ENABLE_PLAYERS,,}" in
        y|yes) ENABLE_PLAYERS="yes" ;;
        *)     ENABLE_PLAYERS="no" ;;
    esac

    read -r -p "Enable /get-world? [y/N]: " ENABLE_WORLD </dev/tty
    ENABLE_WORLD="${ENABLE_WORLD:-n}"
    case "${ENABLE_WORLD,,}" in
        y|yes) ENABLE_WORLD="yes" ;;
        *)     ENABLE_WORLD="no" ;;
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

    PLAYERS_RATE="5"
    if [[ "$ENABLE_PLAYERS" == "yes" ]]; then
        read -r -p "  /get-players rate limit (req/min) [default: 5]: " input </dev/tty
        PLAYERS_RATE="${input:-5}"
    fi

    WORLD_RATE="5"
    if [[ "$ENABLE_WORLD" == "yes" ]]; then
        read -r -p "  /get-world rate limit (req/min) [default: 5]: " input </dev/tty
        WORLD_RATE="${input:-5}"
    fi

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
    local dest="/tes3mp-easy"
    
    # Create all required directories (mount points + scripts + backups + import)
    mkdir -p "$dest/players" \
             "$dest/world/cell" "$dest/world/world" "$dest/world/map" "$dest/world/recordstore" "$dest/world/custom" \
             "$dest/mods/plugins" "$dest/mods/scripts" \
             "$dest/configs" \
             "$dest/backups/mods" "$dest/backups/players" "$dest/backups/world" \
             "$dest/import-mods" "$dest/import-players" "$dest/import-world" \
             "$dest/scripts"
    chown -R root:root "$dest"

    cd "$dest"

    info "Downloading Dockerfile and configs from Saagilat/tes3mp-easy..."
    for f in tes3mp.dockerfile docker-compose.yml nginx.conf export.dockerfile export_server.sh entrypoint.sh; do
        wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server_setup/docker/$f" -O "$dest/$f"
    done
    chmod +x "$dest/entrypoint.sh"

    for f in package.sh import_mods.sh import_players.sh import_world.sh \
             deploy_mods.sh deploy_players.sh deploy_world.sh; do
        wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server_setup/scripts/$f" -O "$dest/scripts/$f"
    done
    chmod +x "$dest/scripts/"*.sh

    # Download management reference
    wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/docs/admin/management.md" -O "$dest/management.md"

    # Download TES3MP version file and extract URL (for Docker build ARG)
    local TES3MP_URL=""
    local version_url="https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server_setup/tes3mp-version.txt"
    local version_file=$(mktemp)
    if wget -q --show-progress "$version_url" -O "$version_file" 2>/dev/null; then
        TES3MP_URL=$(grep '^TES3MP_URL=' "$version_file" | head -1 | cut -d= -f2-)
    fi
    rm -f "$version_file"

    if [ -z "$TES3MP_URL" ]; then
        err "Failed to read TES3MP_URL from $version_url"
        exit 1
    fi

    # Write TES3MP_URL to .env for Docker build ARG
    echo "TES3MP_URL=$TES3MP_URL" > "$dest/.env"

    # Download sample config files from the repo (tes3mp-server-default.cfg, config.lua)
    wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server_setup/tes3mp-server-sample/server/tes3mp-server-default.cfg" \
        -O "$dest/configs/tes3mp-server-default.cfg" 2>/dev/null || {
        # Fallback: generate minimal config
        cat > "$dest/configs/tes3mp-server-default.cfg" << 'CFGEOF'
hostname = tes3mp
password =
serverPort = 25565
maximumPlayers = 4
enableDebug = false
logLevel = 0
CFGEOF
    }

    # Generate empty banlist.json
    cat > "$dest/configs/banlist.json" << 'BANEOF'
{
  "playerNames":[],
  "ipAddresses":[]
}
BANEOF

    # Download sample config.lua
    wget -q --show-progress "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server_setup/tes3mp-server-sample/server/scripts/config.lua" \
        -O "$dest/configs/config.lua" 2>/dev/null || {
        # Fallback: generate minimal config.lua
        cat > "$dest/configs/config.lua" << 'LUAEOF'
return {
    gameMode = "Default",
    difficulty = 0,
    loginTime = 60,
    maxClientsPerIP = 3,
    shareJournal = true,
    shareFactionRanks = true,
    shareFactionExpulsion = false,
    shareFactionReputation = true,
    shareTopics = true,
    shareBounty = false,
    shareReputation = true,
    shareMapExploration = false,
    shareVideos = true,
    allowConsole = false,
    allowBedRest = true,
    allowWildernessRest = true,
    allowWait = true,
    allowSuicideCommand = true,
    allowFixmeCommand = true,
    playersRespawn = true,
    deathTime = 5,
    deathPenaltyJailDays = 5,
    bountyResetOnDeath = false,
    bountyDeathPenalty = false,
    respawnAtImperialShrine = true,
    respawnAtTribunalTemple = true,
    enablePlayerCollision = true,
    enableActorCollision = true,
    enablePlacedObjectCollision = false,
    passTimeWhenEmpty = false,
    nightStartHour = 20,
    nightEndHour = 6,
    maxAttributeValue = 200,
    maxSpeedValue = 365,
    maxSkillValue = 200,
    maxAcrobaticsValue = 1200,
    enforceDataFiles = true,
    ignoreScriptErrors = false,
}
LUAEOF
    }

    ok "All files installed — mount points are in $dest/"
}

# ────────────────────────────────────────────────────────────
# 5. Generate server config from answers
# ────────────────────────────────────────────────────────────
write_config() {
    local dest="/tes3mp-easy/configs"
    local cfg="$dest/tes3mp-server-default.cfg"

    info "Generating $cfg from your answers..."

    # Replace hostname (case-insensitive, allows any whitespace around =)
    sed -i 's/^[[:space:]]*hostname[[:space:]]*=.*/hostname = '"$SERVER_NAME"'/i' "$cfg"
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

    # Replace serverPort (stored in .cfg, but docker-compose maps the external port)
    # docker-compose.yml port mapping is handled in configure_endpoints

    ok "Config updated"
}

# ────────────────────────────────────────────────────────────
# 5b. Generate Lua config from answers
# ────────────────────────────────────────────────────────────
write_lua_config() {
    local dest="/tes3mp-easy/configs"
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
    local dest="/tes3mp-easy"

    # docker-compose.yml
    local compose="$dest/docker-compose.yml"

    # Set TES3MP port
    sed -i "s/\"25565:25565\/udp\"/\"$TES3MP_PORT:25565\/udp\"/" "$compose"

    # Uncomment nginx service if at least one endpoint is enabled
    if [[ "$ENABLE_MODS" == "yes" || "$ENABLE_PLAYERS" == "yes" || "$ENABLE_WORLD" == "yes" ]]; then
        sed -i 's/#\(nginx:\)/\1/' "$compose"
        sed -i 's/#\(  image: nginx:alpine\)/  image: nginx:alpine/' "$compose"
        sed -i 's/#\(  ports:\)/  ports:/' "$compose"
        sed -i "s/#\(    - \"8085:80\"\)/    - \"8085:80\"/" "$compose"
        sed -i 's/#\(  volumes:\)/  volumes:/' "$compose"
        sed -i 's/#\(    - \.\/backups\/mods:\/usr\/share\/nginx\/html\/mods:ro\)/    - .\/backups\/mods:\/usr\/share\/nginx\/html\/mods:ro/' "$compose"
        sed -i 's/#\(    - \.\/nginx.conf:\/etc\/nginx\/conf\.d\/default\.conf:ro\)/    - .\/nginx.conf:\/etc\/nginx\/conf.d\/default.conf:ro/' "$compose"
        sed -i 's/#\(  restart: unless-stopped\)/  restart: unless-stopped/' "$compose"
    fi

    # Uncomment export service if /get-players or /get-world is enabled
    if [[ "$ENABLE_PLAYERS" == "yes" || "$ENABLE_WORLD" == "yes" ]]; then
        sed -i 's/#\(export:\)/\1/' "$compose"
        sed -i 's/#\(  build:\)/  build:/' "$compose"
        sed -i 's/#\(    context: \.\)/    context: ./' "$compose"
        sed -i 's/#\(    dockerfile: export\.dockerfile\)/    dockerfile: export.dockerfile/' "$compose"
        sed -i 's/#\(  volumes:\)/  volumes:/' "$compose"
        # Uncomment all 6 world sub-mounts for the export service
        sed -i 's/#\(    - \.\/players:\/mnt\/characters:ro\)/    - .\/players:\/mnt\/characters:ro/' "$compose"
        sed -i 's/#\(    - \.\/world\/cell:\/mnt\/world\/cell:ro\)/    - .\/world\/cell:\/mnt\/world\/cell:ro/' "$compose"
        sed -i 's/#\(    - \.\/world\/world:\/mnt\/world\/world:ro\)/    - .\/world\/world:\/mnt\/world\/world:ro/' "$compose"
        sed -i 's/#\(    - \.\/world\/map:\/mnt\/world\/map:ro\)/    - .\/world\/map:\/mnt\/world\/map:ro/' "$compose"
        sed -i 's/#\(    - \.\/world\/recordstore:\/mnt\/world\/recordstore:ro\)/    - .\/world\/recordstore:\/mnt\/world\/recordstore:ro/' "$compose"
        sed -i 's/#\(    - \.\/world\/custom:\/mnt\/world\/custom:ro\)/    - .\/world\/custom:\/mnt\/world\/custom:ro/' "$compose"
        sed -i 's/#\(  restart: unless-stopped\)/  restart: unless-stopped/' "$compose"
    fi

    # nginx.conf — uncomment the required location blocks
    local nginx="$dest/nginx.conf"

    # Helper: uncomment a block that starts with a marker comment
    uncomment_nginx_block() {
        local file="$1"
        local marker="$2"
        # Remove the marker comment line
        sed -i "/^    #${marker}#$/d" "$file"
        # Uncomment the location block (4 lines starting with "    #")
        sed -i '/^    #location \/get-/,/^    #}/s/^    #/    /' "$file"
    }

    # Update rate limits in zone declarations
    sed -i "s/^limit_req_zone.*zone=mods:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=mods:10m rate=${MODS_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=players:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=players:10m rate=${PLAYERS_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=world:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=world:10m rate=${WORLD_RATE}r\/m;/" "$nginx"

    if [[ "$ENABLE_MODS" == "yes" ]]; then
        uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_MODS"
    fi

    if [[ "$ENABLE_PLAYERS" == "yes" ]]; then
        uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_PLAYERS"
    fi

    if [[ "$ENABLE_WORLD" == "yes" ]]; then
        uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_WORLD"
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
            if [[ "$ENABLE_MODS" == "yes" || "$ENABLE_PLAYERS" == "yes" || "$ENABLE_WORLD" == "yes" ]]; then
                ufw allow "8085/tcp" comment "TES3MP HTTP endpoints"
            fi
            ;;
        firewall-cmd)
            firewall-cmd --permanent --add-port="$TES3MP_PORT/udp"
            if [[ "$ENABLE_MODS" == "yes" || "$ENABLE_PLAYERS" == "yes" || "$ENABLE_WORLD" == "yes" ]]; then
                firewall-cmd --permanent --add-port="8085/tcp"
            fi
            firewall-cmd --reload
            ;;
    esac

    ok "Ports opened in $fw"
}

# ────────────────────────────────────────────────────────────
# 8. Build Docker image, start, create init archives, deploy
# ────────────────────────────────────────────────────────────
build_and_start() {
    local dest="/tes3mp-easy"
    cd "$dest"

    info "Building Docker image (this may take a minute)..."
    docker compose -f "$dest/docker-compose.yml" up -d --build 2>&1 || {
        err "Failed to start the container. Check the output above."
        exit 1
    }

    ok "Docker container started"

    # --- Create init archives ---
    info "Creating initial (init) archives..."

    source "$dest/scripts/package.sh"

    # Init mods archive (empty plugins/ + empty scripts/ + requiredDataFiles.json)
    export PLUGINS_DIR="$dest/mods/plugins"
    export SERVER_SCRIPTS_DIR="$dest/mods/scripts"
    export ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")

    package_init_mods "$dest/backups/mods/init-$(date +%F_%H-%M-%S)-mods.tar.gz"

    # Init world archive (empty world subdirs)
    export WORLD_CELL_DIR="$dest/world/cell"
    export WORLD_WORLD_DIR="$dest/world/world"
    export WORLD_MAP_DIR="$dest/world/map"
    export WORLD_RECORDSTORE_DIR="$dest/world/recordstore"
    export WORLD_CUSTOM_DIR="$dest/world/custom"

    package_init_world "$dest/backups/world/init-$(date +%F_%H-%M-%S)-world.tar.gz"

    # Init players archive (empty players)
    export PLAYER_DIR="$dest/players"

    package_init_players "$dest/backups/players/init-$(date +%F_%H-%M-%S)-players.tar.gz"

    # Write current.txt for each type (pointing to the init archives)
    local latest_mods
    latest_mods=$(ls -t "$dest/backups/mods"/init-*-mods.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest_mods" ]; then
        local sha256
        sha256=$(sha256sum "$latest_mods" | cut -d' ' -f1)
        echo "$sha256 $(basename "$latest_mods")" > "$dest/backups/mods/current.txt"
        ok "Mods current.txt written"
    fi

    local latest_world
    latest_world=$(ls -t "$dest/backups/world"/init-*-world.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest_world" ]; then
        sha256=$(sha256sum "$latest_world" | cut -d' ' -f1)
        echo "$sha256 $(basename "$latest_world")" > "$dest/backups/world/current.txt"
        ok "World current.txt written"
    fi

    local latest_players
    latest_players=$(ls -t "$dest/backups/players"/init-*-players.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest_players" ]; then
        sha256=$(sha256sum "$latest_players" | cut -d' ' -f1)
        echo "$sha256 $(basename "$latest_players")" > "$dest/backups/players/current.txt"
        ok "Players current.txt written"
    fi

    # Call deploy scripts to apply the init archives (via --latest)
    info "Running initial deployment via deploy scripts..."

    cd "$dest"

    bash "$dest/scripts/deploy_mods.sh" --latest && ok "Initial mods deploy done" || warn "Initial mods deploy had issues"

    bash "$dest/scripts/deploy_world.sh" --latest && ok "Initial world deploy done" || warn "Initial world deploy had issues"

    bash "$dest/scripts/deploy_players.sh" --latest && ok "Initial players deploy done" || warn "Initial players deploy had issues"

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
    echo "    /get-mods:           $ENABLE_MODS"
    echo "    /get-players:        $ENABLE_PLAYERS"
    echo "    /get-world:          $ENABLE_WORLD"
    echo ""
    if [[ "$ENABLE_MODS" == "yes" || "$ENABLE_PLAYERS" == "yes" || "$ENABLE_WORLD" == "yes" ]]; then
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
    echo "  Config:      nano $dest/configs/tes3mp-server-default.cfg"
    echo "  Lua config:  nano $dest/configs/config.lua"
    echo "  Ban list:    nano $dest/configs/banlist.json"
    echo ""
    echo "  After editing any config: docker compose restart"
    echo ""
    echo "  To import mods: scp mods.tar.gz user@host:/tes3mp-easy/import-mods/"
    echo "                   && ssh user@host 'bash scripts/deploy_mods.sh --latest'"
    echo ""
    echo "  Custom server scripts:   $dest/mods/scripts/"
    echo "  Custom plugins:          $dest/mods/plugins/"
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
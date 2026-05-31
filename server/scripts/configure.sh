#!/bin/bash
#
# configure.sh — TES3MP Docker server configuration tool
#
# Can be run standalone to reconfigure an existing TES3MP server
# at /tes3mp-easy after it has been installed by install.sh.
# Or called from install.sh as the final configuration step.
#
# Usage:
#   bash configure.sh            # interactive mode
#   bash configure.sh --default  # non-interactive with defaults
#   bash configure.sh --test     # test mode (password=1234, all endpoints)
#   bash configure.sh --help     # show help
#

set -euo pipefail

# ────────────────────────────────────────────────────────────
# Source shared library
# ────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$(dirname "$SCRIPT_DIR")/common.sh"

# ────────────────────────────────────────────────────────────
# Argument parsing
# ────────────────────────────────────────────────────────────
NON_INTERACTIVE=false
TEST_MODE=false
DEST="/tes3mp-easy"

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Configure or reconfigure a TES3MP Docker server at $DEST.

Options:
  --default   Non-interactive mode with all default values.
              Skips all prompts and uses built-in defaults.
  --test      Like --default, but sets password to "1234" and
              enables all HTTP endpoints.
  --help      Show this help message and exit.

Without options, runs interactively.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --default)
                NON_INTERACTIVE=true
                shift
                ;;
            --test)
                NON_INTERACTIVE=true
                TEST_MODE=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            -*)
                err "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                err "Unexpected argument: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# ────────────────────────────────────────────────────────────
# Check that /tes3mp-easy exists
# ────────────────────────────────────────────────────────────
check_dest() {
    if [[ ! -d "$DEST" ]]; then
        err "$DEST does not exist."
        err "Run install.sh first to set up the server infrastructure."
        exit 1
    fi
}

# ────────────────────────────────────────────────────────────
# 3. Interactive questionnaire (TES3MP core)
# ────────────────────────────────────────────────────────────
set_defaults() {
    SERVER_NAME="tes3mp"
    SERVER_PASSWORD=""
    MAX_PLAYERS="4"
    TES3MP_PORT="25565"
    ENABLE_MODS="no"
    ENABLE_PLAYERS="no"
    ENABLE_WORLD="no"
    MODS_RATE="5"
    PLAYERS_RATE="5"
    WORLD_RATE="5"

    if [[ "$TEST_MODE" == "true" ]]; then
        SERVER_PASSWORD="1234"
        ENABLE_MODS="yes"
        ENABLE_PLAYERS="yes"
        ENABLE_WORLD="yes"
    fi
}

gather_options() {
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        set_defaults
        return 0
    fi

    echo ""
    echo "========================================"
    echo "  TES3MP Server Setup"
    echo "========================================"
    echo ""

    if [[ -c /dev/tty ]]; then
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
    else
        # No TTY — fail, because --default or --test should have been used
        err "Interactive input requested but no TTY available."
        err "Use --default or --test for non-interactive mode."
        exit 1
    fi
}

# ────────────────────────────────────────────────────────────
# 3b. Interactive questionnaire (config.lua)
# ────────────────────────────────────────────────────────────
set_lua_defaults() {
    LUA_GAME_MODE="Default"
    LUA_DIFFICULTY="0"
    LUA_LOGIN_TIME="60"
    LUA_MAX_CLIENTS_PER_IP="3"
    LUA_SHARE_JOURNAL="true"
    LUA_SHARE_FACTION_RANKS="true"
    LUA_SHARE_FACTION_EXPULSION="false"
    LUA_SHARE_FACTION_REPUTATION="true"
    LUA_SHARE_TOPICS="true"
    LUA_SHARE_BOUNTY="false"
    LUA_SHARE_REPUTATION="true"
    LUA_SHARE_MAP_EXPLORATION="false"
    LUA_SHARE_VIDEOS="true"
    LUA_ALLOW_CONSOLE="false"
    LUA_ALLOW_BED_REST="true"
    LUA_ALLOW_WILDERNESS_REST="true"
    LUA_ALLOW_WAIT="true"
    LUA_ALLOW_SUICIDE_COMMAND="true"
    LUA_ALLOW_FIXME_COMMAND="true"
    LUA_PLAYERS_RESPAWN="true"
    LUA_DEATH_TIME="5"
    LUA_DEATH_PENALTY_JAIL_DAYS="5"
    LUA_BOUNTY_RESET_ON_DEATH="false"
    LUA_BOUNTY_DEATH_PENALTY="false"
    LUA_RESPAWN_AT_IMPERIAL_SHRINE="true"
    LUA_RESPAWN_AT_TRIBUNAL_TEMPLE="true"
    LUA_ENABLE_PLAYER_COLLISION="true"
    LUA_ENABLE_ACTOR_COLLISION="true"
    LUA_ENABLE_PLACED_OBJECT_COLLISION="false"
    LUA_PASS_TIME_WHEN_EMPTY="false"
    LUA_NIGHT_START_HOUR="20"
    LUA_NIGHT_END_HOUR="6"
    LUA_MAX_ATTRIBUTE_VALUE="200"
    LUA_MAX_SPEED_VALUE="365"
    LUA_MAX_SKILL_VALUE="200"
    LUA_MAX_ACROBATICS_VALUE="1200"
    LUA_ENFORCE_DATA_FILES="true"
    LUA_IGNORE_SCRIPT_ERRORS="false"
}

gather_lua_options() {
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        set_lua_defaults
        return 0
    fi

    if [[ ! -c /dev/tty ]]; then
        err "Interactive input requested but no TTY available."
        err "Use --default or --test for non-interactive mode."
        exit 1
    fi

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
# 5. Generate server config from answers
# ────────────────────────────────────────────────────────────
write_config() {
    local dest="$DEST/configs"
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

    ok "Config updated"
}

# ────────────────────────────────────────────────────────────
# 5b. Generate Lua config from answers
# ────────────────────────────────────────────────────────────
write_lua_config() {
    local dest="$DEST/configs"
    local cfg="$dest/config.lua"
    local marker="-- configure.sh config"

    # If config already has our marker — overwrite
    info "Generating $cfg from your answers..."

    sed -i "s/^config\.gameMode = .*/config.gameMode = \"$LUA_GAME_MODE\"/" "$cfg"
    sed -i "s/^config\.difficulty = .*/config.difficulty = $LUA_DIFFICULTY/" "$cfg"
    sed -i "s/^config\.loginTime = .*/config.loginTime = $LUA_LOGIN_TIME/" "$cfg"
    sed -i "s/^config\.maxClientsPerIP = .*/config.maxClientsPerIP = $LUA_MAX_CLIENTS_PER_IP/" "$cfg"

    sed -i "s/^config\.shareJournal = .*/config.shareJournal = $LUA_SHARE_JOURNAL/" "$cfg"
    sed -i "s/^config\.shareFactionRanks = .*/config.shareFactionRanks = $LUA_SHARE_FACTION_RANKS/" "$cfg"
    sed -i "s/^config\.shareFactionExpulsion = .*/config.shareFactionExpulsion = $LUA_SHARE_FACTION_EXPULSION/" "$cfg"
    sed -i "s/^config\.shareFactionReputation = .*/config.shareFactionReputation = $LUA_SHARE_FACTION_REPUTATION/" "$cfg"
    sed -i "s/^config\.shareTopics = .*/config.shareTopics = $LUA_SHARE_TOPICS/" "$cfg"
    sed -i "s/^config\.shareBounty = .*/config.shareBounty = $LUA_SHARE_BOUNTY/" "$cfg"
    sed -i "s/^config\.shareReputation = .*/config.shareReputation = $LUA_SHARE_REPUTATION/" "$cfg"
    sed -i "s/^config\.shareMapExploration = .*/config.shareMapExploration = $LUA_SHARE_MAP_EXPLORATION/" "$cfg"
    sed -i "s/^config\.shareVideos = .*/config.shareVideos = $LUA_SHARE_VIDEOS/" "$cfg"

    sed -i "s/^config\.allowConsole = .*/config.allowConsole = $LUA_ALLOW_CONSOLE/" "$cfg"
    sed -i "s/^config\.allowBedRest = .*/config.allowBedRest = $LUA_ALLOW_BED_REST/" "$cfg"
    sed -i "s/^config\.allowWildernessRest = .*/config.allowWildernessRest = $LUA_ALLOW_WILDERNESS_REST/" "$cfg"
    sed -i "s/^config\.allowWait = .*/config.allowWait = $LUA_ALLOW_WAIT/" "$cfg"
    sed -i "s/^config\.allowSuicideCommand = .*/config.allowSuicideCommand = $LUA_ALLOW_SUICIDE_COMMAND/" "$cfg"
    sed -i "s/^config\.allowFixmeCommand = .*/config.allowFixmeCommand = $LUA_ALLOW_FIXME_COMMAND/" "$cfg"

    sed -i "s/^config\.playersRespawn = .*/config.playersRespawn = $LUA_PLAYERS_RESPAWN/" "$cfg"
    sed -i "s/^config\.deathTime = .*/config.deathTime = $LUA_DEATH_TIME/" "$cfg"
    sed -i "s/^config\.deathPenaltyJailDays = .*/config.deathPenaltyJailDays = $LUA_DEATH_PENALTY_JAIL_DAYS/" "$cfg"
    sed -i "s/^config\.bountyResetOnDeath = .*/config.bountyResetOnDeath = $LUA_BOUNTY_RESET_ON_DEATH/" "$cfg"
    sed -i "s/^config\.bountyDeathPenalty = .*/config.bountyDeathPenalty = $LUA_BOUNTY_DEATH_PENALTY/" "$cfg"
    sed -i "s/^config\.respawnAtImperialShrine = .*/config.respawnAtImperialShrine = $LUA_RESPAWN_AT_IMPERIAL_SHRINE/" "$cfg"
    sed -i "s/^config\.respawnAtTribunalTemple = .*/config.respawnAtTribunalTemple = $LUA_RESPAWN_AT_TRIBUNAL_TEMPLE/" "$cfg"

    sed -i "s/^config\.enablePlayerCollision = .*/config.enablePlayerCollision = $LUA_ENABLE_PLAYER_COLLISION/" "$cfg"
    sed -i "s/^config\.enableActorCollision = .*/config.enableActorCollision = $LUA_ENABLE_ACTOR_COLLISION/" "$cfg"
    sed -i "s/^config\.enablePlacedObjectCollision = .*/config.enablePlacedObjectCollision = $LUA_ENABLE_PLACED_OBJECT_COLLISION/" "$cfg"

    sed -i "s/^config\.passTimeWhenEmpty = .*/config.passTimeWhenEmpty = $LUA_PASS_TIME_WHEN_EMPTY/" "$cfg"
    sed -i "s/^config\.nightStartHour = .*/config.nightStartHour = $LUA_NIGHT_START_HOUR/" "$cfg"
    sed -i "s/^config\.nightEndHour = .*/config.nightEndHour = $LUA_NIGHT_END_HOUR/" "$cfg"

    sed -i "s/^config\.maxAttributeValue = .*/config.maxAttributeValue = $LUA_MAX_ATTRIBUTE_VALUE/" "$cfg"
    sed -i "s/^config\.maxSpeedValue = .*/config.maxSpeedValue = $LUA_MAX_SPEED_VALUE/" "$cfg"
    sed -i "s/^config\.maxSkillValue = .*/config.maxSkillValue = $LUA_MAX_SKILL_VALUE/" "$cfg"
    sed -i "s/^config\.maxAcrobaticsValue = .*/config.maxAcrobaticsValue = $LUA_MAX_ACROBATICS_VALUE/" "$cfg"

    sed -i "s/^config\.enforceDataFiles = .*/config.enforceDataFiles = $LUA_ENFORCE_DATA_FILES/" "$cfg"
    sed -i "s/^config\.ignoreScriptErrors = .*/config.ignoreScriptErrors = $LUA_IGNORE_SCRIPT_ERRORS/" "$cfg"

    # Append our marker (before return config)
    sed -i "/^return config$/i $marker" "$cfg"

    ok "Lua config updated"
}

# ────────────────────────────────────────────────────────────
# 6. Configure nginx.conf and docker-compose.yml based on answers
# ────────────────────────────────────────────────────────────
configure_endpoints() {
    local compose="$DEST/docker-compose.yml"
    local nginx="$DEST/nginx.conf"

    # Set TES3MP port
    sed -i "s/\"25565:25565\/udp\"/\"$TES3MP_PORT:25565\/udp\"/" "$compose"

    # Update rate limits in nginx.conf
    sed -i "s/^limit_req_zone.*zone=mods:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=mods:10m rate=${MODS_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=players:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=players:10m rate=${PLAYERS_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=world:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=world:10m rate=${WORLD_RATE}r\/m;/" "$nginx"

    # Uncomment the required location blocks in nginx.conf
    uncomment_nginx_block() {
        local file="$1"
        local marker="$2"
        sed -i "/^    #${marker}#$/d" "$file"
        sed -i '/^    #location \/get-/,/^    #}/s/^    #/    /' "$file"
    }

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

    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        info "Non-interactive mode — opening ports in $fw automatically..."
        OPEN_FW="y"
    else
        if [[ ! -c /dev/tty ]]; then
            info "No TTY available — skipping firewall config."
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
    fi

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
# Helper: Extract missing files from Docker image to host
# ────────────────────────────────────────────────────────────
extract_missing_files() {
    local dest="$DEST"
    local image="tes3mp-tes3mp:latest"

    info "Extracting missing config files from Docker image..."

    local compose="$dest/docker-compose.yml"
    local temp_container
    temp_container=$(docker create "$image" 2>/dev/null) || {
        warn "Could not create temp container from $image — config files may be missing"
        return 1
    }

    grep -E '^\s+- \.\/' "$compose" | while IFS= read -r line; do
        local host_container
        host_container=$(echo "$line" | sed 's/^[[:space:]]*- //')
        local host_path="${host_container%%:*}"
        local container_path="${host_container##*:}"

        [[ "$host_path" == */ ]] && continue
        [ -f "$dest/$host_path" ] && continue

        local full_host_path="$dest/$host_path"
        mkdir -p "$(dirname "$full_host_path")"
        if docker cp "$temp_container:$container_path" "$full_host_path" 2>/dev/null; then
            echo "  [OK] Extracted: $container_path → $host_path"
        else
            echo "  [SKIP] Not found in image: $container_path"
        fi
    done

    docker rm "$temp_container" >/dev/null 2>&1 || true
    ok "Config files extracted"
}

# ────────────────────────────────────────────────────────────
# Apply configs, start containers, init archives, deploy
# ────────────────────────────────────────────────────────────
apply_and_start() {
    pushd "$DEST" >/dev/null || { err "Cannot cd to $DEST"; exit 1; }

    # Extract missing config files from Docker image
    extract_missing_files "$DEST"

    # Generate banlist.json and customScripts.lua if missing
    if [ ! -f "$DEST/configs/banlist.json" ]; then
        cat > "$DEST/configs/banlist.json" << 'BANEOF'
{
  "playerNames":[],
  "ipAddresses":[]
}
BANEOF
        ok "banlist.json generated"
    fi

    if [ ! -f "$DEST/configs/customScripts.lua" ]; then
        cat > "$DEST/configs/customScripts.lua" << 'LUAEOF'
-- This file is auto-generated by configure.sh
LUAEOF
        ok "customScripts.lua generated"
    fi

    # Apply config
    write_config
    write_lua_config

    # Start containers (build should have been done by install.sh)
    info "Starting containers..."
    local compose_cmd="docker compose -f \"$DEST/docker-compose.yml\""
    if [[ "$ENABLE_MODS" == "yes" || "$ENABLE_PLAYERS" == "yes" || "$ENABLE_WORLD" == "yes" ]]; then
        compose_cmd="$compose_cmd --profile enable-endpoints"
    fi
    eval "$compose_cmd up -d 2>&1" || {
        err "Failed to start the container. Check the output above."
        popd >/dev/null || true
        exit 1
    }
    ok "Docker container started"

    # Create init archives
    info "Creating initial (init) archives..."

    if [[ ! -f "$DEST/scripts/package.sh" ]]; then
        err "package.sh not found in $DEST/scripts/"
        popd >/dev/null || true
        exit 1
    fi
    source "$DEST/scripts/package.sh"

    export PLUGINS_DIR="$DEST/mods/plugins"
    export SERVER_SCRIPTS_DIR="$DEST/mods/scripts"
    export ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")

    package_init_mods "$DEST/backups/mods/init-$(date +%F_%H-%M-%S)-mods.tar.gz"

    export WORLD_CELL_DIR="$DEST/world/cell"
    export WORLD_WORLD_DIR="$DEST/world/world"
    export WORLD_MAP_DIR="$DEST/world/map"
    export WORLD_RECORDSTORE_DIR="$DEST/world/recordstore"
    export WORLD_CUSTOM_DIR="$DEST/world/custom"

    package_init_world "$DEST/backups/world/init-$(date +%F_%H-%M-%S)-world.tar.gz"

    export PLAYER_DIR="$DEST/players"

    package_init_players "$DEST/backups/players/init-$(date +%F_%H-%M-%S)-players.tar.gz"

    local latest_mods
    latest_mods=$(ls -t "$DEST/backups/mods"/init-*-mods.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest_mods" ]; then
        local sha256
        sha256=$(sha256sum "$latest_mods" | cut -d' ' -f1)
        echo "$sha256 $(basename "$latest_mods")" > "$DEST/backups/mods/current.txt"
        ok "Mods current.txt written"
    fi

    local latest_world
    latest_world=$(ls -t "$DEST/backups/world"/init-*-world.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest_world" ]; then
        sha256=$(sha256sum "$latest_world" | cut -d' ' -f1)
        echo "$sha256 $(basename "$latest_world")" > "$DEST/backups/world/current.txt"
        ok "World current.txt written"
    fi

    local latest_players
    latest_players=$(ls -t "$DEST/backups/players"/init-*-players.tar.gz 2>/dev/null | head -1)
    if [ -n "$latest_players" ]; then
        sha256=$(sha256sum "$latest_players" | cut -d' ' -f1)
        echo "$sha256 $(basename "$latest_players")" > "$DEST/backups/players/current.txt"
        ok "Players current.txt written"
    fi

    info "Running initial deployment via deploy scripts..."

    bash "$DEST/scripts/deploy_mods.sh" --latest && ok "Initial mods deploy done" || warn "Initial mods deploy had issues"
    bash "$DEST/scripts/deploy_world.sh" --latest && ok "Initial world deploy done" || warn "Initial world deploy had issues"
    bash "$DEST/scripts/deploy_players.sh" --latest && ok "Initial players deploy done" || warn "Initial players deploy had issues"

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
    echo "  Logs:        docker compose -f $DEST/docker-compose.yml logs -f"
    echo "  Stop:        docker compose -f $DEST/docker-compose.yml down"
    echo "  Restart:     docker compose -f $DEST/docker-compose.yml restart"
    echo ""
    echo "  Config:      nano $DEST/configs/tes3mp-server-default.cfg"
    echo "  Lua config:  nano $DEST/configs/config.lua"
    echo "  Ban list:    nano $DEST/configs/banlist.json"
    echo ""
    echo "  After editing any config: docker compose restart"
    echo ""
    echo "  Custom server scripts:   $DEST/mods/scripts/"
    echo "  Custom plugins:          $DEST/mods/plugins/"
    echo ""

    popd >/dev/null || true
}

# ────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────
main() {
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║   TES3MP Server Configuration        ║"
    echo "╚══════════════════════════════════════╝"
    echo ""

    parse_args "$@"

    if [[ "$TEST_MODE" == "true" ]]; then
        info "Running in TEST mode (password=1234, all endpoints enabled)"
    elif [[ "$NON_INTERACTIVE" == "true" ]]; then
        info "Running in non-interactive (default) mode"
    fi

    check_dest
    gather_options
    gather_lua_options
    configure_endpoints
    configure_firewall
    apply_and_start
}

main "$@"
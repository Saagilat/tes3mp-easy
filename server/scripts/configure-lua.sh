#!/bin/bash
#
# configure-lua.sh — configure TES3MP Lua settings (config.lua)
#
# Handles: game settings, sharing, permissions, collisions,
# time, stats limits, safety options.
#
# Usage:
#   bash configure-lua.sh               # interactive
#   bash configure-lua.sh --default     # non-interactive with defaults
#   bash configure-lua.sh --help        # show help
#

set -euo pipefail

# ────────────────────────────────────────────────────────────
# Source shared library
# ────────────────────────────────────────────────────────────
source /tes3mp-easy/common.sh
DEST="/tes3mp-easy"

# ────────────────────────────────────────────────────────────
# Argument parsing
# ────────────────────────────────────────────────────────────
NON_INTERACTIVE=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --default) NON_INTERACTIVE=true; shift ;;
            --help)    echo "Usage: $(basename "$0") [--default]"; exit 0 ;;
            *)         err "Unknown option: $1"; exit 1 ;;
        esac
    done
}

# ────────────────────────────────────────────────────────────
# Defaults
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

# ────────────────────────────────────────────────────────────
# Interactive prompts
# ────────────────────────────────────────────────────────────
gather_lua_options() {
    if [[ "$NON_INTERACTIVE" == "true" ]]; then
        set_lua_defaults
        return 0
    fi

    echo ""
    echo "========================================"
    echo "  Lua Config (config.lua) Settings"
    echo "========================================"
    echo ""

    local input=""

    # Game settings
    echo "--- Game Settings ---"
    echo ""
    read_input "Game mode (displayed in server browser) [default: Default]: " LUA_GAME_MODE "Default"
    read_input "Difficulty (-100..100) [default: 0]: " LUA_DIFFICULTY "0"
    read_input "Login time (seconds) [default: 60]: " LUA_LOGIN_TIME "60"
    read_input "Max clients per IP [default: 3]: " LUA_MAX_CLIENTS_PER_IP "3"

    # Sharing
    echo ""
    echo "--- Sharing ---"
    echo ""
    read_input "Share journal (quests are shared) [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_SHARE_JOURNAL="true" ;; *) LUA_SHARE_JOURNAL="false" ;; esac

    read_input "Share faction ranks [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_SHARE_FACTION_RANKS="true" ;; *) LUA_SHARE_FACTION_RANKS="false" ;; esac

    read_input "Share faction expulsion [y/N]: " input "n"
    case "${input,,}" in y|yes) LUA_SHARE_FACTION_EXPULSION="true" ;; *) LUA_SHARE_FACTION_EXPULSION="false" ;; esac

    read_input "Share faction reputation [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_SHARE_FACTION_REPUTATION="true" ;; *) LUA_SHARE_FACTION_REPUTATION="false" ;; esac

    read_input "Share dialogue topics [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_SHARE_TOPICS="true" ;; *) LUA_SHARE_TOPICS="false" ;; esac

    read_input "Share bounty [y/N]: " input "n"
    case "${input,,}" in y|yes) LUA_SHARE_BOUNTY="true" ;; *) LUA_SHARE_BOUNTY="false" ;; esac

    read_input "Share reputation [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_SHARE_REPUTATION="true" ;; *) LUA_SHARE_REPUTATION="false" ;; esac

    read_input "Share map exploration [y/N]: " input "n"
    case "${input,,}" in y|yes) LUA_SHARE_MAP_EXPLORATION="true" ;; *) LUA_SHARE_MAP_EXPLORATION="false" ;; esac

    read_input "Share videos [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_SHARE_VIDEOS="true" ;; *) LUA_SHARE_VIDEOS="false" ;; esac

    # Permissions
    echo ""
    echo "--- Permissions ---"
    echo ""
    read_input "Allow console (~) [y/N]: " input "n"
    case "${input,,}" in y|yes) LUA_ALLOW_CONSOLE="true" ;; *) LUA_ALLOW_CONSOLE="false" ;; esac

    read_input "Allow bed rest [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_ALLOW_BED_REST="true" ;; *) LUA_ALLOW_BED_REST="false" ;; esac

    read_input "Allow wilderness rest [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_ALLOW_WILDERNESS_REST="true" ;; *) LUA_ALLOW_WILDERNESS_REST="false" ;; esac

    read_input "Allow wait [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_ALLOW_WAIT="true" ;; *) LUA_ALLOW_WAIT="false" ;; esac

    read_input "Allow /suicide command [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_ALLOW_SUICIDE_COMMAND="true" ;; *) LUA_ALLOW_SUICIDE_COMMAND="false" ;; esac

    read_input "Allow /fixme command [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_ALLOW_FIXME_COMMAND="true" ;; *) LUA_ALLOW_FIXME_COMMAND="false" ;; esac

    # Respawn & Death
    echo ""
    echo "--- Respawn & Death ---"
    echo ""
    read_input "Players respawn on death [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_PLAYERS_RESPAWN="true" ;; *) LUA_PLAYERS_RESPAWN="false" ;; esac

    read_input "Death time (seconds) [default: 5]: " LUA_DEATH_TIME "5"
    read_input "Jail days on death [default: 5]: " LUA_DEATH_PENALTY_JAIL_DAYS "5"

    read_input "Reset bounty on death [y/N]: " input "n"
    case "${input,,}" in y|yes) LUA_BOUNTY_RESET_ON_DEATH="true" ;; *) LUA_BOUNTY_RESET_ON_DEATH="false" ;; esac

    read_input "Bounty-based jail time on death [y/N]: " input "n"
    case "${input,,}" in y|yes) LUA_BOUNTY_DEATH_PENALTY="true" ;; *) LUA_BOUNTY_DEATH_PENALTY="false" ;; esac

    read_input "Respawn at Imperial shrine [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_RESPAWN_AT_IMPERIAL_SHRINE="true" ;; *) LUA_RESPAWN_AT_IMPERIAL_SHRINE="false" ;; esac

    read_input "Respawn at Tribunal temple [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_RESPAWN_AT_TRIBUNAL_TEMPLE="true" ;; *) LUA_RESPAWN_AT_TRIBUNAL_TEMPLE="false" ;; esac

    # Collisions
    echo ""
    echo "--- Collisions ---"
    echo ""
    read_input "Player-player collision [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_ENABLE_PLAYER_COLLISION="true" ;; *) LUA_ENABLE_PLAYER_COLLISION="false" ;; esac

    read_input "Actor-actor collision [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_ENABLE_ACTOR_COLLISION="true" ;; *) LUA_ENABLE_ACTOR_COLLISION="false" ;; esac

    read_input "Placed object collision [y/N]: " input "n"
    case "${input,,}" in y|yes) LUA_ENABLE_PLACED_OBJECT_COLLISION="true" ;; *) LUA_ENABLE_PLACED_OBJECT_COLLISION="false" ;; esac

    # Time
    echo ""
    echo "--- Time ---"
    echo ""
    read_input "Pass time when server is empty [y/N]: " input "n"
    case "${input,,}" in y|yes) LUA_PASS_TIME_WHEN_EMPTY="true" ;; *) LUA_PASS_TIME_WHEN_EMPTY="false" ;; esac

    read_input "Night start hour [default: 20]: " LUA_NIGHT_START_HOUR "20"
    read_input "Night end hour [default: 6]: " LUA_NIGHT_END_HOUR "6"

    # Stats Limits
    echo ""
    echo "--- Stats Limits ---"
    echo ""
    read_input "Max attribute value [default: 200]: " LUA_MAX_ATTRIBUTE_VALUE "200"
    read_input "Max Speed value [default: 365]: " LUA_MAX_SPEED_VALUE "365"
    read_input "Max skill value [default: 200]: " LUA_MAX_SKILL_VALUE "200"
    read_input "Max Acrobatics value [default: 1200]: " LUA_MAX_ACROBATICS_VALUE "1200"

    # Safety
    echo ""
    echo "--- Safety ---"
    echo ""
    read_input "Enforce same data files for all clients [Y/n]: " input "y"
    case "${input,,}" in y|yes) LUA_ENFORCE_DATA_FILES="true" ;; *) LUA_ENFORCE_DATA_FILES="false" ;; esac

    read_input "Ignore Lua script errors (dangerous) [y/N]: " input "n"
    case "${input,,}" in y|yes) LUA_IGNORE_SCRIPT_ERRORS="true" ;; *) LUA_IGNORE_SCRIPT_ERRORS="false" ;; esac
}

# ────────────────────────────────────────────────────────────
# Write Lua config
# ────────────────────────────────────────────────────────────
write_lua_config() {
    local cfg="$DEST/configs/config.lua"
    local marker="-- configure.sh config"

    info "Updating $cfg..."

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

    sed -i "/^return config$/i $marker" "$cfg"

    ok "Lua config updated"
}

# ────────────────────────────────────────────────────────────
# Main
# ────────────────────────────────────────────────────────────
main() {
    parse_args "$@"
    if [[ ! -d "$DEST" ]]; then
        err "$DEST does not exist. Run install.sh first."
        exit 1
    fi
    gather_lua_options
    write_lua_config
}

main "$@"
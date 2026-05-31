#!/bin/bash
#
# configure-basic.sh — configure TES3MP server core settings
#
# Handles: server name, password, port, HTTP endpoints, rate limits,
# nginx/docker-compose config, container start, init backups.
#
# Usage:
#   bash configure-basic.sh               # interactive
#   bash configure-basic.sh --default     # non-interactive with defaults
#   bash configure-basic.sh --test        # test mode (password=1234)
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
TEST_MODE=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --default) NON_INTERACTIVE=true; shift ;;
            --test)    NON_INTERACTIVE=true; TEST_MODE=true; shift ;;
            --help)    echo "Usage: $(basename "$0") [--default | --test]"; exit 0 ;;
            *)         err "Unknown option: $1"; exit 1 ;;
        esac
    done
}

# ────────────────────────────────────────────────────────────
# Defaults
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

# ────────────────────────────────────────────────────────────
# Interactive prompts
# ────────────────────────────────────────────────────────────
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

    if [[ ! -c /dev/tty ]]; then
        err "Interactive input requested but no TTY available."
        err "Use --default or --test for non-interactive mode."
        exit 1
    fi

    read_input "Server name [default: tes3mp]: " SERVER_NAME "tes3mp"
    read_input "Password (leave empty to disable) [default: (empty)]: " SERVER_PASSWORD ""
    read_input "Max players [default: 4]: " MAX_PLAYERS "4"

    echo ""
    echo "--- Port ---"
    echo "(If unsure, leave the default value)"
    echo ""

    read_input "TES3MP server port (UDP) [default: 25565]: " TES3MP_PORT "25565"

    echo ""
    echo "--- Endpoints ---"
    echo ""
    echo "The following optional HTTP endpoints give players access to"
    echo "server data. The HTTP port (8085) is only opened if at least"
    echo "one endpoint is enabled. Each endpoint is disabled by default."
    echo ""

    local input=""
    read_input "Enable /get-mods? [y/N]: " input "n"
    case "${input,,}" in y|yes) ENABLE_MODS="yes" ;; *) ENABLE_MODS="no" ;; esac

    read_input "Enable /get-players? [y/N]: " input "n"
    case "${input,,}" in y|yes) ENABLE_PLAYERS="yes" ;; *) ENABLE_PLAYERS="no" ;; esac

    read_input "Enable /get-world? [y/N]: " input "n"
    case "${input,,}" in y|yes) ENABLE_WORLD="yes" ;; *) ENABLE_WORLD="no" ;; esac

    # Rate limits
    echo ""
    echo "--- Rate limiting ---"
    echo "How many requests per minute can a single IP make to each endpoint."
    echo "Default: 5. Enter 0 to disable rate limiting."
    echo ""

    MODS_RATE="5"
    if [[ "$ENABLE_MODS" == "yes" ]]; then
        read_input "  /get-mods rate limit (req/min) [default: 5]: " MODS_RATE "5"
    fi

    PLAYERS_RATE="5"
    if [[ "$ENABLE_PLAYERS" == "yes" ]]; then
        read_input "  /get-players rate limit (req/min) [default: 5]: " PLAYERS_RATE "5"
    fi

    WORLD_RATE="5"
    if [[ "$ENABLE_WORLD" == "yes" ]]; then
        read_input "  /get-world rate limit (req/min) [default: 5]: " WORLD_RATE "5"
    fi
}

# ────────────────────────────────────────────────────────────
# Write server config
# ────────────────────────────────────────────────────────────
write_config() {
    local cfg="$DEST/configs/tes3mp-server-default.cfg"

    info "Updating $cfg..."

    sed -i 's/^[[:space:]]*hostname[[:space:]]*=.*/hostname = '"$SERVER_NAME"'/i' "$cfg"
    if ! grep -qi '^[[:space:]]*hostname[[:space:]]*=' "$cfg" 2>/dev/null; then
        echo "hostname = $SERVER_NAME" >> "$cfg"
    fi

    if [[ -z "$SERVER_PASSWORD" ]]; then
        sed -i 's/^[[:space:]]*password[[:space:]]*=.*/password =/i' "$cfg"
    else
        sed -i 's/^[[:space:]]*password[[:space:]]*=.*/password = '"$SERVER_PASSWORD"'/i' "$cfg"
    fi
    if ! grep -qi '^[[:space:]]*password[[:space:]]*=' "$cfg" 2>/dev/null; then
        echo "password =" >> "$cfg"
    fi

    sed -i 's/^[[:space:]]*maximumPlayers[[:space:]]*=.*/maximumPlayers = '"$MAX_PLAYERS"'/i' "$cfg"
    if ! grep -qi '^[[:space:]]*maximumPlayers[[:space:]]*=' "$cfg" 2>/dev/null; then
        echo "maximumPlayers = $MAX_PLAYERS" >> "$cfg"
    fi

    ok "Server config updated"
}

# ────────────────────────────────────────────────────────────
# Configure nginx and docker-compose
# ────────────────────────────────────────────────────────────
configure_endpoints() {
    local compose="$DEST/docker-compose.yml"
    local nginx="$DEST/nginx.conf"

    sed -i "s/\"25565:25565\/udp\"/\"$TES3MP_PORT:25565\/udp\"/" "$compose"

    sed -i "s/^limit_req_zone.*zone=mods:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=mods:10m rate=${MODS_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=players:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=players:10m rate=${PLAYERS_RATE}r\/m;/" "$nginx"
    sed -i "s/^limit_req_zone.*zone=world:[0-9]\+m rate=[0-9.]\+r\/m;/limit_req_zone \$binary_remote_addr zone=world:10m rate=${WORLD_RATE}r\/m;/" "$nginx"

    uncomment_nginx_block() {
        local file="$1"
        local marker="$2"
        sed -i "/^    #${marker}#$/d" "$file"
        sed -i '/^    #location \/get-/,/^    #}/s/^    #/    /' "$file"
    }

    [[ "$ENABLE_MODS" == "yes" ]]   && uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_MODS"
    [[ "$ENABLE_PLAYERS" == "yes" ]] && uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_PLAYERS"
    [[ "$ENABLE_WORLD" == "yes" ]]   && uncomment_nginx_block "$nginx" "UNCOMMENT_TO_ENABLE_GET_WORLD"
}

# ────────────────────────────────────────────────────────────
# Extract missing config files from Docker image
# ────────────────────────────────────────────────────────────
extract_configs() {
    local image="tes3mp-tes3mp:latest"
    local temp_container
    temp_container=$(docker create "$image" 2>/dev/null) || {
        warn "Could not create temp container from $image — config files may be missing"
        return 1
    }

    grep -E '^\s+- \.\/' "$DEST/docker-compose.yml" | while IFS= read -r line; do
        local host_container
        host_container=$(echo "$line" | sed 's/^[[:space:]]*- //')
        local host_path="${host_container%%:*}"
        local container_path="${host_container##*:}"

        [[ "$host_path" == */ ]] && continue
        [ -f "$DEST/$host_path" ] && continue

        local full_host_path="$DEST/$host_path"
        mkdir -p "$(dirname "$full_host_path")"
        docker cp "$temp_container:$container_path" "$full_host_path" 2>/dev/null || true
    done

    docker rm "$temp_container" >/dev/null 2>&1 || true
}

# ────────────────────────────────────────────────────────────
# Start containers and create init backups
# ────────────────────────────────────────────────────────────
apply_and_start() {
    pushd "$DEST" >/dev/null || { err "Cannot cd to $DEST"; exit 1; }

    # Extract missing config files from Docker image
    extract_configs

    # Generate banlist.json and customScripts.lua if missing
    [ ! -f "$DEST/configs/banlist.json" ] && cat > "$DEST/configs/banlist.json" << 'BANEOF'
{
  "playerNames":[],
  "ipAddresses":[]
}
BANEOF

    [ ! -f "$DEST/configs/customScripts.lua" ] && cat > "$DEST/configs/customScripts.lua" << 'LUAEOF'
-- Auto-generated by configure-basic.sh
LUAEOF

    write_config
    configure_endpoints

    # Start containers
    info "Starting containers..."
    local compose_cmd="docker compose -f \"$DEST/docker-compose.yml\""
    if [[ "$ENABLE_MODS" == "yes" || "$ENABLE_PLAYERS" == "yes" || "$ENABLE_WORLD" == "yes" ]]; then
        compose_cmd="$compose_cmd --profile enable-endpoints"
    fi
    eval "$compose_cmd up -d 2>&1" || {
        err "Failed to start the container."
        popd >/dev/null || true
        exit 1
    }
    ok "Docker container started"

    # Create init archives
    if [[ -f "$DEST/scripts/package.sh" ]]; then
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

        local latest
        latest=$(ls -t "$DEST/backups/mods"/init-*-mods.tar.gz 2>/dev/null | head -1)
        [ -n "$latest" ] && sha256sum "$latest" | awk '{print $1, $2}' > "$DEST/backups/mods/current.txt"
        latest=$(ls -t "$DEST/backups/world"/init-*-world.tar.gz 2>/dev/null | head -1)
        [ -n "$latest" ] && sha256sum "$latest" | awk '{print $1, $2}' > "$DEST/backups/world/current.txt"
        latest=$(ls -t "$DEST/backups/players"/init-*-players.tar.gz 2>/dev/null | head -1)
        [ -n "$latest" ] && sha256sum "$latest" | awk '{print $1, $2}' > "$DEST/backups/players/current.txt'

        bash "$DEST/scripts/deploy_mods.sh" --latest 2>/dev/null || true
        bash "$DEST/scripts/deploy_world.sh" --latest 2>/dev/null || true
        bash "$DEST/scripts/deploy_players.sh" --latest 2>/dev/null || true
    fi

    echo ""
    echo "  Server name:     $SERVER_NAME"
    echo "  Server password: ${SERVER_PASSWORD:-(not set)}"
    echo "  Max players:     $MAX_PLAYERS"
    echo "  TES3MP port:     $TES3MP_PORT"
    echo "  Endpoints:       mods=$ENABLE_MODS players=$ENABLE_PLAYERS world=$ENABLE_WORLD"
    echo ""

    popd >/dev/null || true
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
    gather_options
    apply_and_start
}

main "$@"
#!/bin/bash
#
# export_server.sh — lightweight HTTP server for TES3MP state exports
#
# Endpoints:
#   GET /list-backups/<type>       — JSON list of backup files (mods/state)
#   GET /download/<type>           — latest backup
#   GET /download/<type>?latest    — force new backup and return it
#   GET /download/<type>/<file>    — specific backup file
#
# Background: creates state backups every 5 minutes, cleans up >30 days old.
#
# Environment variables:
#   CHARACTERS_DIR     — path to players directory          (default: /mnt/characters)
#   WORLD_CELL_DIR     — path to world/cell directory       (default: /mnt/world/cell)
#   WORLD_WORLD_DIR    — path to world/world directory      (default: /mnt/world/world)
#   WORLD_MAP_DIR      — path to world/map directory        (default: /mnt/world/map)
#   WORLD_RECORDSTORE_DIR — path to world/recordstore dir   (default: /mnt/world/recordstore)
#   WORLD_CUSTOM_DIR   — path to world/custom directory     (default: /mnt/world/custom)
#   CACHE_DIR          — cache directory                    (default: /tmp/export_cache)
#   PORT               — listen port                        (default: 5000)
#   BACKUPS_DIR        — path to backups dir                (default: /mnt/backups)
#
# Dependencies: bash, tar, socat, jq

set -euo pipefail

CHARACTERS_DIR="${CHARACTERS_DIR:-/mnt/characters}"
WORLD_CELL_DIR="${WORLD_CELL_DIR:-/mnt/world/cell}"
WORLD_WORLD_DIR="${WORLD_WORLD_DIR:-/mnt/world/world}"
WORLD_MAP_DIR="${WORLD_MAP_DIR:-/mnt/world/map}"
WORLD_RECORDSTORE_DIR="${WORLD_RECORDSTORE_DIR:-/mnt/world/recordstore}"
WORLD_CUSTOM_DIR="${WORLD_CUSTOM_DIR:-/mnt/world/custom}"
CACHE_DIR="${CACHE_DIR:-/tmp/export_cache}"
PORT="${PORT:-5000}"
BACKUPS_DIR="${BACKUPS_DIR:-/mnt/backups}"

# Set up variables for package.sh
export PLAYER_DIR="$CHARACTERS_DIR"
export WORLD_CELL_DIR
export WORLD_WORLD_DIR
export WORLD_MAP_DIR
export WORLD_RECORDSTORE_DIR
export WORLD_CUSTOM_DIR
export BACKUPS_DIR

source /app/package.sh

mkdir -p "$CACHE_DIR"

# ─────────────────────────────────────────────
# JSON list of backups for a given type
# Delegates to list-backups.sh
# ─────────────────────────────────────────────
list_backups_json() {
    local type="$1"
    bash /app/list-backups.sh "$type" 2>/dev/null || echo '{"files":[],"current":null}'
}

# ─────────────────────────────────────────────
# Get the newest backup file for a type
# ─────────────────────────────────────────────
get_newest_backup() {
    local type="$1"
    local dir="$BACKUPS_DIR/$type"
    if [ -d "$dir" ]; then
        ls -t "$dir"/*.tar.gz 2>/dev/null | head -1 || true
    fi
}

# ─────────────────────────────────────────────
# Run export for a type (state only)
# ─────────────────────────────────────────────
run_export() {
    local type="$1"
    local timestamp
    timestamp=$(date +%F_%H-%M-%S)
    local dest_dir="$BACKUPS_DIR/$type"
    mkdir -p "$dest_dir"

    case "$type" in
        state)
            local archive_path="$dest_dir/export-${timestamp}-state.tar.gz"
            package_state "$archive_path" 2>/dev/null
            echo "$archive_path"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ─────────────────────────────────────────────
# Clean up backups older than N days
# ─────────────────────────────────────────────
cleanup_old_backups() {
    local type="$1"
    local max_days="${2:-30}"
    local dir="$BACKUPS_DIR/$type"
    [ -d "$dir" ] || return
    find "$dir" -maxdepth 1 -name "export-*.tar.gz" -mtime +"$max_days" -delete 2>/dev/null || true
}

# ─────────────────────────────────────────────
# Serve a file via HTTP
# ─────────────────────────────────────────────
_resolve_real_path() {
    local path="$1"
    local real

    real=$(realpath "$path" 2>/dev/null) && { echo "$real"; return; }
    real=$(readlink -f "$path" 2>/dev/null) && { echo "$real"; return; }

    if [ -L "$path" ]; then
        local link_target
        link_target=$(readlink "$path")
        local dir
        dir=$(dirname "$path")
        if [ "${link_target:0:1}" = "/" ]; then
            echo "$link_target"
        else
            echo "$dir/$link_target"
        fi
    else
        echo "$path"
    fi
}

serve_file() {
    local file_path="$1"

    file_path=$(_resolve_real_path "$file_path")

    local filename
    filename=$(basename "$file_path")

    if [ ! -f "$file_path" ]; then
        echo -ne "HTTP/1.1 404 Not Found\r\n"
        echo -ne "Content-Type: text/plain\r\n"
        echo -ne "Connection: close\r\n\r\n"
        echo -n "File not found"
        return
    fi

    local size
    size=$(stat -c %s "$file_path" 2>/dev/null || echo 0)

    echo -ne "HTTP/1.1 200 OK\r\n"
    echo -ne "Content-Type: application/gzip\r\n"
    echo -ne "Content-Disposition: attachment; filename=\"$filename\"\r\n"
    echo -ne "Content-Length: $size\r\n"
    echo -ne "Connection: close\r\n\r\n"
    cat "$file_path"
}

# ─────────────────────────────────────────────
# Send JSON response
# ─────────────────────────────────────────────
serve_json() {
    local json="$1"
    local size
    size=$(printf "%s" "$json" | wc -c)

    echo -ne "HTTP/1.1 200 OK\r\n"
    echo -ne "Content-Type: application/json\r\n"
    echo -ne "Content-Length: $size\r\n"
    echo -ne "Connection: close\r\n\r\n"
    printf "%s" "$json"
}

# ─────────────────────────────────────────────
# Send 404 JSON
# ─────────────────────────────────────────────
serve_404() {
    echo -ne "HTTP/1.1 404 Not Found\r\n"
    echo -ne "Content-Type: application/json\r\n"
    echo -ne "Connection: close\r\n\r\n"
    echo -n '{"error":"Not found"}'
}

# ─────────────────────────────────────────────
# Send 400 JSON
# ─────────────────────────────────────────────
serve_400() {
    echo -ne "HTTP/1.1 400 Bad Request\r\n"
    echo -ne "Content-Type: application/json\r\n"
    echo -ne "Connection: close\r\n\r\n"
    echo -n '{"error":"Bad request"}'
}

# ─────────────────────────────────────────────
# Request handler
# ─────────────────────────────────────────────
handle_request() {
    IFS=' ' read -r method path _ || true

    if [ "$method" != "GET" ]; then
        echo -ne "HTTP/1.1 405 Method Not Allowed\r\n"
        echo -ne "Content-Type: text/plain\r\n"
        echo -ne "Connection: close\r\n\r\n"
        echo -n "Method not allowed"
        return
    fi

    # Extract query parameter(s)
    local latest_flag=""
    case "$path" in
        *\?latest*) latest_flag="1" ;;
    esac

    # Remove query string
    path="${path%%\?*}"

    case "$path" in
        /list-backups/*)
            local type="${path#/list-backups/}"
            case "$type" in
                mods|state)
                    serve_json "$(list_backups_json "$type")"
                    ;;
                *)
                    serve_400
                    ;;
            esac
            ;;
        /download/mods)
            # Mods without filename: serve latest
            local file
            file=$(get_newest_backup "mods")
            if [ -n "$file" ]; then
                serve_file "$file"
            else
                serve_404
            fi
            ;;
        /download/state)
            # State without filename: serve latest, or force new with ?latest
            local file
            if [ -n "$latest_flag" ]; then
                file=$(run_export "state")
            else
                file=$(get_newest_backup "state")
            fi
            if [ -n "$file" ]; then
                serve_file "$file"
            else
                serve_404
            fi
            ;;
        /download/*)
            # /download/<type>/<filename>
            local rest="${path#/download/}"
            local type="${rest%%/*}"
            local filename="${rest#*/}"

            case "$type" in
                mods|state)
                    local file_path="$BACKUPS_DIR/$type/$filename"
                    local real_path
                    real_path=$(realpath "$file_path" 2>/dev/null || echo "")
                    local allowed_prefix
                    allowed_prefix=$(realpath "$BACKUPS_DIR/$type" 2>/dev/null || echo "")
                    if [ -z "$real_path" ] || [ -z "$allowed_prefix" ] || [ "${real_path##$allowed_prefix}" = "$real_path" ]; then
                        serve_404
                    else
                        serve_file "$real_path"
                    fi
                    ;;
                *)
                    serve_400
                    ;;
            esac
            ;;
        *)
            echo -ne "HTTP/1.1 404 Not Found\r\n"
            echo -ne "Content-Type: text/plain\r\n"
            echo -ne "Connection: close\r\n\r\n"
            echo -n "Not found"
            ;;
    esac
}

# ─────────────────────────────────────────────
# Background: periodic state backups every 5 minutes
# ─────────────────────────────────────────────
(
    while true; do
        sleep 300
        run_export "state" >/dev/null 2>&1 || true
        cleanup_old_backups "state" 30
    done
) &

echo "Export server listening on port $PORT" >&2

if [ $# -eq 0 ]; then
    socat TCP-LISTEN:"$PORT",reuseaddr,fork EXEC:"bash $0 request"
else
    handle_request
fi
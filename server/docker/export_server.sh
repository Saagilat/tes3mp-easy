#!/bin/bash
#
# export_server.sh — lightweight HTTP server for TES3MP player/world exports
#
# Endpoints:
#   GET /list-backups/<type>       — JSON list of backup files (mods/players/world)
#   GET /download/<type>           — latest backup (players/world: auto-export if stale)
#   GET /download/<type>/<file>    — specific backup file
#
# Environment variables:
#   CHARACTERS_DIR     — path to players directory          (default: /mnt/characters)
#   WORLD_CELL_DIR     — path to world/cell directory       (default: /mnt/world/cell)
#   WORLD_WORLD_DIR    — path to world/world directory      (default: /mnt/world/world)
#   WORLD_MAP_DIR      — path to world/map directory        (default: /mnt/world/map)
#   WORLD_RECORDSTORE_DIR — path to world/recordstore dir   (default: /mnt/world/recordstore)
#   WORLD_CUSTOM_DIR   — path to world/custom directory     (default: /mnt/world/custom)
#   CACHE_DIR          — cache directory                    (default: /tmp/export_cache)
#   CACHE_MINUTES      — cache TTL                          (default: 5)
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
CACHE_MINUTES="${CACHE_MINUTES:-5}"
PORT="${PORT:-5000}"
BACKUPS_DIR="${BACKUPS_DIR:-/mnt/backups}"
CACHE_TTL=$((CACHE_MINUTES * 60))

# Freshness threshold: 10 minutes
FRESHNESS_SECONDS=600

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
# Utility: URL decode
# ─────────────────────────────────────────────
urldecode() {
    local str="$1"
    printf '%b' "${str//%/\\x}"
}

# ─────────────────────────────────────────────
# JSON list of backups for a given type
# ─────────────────────────────────────────────
# Read current filename from current.txt for a given backup type
# Returns empty string if file doesn't exist
_get_current_filename() {
    local type="$1"
    local current_file="$BACKUPS_DIR/$type/current.txt"
    if [ -f "$current_file" ]; then
        local sha256 name
        read -r sha256 name < "$current_file" 2>/dev/null
        echo "$name"
    fi
}

list_backups_json() {
    local type="$1"  # mods, players, world
    local dir="$BACKUPS_DIR/$type"
    local tmp
    tmp=$(mktemp)

    # Determine current file name for this backup type
    local current_name
    current_name=$(_get_current_filename "$type")

    if [ -d "$dir" ]; then
        # List files sorted by mtime (newest first), output JSON
        # Format: [{"name":"file.tar.gz","mtime":"2025-01-01T12:00:00","size":12345,"current":true}]
        local first=1
        echo "[" > "$tmp"
        for f in $(ls -t "$dir"/*.tar.gz 2>/dev/null); do
            local name mtime size is_current
            name=$(basename "$f")
            mtime=$(date -u -d "@$(stat -c %Y "$f")" "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "null")
            size=$(stat -c %s "$f" 2>/dev/null || echo 0)
            [ "$first" -eq 0 ] && echo "," >> "$tmp"
            first=0
            if [ -n "$current_name" ] && [ "$name" = "$current_name" ]; then
                is_current="true"
            else
                is_current="false"
            fi
            printf '{"name":"%s","mtime":"%s","size":%s,"current":%s}' "$name" "$mtime" "$size" "$is_current" >> "$tmp"
        done
        echo "]" >> "$tmp"
    else
        echo "[]" > "$tmp"
    fi

    cat "$tmp"
    rm -f "$tmp"
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
# Get age of a file in seconds
# ─────────────────────────────────────────────
get_file_age() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "999999"
        return
    fi
    local now mtime
    now=$(date +%s)
    mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
    echo $((now - mtime))
}

# ─────────────────────────────────────────────
# Run export for a type (players or world)
# ─────────────────────────────────────────────
run_export() {
    local type="$1"
    local timestamp
    timestamp=$(date +%F_%H-%M-%S)
    local dest_dir="$BACKUPS_DIR/$type"
    mkdir -p "$dest_dir"

    case "$type" in
        players)
            local archive_path="$dest_dir/export-${timestamp}-players.tar.gz"
            package_players "$archive_path" 2>/dev/null
            echo "$archive_path"
            ;;
        world)
            local archive_path="$dest_dir/export-${timestamp}-world.tar.gz"
            package_world "$archive_path" 2>/dev/null
            echo "$archive_path"
            ;;
        *)
            echo ""
            ;;
    esac
}

# ─────────────────────────────────────────────
# Ensure a fresh backup exists; returns path to it
# For players/world: if newest >10min old, run export
# For mods: just return current.tar.gz or newest
# ─────────────────────────────────────────────
ensure_fresh_backup() {
    local type="$1"

    # For mods: read current.txt and return the real archive path
    if [ "$type" = "mods" ]; then
        local current_name
        current_name=$(_get_current_filename "mods")
        if [ -n "$current_name" ]; then
            local real_path="$BACKUPS_DIR/mods/$current_name"
            if [ -f "$real_path" ]; then
                echo "$real_path"
                return
            fi
        fi
        get_newest_backup "mods"
        return
    fi

    # For players/world: check freshness
    local newest
    newest=$(get_newest_backup "$type")

    if [ -z "$newest" ]; then
        # No backup at all — run export
        run_export "$type"
    else
        local age
        age=$(get_file_age "$newest")
        if [ "$age" -ge "$FRESHNESS_SECONDS" ]; then
            run_export "$type"
        else
            echo "$newest"
        fi
    fi
}

# ─────────────────────────────────────────────
# Serve a file via HTTP
# ─────────────────────────────────────────────
# Resolve symlinks to the real file path (portable approach)
_resolve_real_path() {
    local path="$1"
    local real

    # Try realpath first (GNU/coreutils)
    real=$(realpath "$path" 2>/dev/null) && { echo "$real"; return; }

    # Fallback: readlink -f (busybox)
    real=$(readlink -f "$path" 2>/dev/null) && { echo "$real"; return; }

    # Manual symlink resolution
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

    # Resolve symlinks so the real filename is used in Content-Disposition
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

    # Remove query string
    path="${path%%\?*}"

    case "$path" in
        /list-backups/*)
            local type="${path#/list-backups/}"
            case "$type" in
                mods|players|world)
                    serve_json "$(list_backups_json "$type")"
                    ;;
                *)
                    serve_400
                    ;;
            esac
            ;;
        /download/mods)
            # Mods without filename: serve current.tar.gz or newest
            local file
            file=$(ensure_fresh_backup "mods")
            if [ -n "$file" ]; then
                serve_file "$file"
            else
                serve_404
            fi
            ;;
        /download/players)
            # Players without filename: ensure fresh, serve newest
            local file
            file=$(ensure_fresh_backup "players")
            if [ -n "$file" ]; then
                serve_file "$file"
            else
                serve_404
            fi
            ;;
        /download/world)
            # World without filename: ensure fresh, serve newest
            local file
            file=$(ensure_fresh_backup "world")
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
            filename=$(urldecode "$filename")

            case "$type" in
                mods|players|world)
                    local file_path="$BACKUPS_DIR/$type/$filename"
                    # Security: prevent path traversal
                    # Resolve to real path and check it's under BACKUPS_DIR/$type/
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

echo "Export server listening on port $PORT" >&2

if [ $# -eq 0 ]; then
    socat TCP-LISTEN:"$PORT",reuseaddr,fork EXEC:"bash $0 request"
else
    handle_request
fi

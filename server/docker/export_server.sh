#!/bin/bash
#
# export_server.sh — lightweight HTTP server for TES3MP world/character exports
#
# Endpoints:
#   GET /get-world      — serves a tar.gz of the cells directory
#   GET /get-characters — serves a tar.gz of the characters directory
#
# Archives are cached for CACHE_MINUTES minutes to avoid regenerating
# on every request. The cache is invalidated after the TTL.
#
# Environment variables:
#   CHARACTERS_DIR — path to characters (default: /mnt/characters)
#   CELLS_DIR     — path to cells       (default: /mnt/cells)
#   CACHE_DIR     — cache directory     (default: /tmp/export_cache)
#   CACHE_MINUTES — cache TTL           (default: 10)
#   PORT          — listen port         (default: 5000)
#
# Dependencies: bash, tar, socat

set -euo pipefail

CHARACTERS_DIR="${CHARACTERS_DIR:-/mnt/characters}"
CELLS_DIR="${CELLS_DIR:-/mnt/cells}"
CACHE_DIR="${CACHE_DIR:-/tmp/export_cache}"
CACHE_MINUTES="${CACHE_MINUTES:-10}"
PORT="${PORT:-5000}"
CACHE_TTL=$((CACHE_MINUTES * 60))

mkdir -p "$CACHE_DIR"

# Read request from stdin, write response to stdout
handle_request() {
    # Read the HTTP request line
    IFS=' ' read -r method path _ || true

    if [ "$method" != "GET" ]; then
        echo -ne "HTTP/1.1 405 Method Not Allowed\r\n"
        echo -ne "Content-Type: text/plain\r\n"
        echo -ne "Connection: close\r\n\r\n"
        echo -n "Method not allowed"
        return
    fi

    case "$path" in
        /get-world)
            serve_archive "$CELLS_DIR" "world_state.tar.gz"
            ;;
        /get-characters)
            serve_archive "$CHARACTERS_DIR" "characters.tar.gz"
            ;;
        *)
            echo -ne "HTTP/1.1 404 Not Found\r\n"
            echo -ne "Content-Type: text/plain\r\n"
            echo -ne "Connection: close\r\n\r\n"
            echo -n "Not found"
            ;;
    esac
}

serve_archive() {
    local source_dir="$1"
    local archive_name="$2"
    local archive_path="$CACHE_DIR/$archive_name"

    # Rebuild if cache is stale or missing
    local rebuild=0
    if [ -f "$archive_path" ]; then
        local now mtime
        now=$(date +%s)
        mtime=$(stat -c %Y "$archive_path" 2>/dev/null || echo 0)
        if [ $((now - mtime)) -ge "$CACHE_TTL" ]; then
            rebuild=1
        fi
    else
        rebuild=1
    fi

    if [ "$rebuild" -eq 1 ]; then
        if [ -d "$source_dir" ] && [ -n "$(ls -A "$source_dir" 2>/dev/null)" ]; then
            tar czf "$archive_path" -C "$source_dir" . 2>/dev/null
        else
            tar czf "$archive_path" --files-from /dev/null 2>/dev/null
        fi
    fi

    if [ ! -f "$archive_path" ]; then
        echo -ne "HTTP/1.1 500 Internal Server Error\r\n"
        echo -ne "Content-Type: text/plain\r\n"
        echo -ne "Connection: close\r\n\r\n"
        echo -n "Export error"
        return
    fi

    local size
    size=$(stat -c %s "$archive_path" 2>/dev/null || echo 0)

    echo -ne "HTTP/1.1 200 OK\r\n"
    echo -ne "Content-Type: application/gzip\r\n"
    echo -ne "Content-Disposition: attachment; filename=\"$archive_name\"\r\n"
    echo -ne "Content-Length: $size\r\n"
    echo -ne "Connection: close\r\n\r\n"
    cat "$archive_path"
}

echo "Export server listening on port $PORT" >&2

# socat: for each connection, run this script in request-handler mode
if [ $# -eq 0 ]; then
    # Normal mode: start the server loop
    socat TCP-LISTEN:"$PORT",reuseaddr,fork EXEC:"bash $0 request"
else
    # Request handler mode: read from stdin, write to stdout
    handle_request
fi
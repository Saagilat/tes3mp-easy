#!/bin/bash
#
# export_server.sh — lightweight HTTP server for TES3MP player/cell exports
#
# Endpoints:
#   GET /get-players — serves a tar.gz of the player/ directory (cached 5 min)
#   GET /get-cells   — serves a tar.gz of the cell/ directory (cached 5 min)
#
# Environment variables:
#   CHARACTERS_DIR — path to players directory    (default: /mnt/characters)
#   CELLS_DIR      — path to cells directory      (default: /mnt/cells)
#   CACHE_DIR      — cache directory              (default: /tmp/export_cache)
#   CACHE_MINUTES  — cache TTL                    (default: 5)
#   PORT           — listen port                  (default: 5000)
#
# Dependencies: bash, tar, socat

set -euo pipefail

CHARACTERS_DIR="${CHARACTERS_DIR:-/mnt/characters}"
CELLS_DIR="${CELLS_DIR:-/mnt/cells}"
CACHE_DIR="${CACHE_DIR:-/tmp/export_cache}"
CACHE_MINUTES="${CACHE_MINUTES:-5}"
PORT="${PORT:-5000}"
CACHE_TTL=$((CACHE_MINUTES * 60))

# Set up variables for package.sh
export PLAYER_DIR="$CHARACTERS_DIR"
export CELL_DIR="$CELLS_DIR"

source /app/package.sh

mkdir -p "$CACHE_DIR"

# Build and cache an archive using the provided packaging function
# Usage: build_cached_archive <archive_name> <package_function>
build_cached_archive() {
    local archive_name="$1"
    local package_func="$2"
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
        "$package_func" "$archive_path" 2>/dev/null
    fi
}

serve_archive() {
    local archive_name="$1"
    local package_func="$2"

    build_cached_archive "$archive_name" "$package_func"

    local archive_path="$CACHE_DIR/$archive_name"

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
        /get-players)
            serve_archive "players.tar.gz" "package_players"
            ;;
        /get-cells)
            serve_archive "cells.tar.gz" "package_cells"
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
    # Normal mode: start the server loop
    socat TCP-LISTEN:"$PORT",reuseaddr,fork EXEC:"bash $0 request"
else
    # Request handler mode: read from stdin, write to stdout
    handle_request
fi
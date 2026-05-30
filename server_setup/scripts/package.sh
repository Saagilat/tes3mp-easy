#!/bin/bash
#
# package.sh — Shared packaging library for TES3MP server data
#
# This script is meant to be sourced (not executed directly).
#
# Variable requirements per function:
#   package_mods_and_scripts()    — PLUGINS_DIR, SERVER_SCRIPTS_DIR, ORIGINAL_FILES
#   package_players()             — PLAYER_DIR
#   package_cells()               — CELL_DIR
#   (package_world removed — use package_players + package_cells separately)
#
# Functions provided:
#   package_mods_and_scripts(output_file)           — plugins + scripts + requiredDataFiles.json
#   package_players(output_file)                    — player/ only
#   package_cells(output_file)                      — cell/ only
#

# ────────────────────────────────────────────────────────────────
# Internal: Check disk space before packaging
#   Usage: _check_disk_space <output_file> <dir1> [dir2 ...]
#   Exits with code 1 if there isn't enough space (2x estimated size)
# ────────────────────────────────────────────────────────────────
_check_disk_space() {
    local output_file="$1"
    shift
    local dirs=("$@")

    local backup_dir
    backup_dir="$(dirname "$output_file")"

    if [ ! -d "$backup_dir" ]; then
        echo "[package.sh] Creating output directory: $backup_dir"
        mkdir -p "$backup_dir"
    fi

    local total_size=0
    local dir

    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
            local size
            size=$(du -sb "$dir" 2>/dev/null | cut -f1)
            total_size=$((total_size + size))
        fi
    done

    # Multiply by 2 for safety margin
    local needed=$((total_size * 2))
    # Convert to KB for df comparison
    local needed_kb=$((needed / 1024))

    local free_kb
    free_kb=$(df --output=avail "$backup_dir" 2>/dev/null | tail -1)

    if [ -z "$free_kb" ] || [ "$free_kb" -lt "$needed_kb" ]; then
        echo "[package.sh] ERROR: Not enough disk space for backup." >&2
        echo "  Estimated space needed: $((needed / 1024 / 1024)) MB (with 2x margin)" >&2
        echo "  Available in $backup_dir: $((free_kb / 1024)) MB" >&2
        echo "  Free up space (e.g. remove old backups from $backup_dir) and try again." >&2
        exit 1
    fi

    echo "[package.sh] Disk space OK: $((free_kb / 1024)) MB available, ~$((needed / 1024 / 1024)) MB needed"
}

# ────────────────────────────────────────────────────────────────
# Generate requiredDataFiles.json content (passed via stdin to the actual file)
#   This is a helper used internally by package_mods_and_scripts
# ────────────────────────────────────────────────────────────────
_generate_required_json() {
    local plugins_dir="$1"
    shift
    local orig_files=("$@")

    printf "[\n"
    for orig in "${orig_files[@]}"; do
        printf '  {\n    "%s": []\n  },\n' "$orig"
    done

    # Collect and sort mod files
    local mod_files=()
    for pattern in *.esp *.ESP *.esm *.ESM \
                   *.omwaddon *.OMWADDON \
                   *.omwscripts *.OMWSCRIPTS \
                   *.omwgame *.OMWGAME; do
        for file in "$plugins_dir"/$pattern; do
            [ -f "$file" ] || continue
            local basename
            basename="$(basename "$file")"

            local skip=0
            for orig in "${orig_files[@]}"; do
                if [ "$basename" = "$orig" ]; then
                    skip=1
                    break
                fi
            done
            [ "$skip" -eq 1 ] && continue

            mod_files+=("$file")
        done
    done

    # Sort by filename
    local sorted
    IFS=$'\n' sorted=($(sort <<<"${mod_files[*]}"))
    unset IFS

    for filepath in "${sorted[@]}"; do
        local basename crc
        basename="$(basename "$filepath")"
        crc=""
        if command -v rhash &>/dev/null; then
            crc=$(rhash --crc32 --simple "$filepath" | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')
        fi
        if [ -n "$crc" ]; then
            printf '  {\n    "%s": ["0x%s"]\n  },\n' "$basename" "$crc"
        else
            printf '  {\n    "%s": []\n  },\n' "$basename"
        fi
    done
}

# ────────────────────────────────────────────────────────────────
# Package mods and scripts into a tar.gz archive
#   Usage: package_mods_and_scripts <output_file>
#   Always includes requiredDataFiles.json inside plugins/ subdir.
#   Archive structure:
#     output.tar.gz
#     ├── plugins/
#     │   ├── mod1.esp
#     │   ├── mod2.esm
#     │   └── requiredDataFiles.json
#     └── scripts/
#         └── test.lua
# ────────────────────────────────────────────────────────────────
package_mods_and_scripts() {
    local output_file="$1"

    if [ -z "$output_file" ]; then
        echo "[package.sh] ERROR: package_mods_and_scripts requires an output file path" >&2
        return 1
    fi

    # Check disk space before proceeding
    _check_disk_space "$output_file" "$PLUGINS_DIR" "$SERVER_SCRIPTS_DIR"

    local stage_dir
    stage_dir=$(mktemp -d)
    trap 'rm -rf "${stage_dir:-}"' RETURN

    local plugins_stage="$stage_dir/plugins"
    local scripts_stage="$stage_dir/scripts"
    mkdir -p "$plugins_stage" "$scripts_stage"

    local copied=0

    # --- Copy plugins ---
    if [ -d "$PLUGINS_DIR" ]; then
        for pattern in *.esp *.ESP *.esm *.ESM \
                       *.omwaddon *.OMWADDON \
                       *.omwscripts *.OMWSCRIPTS \
                       *.omwgame *.OMWGAME; do
            for file in "$PLUGINS_DIR"/$pattern; do
                [ -f "$file" ] || continue
                local basename
                basename="$(basename "$file")"

                # Skip original files
                local skip=0
                for orig in "${ORIGINAL_FILES[@]}"; do
                    if [ "${basename,,}" = "${orig,,}" ]; then
                        skip=1
                        break
                    fi
                done
                [ "$skip" -eq 1 ] && continue

                cp "$file" "$plugins_stage/"
                ((copied++)) || true
            done
        done
    fi

    # --- Generate requiredDataFiles.json inside plugins/ ---
    _generate_required_json "$PLUGINS_DIR" "${ORIGINAL_FILES[@]}" > "$plugins_stage/requiredDataFiles.json"

    # --- Copy server scripts ---
    local script_copied=0
    if [ -d "$SERVER_SCRIPTS_DIR" ]; then
        for file in "$SERVER_SCRIPTS_DIR"/*.lua "$SERVER_SCRIPTS_DIR"/*.LUA; do
            [ -f "$file" ] || continue
            cp "$file" "$scripts_stage/"
            ((script_copied++)) || true
        done
    fi

    # --- Create the archive ---
    local parent_dir
    parent_dir="$(dirname "$output_file")"
    mkdir -p "$parent_dir"

    tar czf "$output_file" -C "$stage_dir" .

    echo "[package.sh] Created: $output_file"
    echo "[package.sh]   plugins: $copied, scripts: $script_copied, requiredDataFiles.json: yes"
}

# ────────────────────────────────────────────────────────────────
# Internal: Create tar.gz archive from a staged directory
#   Usage: _package_stage <output_file> <stage_dir>
# ────────────────────────────────────────────────────────────────
_package_stage() {
    local output_file="$1"
    local stage_dir="$2"

    local parent_dir
    parent_dir="$(dirname "$output_file")"
    mkdir -p "$parent_dir"

    tar czf "$output_file" -C "$stage_dir" .
    echo "[package.sh] Created: $output_file"
}

# ────────────────────────────────────────────────────────────────
# Package only players into a tar.gz archive
#   Usage: package_players <output_file>
#   Archive structure:
#     output.tar.gz
#     └── player/
#         └── AccountName1.json
# ────────────────────────────────────────────────────────────────
package_players() {
    local output_file="$1"

    if [ -z "$output_file" ]; then
        echo "[package.sh] ERROR: package_players requires an output file path" >&2
        return 1
    fi

    # Check disk space before proceeding
    _check_disk_space "$output_file" "$PLAYER_DIR"

    local stage_dir
    stage_dir=$(mktemp -d)
    trap 'rm -rf "${stage_dir:-}"' RETURN

    # Copy players to staging/player/
    if [ -d "$PLAYER_DIR" ] && [ -n "$(ls -A "$PLAYER_DIR" 2>/dev/null)" ]; then
        mkdir -p "$stage_dir/player"
        cp -r "$PLAYER_DIR"/* "$stage_dir/player/"
        echo "[package.sh]   players: $(ls -1 "$stage_dir/player" | wc -l)"
    else
        echo "[package.sh]   players: 0 (empty or missing)"
    fi

    # Create the archive
    _package_stage "$output_file" "$stage_dir"
}

# ────────────────────────────────────────────────────────────────
# Package only cells into a tar.gz archive
#   Usage: package_cells <output_file>
#   Archive structure:
#     output.tar.gz
#     └── cell/
#         └── -1_-2.json
# ────────────────────────────────────────────────────────────────
package_cells() {
    local output_file="$1"

    if [ -z "$output_file" ]; then
        echo "[package.sh] ERROR: package_cells requires an output file path" >&2
        return 1
    fi

    # Check disk space before proceeding
    _check_disk_space "$output_file" "$CELL_DIR"

    local stage_dir
    stage_dir=$(mktemp -d)
    trap 'rm -rf "${stage_dir:-}"' RETURN

    # Copy cells to staging/cell/
    if [ -d "$CELL_DIR" ] && [ -n "$(ls -A "$CELL_DIR" 2>/dev/null)" ]; then
        mkdir -p "$stage_dir/cell"
        cp -r "$CELL_DIR"/* "$stage_dir/cell/"
        echo "[package.sh]   cells: $(ls -1 "$stage_dir/cell" | wc -l)"
    else
        echo "[package.sh]   cells: 0 (empty or missing)"
    fi

    # Create the archive
    _package_stage "$output_file" "$stage_dir"
}

# (package_world is removed — use package_players + package_cells instead)

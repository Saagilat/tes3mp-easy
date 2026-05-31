#!/bin/bash
#
# package.sh — Shared packaging library for TES3MP server data
#
# This script is meant to be sourced (not executed directly).
#
# Variable requirements per function:
#   package_mods()    — PLUGINS_DIR, SERVER_SCRIPTS_DIR, ORIGINAL_FILES
#   package_players() — PLAYER_DIR
#   package_world()   — WORLD_CELL_DIR, WORLD_WORLD_DIR, WORLD_MAP_DIR,
#                       WORLD_RECORDSTORE_DIR, WORLD_CUSTOM_DIR
#
# Functions provided:
#   package_mods(output_file)                — plugins + scripts + requiredDataFiles.json
#   package_players(output_file)             — player/ + metadata files
#   package_world(output_file)               — cell/ + world/ + map/ + recordstore/ + custom/ + metadata
#   package_init_mods(output_file)            — empty plugins/ + empty scripts/ + requiredDataFiles.json
#   package_init_players(output_file)         — empty player/ + metadata
#   package_init_world(output_file)           — empty world subdirs + metadata
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
# Generate requiredDataFiles.json content (passed via stdout)
#   Usage: _generate_required_json <plugins_dir> [orig_files...]
# ────────────────────────────────────────────────────────────────
_generate_required_json() {
    local plugins_dir="$1"
    shift
    local orig_files=("$@")

    local all_entries=()
    local tmp

    # Add original files with empty CRC
    for orig in "${orig_files[@]}"; do
        tmp=$(printf '  {\n    "%s": []\n  }' "$orig")
        all_entries+=("$tmp")
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

            skip=0
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
            tmp=$(printf '  {\n    "%s": ["0x%s"]\n  }' "$basename" "$crc")
        else
            tmp=$(printf '  {\n    "%s": []\n  }' "$basename")
        fi
        all_entries+=("$tmp")
    done

    # Print all entries with comma separators in proper JSON
    printf "[\n"
    local i=0
    for entry in "${all_entries[@]}"; do
        if [ "$i" -gt 0 ]; then
            printf ",\n"
        fi
        printf "%s" "$entry"
        ((i++)) || true
    done
    printf "\n]\n"
}

# ────────────────────────────────────────────────────────────────
# Package mods and scripts into a tar.gz archive
#   Usage: package_mods <output_file>
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
package_mods() {
    local output_file="$1"

    if [ -z "$output_file" ]; then
        echo "[package.sh] ERROR: package_mods requires an output file path" >&2
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
                skip=0
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
    _package_stage "$output_file" "$stage_dir"

    echo "[package.sh]   plugins: $copied, scripts: $script_copied, requiredDataFiles.json: yes"
}

# ────────────────────────────────────────────────────────────────
# Package only players into a tar.gz archive
#   Usage: package_players <output_file> [mods_sha256]
#   Archive structure:
#     output.tar.gz
#     ├── player/
#     │   └── AccountName1.json
#     ├── requiredDataFiles.json   (meta — list of mods at export time)
#     └── current.txt               (meta — mods archive sha256)
# ────────────────────────────────────────────────────────────────
package_players() {
    local output_file="$1"
    local mods_sha256="${2:-}"

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
    mkdir -p "$stage_dir/player"
    if [ -d "$PLAYER_DIR" ]; then
        local count=0
        for f in "$PLAYER_DIR"/*; do
            [ -e "$f" ] || continue
            cp -r "$f" "$stage_dir/player/"
            ((count++)) || true
        done
        echo "[package.sh]   players: $count"
    else
        echo "[package.sh]   players: 0 (directory missing)"
    fi

    # Add metadata: current.txt (mods archive sha256)
    if [ -n "$mods_sha256" ]; then
        echo "$mods_sha256" > "$stage_dir/current.txt"
    fi

    # Add metadata: requiredDataFiles.json (copy from mods/plugins/ if available)
    if [ -n "${MODS_PLUGINS_DIR:-}" ] && [ -f "$MODS_PLUGINS_DIR/requiredDataFiles.json" ]; then
        cp "$MODS_PLUGINS_DIR/requiredDataFiles.json" "$stage_dir/requiredDataFiles.json"
    fi

    # Create the archive
    _package_stage "$output_file" "$stage_dir"
}

# ────────────────────────────────────────────────────────────────
# Package world into a tar.gz archive
#   Usage: package_world <output_file> [mods_sha256]
#   Archives cell/ + world/ + map/ + recordstore/ + custom/
#   Archive structure:
#     output.tar.gz
#     ├── cell/
#     ├── world/
#     ├── map/
#     ├── recordstore/
#     ├── custom/
#     ├── requiredDataFiles.json   (meta — list of mods at export time)
#     └── current.txt               (meta — mods archive sha256)
# ────────────────────────────────────────────────────────────────
package_world() {
    local output_file="$1"
    local mods_sha256="${2:-}"

    if [ -z "$output_file" ]; then
        echo "[package.sh] ERROR: package_world requires an output file path" >&2
        return 1
    fi

    # Check disk space before proceeding
    _check_disk_space "$output_file" \
        "${WORLD_CELL_DIR:-}" \
        "${WORLD_WORLD_DIR:-}" \
        "${WORLD_MAP_DIR:-}" \
        "${WORLD_RECORDSTORE_DIR:-}" \
        "${WORLD_CUSTOM_DIR:-}"

    local stage_dir
    stage_dir=$(mktemp -d)
    trap 'rm -rf "${stage_dir:-}"' RETURN

    local count=0

    # Copy each world subdirectory
    _copy_world_subdir() {
        local src="$1"
        local dest_subdir="$2"
        if [ -d "$src" ]; then
            mkdir -p "$stage_dir/$dest_subdir"
            for f in "$src"/*; do
                [ -e "$f" ] || continue
                cp -r "$f" "$stage_dir/$dest_subdir/"
                ((count++)) || true
            done
        fi
    }

    _copy_world_subdir "${WORLD_CELL_DIR:-}" "cell"
    _copy_world_subdir "${WORLD_WORLD_DIR:-}" "world"
    _copy_world_subdir "${WORLD_MAP_DIR:-}" "map"
    _copy_world_subdir "${WORLD_RECORDSTORE_DIR:-}" "recordstore"
    _copy_world_subdir "${WORLD_CUSTOM_DIR:-}" "custom"

    echo "[package.sh]   world entries: $count"

    # Add metadata: current.txt (mods archive sha256)
    if [ -n "$mods_sha256" ]; then
        echo "$mods_sha256" > "$stage_dir/current.txt"
    fi

    # Add metadata: requiredDataFiles.json (copy from mods/plugins/ if available)
    if [ -n "${MODS_PLUGINS_DIR:-}" ] && [ -f "$MODS_PLUGINS_DIR/requiredDataFiles.json" ]; then
        cp "$MODS_PLUGINS_DIR/requiredDataFiles.json" "$stage_dir/requiredDataFiles.json"
    fi

    # Create the archive
    _package_stage "$output_file" "$stage_dir"
}

# ────────────────────────────────────────────────────────────────
# Package init mods archive (empty plugins/ + empty scripts/ + requiredDataFiles.json)
#   Usage: package_init_mods <output_file>
#   Creates an archive with empty plugins/ and scripts/ directories and
#   a minimal requiredDataFiles.json.
# ────────────────────────────────────────────────────────────────
package_init_mods() {
    local output_file="$1"

    if [ -z "$output_file" ]; then
        echo "[package.sh] ERROR: package_init_mods requires an output file path" >&2
        return 1
    fi

    local stage_dir
    stage_dir=$(mktemp -d)
    trap 'rm -rf "${stage_dir:-}"' RETURN

    mkdir -p "$stage_dir/plugins" "$stage_dir/scripts"

    # Generate minimal requiredDataFiles.json (only original files)
    local orig_files=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")
    _generate_required_json "/dev/null" "${orig_files[@]}" > "$stage_dir/plugins/requiredDataFiles.json"

    # Create the archive
    _package_stage "$output_file" "$stage_dir"

    echo "[package.sh]   init mods archive: empty plugins/ + empty scripts/ + requiredDataFiles.json"
}

# ────────────────────────────────────────────────────────────────
# Package init players archive (empty player/ + metadata)
#   Usage: package_init_players <output_file> [mods_sha256]
#   Creates an archive with an empty player/ directory and metadata files.
# ────────────────────────────────────────────────────────────────
package_init_players() {
    local output_file="$1"
    local mods_sha256="${2:-}"

    if [ -z "$output_file" ]; then
        echo "[package.sh] ERROR: package_init_players requires an output file path" >&2
        return 1
    fi

    local stage_dir
    stage_dir=$(mktemp -d)
    trap 'rm -rf "${stage_dir:-}"' RETURN

    mkdir -p "$stage_dir/player"

    # Add metadata: current.txt (mods archive sha256)
    if [ -n "$mods_sha256" ]; then
        echo "$mods_sha256" > "$stage_dir/current.txt"
    fi

    # Create the archive
    _package_stage "$output_file" "$stage_dir"

    echo "[package.sh]   init players archive: empty player/ + metadata"
}

# ────────────────────────────────────────────────────────────────
# Package init world archive (empty world subdirs + metadata)
#   Usage: package_init_world <output_file> [mods_sha256]
#   Creates an archive with empty cell/, world/, map/, recordstore/, custom/
#   directories and metadata files.
# ────────────────────────────────────────────────────────────────
package_init_world() {
    local output_file="$1"
    local mods_sha256="${2:-}"

    if [ -z "$output_file" ]; then
        echo "[package.sh] ERROR: package_init_world requires an output file path" >&2
        return 1
    fi

    local stage_dir
    stage_dir=$(mktemp -d)
    trap 'rm -rf "${stage_dir:-}"' RETURN

    mkdir -p "$stage_dir/cell" \
             "$stage_dir/world" \
             "$stage_dir/map" \
             "$stage_dir/recordstore" \
             "$stage_dir/custom"

    # Add metadata: current.txt (mods archive sha256)
    if [ -n "$mods_sha256" ]; then
        echo "$mods_sha256" > "$stage_dir/current.txt"
    fi

    # Create the archive
    _package_stage "$output_file" "$stage_dir"

    echo "[package.sh]   init world archive: empty cell/ + world/ + map/ + recordstore/ + custom/ + metadata"
}
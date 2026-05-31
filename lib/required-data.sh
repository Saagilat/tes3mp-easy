#!/bin/bash
#
# required-data.sh — generate requiredDataFiles.json (CRC32)
#
# Migrated from tools/linux/tes3mp-easy-generate-required-data
#
# Provides:
#   - generate_required_data()  — scan PLUGINS_DIR, write CRC32 JSON
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before required-data.sh" >&2
    exit 1
fi

# ────────────────────────────────────────────────────────────
# generate_required_data — scan plugins and write requiredDataFiles.json
# Usage: generate_required_data [plugin_dir]
# ────────────────────────────────────────────────────────────
generate_required_data() {
    local plugin_dir="${1:-}"
    if [[ -z "$plugin_dir" ]]; then
        plugin_dir="${MODPACK_DIR}/plugins"
    fi

    if [[ -z "$plugin_dir" ]]; then
        err "MODPACK_DIR is not set."
        err "Usage: generate_required_data [path-to-plugins]"
        err "Or set MODPACK_DIR in config."
        return 1
    fi

    if [[ ! -d "$plugin_dir" ]]; then
        err "Directory not found: $plugin_dir"
        return 1
    fi

    check_deps rhash

    ORIGINAL_FILES=("Morrowind.esm" "Tribunal.esm" "Bloodmoon.esm")

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Generating requiredDataFiles.json"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  Scanning: $plugin_dir"
    echo ""

    local output_file="$plugin_dir/requiredDataFiles.json"

    # Start JSON
    cat > "$output_file" << 'EOF'
{
    "requiredDataFiles":
    {
EOF

    local first=true

    while IFS= read -r -d '' file; do
        local filename
        filename=$(basename "$file")

        # Skip original Morrowind files
        local skip=0
        for orig in "${ORIGINAL_FILES[@]}"; do
            if [[ "${filename,,}" == "${orig,,}" ]]; then
                skip=1
                break
            fi
        done
        [[ "$skip" -eq 1 ]] && continue

        # Compute CRC32
        local crc32
        crc32=$(rhash --crc32 --simple "$file" 2>/dev/null | cut -d' ' -f1 | tr '[:lower:]' '[:upper:]')

        if [[ -n "$crc32" ]]; then
            if [[ "$first" == true ]]; then
                first=false
            else
                echo "," >> "$output_file"
            fi
            echo -n "        \"$filename\": [\"0x$crc32\"]" >> "$output_file"
            echo -n "  [OK] $filename"
            [[ -n "$crc32" ]] && echo " → CRC32: 0x$crc32" || echo ""
        fi
    done < <(find "$plugin_dir" -maxdepth 1 -type f \( -iname "*.esp" -o -iname "*.esm" -o -iname "*.omwaddon" \) -print0 | sort -z)

    # Close JSON
    cat >> "$output_file" << 'EOF'

    }
}
EOF

    echo ""
    ok "requiredDataFiles.json generated at: $output_file"
    echo ""
    echo "Note: Original files (Morrowind.esm, Tribunal.esm, Bloodmoon.esm)"
    echo "are excluded from the list as they are validated by TES3MP itself."
}
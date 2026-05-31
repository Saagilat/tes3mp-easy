#!/bin/bash
#
# i18n.sh — internationalization for tes3mp-easy
#
# Provides:
#   - load_lang(lang)   — source .lang file, fallback to en
#   - lang_available()  — list available languages
#
# Language files are in $PROJECT_DIR/lang/<code>.sh
# Each file defines KEY="value" variables.
#

if [[ -z "${LIB_DIR:-}" ]]; then
    echo "ERROR: common.sh must be sourced before i18n.sh" >&2
    exit 1
fi

LANG_DIR="${PROJECT_DIR:-$LIB_DIR/..}/lang"

# ────────────────────────────────────────────────────────────
# lang_available — list installed language codes
# Usage: lang_available
# Returns: space-separated list: en ru
# ────────────────────────────────────────────────────────────
lang_available() {
    local langs=()
    if [[ -d "$LANG_DIR" ]]; then
        for f in "$LANG_DIR"/*; do
            [[ -f "$f" ]] || continue
            local basename
            basename=$(basename "$f")
            langs+=("$basename")
        done
    fi
    echo "${langs[*]}"
}

# ────────────────────────────────────────────────────────────
# load_lang — load language file
# Usage: load_lang [code]
# If code is empty or not found, falls back to en
# ────────────────────────────────────────────────────────────
load_lang() {
    local lang="${1:-en}"
    local lang_file="$LANG_DIR/$lang"

    if [[ -f "$lang_file" ]]; then
        source "$lang_file"
        return 0
    fi

    # Fallback to English
    if [[ "$lang" != "en" ]]; then
        lang_file="$LANG_DIR/en"
        if [[ -f "$lang_file" ]]; then
            source "$lang_file"
            return 0
        fi
    fi

    # Last resort — empty fallback
    warn "Language file not found: $LANG_DIR/$lang"
    return 1
}
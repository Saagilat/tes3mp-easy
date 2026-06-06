#!/bin/bash
#
# layer2/admin.sh — Interactive wrappers for admin operations
#
# Layer 2: Each function wraps one or more Layer 1 calls,
# adding human-friendly output and user interaction.
#
# All Layer 1 paths are in LAYER1_DIR="$PROJECT_DIR/layer1/admin"
#

if [[ -z "${LIB_DIR:-}" ]]; then
    PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    LAYER1_DIR="$PROJECT_DIR/layer1/admin"
    LIB_DIR="$PROJECT_DIR/lib"
    source "$LIB_DIR/common"
    source "$LIB_DIR/config"
    source "$LIB_DIR/lang"
fi

LAYER1_DIR="${LAYER1_DIR:-$PROJECT_DIR/layer1/admin}"

# ────────────────────────────────────────────────────────────
# Simple wrappers — just call layer1 with no extra logic
# ────────────────────────────────────────────────────────────
interactive_server_start()       { bash "$LAYER1_DIR/start-server"; }
interactive_server_stop()        { bash "$LAYER1_DIR/stop-server"; }
interactive_server_restart()     { bash "$LAYER1_DIR/restart-server"; }
interactive_server_status()      { bash "$LAYER1_DIR/server-status"; }
interactive_server_logs()        { bash "$LAYER1_DIR/server-logs"; }
interactive_install_server()     { bash "$LAYER1_DIR/install-server"; }
interactive_generate_data()      { bash "$LAYER1_DIR/generate-data"; }
interactive_export_mods()        { bash "$LAYER1_DIR/export-mods"; }
interactive_export_players()     { bash "$LAYER1_DIR/export-players"; }
interactive_export_world()       { bash "$LAYER1_DIR/export-world"; }
interactive_show_backups_mods()  { bash "$LAYER1_DIR/show-backups-mods"; }
interactive_show_backups_players() { bash "$LAYER1_DIR/show-backups-players"; }
interactive_show_backups_world() { bash "$LAYER1_DIR/show-backups-world"; }
interactive_edit_server_cfg()    { bash "$LAYER1_DIR/edit-server-cfg"; }
interactive_edit_lua()           { bash "$LAYER1_DIR/edit-lua"; }
interactive_edit_banlist()       { bash "$LAYER1_DIR/edit-banlist"; }
interactive_edit_config()        { bash "$LAYER1_DIR/edit-config"; }

# ────────────────────────────────────────────────────────────
# Helper: require SSH_HOST
# ────────────────────────────────────────────────────────────
_require_ssh_host() {
    load_config 2>/dev/null || true
    if [[ -z "${SSH_HOST:-}" ]]; then
        err "SSH_HOST is not set."
        err "Run 'Admin Menu Settings' first."
        return 1
    fi
}

# ────────────────────────────────────────────────────────────
# Download backup — list via layer1 show-backups, prompt, call layer1 download
# ────────────────────────────────────────────────────────────
_interactive_download_backup() {
    local type="$1"
    local label="$2"

    _require_ssh_host || return 1

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Download $label Backup"
    echo "═══════════════════════════════════════════════"
    echo ""

    local json
    json=$(bash "$LAYER1_DIR/show-backups-${type}")
    if [[ -z "$json" ]]; then
        warn "No $label backups available on server."
        return
    fi

    local current_sha256
    current_sha256=$(echo "$json" | grep -o '"current":"[^"]*"' | head -1 | sed 's/"current":"//;s/"//')

    local names=() sha256s=()
    local files_part
    files_part=$(echo "$json" | grep -o '"files":\[.*\]' | sed 's/"files":\[//;s/\]$//')
    if [[ -z "$files_part" ]]; then
        warn "No $label backups available on server."
        return
    fi

    IFS="}" read -ra objects <<< "$files_part"
    for obj in "${objects[@]}"; do
        obj="${obj#\{}"
        obj="${obj#,}"
        obj="${obj%,}"
        obj="${obj%\]}"
        [[ -z "$obj" ]] && continue
        local name="" sha256=""
        if [[ "$obj" =~ \"name\":[[:space:]]*\"([^\"]+)\" ]]; then name="${BASH_REMATCH[1]}"; fi
        if [[ "$obj" =~ \"sha256\":[[:space:]]*\"([^\"]+)\" ]]; then sha256="${BASH_REMATCH[1]}"; fi
        [[ -z "$name" ]] && continue
        names+=("$name")
        sha256s+=("$sha256")
    done

    if [[ ${#names[@]} -eq 0 ]]; then
        warn "No $label backups available on server."
        return
    fi

    local i=1
    for name in "${names[@]}"; do
        local idx=$((i - 1))
        if [[ -n "$current_sha256" && "${sha256s[$idx]}" == "$current_sha256" ]]; then
            echo "  $i) $name  (current)"
        else
            echo "  $i) $name"
        fi
        ((i++)) || true
    done
    echo ""

    local choice
    read -r -p "  Select number (empty = cancel): " choice
    if [[ -z "$choice" ]]; then
        info "Cancelled."
        return
    fi

    local selected="${names[$((choice - 1))]}"
    if [[ -z "$selected" ]]; then
        err "Invalid selection."
        return
    fi

    echo ""
    info "Downloading $selected..."
    bash "$LAYER1_DIR/download-backup-${type}" "$selected" || { err "Download failed."; }
    ok "Done."
}

interactive_download_mods()    { _interactive_download_backup "mods" "Mods"; }
interactive_download_players() { _interactive_download_backup "players" "Players"; }
interactive_download_world()   { _interactive_download_backup "world" "World"; }

# ────────────────────────────────────────────────────────────
# Deploy — list archives via SSH, prompt, call layer1 deploy
# ────────────────────────────────────────────────────────────
_interactive_deploy() {
    local type="$1"
    local label="$2"

    _require_ssh_host || return 1

    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  Deploy $label"
    echo "═══════════════════════════════════════════════"
    echo ""
    echo "  Choose archive to deploy (or press Enter for latest):"
    echo ""

    load_config 2>/dev/null || true
    local archives
    archives=$(ssh "$SSH_HOST" "ls -t /tes3mp-easy/backups/$type/*.tar.gz 2>/dev/null | head -10 | xargs -n1 basename" 2>/dev/null)
    if [[ -z "$archives" ]]; then
        warn "No archives found on server."
        return
    fi

    local names=()
    while IFS= read -r name; do names+=("$name"); done <<< "$archives"

    local i=1
    for name in "${names[@]}"; do
        echo "  $i) $name"
        ((i++)) || true
    done
    echo ""

    local choice
    read -r -p "  Select number (empty = latest): " choice

    local archive
    if [[ -z "$choice" ]]; then
        archive="${names[0]}"
    else
        archive="${names[$((choice - 1))]}"
    fi

    if [[ -z "$archive" ]]; then
        err "Invalid selection."
        return
    fi

    info "Deploying: $archive"
    bash "$LAYER1_DIR/deploy-${type}" "$archive" || { err "Deploy failed."; }
    ok "Deploy queued. Use RESTART to apply."
}

interactive_deploy_mods()    { _interactive_deploy "mods" "Mods"; }
interactive_deploy_players() { _interactive_deploy "players" "Players"; }
interactive_deploy_world()   { _interactive_deploy "world" "World"; }

# ────────────────────────────────────────────────────────────
# Restart flag check — query server via SSH
# ────────────────────────────────────────────────────────────
interactive_check_restart_flag() {
    load_config 2>/dev/null || true
    if [[ -n "${SSH_HOST:-}" ]]; then
        local running
        running=$(ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose ps --format '{{.State}}' 2>/dev/null | head -1" 2>/dev/null)
        if [[ "$running" == "running" ]]; then
            if ssh "$SSH_HOST" "test -f /tes3mp-easy/needs_restart.flag" 2>/dev/null; then
                echo "1"
            fi
        fi
    fi
    echo ""
}

# ────────────────────────────────────────────────────────────
# Server status check — query via SSH
# ────────────────────────────────────────────────────────────
interactive_check_server_status() {
    load_config 2>/dev/null || true
    if [[ -n "${SSH_HOST:-}" ]]; then
        local state
        state=$(ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose ps --format '{{.State}}' 2>/dev/null | head -1" 2>/dev/null || echo "")
        if [[ "$state" == "running" ]]; then
            echo "Running"
        else
            echo "Stopped"
        fi
    else
        echo ""
    fi
}

# ────────────────────────────────────────────────────────────
# Setup wizard — interactive guided setup
# ────────────────────────────────────────────────────────────
interactive_setup_wizard() {
    local TOTAL=6
    local CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tes3mp-easy"
    local CONFIG="$CONFIG_DIR/tes3mp-easy.ini"

    echo ""
    echo "  ${T_LABEL}╔══════════════════════════════════════════════════╗${NC}"
    echo "  ${T_LABEL}║       TES3MP Easy — Admin Setup Wizard          ║${NC}"
    echo "  ${T_LABEL}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    info "This wizard will guide you through setting up the server."
    info "Press Ctrl+C at any time to exit."
    echo ""

    load_config 2>/dev/null || true

    step_header() { local num="$1" total="$2" title="$3"; echo ""; echo "  ${T_LABEL}━━━ [${num}/${total}] ${title} ━━━${NC}"; echo ""; }

    # Step 1: SSH_HOST
    step_header 1 $TOTAL "SSH Connection"
    while true; do
        if [[ -n "${SSH_HOST:-}" ]]; then
            input "Enter SSH host (from ~/.ssh/config)" "$SSH_HOST" SSH_HOST_VAL
        else
            echo ""
            echo "  You need an SSH host configured in ~/.ssh/config."
            echo ""
            input "Enter SSH host" "" SSH_HOST_VAL
        fi
        if [[ -z "$SSH_HOST_VAL" ]]; then
            err "SSH_HOST cannot be empty."
            continue
        fi
        if bash "$LAYER1_DIR/set-ssh-host" "$SSH_HOST_VAL"; then
            break
        else
            confirm "Try again?" "y" || { warn "Skipping SSH."; break; }
        fi
    done
    load_config 2>/dev/null || true

    # Step 2: EXPORT_DIR
    step_header 2 $TOTAL "Export Directory"
    input "Enter path to export directory" "${EXPORT_DIR:-./exports}" EXPORT_DIR_VAL
    if [[ -n "$EXPORT_DIR_VAL" ]]; then
        bash "$LAYER1_DIR/set-export-dir" "$EXPORT_DIR_VAL"
    fi
    load_config 2>/dev/null || true

    # Step 3: Install server
    step_header 3 $TOTAL "Server Installation"
    if [[ -z "${SSH_HOST:-}" ]]; then
        warn "SSH_HOST not set — skipping server installation."
    else
        local server_installed=false
        if ssh "$SSH_HOST" "test -f /tes3mp-easy/docker-compose.yml" 2>/dev/null; then
            server_installed=true
        fi
        if $server_installed; then
            ok "Server is already installed."
            if confirm "Re-install / upgrade server?" "n"; then
                bash "$LAYER1_DIR/install-server" || err "Installation failed."
            fi
        else
            if confirm "Install server?" "y"; then
                bash "$LAYER1_DIR/install-server" || err "Installation failed."
            fi
        fi
    fi

    # Step 4: Server configuration (config.lua via SSH)
    step_header 4 $TOTAL "Server Configuration"
    _interactive_configure_server

    # Step 5: Mods setup
    step_header 5 $TOTAL "Mods Setup"
    load_config 2>/dev/null || true
    if [[ -n "${EXPORT_DIR:-}" ]]; then
        local resolved="${EXPORT_DIR/#\~/$HOME}"
        local mod_plugins="$resolved/mods/plugins"
        local mod_scripts="$resolved/mods/scripts"
        if [[ ! -d "$mod_plugins" ]] || [[ ! -d "$mod_scripts" ]]; then
            if confirm "Create mod directories (plugins + scripts)?" "y"; then
                mkdir -p "$mod_plugins" "$mod_scripts"
                ok "Created mod directories."
            fi
        else
            ok "Mod directories already exist."
        fi
    else
        warn "EXPORT_DIR not set — skipping."
    fi

    # Step 6: Start server
    step_header 6 $TOTAL "Start Server"
    if [[ -n "${SSH_HOST:-}" ]]; then
        if confirm "Start server now?" "n"; then
            bash "$LAYER1_DIR/start-server" || err "Failed to start server."
        fi
    fi

    echo ""
    echo "  ${T_LABEL}╔══════════════════════════════════════════════════╗${NC}"
    echo "  ${T_LABEL}║            Setup Wizard Complete!                ║${NC}"
    echo "  ${T_LABEL}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ────────────────────────────────────────────────────────────
# Server config.lua editor (interactive, via SSH)
# ────────────────────────────────────────────────────────────
_interactive_configure_server() {
    if [[ -z "${SSH_HOST:-}" ]]; then
        warn "SSH not available — skipping."
        return
    fi

    echo ""
    info "Loading current config from server..."

    # Read config.lua into associative arrays
    declare -g -A _LUA_CONF=()
    while IFS='=' read -r key val; do
        key="${key%% }"; key="${key## }"
        [[ -z "$key" || "$key" == '--'* ]] && continue
        val="${val# \"}"; val="${val%\"}"; val="${val# }"; val="${val% }"
        _LUA_CONF["$key"]="$val"
    done < <(ssh "$SSH_HOST" "grep '^config\.' /tes3mp-easy/configs/config.lua" 2>/dev/null || true)

    declare -g -A _LUA_CHANGED=()
    declare -g -A _LUA_TYPE=()

    _lua_set() {
        local key="$1" value="$2" type="${3:-string}"
        _LUA_CONF["$key"]="$value"
        _LUA_CHANGED["$key"]="1"
        _LUA_TYPE["$key"]="$type"
    }

    _lua_get() { local key="$1" default="$2"; echo "${_LUA_CONF[$key]:-$default}"; }

    _ask_bool() {
        local key="$1" prompt="$2" default="$3"
        if confirm "$prompt" "$default"; then _lua_set "$key" "true" "bool"
        else _lua_set "$key" "false" "bool"; fi
    }

    _ask_value() {
        local key="$1" prompt="$2" default="$3" type="${4:-string}" val
        input "$prompt" "$default" val
        _lua_set "$key" "$val" "$type"
    }

    info "Press Enter to keep the default value shown in brackets."
    echo ""

    echo "  --- Game ---"
    _ask_value "config.serverName" "  Server name" "$(_lua_get "config.serverName" "TES3MP Server")"
    _ask_value "config.serverPassword" "  Server password (empty = no password)" "$(_lua_get "config.serverPassword" "")" "password"
    _ask_value "config.gameMode" "  Game mode" "$(_lua_get "config.gameMode" "Default")"
    _ask_value "config.difficulty" "  Difficulty (-100..100)" "$(_lua_get "config.difficulty" "0")" "number"
    _ask_value "config.loginTime" "  Login time (seconds)" "$(_lua_get "config.loginTime" "60")" "number"
    _ask_value "config.maxClientsPerIP" "  Max clients per IP" "$(_lua_get "config.maxClientsPerIP" "3")" "number"

    echo "  --- Time ---"
    _ask_bool "config.passTimeWhenEmpty" "  Pass time when empty?" "$(_lua_get "config.passTimeWhenEmpty" "false")"
    _ask_value "config.nightStartHour" "  Night start hour" "$(_lua_get "config.nightStartHour" "20")" "number"
    _ask_value "config.nightEndHour" "  Night end hour" "$(_lua_get "config.nightEndHour" "6")" "number"

    echo "  --- Permissions ---"
    _ask_bool "config.allowConsole" "  Allow console?" "$(_lua_get "config.allowConsole" "false")"
    _ask_bool "config.allowBedRest" "  Allow bed rest?" "$(_lua_get "config.allowBedRest" "true")"
    _ask_bool "config.allowWildernessRest" "  Allow wilderness rest?" "$(_lua_get "config.allowWildernessRest" "true")"
    _ask_bool "config.allowWait" "  Allow wait?" "$(_lua_get "config.allowWait" "true")"
    _ask_bool "config.allowSuicideCommand" "  Allow /suicide?" "$(_lua_get "config.allowSuicideCommand" "true")"
    _ask_bool "config.allowFixmeCommand" "  Allow /fixme?" "$(_lua_get "config.allowFixmeCommand" "true")"

    echo "  --- Sharing ---"
    _ask_bool "config.shareJournal" "  Share journal?" "$(_lua_get "config.shareJournal" "true")"
    _ask_bool "config.shareFactionRanks" "  Share faction ranks?" "$(_lua_get "config.shareFactionRanks" "true")"
    _ask_bool "config.shareFactionExpulsion" "  Share faction expulsion?" "$(_lua_get "config.shareFactionExpulsion" "false")"
    _ask_bool "config.shareFactionReputation" "  Share faction reputation?" "$(_lua_get "config.shareFactionReputation" "true")"
    _ask_bool "config.shareTopics" "  Share dialogue topics?" "$(_lua_get "config.shareTopics" "true")"
    _ask_bool "config.shareBounty" "  Share bounty?" "$(_lua_get "config.shareBounty" "false")"
    _ask_bool "config.shareReputation" "  Share reputation?" "$(_lua_get "config.shareReputation" "true")"
    _ask_bool "config.shareMapExploration" "  Share map exploration?" "$(_lua_get "config.shareMapExploration" "false")"
    _ask_bool "config.shareVideos" "  Share videos?" "$(_lua_get "config.shareVideos" "true")"

    echo "  --- Respawn & Death ---"
    _ask_bool "config.playersRespawn" "  Players respawn?" "$(_lua_get "config.playersRespawn" "true")"
    _ask_value "config.deathTime" "  Death time (seconds)" "$(_lua_get "config.deathTime" "5")" "number"
    _ask_value "config.deathPenaltyJailDays" "  Jail days penalty" "$(_lua_get "config.deathPenaltyJailDays" "5")" "number"
    _ask_bool "config.bountyResetOnDeath" "  Reset bounty on death?" "$(_lua_get "config.bountyResetOnDeath" "false")"
    _ask_bool "config.bountyDeathPenalty" "  Bounty death penalty?" "$(_lua_get "config.bountyDeathPenalty" "false")"
    _ask_bool "config.respawnAtImperialShrine" "  Respawn at Imperial shrine?" "$(_lua_get "config.respawnAtImperialShrine" "true")"
    _ask_bool "config.respawnAtTribunalTemple" "  Respawn at Tribunal temple?" "$(_lua_get "config.respawnAtTribunalTemple" "true")"

    echo "  --- Collisions ---"
    _ask_bool "config.enablePlayerCollision" "  Player-player collision?" "$(_lua_get "config.enablePlayerCollision" "true")"
    _ask_bool "config.enableActorCollision" "  Actor-actor collision?" "$(_lua_get "config.enableActorCollision" "true")"
    _ask_bool "config.enablePlacedObjectCollision" "  Placed object collision?" "$(_lua_get "config.enablePlacedObjectCollision" "false")"

    echo "  --- Stats Limits ---"
    _ask_value "config.maxAttributeValue" "  Max attribute value" "$(_lua_get "config.maxAttributeValue" "200")" "number"
    _ask_value "config.maxSpeedValue" "  Max Speed value" "$(_lua_get "config.maxSpeedValue" "365")" "number"
    _ask_value "config.maxSkillValue" "  Max skill value" "$(_lua_get "config.maxSkillValue" "200")" "number"
    _ask_value "config.maxAcrobaticsValue" "  Max Acrobatics value" "$(_lua_get "config.maxAcrobaticsValue" "1200")" "number"

    echo "  --- Safety ---"
    _ask_bool "config.enforceDataFiles" "  Enforce data files?" "$(_lua_get "config.enforceDataFiles" "true")"
    _ask_bool "config.ignoreScriptErrors" "  Ignore script errors?" "$(_lua_get "config.ignoreScriptErrors" "false")"

    # Save all changes
    if [[ ${#_LUA_CHANGED[@]} -gt 0 ]]; then
        ok "Saving server configuration..."

        # Generate sed script
        local script_path="/tmp/tes3mp-wizard-$$.sed"
        > /tmp/tes3mp-wizard-local.sed
        for key in "${!_LUA_CHANGED[@]}"; do
            local val="${_LUA_CONF[$key]}"
            local escaped_key
            escaped_key=$(printf '%s\n' "$key" | sed 's/[\/&]/\\&/g')
            case "${_LUA_TYPE[$key]}" in
                bool|number)
                    echo "s/^${escaped_key}[[:space:]]*=.*/${key} = ${val}/" >> /tmp/tes3mp-wizard-local.sed ;;
                password)
                    local escaped_val
                    escaped_val=$(printf '%s\n' "$val" | sed 's/[\/&"]/\\&/g')
                    echo "s/^${escaped_key}[[:space:]]*=.*/${key} = \"${escaped_val}\"/" >> /tmp/tes3mp-wizard-local.sed ;;
                string|*)
                    local escaped_val
                    escaped_val=$(printf '%s\n' "$val" | sed 's/[\/&"]/\\&/g')
                    echo "s|^${escaped_key}[[:space:]]*=.*|${key} = \"${escaped_val}\"|" >> /tmp/tes3mp-wizard-local.sed ;;
            esac
        done

        scp /tmp/tes3mp-wizard-local.sed "$SSH_HOST:$script_path" >/dev/null 2>&1
        rm -f /tmp/tes3mp-wizard-local.sed
        ssh "$SSH_HOST" "sed -i -f $script_path /tes3mp-easy/configs/config.lua && rm -f $script_path" 2>/dev/null
        ok "Server configuration updated."
    else
        info "No changes to save."
    fi
}
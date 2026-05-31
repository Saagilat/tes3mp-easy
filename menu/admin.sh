#!/bin/bash
#
# menu-admin.sh — interactive menu for TES3MP server administrators
#
# Usage: bash menu-admin.sh
# Can be called directly or via tes3mp-easy (bootstrap)
#

# ────────────────────────────────────────────────────────────
# Ensure we're being sourced from tes3mp-easy or have deps
# ────────────────────────────────────────────────────────────
if [[ -z "${LIB_DIR:-}" ]]; then
    # Running standalone — source libraries (menu/ is one level down)
    SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
    LIB_DIR="$SCRIPT_DIR/lib"
    source "$LIB_DIR/common.sh"
    source "$LIB_DIR/config.sh"
    source "$LIB_DIR/server-install.sh"
    source "$LIB_DIR/server-control.sh"
    source "$LIB_DIR/server-configs.sh"
    source "$LIB_DIR/export-mods.sh"
    source "$LIB_DIR/export-players.sh"
    source "$LIB_DIR/export-world.sh"
    source "$LIB_DIR/import-server.sh"
    source "$LIB_DIR/player-roles.sh"
    source "$LIB_DIR/required-data.sh"
    source "$LIB_DIR/self-update.sh"
fi

# ────────────────────────────────────────────────────────────
# Show Admin Menu
# ────────────────────────────────────────────────────────────
show_admin_menu() {
    local choice

    while true; do
        clear_screen
        print_header "TES3MP Easy — Admin"
        echo "  Host: ${SSH_HOST:-<not set>}"
        echo ""

        echo "  ── Установка / Настройка ──"
        echo ""
        echo "  1. 📦 Установить сервер на VPS (интерактивно)"
        echo "  2. 🤖 Установить сервер (--default, авто)"
        echo "  3. 🛠  Перенастроить сервер"
        echo ""
        echo "  ── Управление сервером ──"
        echo ""
        echo "  4. ▶  Запустить сервер"
        echo "  5. ■  Остановить сервер"
        echo "  6. ↻  Перезапустить сервер"
        echo "  7. 📜 Логи сервера"
        echo "  8. 📊 Статус сервера"
        echo ""
        echo "  ── Конфигурация ──"
        echo ""
        echo "  9. ✎  Редактировать конфиги сервера"
        echo ""
        echo "  ── Моды / Игроки / Мир ──"
        echo ""
        echo "  10. 📦 Экспорт модов на сервер"
        echo "  11. 👥 Экспорт игроков"
        echo "  12. 🌍 Экспорт мира"
        echo "  13. 🛡  Управление ролями игроков"
        echo ""
        echo "  ── Импорт на сервер ──"
        echo ""
        echo "  14. 📥 Импорт на сервер (моды/игроки/мир)"
        echo ""
        echo "  ── Инструменты ──"
        echo ""
        echo "  15. 🔑 Сгенерировать requiredDataFiles.json"
        echo ""
        echo "  p. 🎮 Перейти в меню игрока →"
        echo "  u. 🔄 Обновить tes3mp-easy"
        echo "  s. ⚙  Настройки (SSH, пути)"
        echo "  q.  Выход"
        echo ""
        read -r -p "  Выберите пункт: " choice

        case "$choice" in
            1) install_server interactive ;;
            2) install_server --default ;;
            3) configure_server ;;
            4) server_start ;;
            5) server_stop ;;
            6) server_restart ;;
            7) server_logs ;;
            8) server_status ;;
            9) edit_configs_menu ;;
            10) export_mods ;;
            11) export_players ;;
            12) export_world ;;
            13) player_roles_menu ;;
            14) import_server_menu ;;
            15) generate_required_data ;;
            p|P)
                # Switch to player menu
                local player_menu="$SCRIPT_DIR/menu/player.sh"
                if [[ -f "$player_menu" ]]; then
                    info "Переход в меню игрока..."
                    sleep 1
                    exec bash "$player_menu"
                else
                    err "menu/player.sh not found at $player_menu"
                fi
                ;;
            u|U) self_update ;;
            s|S)
                edit_config
                show_config
                ;;
            q|Q)
                echo ""
                info "Bye!"
                exit 0
                ;;
            *) echo "Неверный пункт." ;;
        esac

        echo ""
        read -r -p "Нажмите Enter чтобы продолжить..."
    done
}

# ────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────
clear_screen() {
    printf "\033c" 2>/dev/null || clear 2>/dev/null || true
}

print_header() {
    local title="$1"
    local width=60
    local padding=$(( (width - ${#title} - 2) / 2 ))

    echo ""
    printf "╔"
    printf '═%.0s' $(seq 1 $width)
    printf "╗\n"
    printf "║%*s %s %*s║\n" $padding "" "$title" $padding ""
    printf "╚"
    printf '═%.0s' $(seq 1 $width)
    printf "╝\n"
}

# ────────────────────────────────────────────────────────────
# Subcommand dispatcher (for direct calls like: menu/admin.sh start)
# ────────────────────────────────────────────────────────────
dispatch_admin() {
    case "${1:-}" in
        install-server)
            shift
            install_server "${1:-interactive}"
            ;;
        configure-server)
            shift
            configure_server "${1:-interactive}"
            ;;
        start) server_start ;;
        stop) server_stop ;;
        restart) server_restart ;;
        logs) server_logs ;;
        export-mods) export_mods ;;
        export-players) export_players ;;
        export-world) export_world ;;
        import-server) import_server_menu ;;
        generate-required-data) generate_required_data ;;
        config) edit_config ;;
        player-menu)
            local pm="${SCRIPT_DIR}/menu/player.sh"
            [[ -f "$pm" ]] && exec bash "$pm" || err "menu/player.sh not found"
            ;;
        self-update)
            self_update
            ;;
        help|--help|-h)
            echo "Admin subcommands: install-server, configure-server, start, stop, restart,"
            echo "  logs, export-mods, export-players, export-world, import-server,"
            echo "  generate-required-data, config, player-menu, self-update, menu"
            ;;
        menu|"")
            show_admin_menu
            ;;
        *)
            echo "Unknown command: $1"
            echo "Run 'menu/admin.sh help' for available commands."
            exit 1
            ;;
    esac
}

# ────────────────────────────────────────────────────────────
# Entry point when called directly
# ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_config || {
        first_run_wizard
        load_config
    }
    dispatch_admin "$@"
fi

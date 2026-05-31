#!/bin/bash
#
# menu-player.sh — interactive menu for TES3MP players
#
# Usage: bash menu-player.sh
# Can be called directly or via tes3mp-easy (bootstrap)
#

# ────────────────────────────────────────────────────────────
# Ensure we're being sourced from tes3mp-easy or have deps
# ────────────────────────────────────────────────────────────
if [[ -z "${LIB_DIR:-}" ]]; then
    # Running standalone — source libraries
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    LIB_DIR="$SCRIPT_DIR/lib"
    source "$LIB_DIR/common.sh"
    source "$LIB_DIR/config.sh"
    source "$LIB_DIR/import-client.sh"
    source "$LIB_DIR/client-install.sh"
    source "$LIB_DIR/client-configs.sh"
    source "$LIB_DIR/localization.sh"
    source "$LIB_DIR/required-data.sh"
    source "$LIB_DIR/self-update.sh"
fi

# ────────────────────────────────────────────────────────────
# Show Player Menu
# ────────────────────────────────────────────────────────────
show_player_menu() {
    local choice

    while true; do
        clear_screen
        print_header "TES3MP Easy — Player"

        echo ""
        echo "  ── Установка клиента ──"
        echo ""
        echo "  1. 🎮 Установить TES3MP клиент (Proton)"
        echo "  2. 🔤 Настроить шрифты (TrueType)"
        echo "  3. 🌐 Настроить адрес сервера"
        echo ""
        echo "  ── Моды с сервера ──"
        echo ""
        echo "  4. 📥 Скачать и установить моды"
        echo "  5. 🔄 Обновить моды (перекачать)"
        echo ""
        echo "  ── Данные с сервера ──"
        echo ""
        echo "  6. 👥 Скачать данные игроков"
        echo "  7. 🌍 Скачать данные мира"
        echo ""
        echo "  ── Инструменты ──"
        echo ""
        echo "  8. 🔑 Сгенерировать requiredDataFiles.json"
        echo "  9. 🌐 Установить локализацию"
        echo ""
        echo "  s. ⚙  Настройки"
        echo "  u. 🔄 Обновить tes3mp-easy"
        echo "  q.  Выход"
        echo ""
        read -r -p "  Выберите пункт: " choice

        case "$choice" in
            1) install_client ;;
            2) setup_fonts ;;
            3) set_server_address ;;
            4|5) download_mods ;;
            6) download_players ;;
            7) download_world ;;
            8) generate_required_data ;;
            9) install_localization ;;
            s|S) edit_config ; show_config ;;
            u|U) self_update ;;
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
# Entry point when called directly
# ────────────────────────────────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    load_config || {
        first_run_wizard
        load_config
    }
    show_player_menu
fi
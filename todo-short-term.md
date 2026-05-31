# TODO: Переработка логики управления на единое bash-меню

## Цель
Заменить разрозненные bash-скрипты и SSH-команды на единую модульную систему управления
TES3MP сервером и клиентом через одно меню. Пользователь (админ или игрок) скачивает
один скрипт `tes3mp-easy` и дальше всё делает через меню, без ручного SSH.

Избавиться от python на сторонах пользователя и клиента — всё на чистом bash.

---

## Архитектура

### Файловая структура
```
tes3mp-easy                          # bootstrap (~100 строк) — wget'ается пользователем
├── menu-admin.sh                    # меню админа
├── menu-player.sh                   # меню игрока
└── lib/
    ├── common.sh                    # цвета, логи, проверка зависимостей
    ├── config.sh                    # ~/.tes3mp-easy.conf (загрузка, сохранение, wizard)
    ├── server-install.sh            # установка сервера на VPS (ssh + curl install.sh)
    ├── server-control.sh            # start, stop, restart, logs, status
    ├── server-configs.sh            # редактирование конфигов сервера (nano через SSH)
    ├── export-mods.sh               # упаковка + отправка модов на сервер (из tools/linux/)
    ├── export-players.sh            # упаковка + отправка игроков
    ├── export-world.sh              # упаковка + отправка мира
    ├── import-server.sh             # импорт бекапов на сервер (server-side, через SSH)
    ├── import-client.sh             # скачивание с сервера по HTTP — моды, игроки, мир
    ├── required-data.sh             # генерация requiredDataFiles.json (CRC32)
    ├── client-install.sh            # [NEW] установка клиента TES3MP через Proton
    ├── client-configs.sh            # [NEW] настройка клиента (шрифты, settings.cfg, адрес)
    ├── localization.sh              # [NEW] установка локализации (из tools/linux/localization/)
    ├── player-roles.sh              # управление ролями игроков (staffRank)
    └── self-update.sh               # обновление всех скриптов (wget с GitHub)
```

### Единый конфиг: `~/.tes3mp-easy.conf`
```bash
ROLE=admin|player
SSH_HOST=my-server
PLUGINS_DIR=/path/to/plugins
SERVER_SCRIPTS_DIR=/path/to/scripts
CLIENT_DEFAULT=/path/to/tes3mp-client-default.cfg
DATA_FILES=/path/to/Data Files/
OPENMW_CFG=/path/to/openmw.cfg
SERVER_URL=http://server-ip:8085
```
Заполняется через wizard при первом запуске.

### Два режима работы
1. **Интерактивное меню** — `./tes3mp-easy` (без аргументов)
2. **Прямой вызов утилит** — `./tes3mp-easy export-mods`, `./tes3mp-easy start` и т.д.

---

## Меню админа (menu-admin.sh)

```
┌──────────────────────────────────────────────────────┐
│                TES3MP Easy — Admin                    │
│  Host: my-server                                     │
├──────────────────────────────────────────────────────┤
│  ── Установка / Настройка ──                         │
│  1. Установить сервер на VPS                         │
│  2. Перенастроить сервер                             │
│                                                      │
│  ── Управление сервером ──                           │
│  3. ▶ Запустить сервер                               │
│  4. ■ Остановить сервер                              │
│  5. ↻ Перезапустить сервер                           │
│  6. 📜 Логи сервера (Ctrl+C для выхода)              │
│  7. ✎ Редактировать конфиги (cfg / lua / banlist)   │
│                                                      │
│  ── Моды ──                                          │
│  8. 📦 Экспорт модов на сервер                       │
│  9. 🔑 Сгенерировать requiredDataFiles.json          │
│                                                      │
│  ── Игроки / Мир ──                                  │
│  10. 👥 Экспорт игроков                              │
│  11. 🌍 Экспорт мира                                 │
│  12. 🛡 Управление ролями игроков                    │
│                                                      │
│  ── Импорт (с серверной стороны) ──                  │
│  13. 📥 Импорт модов (server-side)                   │
│  14. 📥 Импорт игроков (server-side)                 │
│  15. 📥 Импорт мира (server-side)                    │
│                                                      │
│  ── Инструменты ──                                   │
│  p. 🎮 Перейти в меню игрока                         │
│  u. 🔄 Обновить tes3mp-easy                          │
│  s. ⚙ Настройки (SSH host, пути)                    │
│  q. Выход                                            │
└──────────────────────────────────────────────────────┘
```

## Меню игрока (menu-player.sh)

```
┌──────────────────────────────────────────────────────┐
│                TES3MP Easy — Player                   │
├──────────────────────────────────────────────────────┤
│  ── Установка клиента ──                             │
│  1. 🎮 Установить TES3MP клиент (Proton)             │
│  2. 🔤 Настроить шрифты (TrueType)                   │
│  3. 🌐 Настроить адрес сервера                       │
│                                                      │
│  ── Моды с сервера ──                                │
│  4. 📥 Скачать и установить моды                     │
│  5. 🔄 Обновить моды (перекачать)                    │
│                                                      │
│  ── Данные с сервера (если разрешено) ──             │
│  6. 👥 Скачать данные игроков                        │
│  7. 🌍 Скачать данные мира                           │
│                                                      │
│  ── Инструменты ──                                   │
│  8. 🔑 Сгенерировать requiredDataFiles.json          │
│  9. 🌐 Установить локализацию                        │
│  s. ⚙ Настройки (URL сервера, пути Data Files)      │
│  u. 🔄 Обновить tes3mp-easy                          │
│  q. Выход                                            │
└──────────────────────────────────────────────────────┘
```

---

## Bash subcommands (прямой вызов без меню)

```bash
./tes3mp-easy install-server          # установить сервер на VPS
./tes3mp-easy configure-server        # перенастроить сервер
./tes3mp-easy start                   # запустить сервер
./tes3mp-easy stop                    # остановить
./tes3mp-easy restart                 # перезапустить
./tes3mp-easy logs                    # логи (follow)
./tes3mp-easy export-mods             # экспорт модов
./tes3mp-easy export-players          # экспорт игроков
./tes3mp-easy export-world            # экспорт мира
./tes3mp-easy import-mods-client      # скачать моды (HTTP)
./tes3mp-easy import-players-client   # скачать игроков (HTTP)
./tes3mp-easy import-world-client     # скачать мир (HTTP)
./tes3mp-easy install-client          # установка клиента TES3MP
./tes3mp-easy install-localization    # установка локализации
./tes3mp-easy self-update             # обновить скрипты
./tes3mp-easy config                  # открыть nano ~/.tes3mp-easy.conf
./tes3mp-easy menu                    # меню админа
./tes3mp-easy player-menu             # меню игрока
```

---

## План реализации

### Шаг 1. `lib/common.sh` — общие утилиты
- Цвета (RED, GREEN, YELLOW, BLUE, NC)
- Функции: info(), ok(), warn(), err()
- Проверка зависимостей (check_deps: curl, wget, tar, rhash, ssh, scp, dialog/whiptail опционально)
- Функция press_enter_to_continue()

### Шаг 2. `lib/config.sh` — конфигурация
- `load_config()` — source ~/.tes3mp-easy.conf, проверка наличия
- `save_config()` — запись переменных в файл
- `first_run_wizard()` — диалог первого запуска:
  - Спрашивает роль (admin / player)
  - Если admin: спрашивает SSH_HOST, PLUGINS_DIR, SERVER_SCRIPTS_DIR
  - Если player: спрашивает SERVER_URL, DATA_FILES, OPENMW_CFG, CLIENT_DEFAULT
- `edit_config()` — открыть nano ~/.tes3mp-easy.conf

### Шаг 3. `lib/server-install.sh` — установка сервера
- `install_server()` — ssh "$SSH_HOST" "curl -fsSL https://raw.../install.sh | bash"
- `configure_server()` — ssh "$SSH_HOST" "bash /tes3mp-easy/scripts/configure.sh"
  - Поддержка флагов: --default, --test
  - Интерактивный режим: проброс TTY (-t)

### Шаг 4. `lib/server-control.sh` — управление сервером
- `server_start()` — ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose up -d"
- `server_stop()` — ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose down"
- `server_restart()` — ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose restart"
- `server_logs()` — ssh -t "$SSH_HOST" "cd /tes3mp-easy && docker compose logs -f"
- `server_status()` — ssh "$SSH_HOST" "cd /tes3mp-easy && docker compose ps"

### Шаг 5. `lib/server-configs.sh` — редактирование конфигов
- `edit_server_cfg()` — ssh -t "$SSH_HOST" "nano /tes3mp-easy/configs/tes3mp-server-default.cfg"
- `edit_lua_config()` — ssh -t "$SSH_HOST" "nano /tes3mp-easy/configs/config.lua"
- `edit_banlist()` — ssh -t "$SSH_HOST" "nano /tes3mp-easy/configs/banlist.json"
- С подменю: выбор какого конфига редактировать

### Шаг 6. `lib/export-mods.sh` — экспорт модов
- Перенести логику из `tools/linux/tes3mp-easy-export-mods`
- Читает конфиг из ~/.tes3mp-easy.conf (вместо отдельного .conf)
- Валидация CRC32 через requiredDataFiles.json
- Упаковка через source package.sh (из server_setup/scripts/)
- SCP архива на сервер
- SSH вызов import_mods.sh + deploy_mods.sh --latest
- Убрать жёсткую привязку к $(dirname "$0")/tes3mp-easy-export.conf

### Шаг 7. `lib/export-players.sh` — экспорт игроков
- Перенести логику из `tools/linux/tes3mp-easy-export-players`
- Упаковка player-файлов
- SCP + SSH deploy_players.sh --latest

### Шаг 8. `lib/export-world.sh` — экспорт мира
- Перенести логику из `tools/linux/tes3mp-easy-export-world`
- Упаковка world-файлов
- SCP + SSH deploy_world.sh --latest

### Шаг 9. `lib/import-server.sh` — серверный импорт
- `import_mods_server()` — ssh "cd /tes3mp-easy && bash scripts/import_mods.sh"
- `import_players_server()` — ssh "cd /tes3mp-easy && bash scripts/import_players.sh"
- `import_world_server()` — ssh "cd /tes3mp-easy && bash scripts/import_world.sh"
- Подменю выбора типа импорта

### Шаг 10. `lib/import-client.sh` — клиентское скачивание (HTTP)
- Перенести логику из `tools/linux/tes3mp-easy-import-mods`
- `download_mods()` — wget $SERVER_URL/get-mods -O mods.tar.gz → распаковать в DATA_FILES
- `download_players()` — wget $SERVER_URL/get-players
- `download_world()` — wget $SERVER_URL/get-world
- Обновление openmw.cfg (добавление путей к плагинам)
- Проверка и удаление конфликтующей data/ папки

### Шаг 11. `lib/required-data.sh` — requiredDataFiles.json
- Перенести логику из `tools/linux/tes3mp-easy-generate-required-data`
- Генерация CRC32 для плагинов из PLUGINS_DIR
- Исключение оригинальных файлов (Morrowind.esm, Tribunal.esm, Bloodmoon.esm)

### Шаг 12. `lib/client-install.sh` — установка клиента [NEW]
- Автоматизация инструкции из `docs/player/linux/proton/install.md`
- Скачивание tes3mp.Win64.release.0.8.1.zip
- Распаковка в ~/morrowind/tes3mp
- Создание symlink ~/morrowind → ~/.steam/steam/steamapps/common/Morrowind
- Поиск compatdata wizard'а (find + grep .reg файлов)
- Поиск compatdata tes3mp
- Symlink pfx между wizard и tes3mp
- Инструкция по добавлению в Steam (если не автоматизировано)
- Установка MangoHud для ограничения FPS

### Шаг 13. `lib/client-configs.sh` — настройка клиента [NEW]
- Копирование example-settings.cfg в openmw-profile
- Настройка серверного адреса в tes3mp-client-default.cfg
- Кастомные TTF шрифты

### Шаг 14. `lib/localization.sh` — локализация [NEW]
- Перенести логику из `tools/linux/localization/russian/install.sh`
- Поддержка разных языков (пока русский)
- Скачивание и установка файлов локализации

### Шаг 15. `lib/player-roles.sh` — роли игроков
- Просмотр списка игроков (ls /tes3mp-easy/players/*.json)
- Изменение staffRank через sed/jq на сервере
- Требует stop/start сервера

### Шаг 16. `lib/self-update.sh` — самообновление
- Скачивание свежих версий всех lib/*.sh, menu-*.sh, tes3mp-easy
- Проверка хешей (опционально)
- Перезапуск меню после обновления

### Шаг 17. `menu-player.sh` — меню игрока
- select-based меню (или dialog/whiptail если доступен)
- Вызов функций из lib/
- Пункт выхода

### Шаг 18. `menu-admin.sh` — меню админа
- select-based меню (или dialog/whiptail если доступен)
- Вызов функций из lib/
- Пункт «Перейти в меню игрока» → exec menu-player.sh

### Шаг 19. `tes3mp-easy` — точка входа (bootstrap)
- При первом запуске: скачивает все lib/*.sh + menu-*.sh в ~/.local/share/tes3mp-easy/
- source всех lib/*.sh
- Если нет конфига → first_run_wizard()
- Если передан subcommand → диспатч
- Иначе → show_menu() (menu-admin.sh или menu-player.sh в зависимости от ROLE)

### Шаг 20. Обновление документации
- `docs/admin/install.md` — сократить до reference, заменить шаги на «запусти ./tes3mp-easy»
- `docs/admin/management.md` — сократить, оставить только концептуальные вещи
- `docs/player/install.md` — сократить до «запусти ./tes3mp-easy и выбери пункт 1»
- `README.md` — новая секция «Быстрый старт» с wget и меню

---

## Что будет удалено / заменено

| Было | Стало |
|------|-------|
| `tools/linux/tes3mp-easy-export-mods` | `lib/export-mods.sh` |
| `tools/linux/tes3mp-easy-export-players` | `lib/export-players.sh` |
| `tools/linux/tes3mp-easy-export-world` | `lib/export-world.sh` |
| `tools/linux/tes3mp-easy-import-mods` | `lib/import-client.sh` |
| `tools/linux/tes3mp-easy-generate-required-data` | `lib/required-data.sh` |
| `tools/linux/tes3mp-easy-export.conf.example` | `~/.tes3mp-easy.conf` (секция export+mods) |
| `tools/linux/tes3mp-easy-import.conf.example` | `~/.tes3mp-easy.conf` (секция import) |
| `tools/linux/localization/russian/install.sh` | `lib/localization.sh` |
| Алиасы в .bashrc | `./tes3mp-easy <subcommand>` |
| Ручные SSH-команды из management.md | Пункты меню |

## Что остаётся без изменений
- `server_setup/scripts/*.sh` — серверные скрипты (дёргаются через SSH)
- `server_setup/docker/*` — Docker-файлы
- `tools/example-settings.cfg` — копируется скриптом
- `tools/localization/russian/` — файлы локализации (скачиваются скриптом)

---

## Безопасность
- Все исходники открыты на GitHub — пользователь может прочитать
- Скрипт **не трогает** `~/.ssh/config` без явного согласия
- Перед выполнением показывает команду: `Будет выполнено: ssh my-server "..." `
- Работает от обычного пользователя, не требует root (кроме server-side install.sh)
- Никаких скрытых curl | bash без предупреждения

---

## Заметки по текущим «костылям» (для исправления в процессе)

1. **Установка клиента через Proton** — сейчас 4 ручных шага с поиском compatdata ID.
   Можно автоматизировать поиск ID через find+grep .reg файлов.

2. **Два разных конфига для экспорта и импорта** — пересекаются по переменным.
   Объединить в один `~/.tes3mp-easy.conf`.

3. **Игрок клонирует весь репозиторий** — заменить на wget одного скрипта.

4. **Локализация отдельным скриптом** — встроить в меню игрока.

5. **20+ SSH-команд в management.md** — все уезжают в пункты меню.
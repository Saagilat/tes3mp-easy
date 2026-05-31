# План: Рефакторинг импорта/экспорта — разделение стадий

## Мотивация
Текущая архитектура смешивает доставку архива и его развёртывание.
Нужно разделить:
1. **Stage 1 — Валидация и хранение** (принять архив, проверить, сохранить)
2. **Stage 2 — Развёртывание** (остановить сервер, бэкап, накат, запуск)

### Почему import и deploy — разные скрипты?
- **import** работает без остановки сервера: можно параллельно загружать несколько архивов.
- **deploy** требует остановки: перезапись данных на работающем сервере приведёт к рассинхронизации или повреждению.
- Разделение даёт гибкость: администратор может накопить несколько архивов через import, а потом сделать deploy один раз.

---

## Архитектура маунтов (новый Dockerfile)

Переделать tes3mp.dockerfile: скачивать TES3MP tarball в образ, копировать в образ
`tes3mp-server` + `lib/` + `resources/` + `server/lib/`.

Маунт — только изменяемые данные. Всего 4 группы маунтов:

### 1. `players/` → `/tes3mp/server/data/player`

### 2. `world/` — **пять подмаунтов**, по одной на каждую поддиректорию:
- `world/cell/` → `/tes3mp/server/data/cell`
- `world/world/` → `/tes3mp/server/data/world`
- `world/map/` → `/tes3mp/server/data/map`
- `world/recordstore/` → `/tes3mp/server/data/recordstore`
- `world/custom/` → `/tes3mp/server/data/custom`

> **Почему пять подмаунтов, а не один `world/` → `/tes3mp/server/data`?**
> Потому что плагины (.esp/.omwaddon) тоже должны лежать в `/tes3mp/server/data/`. Если бы world/ маунтился в корень `/tes3mp/server/data`, то Docker bind mount перекрыл бы всю директорию, и файлы из образа (или других маунтов) стали бы невидны. Разделив world/ на поддиректории, мы оставляем возможность положить плагины в корень `/tes3mp/server/data/` — см. секцию "Симлинки плагинов" ниже.

### 3. `mods/` — два подмаунта:
- `mods/plugins/` → **`/tes3mp/data-plugins/`** (плагины маунтятся в отдельную директорию, откуда entrypoint.sh создаёт симлинки в нужное место)
- `mods/scripts/` → `/tes3mp/server/scripts/custom` (Lua-скрипты)

> **Почему mods/plugins/ маунтится не напрямую в `/tes3mp/server/data`?**
> Если замаунтить `mods/plugins/` в `/tes3mp/server/data`, этот маунт перекроет собой ВСЁ содержимое `/tes3mp/server/data` в контейнере, в том числе поддиректории, замаунченные другими маунтами: `cell/`, `world/`, `map/`, `recordstore/`, `custom/` (из группы `world/`) и `player/` (из группы `players/`). Docker не гарантирует корректную работу nested bind mounts — дочерние mounts могут не создаться или работать непредсказуемо в зависимости от storage driver. Поэтому плагины маунтятся в отдельный уникальный путь, а entrypoint-скрипт контейнера создаёт симлинки в нужную директорию (см. ниже "Симлинки плагинов").
>
> **Почему deploy-скрипты работают на хосте, а не лезут в контейнер?** Все изменяемые данные вынесены в маунты на хосте. deploy-скрипт просто распаковывает архив в соответствующую маунт-директорию — контейнер видит изменения сразу после перезапуска. Не нужно exec'иться в контейнер или копировать файлы внутрь.

### 4. `configs/`:
- `configs/tes3mp-server-default.cfg` → `/tes3mp/tes3mp-server-default.cfg`
- `configs/banlist.json` → **`/tes3mp/server/data/banlist.json`** (маунтится напрямую — изменения, внесённые сервером (баны через игру), сохраняются между рестартами контейнера)
- `configs/config.lua` → `/tes3mp/server/scripts/config.lua`

> **Почему banlist.json маунтится напрямую в `/tes3mp/server/data/banlist.json`, а не копируется через entrypoint?** Потому что banlist.json может изменяться самим TES3MP (игра добавляет/удаляет записи в баны при игре через админку). Если бы entrypoint.sh копировал его при каждом старте контейнера, эти изменения терялись бы после перезапуска. Прямой маунт гарантирует, что контейнер пишет изменения обратно на хостовую ФС — баны сохраняются между рестартами. Конфликта с маунтами world/* и players/ нет — Docker корректно обрабатывает маунт отдельного файла в директорию, где замаунчены поддиректории (это не nested bind mount в опасном смысле, т.к. маунтится не директория, а файл).

> `requiredDataFiles.json` не маунтится отдельно — он является частью архива модов и обновляется при деплое модов (копируется из архива в `mods/plugins/requiredDataFiles.json`).

`backups/` на хосте — не маунтится.
`mods.tar.gz` для nginx отдельно не создаётся — nginx раздаёт файл по `current.txt`.

### Симлинки плагинов в контейнере (entrypoint.sh)

Поскольку плагины (.esp, .omwaddon) и `requiredDataFiles.json` маунтятся в `/tes3mp/data-plugins/`, а TES3MP ожидает их в `/tes3mp/server/data/`, в образ добавляется entrypoint-скрипт, который при старте контейнера создаёт симлинки:

```bash
#!/bin/sh
# Включаем nullglob, чтобы glob *.esp/*.omwaddon не создавал битые симлинки
# при пустой директории /tes3mp/data-plugins/
shopt -s nullglob
# Создать симлинки на плагины из /tes3mp/data-plugins/ в /tes3mp/server/data/
if [ -d /tes3mp/data-plugins ]; then
  ln -sf /tes3mp/data-plugins/*.esp /tes3mp/server/data/ 2>/dev/null
  ln -sf /tes3mp/data-plugins/*.omwaddon /tes3mp/server/data/ 2>/dev/null
  if [ -f /tes3mp/data-plugins/requiredDataFiles.json ]; then
    ln -sf /tes3mp/data-plugins/requiredDataFiles.json /tes3mp/server/data/requiredDataFiles.json
  fi
fi
# Перейти к основному процессу
exec /tes3mp/tes3mp-server
```

**Почему не копировать, а симлинки?** При следующем деплое модов файлы в `/tes3mp/data-plugins/` заменяются (через маунт на хосте). Симлинки автоматически указывают на новые файлы после перезапуска контейнера — не нужно пересобирать образ.

> **Почему banlist.json не копируется, а маунтится напрямую?** См. пояснение в секции configs/ выше. Баны через игру должны сохраняться между рестартами контейнера, поэтому файл маунтится напрямую в `/tes3mp/server/data/banlist.json`.

> **Почему в entrypoint.sh используется `shopt -s nullglob`?** Если в `/tes3mp/data-plugins/` нет .esp/.omwaddon файлов, bash по умолчанию раскрывает несовпавший glob как литерал: `ln -sf /tes3mp/data-plugins/*.esp …` создаст битую симлинку с именем `*.esp`. nullglob заставляет bash превращать несовпавший glob в пустую строку — команда просто ничего не сделает.

### Почему 4 группы маунтов, а не больше?
- `players/` — отдельно, чтобы можно было мигрировать игроков между серверами (забрать свой профиль и перенести на другой сервер).
- `world/` — отдельно, чтобы можно было сбросить состояние мира или запустить новую игру, не трогая игроков и моды.
- `mods/` — отдельно, чтобы менять сборку модов независимо от мира и игроков.
- `configs/` — отдельно, настройки сервера.

> **Чем отличается `custom/` внутри world от `scripts/` внутри mods?**
> - `world/custom/` (маунтится в `/tes3mp/server/data/custom/`) — это **данные Lua-модов**: например, состояния кастомных механик, таблицы, сохранённые модом значения. Это часть состояния мира.
> - `mods/scripts/` (маунтится в `/tes3mp/server/scripts/custom/`) — это **серверные Lua-скрипты**: код, который выполняется на сервере. Это часть модов.
>
> Они находятся в разных местах иерархии TES3MP, поэтому разнесены по разным маунтам.

---

## Общее хранилище бэкапов

```
backups/
├── mods/
│   ├── init-<timestamp>-mods.tar.gz          # создано install.sh при первом развёртывании
│   ├── import-<timestamp>-mods.tar.gz        # получено извне (import_mods.sh)
│   ├── backup-<timestamp>-mods.tar.gz        # бэкап старых модов при деплое
│   └── current.txt                           # "<sha256> <filename>"
├── players/
│   ├── init-<timestamp>-players.tar.gz       # создано install.sh при первом развёртывании
│   ├── import-<timestamp>-players.tar.gz     # получено извне (import_players.sh)
│   ├── backup-<timestamp>-players.tar.gz     # бэкап при деплое
│   └── current.txt
└── world/
    ├── init-<timestamp>-world.tar.gz         # создано install.sh при первом развёртывании
    ├── import-<timestamp>-world.tar.gz       # получено извне (import_world.sh)
    ├── backup-<timestamp>-world.tar.gz       # бэкап при деплое
    └── current.txt
```

- Все архивы — именованные по времени с префиксом `init-`, `import-` или `backup-`
- `current.txt` (в формате `<sha256> <filename>`) — какой архив сейчас активен. Для world и players внутри самого архива тоже есть `current.txt`, но он содержит **ссылку на сборку модов** (sha256 архива модов), на которой эти данные были созданы — это мета-информация для человека/скрипта, а не self-hash.
- Откат = переключить `current.txt` на другой архив + перезапуск
- `import-mods/` / `import-players/` / `import-world/` — временные директории для SCP, чистятся после валидации
- **Префиксы:**
  - `init-` — архив, созданный install.sh при первом развёртывании сервера (пустой мир, пустые игроки). По сути это "заводской" бэкап.
  - `import-` — архив, присланный администратором через import-скрипт (SCP).
  - `backup-` — архив, созданный автоматически deploy-скриптом перед накаткой нового архива.
- Для `--latest` deploy-скрипты ищут только `import-*` и `init-*` файлы (все валидные "целевые" архивы, не бэкапы).

---

## Моды

### Формат архива
```
mods.tar.gz
├── plugins/
│   ├── mod1.esp
│   ├── mod2.omwaddon
│   └── requiredDataFiles.json
└── scripts/
    └── test.lua
```

Архив распаковывается на хосте напрямую в маунт-директории:
- `plugins/` → `mods/plugins/` (контейнер видит как /tes3mp/data-plugins/, откуда entrypoint.sh создаёт симлинки в /tes3mp/server/data/)
- `scripts/` → `mods/scripts/` (контейнер видит как /tes3mp/server/scripts/custom)

### Доставка (`tes3mp-easy-export-mods`)
- [ ] 0) Пользователь запускает клиент
- [ ] 1) Пакет модов + валидация CRC32 (как сейчас)
- [ ] 2) SCP на сервер в `/tes3mp-easy/import-mods/`
- [ ] 3) SSH `bash scripts/import_mods.sh` — приём и валидация
       - **Клиент проверяет exit code.** Если import завершился ошибкой (архив битый, CRC32 не совпал, диск переполнен) — deploy НЕ вызывается, скрипт завершается с ошибкой.
- [ ] 4) SSH `bash scripts/deploy_mods.sh` — развёртывание (только если шаг 3 успешен)

### Приём и валидация (`import_mods.sh`)
- [ ] 1) Проверяет архив на целостность (CRC32 из requiredDataFiles.json)
- [ ] 2) Если ок — перемещает в `backups/mods/import-<timestamp>-mods.tar.gz`
- [ ] 3) Если нет — удаляет, пишет ошибку
- [ ] 4) Сервер **НЕ останавливает**
- [ ] 5) Очищает `import-mods/`

> **Почему сервер не останавливается?** import — это только сохранение архива. Развёртывание (deploy) — отдельный шаг. Это позволяет принять несколько архивов подряд, не прерывая игру.

### Развёртывание (`deploy_mods.sh`)

**Три режима:**
- `deploy_mods.sh` — развернуть из current.txt (проверяет sha256 и существование файла)
- `deploy_mods.sh --latest` — найти последний `import-*.tar.gz` или `init-*.tar.gz` в `backups/mods/`, развернуть его и записать в current.txt
- `deploy_mods.sh <filename>` — откат на конкретный архив из `backups/mods/`

**Флоу:**
- [ ] 1) Определить, какой архив деплоить (current.txt / --latest / <filename>)
- [ ] 2) **Проверить свободное место на диске для бэкапов.** Оценить размер текущих данных (моды, мир, игроки). Если места не хватит на создание всех бэкапов — завершиться с ошибкой (ничего не трогать).
- [ ] 3) Бэкап текущих модов перед деплоем:
       - Если current.txt **валиден** (файл существует, sha256 совпадает, сам архив на месте) — бэкап модов не нужен, данные на хосте уже соответствуют этому архиву. Просто переключаемся на новый архив.
       - Если current.txt **невалиден** (отсутствует/пуст/хеш не совпадает/файла нет) ИЛИ это откат (`<filename>`) — значит текущее состояние на хосте не привязано ни к какому архиву, и перед заменой его нужно сохранить:
         - Бэкапит текущие моды через `package.sh package_mods` в `backups/mods/backup-<timestamp>-mods.tar.gz`

> **Почему нельзя всегда бэкапить моды, чтобы упростить логику?** VPS может быть на 7GB SSD — архив модов бывает большим, а каждый лишний бэкап съедает место. Если админ что-то вручную меняет в маунтах, а не катает через deploy — это его ответственность, и оптимизировать под такой сценарий ценой дополнительных бэкапов нецелесообразно. Автоматическая чистка старых бэкапов тоже нежелательна — админ может рассчитывать на возможность отката к конкретной версии.
- [ ] 4) Бэкапит мир (`package_world`) и игроков (`package_players`) в `backups/.../backup-<timestamp>-*.tar.gz` (всегда)

> **Почему deploy_mods.sh бэкапит мир и игроков?** Моды могут сломать персонажей или состояние мира (например, неправильный скрипт затирает данные). Бэкап мира и игроков перед накаткой модов даёт возможность откатиться до "до-модного" состояния целиком.
- [ ] 5) Останавливает TES3MP (`docker compose down`)
- [ ] 6) **Проверить свободное место для распаковки архива.** Оценить размер разархивированных модов (`gzip -dc архив | wc -c` или `tar t`). Если места не хватит — восстановить состояние: запустить сервер (`docker compose up -d`) и завершиться с ошибкой. Старые данные не тронуты, т.к. мы ещё ничего не удаляли.
- [ ] 7) Распаковывает архив: `plugins/` → `mods/plugins/`, `scripts/` → `mods/scripts/`
- [ ] 8) Генерирует `customScripts.lua`
- [ ] 9) Записывает `current.txt` (sha256 + filename)
- [ ] 10) Запускает TES3MP (`docker compose up -d`)

---

## Игроки

### Формат архива
```
players.tar.gz
├── player/
│   └── AccountName1.json
├── requiredDataFiles.json   (мета-информация — не валидируется¹)
└── current.txt               (метка сборки модов²)
¹ Файл нужен человеку, который скачал архив, чтобы понимать: этот персонаж играл на определённой сборке модов. Импорт такого персонажа в другую сборку или ванилу может сломать его. Валидация CRC32 для игроков/мира не имеет смысла — файлы JSON не бинарные, их CRC32 меняется от любого пересохранения сервером.
² current.txt внутри архива игроков/мира содержит sha256 архива модов, на котором эти данные были экспортированы. Это мета-информация для сопоставления сборок. Это НЕ self-hash архива игроков/мира — хеш самого архива записывается в backups/<type>/current.txt при деплое.
```

### Приём (`import_players.sh`)
- [ ] 1) Принимает архив (SCP во временную директорию)
- [ ] 2) Перемещает в `backups/players/import-<timestamp>-players.tar.gz`
- [ ] 3) Очищает import-players/
- [ ] 4) Сервер **НЕ останавливает**

> **Почему import_players.sh не останавливает сервер?** Он только сохраняет присланный архив. Разворачивать его или нет — решает администратор отдельным вызовом deploy_players.sh.

### Развёртывание (`deploy_players.sh`)
- [ ] 1) Проверить свободное место для бэкапа — если не хватит, abort
- [ ] 2) Бэкап текущих игроков в `backups/players/backup-<timestamp>-players.tar.gz`
- [ ] 3) Останавливает TES3MP
- [ ] 4) Проверить свободное место для распаковки — если не хватит, запустить сервер и abort
- [ ] 5) Очищает папку `players/` (удалить всё содержимое)
- [ ] 6) Распаковывает архив: извлекается только `player/` (директория с JSON), мета-файлы `requiredDataFiles.json` и `current.txt` из архива в маунт не попадают
- [ ] 7) Запускает TES3MP
- [ ] 8) Записывает `current.txt` (sha256 развёрнутого архива импорта)

---

## Мир (world)

### Формат архива
```
world.tar.gz
├── cell/           (внешние ячейки)
├── world/          (динамическое состояние мира)
├── map/            (тайлы карты)
├── recordstore/    (record overrides)
├── custom/         (данные Lua-модов)
├── requiredDataFiles.json   (мета-информация — не валидируется¹)
└── current.txt               (метка сборки модов² — см. примечание для игроков выше)
¹ См. примечание для игроков выше.
² См. примечание для игроков выше.
```

### Приём (`import_world.sh`)
- [ ] 1) Принимает архив (SCP во временную директорию)
- [ ] 2) Перемещает в `backups/world/import-<timestamp>-world.tar.gz`
- [ ] 3) Очищает import-world/
- [ ] 4) Сервер **НЕ останавливает**

> **Почему import_world.sh не останавливает сервер?** Аналогично import_players.sh — только приём. Развёртывание — отдельный шаг.

### Развёртывание (`deploy_world.sh`)
- [ ] 1) Проверить свободное место для бэкапа — если не хватит, abort
- [ ] 2) Бэкап текущего мира в `backups/world/backup-<timestamp>-world.tar.gz`
- [ ] 3) Останавливает TES3MP
- [ ] 4) Проверить свободное место для распаковки — если не хватит, запустить сервер и abort
- [ ] 5) Очищает папки `cell/`, `world/`, `map/`, `recordstore/`, `custom/` внутри маунта `world/`
- [ ] 6) Распаковывает архив: извлекаются только `cell/`, `world/`, `map/`, `recordstore/`, `custom/`; мета-файлы `requiredDataFiles.json` и `current.txt` в маунт не попадают
- [ ] 7) Запускает TES3MP
- [ ] 8) Записывает `current.txt` (sha256 развёрнутого архива импорта)

---

## Проверка свободного места — общее правило для deploy-скриптов

Все deploy-скрипты (deploy_mods.sh, deploy_players.sh, deploy_world.sh) следуют одинаковому флоу проверки места:

1. **Перед бэкапом:** оценить размер текущих данных (то, что будем паковать). Если места на бэкап не хватит — abort (ничего не трогали).
2. **После бэкапа, после остановки сервера, перед распаковкой:** оценить размер архива (uncompressed size). Если места не хватит — **восстановить состояние**: запустить сервер (`docker compose up -d`) и abort с ошибкой. Старые данные не тронуты, т.к. мы ничего не удаляли — только создали бэкапы.

Оценка размера разархивированных данных:
- Для распаковки: `gzip -dc архив.tar.gz | wc -c` (размер в байтах) или `tar -tzf архив.tar.gz --to-stdout | wc -c`
- Для бэкапа: оценочно `du -sb` по соответствующей маунт-директории

---

## Установка (install.sh) — что происходит при первом запуске

install.sh не делает специального "inline-деплоя". Вместо этого он использует те же deploy-скрипты, что и при обычной работе:

1. Создаёт маунт-директории (`players/`, `world/cell/`, `world/world/`, `world/map/`, `world/recordstore/`, `world/custom/`, `mods/plugins/`, `mods/scripts/`, `configs/`, `backups/...`)
2. `docker compose up -d --build` — контейнер стартует с пустыми маунтами
3. Если есть файлы в `plugins/` и `server-scripts/` (примеры или пользовательские) — создаёт из них init-архивы:
   - `package_mods` → `backups/mods/init-<timestamp>-mods.tar.gz`
   - `package_world` → `backups/world/init-<timestamp>-world.tar.gz` (пустой мир)
   - `package_players` → `backups/players/init-<timestamp>-players.tar.gz` (пустые игроки)
4. Пишет `current.txt` для каждого типа (ссылается на свежий `init-*` архив)
5. Вызывает `bash scripts/deploy_mods.sh --latest`, `deploy_world.sh --latest`, `deploy_players.sh --latest`
6. Deploy-скрипты выполняют стандартный флоу: бэкап → остановка → распаковка → запуск

> **Почему так, а не inline?** Это гарантирует, что deploy-скрипты всегда работают одинаково — и при первом запуске, и при обычном деплое. Нет special-case'ов. Единственное отличие: init-архивы имеют префикс `init-` вместо `import-`, что визуально отличает "заводские" архивы от присланных администратором.

---

## Nginx — раздача файлов по current.txt

`mods.tar.gz` для nginx отдельно не создаётся. Вместо этого nginx читает `backups/mods/current.txt`, парсит имя файла и раздаёт соответствующий архив из `backups/mods/`.

Техническая реализация (на выбор):
- **Симлинк:** deploy_mods.sh после распаковки создаёт/обновляет симлинк `backups/mods/current.tar.gz` → `backups/mods/<имя-из-current.txt>`. nginx раздаёт `current.tar.gz` по /get-mods.
- **rewrite/alias:** nginx.conf использует `map` для чтения current.txt и переадресации запроса на нужный файл. Сложнее, но без симлинков.

Рекомендуется вариант с симлинком — он проще, на symlink можно повесить корректные права и владельца.

---

## Файлы, которые нужно изменить/создать

### server_setup/docker/
- [ ] **tes3mp.dockerfile** — скачивать tarball, копировать бинарник + lib/ + resources/ в образ, добавить entrypoint.sh как ENTRYPOINT
- [ ] **docker-compose.yml** — 4 группы маунтов (players/, world/* 5 поддиректорий, mods/plugins+scripts, configs/). Пути маунтов: `mods/plugins/ → /tes3mp/data-plugins/`, `configs/banlist.json → /tes3mp/server/data/banlist.json`
- [ ] **entrypoint.sh** — новый файл: создаёт симлинки на плагины из /tes3mp/data-plugins/ в /tes3mp/server/data/ (с `shopt -s nullglob`), НЕ копирует banlist.json (он маунтится напрямую)
- [ ] **nginx.conf** — раздача по current.txt (симлинк)
- [ ] **export.dockerfile** / **export_server.sh** — адаптировать пути под новые маунты

### server_setup/scripts/
- [ ] **install.sh** — создание init-архивов + вызов deploy-скриптов (вместо inline-деплоя). Убрать скачивание примеров из modding-test/.
- [ ] **import_mods.sh** — только приём, валидация, сохранение в `backups/mods/import-*`
- [ ] **deploy_mods.sh** — новый скрипт (развёртывание, бэкап мира/игроков, симлинк для nginx)
- [ ] **import_players.sh** — переделать: только приём и сохранение (без остановки сервера)
- [ ] **deploy_players.sh** — новый скрипт (с остановкой сервера и очисткой players/)
- [ ] **import_cells.sh → import_world.sh** — переименовать, добавить world/ + map/ + recordstore/ + custom/, переименовать у клиента
- [ ] **deploy_world.sh** — новый скрипт
- [ ] **package.sh** — `package_world()` (cell/ + world/ + map/ + recordstore/ + custom/), `package_players()`, `package_mods()`, `package_init_*()` — для пустых init-архивов с requiredDataFiles.json и current.txt

### tools/linux/
- [ ] **tes3mp-easy-export-cells → tes3mp-easy-export-world** — переименовать/адаптировать
- [ ] **tes3mp-easy-export-mods** — под новую архитектуру (SCP + SSH import + SSH deploy, deploy только при успешном import)
- [ ] **tes3mp-easy-export-players** — адаптировать

### Удалить из репозитория
- [ ] **server_setup/tes3mp-server-sample/** — весь каталог
- [ ] **server_setup/modding-test/** — весь каталог

---

## Очерёдность

1. `tes3mp.dockerfile` + `docker-compose.yml` + `entrypoint.sh` — новый Dockerfile, 4 группы маунтов (world/ — 5 подмаунтов), entrypoint для симлинков
2. `package.sh` — `package_world()`, `package_players()`, `package_mods()` с requiredDataFiles.json и current.txt
3. `import_world.sh` (бывший import_cells.sh) — приём, без остановки сервера
4. `deploy_world.sh` — новый скрипт
5. `import_players.sh` — приём, без остановки сервера
6. `deploy_players.sh` — новый скрипт
7. `import_mods.sh` — только приём и валидация
8. `deploy_mods.sh` — единый флоу с current.txt, --latest, откатом, симлинк для nginx
9. `nginx.conf` + `export.dockerfile` / `export_server.sh` — адаптация под новые маунты
10. `install.sh` — адаптация: init-архивы вместо inline-деплоя, вызов deploy-скриптов
11. Клиентские тулы — адаптация под новую архитектуру
12. Удаление tes3mp-server-sample/ и modding-test/
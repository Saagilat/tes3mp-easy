# Managing the TES3MP server (Docker)

All commands are run as root on the VPS from /opt/tes3mp.

| Action | Command | Details |
|--------|---------|---------|
| Start | `cd /opt/tes3mp && docker compose up -d` | First run only — builds and starts the container |
| Restart | `cd /opt/tes3mp && docker compose restart` | Sends SIGTERM to TES3MP; with `stop_grace_period: 30s` the server saves before exit |
| View live logs | `cd /opt/tes3mp && docker compose logs -f` | |
| Stop | `cd /opt/tes3mp && docker compose down` | |
| Edit config | `nano /opt/tes3mp/data/tes3mp-server-default.cfg` | Afterwards, run **Restart** to apply changes |
| Edit Lua config | `nano /opt/tes3mp/data/server/scripts/config.lua` | Afterwards, run **Restart** to apply changes |
| Edit ban list | `nano /opt/tes3mp/data/server/data/banlist.json` | Afterwards, run **Restart** to apply changes |
| Sync plugins & scripts | `bash /opt/tes3mp/update_mods.sh` | Copies files from `plugins/` and `server-scripts/` to the server data directories |

## Configuration (direct access via data/)

All config files are stored in the `data/` directory on the host, which is bind-mounted into the container at `/tes3mp`. Edit them with any text editor and run **`docker compose restart`** for changes to take effect.

| Host path | Container path |
|-----------|----------------|
| `/opt/tes3mp/data/tes3mp-server-default.cfg` | `/tes3mp/tes3mp-server-default.cfg` |
| `/opt/tes3mp/data/server/scripts/config.lua` | `/tes3mp/server/scripts/config.lua` |
| `/opt/tes3mp/data/server/data/banlist.json` | `/tes3mp/server/data/banlist.json` |
| `/opt/tes3mp/data/requiredDataFiles.json` | `/tes3mp/server/data/requiredDataFiles.json` |

After editing any config file, run:

```bash
cd /opt/tes3mp && docker compose restart
```

> **Note:** Config bind mounts are read-only inside the container. To make persistent changes, edit the host files. If you delete a config file from the host, the container will use the defaults bundled in the image.

## Data persistence

Player progress (characters, inventory, cells) is stored in bind mounts on the host filesystem:

| Inside container | On host |
|-----------------|---------|
| `/tes3mp/server/data/player/` | `/opt/tes3mp/data/players/` |
| `/tes3mp/server/data/cell/` | `/opt/tes3mp/data/cells/` |
| `/tes3mp/data/` (mods & assets) | `/opt/tes3mp/data/` |

Why `/tes3mp/server/data/player` and not `/tes3mp/players`? Because TES3MP's config sets `home = ./server`, and by default it writes player data to `./data/player` relative to that home directory. The bind mounts mirror exactly where TES3MP writes.

Unlike named volumes, bind mounts are never automatically removed by Docker — data survives rebuilds, container crashes, and even `docker compose down -v`.

### How saving works

TES3MP saves player data in three ways:

1. **On disconnect** — when a player leaves, `OnPlayerDisconnect` fires and calls `SaveToDrive()`
2. **Auto-save interval** — by default every **300 seconds (5 minutes)**, all players, world, and record stores are serialized to disk
3. **On server shutdown** — when the server receives SIGTERM (e.g. `docker compose restart` or `docker compose down`), it calls `OnServerExit` which triggers a final save

The auto-save interval (`config.autoSaveInterval` in `config.lua`) is your safety net — even if the server crashes, you lose at most 5 minutes of progress.


## Staff ranks (права администратора)

В TES3MP используется система рангов (staffRank) для разграничения прав. Ранг хранится в JSON-файле игрока и проверяется при выполнении команд.

| Ранг | Название | Метод проверки | Описание |
|------|----------|----------------|----------|
| 0 | Обычный игрок | — | Нет особых прав |
| 1 | Модератор | `IsModerator()` | Базовые команды: `/ban`, `/kick`, `/teleport`, `/resetcell` и др. |
| 2 | Администратор | `IsAdmin()` | Команды управления сервером: `/addmoderator`, `/setrace`, `/load` и др. |
| 3 | Владелец сервера | `IsServerOwner()` | Полный доступ: `/addadmin`, `/removeadmin` |

### Команды для управления рангами

Все команды выполняются в игровом чате. PID игрока можно узнать через `/players` или `/list`.

| Команда | Требуется ранг | Действие |
|---------|----------------|----------|
| `/addadmin <pid>` | ServerOwner (3) | Назначить игрока администратором (staffRank = 2) |
| `/removeadmin <pid>` | ServerOwner (3) | Понизить администратора до модератора (staffRank = 1) |
| `/addmoderator <pid>` | Admin (2+) | Назначить игрока модератором (staffRank = 1) |
| `/removemoderator <pid>` | Admin (2+) | Снять модератора (staffRank = 0) |

> **Примечание:** ServerOwner (staffRank = 3) назначается автоматически первому зарегистрированному аккаунту на сервере. Через игровые команды назначить ServerOwner нельзя — только через прямое редактирование файла.

### Ручное редактирование ранга

Если нужно изменить ранг напрямую (например, назначить ServerOwner другому игроку или восстановить права):

1. Остановите сервер:
   ```bash
   cd /opt/tes3mp && docker compose down
   ```
2. Откройте JSON-файл игрока:
   ```bash
   nano /opt/tes3mp/data/players/<accountName>.json
   ```
3. Найдите секцию `settings` и измените поле `staffRank`:
   ```json
   "settings": {
       "staffRank": 2,
       ...
   }
   ```
   Значения: `0` — обычный игрок, `1` — модератор, `2` — администратор, `3` — владелец сервера.
4. Сохраните файл и запустите сервер:
   ```bash
   cd /opt/tes3mp && docker compose up -d
   ```

## Plugin and script management

### Local plugins directory

Place `.esp`/`.esm`/`.omwaddon` files in `plugins/`.  
Place Lua server scripts in `server-scripts/`.

### tes3mp-server-update (from a client machine)

If you develop plugins and scripts on another machine, use `tes3mp-server-update`:

```bash
# Edit the config
nano tools/tes3mp-server-update.conf

# Sync everything to the server
bash tools/tes3mp-server-update
```

### update_mods.sh (on the server)

Run this on the server after placing files in `plugins/` and `server-scripts/`:

```bash
bash /opt/tes3mp/update_mods.sh
```

The script:
* Removes old plugins from `server/data/` (keeping original files: `Morrowind.esm`,
  `Tribunal.esm`, `Bloodmoon.esm`)
* Copies all plugins from `plugins/` to `server/data/`
* Synchronises `.lua` scripts from `server-scripts/` to `server/scripts/custom/`
  (removes files that no longer exist)
* Generates `server/scripts/customScripts.lua` with `require()` for each script
* Computes CRC32 and generates `server/data/requiredDataFiles.json`
* Creates `plugins.zip` for the `/get-plugins` endpoint
* Creates `server-scripts.zip` for the `/get-server-scripts` endpoint
* Restarts the Docker container automatically

## Enabling HTTP endpoints

The server provides optional HTTP endpoints via port **8085**.
All endpoints are disabled by default. See [tes3mp_settings.md](tes3mp_settings.md) for the full config.lua reference.

### Available endpoints

| Endpoint | Description | File |
|----------|-------------|------|
| `/get-plugins` | Download all server plugins (`.esp`/`.esm`/`.omwaddon`) | `plugins.zip` |
| `/get-server-scripts` | Download all custom Lua server scripts | `server-scripts.zip` |
| `/get-world` | Download world state (all cell JSON files) | `world_state.tar.gz` |
| `/get-characters` | Download all character data | `characters.tar.gz` |

### To enable

1. **Uncomment the desired location blocks** in `/opt/tes3mp/nginx.conf`.
2. For `/get-world` and `/get-characters` you also need to **uncomment the `export` service** in `/opt/tes3mp/docker-compose.yml`.
3. Uncomment the **`nginx` service** in docker-compose.yml (required for all endpoints).
4. Start the container:
   ```bash
   cd /opt/tes3mp && docker compose up -d
   ```

### Notes

- Rate limit: each endpoint has its own configurable limit (default: **5 requests per minute** per IP).
- When enabled, endpoints are available at:
  - `http://<server-IP>:8085/get-plugins`
  - `http://<server-IP>:8085/get-server-scripts`
  - `http://<server-IP>:8085/get-world`
  - `http://<server-IP>:8085/get-characters`
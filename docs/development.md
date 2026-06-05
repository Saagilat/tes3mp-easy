# Development Guide

Full reference for developers and anyone who needs to understand the project internals.

## Architecture

```
Local Machine                         VPS (Docker)
─────────────                        ────────────
Admin Menu (bash) ───[SSH]──► ┌─────────────────────┐
  ├─ Install Server           │  tes3mp (:25565/udp) │
  ├─ Start/Stop/Restart       │  nginx (:8085)        │
  ├─ Export Mods/Players      │  export (backup cron) │
  ├─ Deploy backups           └─────────────────────┘
  └─ Edit configs
```

Three Docker services on the VPS:
- **tes3mp** — game server (UDP 25565)
- **nginx** — serves backup archives via HTTP (port 8085), endpoints: `/list-backups/{type}`, `/download/{type}/{filename}`
- **export** — periodically packages data into `.tar.gz` archives

## Repository Structure

```
├── client/                     # Client-side scripts (bash)
│   ├── install-admin.sh        # One-line installer (curl | bash)
│   ├── install-player.sh       # One-line installer (curl | bash)
│   ├── bin/
│   │   ├── admin/              # Admin CLI subcommands
│   │   ├── player/             # Player CLI subcommands
│   │   └── common/             # Shared subcommands (edit-config)
│   ├── lib/                    # Shared libraries (sourced, not executed)
│   │   ├── common              # Colors, logging, utility functions
│   │   ├── config              # INI config parser and editor
│   │   ├── menu-nav            # Interactive TUI menu engine
│   │   └── lang                # Internationalization loader
│   ├── menu/                   # Interactive menu wrappers
│   │   ├── admin.sh            # Admin menu (dispatches to bin/admin/)
│   │   └── player.sh           # Player menu (dispatches to bin/player/)
│   └── lang/                   # Translation files
│       ├── en                  # English
│       └── ru                  # Russian
├── server/                     # Server-side scripts (bash)
│   ├── scripts/                # VPS-hosted utilities
│   │   ├── install.sh          # Server installer (curl | sudo bash)
│   │   ├── package.sh          # Archive packer (sourced by export service)
│   │   ├── deploy_*.sh         # Deploy archives into active directories
│   │   ├── import_*.sh         # Import data into server directories
│   │   └── export_*.sh         # Export scripts for export service
│   ├── docker/                 # Docker Compose, Dockerfiles, nginx config
│   └── common                  # Server-side shared library
└── docs/
```

## Configuration System

Three INI-format config files at `~/`:

| File | Created By | Purpose |
|------|-----------|---------|
| `~/.tes3mp-easy.ini` | Both installers | Shared: `LANG_CODE`, `EDITOR`, `BACKUP_DIR` |
| `~/.tes3mp-easy-admin.ini` | `install-admin.sh` | Admin: `SSH_HOST`, `EXPORT_DIR` |
| `~/.tes3mp-easy-player.ini` | `install-player.sh` | Player: `DATA_FILES`, `TES3MP_DIR`, `PROTON_PATH` |

Loading order: shared config first → role config overrides shared values. The parser `parse_ini()` uses regex, not `source`, for safety.

## Admin Commands (Full Reference)

All accessible from the menu or directly: `bash ~/.local/share/tes3mp-easy/bin/admin/<command>`

### Server Control

| Command | Description |
|---------|-------------|
| `install-server` | Runs server installer on VPS via SSH, then interactive configurator for `config.lua` |
| `start-server` | Start Docker Compose stack |
| `stop-server` | Stop Docker Compose stack |
| `restart-server` | Restart all Docker services |
| `server-status` | Show running state |
| `server-logs` | Tail TES3MP logs |

### Export

| Command | Description |
|---------|-------------|
| `export-mods` | Create `mods.tar.gz` from local `EXPORT_DIR/mods/` and upload via SSH |
| `export-players` | Create `players.tar.gz` from local `EXPORT_DIR/players/` and upload |
| `export-world` | Create `world.tar.gz` from local `EXPORT_DIR/world/` and upload |
| `generate-required-data` | Generate `requiredDataFiles.json` |

### Deploy

| Command | Description |
|---------|-------------|
| `deploy-mods` | Extract a selected archive into `mods/` |
| `deploy-players` | Extract a selected archive into `players/` |
| `deploy-world` | Extract a selected archive into `world/` |

### Backup Management

| Command | Description |
|---------|-------------|
| `show-backups-mods` | List mod backup archives |
| `show-backups-players` | List player backup archives |
| `show-backups-world` | List world backup archives |

### Config Editing

| Command | Description |
|---------|-------------|
| `edit-server-cfg` | Edit `tes3mp-server-default.cfg` on VPS |
| `edit-lua` | Edit `customScripts.lua` on VPS |
| `edit-banlist` | Edit `banlist.json` on VPS |
| `edit-config` | Edit local admin config |

## Player Commands (Full Reference)

All accessible from the menu or directly: `bash ~/.local/share/tes3mp-easy/bin/player/<command>`

| Command | Description |
|---------|-------------|
| `install-client` | Download TES3MP, set up Proton prefix, generate config |
| `run-client` | Launch TES3MP via Proton |
| `run-openmw-cs` | Launch OpenMW Construction Set |
| `edit-client-cfg` | Edit `tes3mp-client-default.cfg` |
| `install-mods` | Download and unpack latest mods archive |
| `install-localization` | Install Russian localization |
| `install-fonts` | Install custom fonts |
| `configure-ui` | Set up OpenMW UI for multiplayer |
| `download-backup-mods` | Download mod backup archive |
| `download-backup-players` | Download player backup archive |
| `download-backup-world` | Download world backup archive |
| `show-backups-mods` | List mod backups |
| `show-backups-players` | List player backups |
| `show-backups-world` | List world backups |
| `edit-config` | Edit player config |

## Library Modules

### `client/lib/common`

- **Colors** — loaded from `theme.ini` (`T_LABEL`, `T_ACCENT`)
- **Logging** — `info()`, `ok()`, `warn()`, `err()`
- **Deps** — `check_deps cmd1 cmd2 ...`
- **OS detection** — `is_os("linux")`, `is_os("windows")`
- **Server URL** — `_get_server_url()` from TES3MP config

### `client/lib/config`

- `parse_ini <file> [prefix]` — safe INI parser
- `load_config [path]` — loads shared + role config
- `find_editor` — detects available editor
- `edit_config [file]` — opens config in editor

### `client/lib/menu-nav`

Interactive TUI engine. `run_menu(title, ssh_host, modpack, config_file, needs_restart, server_status, items...)`

Menu items format: `"Label|fn|function_name"` or `"Label|sep|"` for separators.

### `client/lib/lang`

- `load_lang(code)` — loads language file
- `lang_available()` — lists installed languages

## How Installation Works

### `install-admin.sh` / `install-player.sh`

Downloads individual files from GitHub via `curl`, places them in `~/.local/share/tes3mp-easy/`, creates default configs.

### `server/scripts/install.sh`

Runs on VPS via `install-server` command. Installs Docker, downloads Docker files, builds image, extracts configs, creates init backups.

## Server-Side Scripts

| Script | Purpose |
|--------|---------|
| `package.sh` | Creates `.tar.gz` archives (sourced by other scripts) |
| `deploy_mods.sh` | Extracts mods archive into `mods/plugins/` and `mods/scripts/` |
| `deploy_players.sh` | Extracts players archive into `players/player/` |
| `deploy_world.sh` | Extracts world archive into `world/{cell,world,...}/` |
| `import_*.sh` | Import data from external sources |
| `export_*.sh` | Export data to backup archives |

## How to Add a New Command

1. Create script in `client/bin/admin/<command>` or `client/bin/player/<command>`
2. Register in the menu: add wrapper function, dispatch entry, and menu item
3. Add translations in `client/lang/en` and `client/lang/ru`
4. Add download line in `install-admin.sh` or `install-player.sh`

See the existing scripts for examples.

## Docker Infrastructure

- `docker-compose.yml` — defines `tes3mp`, `nginx`, `export` services
- `tes3mp.dockerfile` — builds the game server image
- `export.dockerfile` — builds the backup export service
- `nginx.conf` — serves `/list-backups/` and `/download/` endpoints
- `entrypoint.sh` — container startup script
- `export_server.sh` — backup cron logic

## See Also

- [Modding Documentation](./admin/modding.md) — what's supported in TES3MP 0.8.1
- [Server Settings Reference](./admin/tes3mp_settings.md) — all `config.lua` settings
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

Single INI-format config file at `~/.config/tes3mp-easy/`:

| File | Purpose |
|------|---------|
| `tes3mp-easy.ini` | All settings: `LANG_CODE`, `EDITOR`, `BACKUP_DIR`, `SSH_HOST`, `EXPORT_DIR`, `MORROWIND_PATH`, `TES3MP_DIR`, `PROTON_PATH` |

The parser `parse_ini()` uses regex, not `source`, for safety.

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
| `setup-wizard` | Interactive guided setup (SSH, export dir, server install, config, mods, start) |

### Export

| Command | Description |
|---------|-------------|
| `export-mods` | Create `mods.tar.gz` from local `EXPORT_DIR/mods/` and upload via SSH |
| `export-players` | Create `players.tar.gz` from local `EXPORT_DIR/players/` and upload |
| `export-world` | Create `world.tar.gz` from local `EXPORT_DIR/world/` and upload |
| `generate-data` | Generate `requiredDataFiles.json` for mod verification |

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

### Backup Download (via HTTP)

| Command | Description |
|---------|-------------|
| `backup-mods` | Download a mod backup archive (interactive: lists and selects from HTTP endpoint) |
| `backup-players` | Download a player backup archive (interactive) |
| `backup-world` | Download a world backup archive (interactive) |

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
| `install-localization` | Install translated UI (e.g., Russian) |
| `install-fonts` | Install custom fonts |
| `configure-ui` | Set up OpenMW UI for multiplayer (resolution, font size, scaling) |
| `download-backup-mods` | Download a specific mod backup archive to `~/Downloads/` |
| `download-backup-players` | Download a specific player backup archive to `~/Downloads/` |
| `download-backup-world` | Download a specific world backup archive to `~/Downloads/` |
| `show-backups-mods` | List mod backups available on server |
| `show-backups-players` | List player backups available on server |
| `show-backups-world` | List world backups available on server |
| `edit-config` | Edit player config |

## Library Modules

### `client/lib/common`

- **Colors** — loaded from `theme.ini` (`T_LABEL`, `T_ACCENT`)
- **Logging** — `info()`, `ok()`, `warn()`, `err()`
- **Interactive input** — `confirm(prompt, default)` (yes/no prompt), `input(prompt, default, result_var)` (string input)
- **Deps** — `check_deps cmd1 cmd2 ...` (exits if any command is missing)
- **OS detection** — `is_os("linux")`, `is_os("windows")`, `is_os("macos")`
- **Server URL** — `_get_server_url()` builds `http://<server-addr>:8085` from TES3MP config

### `client/lib/config`

- `parse_ini <file> [prefix]` — safe INI parser (uses regex, not `source`)
- `load_config [path]` — loads shared config from `tes3mp-easy.ini`
- `find_editor` — detects available editor (checks `EDITOR` env var → config → nano → vim → vi)
- `edit_config [file]` — opens config in detected editor

### `client/lib/menu-nav`

Interactive TUI engine. `run_menu(title, ssh_host, modpack, config_file, needs_restart, server_status, items...)`

Menu items format: `"Label|fn|function_name"` or `"Label|sep|"` for separators.

Parameters:
- `title` — menu header text
- `ssh_host` — displayed host info (empty if not admin)
- `modpack` — displayed export dir / modpack info
- `config_file` — path to config (re-sourced after each action)
- `needs_restart` — "1" to show restart warning
- `server_status` — "Running" / "Stopped"
- `items...` — menu item definitions

### `client/lib/lang`

- `load_lang(code)` — loads language file
- `lang_available()` — lists installed languages

## How Installation Works

### `install-admin.sh` / `install-player.sh`

Downloads individual files from GitHub via `curl`, places them in `~/.local/share/tes3mp-easy/`, creates default configs.

Each command script must be added to the download list in the corresponding installer.

### `server/scripts/install.sh`

Runs on VPS via `install-server` command. Installs Docker, downloads Docker files, builds image, extracts configs, creates init backups.

## Server-Side Scripts

All located at `/tes3mp-easy/scripts/` on the VPS:

| Script | Purpose |
|--------|---------|
| `package.sh` | Creates `.tar.gz` archives (sourced by other scripts) |
| `deploy_mods.sh` | Extracts mods archive into `mods/plugins/` and `mods/scripts/` |
| `deploy_players.sh` | Extracts players archive into `players/player/` |
| `deploy_world.sh` | Extracts world archive into `world/{cell,world,...}/` |
| `import_mods.sh` | Import mod data from external sources |
| `import_players.sh` | Import player data from external sources |
| `import_world.sh` | Import world data from external sources |
| `export_players.sh` | Export player data to backup archives (for export Docker service) |
| `export_world.sh` | Export world data to backup archives (for export Docker service) |

## How to Add a New Command

1. Create script in `client/bin/admin/<command>` or `client/bin/player/<command>`
2. Register in the menu:
   - Add wrapper function in `client/menu/admin.sh` or `client/menu/player.sh`
   - Add dispatch entry in the `case` block
   - Add menu item to the items array
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
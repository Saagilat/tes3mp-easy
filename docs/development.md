# Development Guide

Full reference for developers and anyone who needs to understand the project internals.

> **All documentation must be written in English.** This includes code comments, commit messages, pull requests, and any other project documentation.

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

Player Menu (bash) ──[HTTP]─►
  ├─ Install Client (GitHub)
  ├─ Launch TES3MP
  ├─ Install Mods / Fonts
  ├─ Download backups
  └─ Configure UI / Localization
```

Three Docker services on the VPS:
- **tes3mp** — game server (UDP 25565)
- **nginx** — serves backup archives via HTTP (port 8085), endpoints: `/list-backups/{type}`, `/download/{type}/{filename}`
- **export** — periodically packages data into `.tar.gz` archives

## Layer Architecture

The CLI is divided into three strict layers. Each layer has a clear responsibility and calls the layer below it.

### Layer 1 — Non-Interactive (`client/layer1/`)

Scripts that perform a single operation: fetch data, run a command, edit a file. No interaction with the user.

**Rules:**
- **No TUI** — no prompts, no menus, no `read` from user.
- **No formatting** — no ANSI colors, no headers, no `[WARN]` / `[OK]` prefixes.
- **All SSH and HTTP calls live here** — no lower layer makes network requests.
- **Output** — data on stdout (JSON, filenames, status strings). Empty output is valid.
- **Exit code** — zero on success, non-zero on failure.
- **Dependencies** — minimal; prefer curl/ssh over python/jq for portability.
- **CLI usage** — every script is callable from the command line: `bash layer1/player/download-backup-mods "file.tar.gz"`

**Examples:** `show-backups-mods` (returns JSON), `deploy-mods "archive.tar.gz"` (deploys via SSH), `check-server-status` (outputs "Running"/"Stopped"), `install-client` (downloads and extracts TES3MP).

### Layer 2 — Interactive Wrappers (`client/layer2/`)

Scripts that add human-friendly interaction on top of Layer 1. They exist **only** when user input is needed: selecting from a list, answering prompts, running a multi-step wizard.

**Rules:**
- **No SSH/HTTP calls** — all network requests go through Layer 1.
- **No data fetching or parsing** — delegate to Layer 1, consume its output.
- **Adds UI** — headers, colors, numbering, error messages, confirmation prompts.
- **Each file is a standalone CLI utility** — callable directly: `bash layer2/player/interactive-download-mods`
- **If Layer 2 adds no interaction** — don't create it. Call Layer 1 directly from Layer 3.

**Examples:** `interactive-download-mods` (parses JSON from `show-backups-mods`, shows menu, calls `download-backup-mods`), `interactive-install-fonts` (shows font list, calls `install-fonts <option>`), `interactive-setup-wizard` (multi-step guided setup).

### Layer 3 — Menu / TUI (`client/layer3/`)

The interactive menu system. Pure structure, no business logic.

**Rules:**
- **No logic** — each menu item calls either Layer 1 (`bash layer1/player/xxx`) or Layer 2 (`bash layer2/player/interactive-xxx`).
- **dispatch()** — handles CLI arguments and routes them to the appropriate layer.
- **show_menu()** — builds the menu items array and calls `run_menu()`.
- **No data fetching** — all data comes from layers below.

**Example dispatch entry:**
```bash
case "${1:-}" in
    # Non-interactive → Layer 1
    run-client)     bash "$LAYER1_PLAYER/run-client" ;;
    show-backups)   bash "$LAYER1_PLAYER/show-backups-mods" ;;

    # Interactive → Layer 2
    install-fonts)  bash "$LAYER2_PLAYER/interactive-install-fonts" ;;
    download-mods)  bash "$LAYER2_PLAYER/interactive-download-mods" ;;
esac
```

### Decision Flow

When adding a new operation:

```
Need an operation
    ↓
Is there user interaction? (selection, prompt, wizard)
    ├── NO → write Layer 1 (client/layer1/player/xxx or admin/xxx)
    │         Call from Layer 3 directly: bash layer1/player/xxx
    └── YES → write Layer 1 + Layer 2
              Layer 1: client logic (SSH/HTTP/files)
              Layer 2: interactive (menu, prompt) → calls Layer 1
              Layer 3: menu item → bash layer2/player/interactive-xxx
```

### Data Flow

```
User → Layer 3 (menu) ──→ Layer 2 (interactive) ──→ Layer 1 (non-int.) ──→ HTTP / SSH → Server
                            (if interaction needed)     (all network)              ↓
User ← Layer 3 (menu) ←── Layer 2 (interactive) ←── Layer 1 (non-int.) ←── JSON / stdout
```

### Example: Backup Workflow

```
User selects "Download player backup"
  → Layer 3: menu → menu_download_players()
    → Layer 2: interactive-download-players
      → Layer 1: show-backups-players (returns JSON via HTTP/SSH)
      → Layer 2: parses JSON, shows numbered menu
      → User picks a file
      → Layer 1: download-backup-players "file.tar.gz" (download via HTTP/SSH)
      → Layer 2: prints success message
    → Layer 3: returns to menu
```

## Repository Structure

```
├── client/                     # Client-side scripts (bash)
│   ├── install.sh              # One-line installer (curl | bash)
│   ├── layer1/                 # Non-interactive commands
│   │   ├── admin/              #   Admin CLI
│   │   │   ├── start-server    #     SSH → docker compose up
│   │   │   ├── show-backups-*  #     JSON via SSH
│   │   │   ├── deploy-*        #     SSH → deploy script
│   │   │   ├── check-*         #     Status queries
│   │   │   └── ...
│   │   ├── shared/             #   Shared CLI (admin + player)
│   │   │   ├── edit-config-record
│   │   │   └── run-openmw-cs
│   │   └── player/             #   Player CLI
│   │       ├── run-client      #     Proton launch
│   │       ├── download-*      #     HTTP download
│   │       ├── install-*       #     Installers
│   │       └── ...
│   ├── layer2/                 # Interactive wrappers
│   │   ├── admin/              #   Admin (8 files)
│   │   │   ├── interactive-deploy-*      # Archive selection → Layer 1
│   │   │   ├── interactive-download-*    # Backup selection → Layer 1
│   │   │   ├── interactive-setup-wizard  # Multi-step setup
│   │   │   └── interactive-configure-server  # Config.lua editor
│   │   └── player/             #   Player (7 files)
│   │       ├── interactive-install-fonts # Font selection → Layer 1
│   │       ├── interactive-download-*    # Backup selection → Layer 1
│   │       └── interactive-setup-wizard  # Multi-step setup
│   ├── layer3/                 # Interactive menu (TUI)
│   │   ├── admin.sh            #   Admin menu
│   │   └── player.sh           #   Player menu
│   ├── lib/                    # Shared libraries (sourced, not executed)
│   │   ├── common              #   Colors, logging wrappers, utility functions
│   │   ├── log                 #   Logging subsystem (automatic log files)
│   │   ├── config              #   JSON config parser and editor
│   │   ├── menu-nav            #   Interactive TUI menu engine
│   │   ├── menu-strings        #   English menu string constants
│   │   ├── settings.cfg.example  #   Example TES3MP settings
│   │   └── localization/       # Translation installers
│   │       └── russian/        #   Russian localization installer
│   └── localization/           # (Legacy — use lib/localization/)
├── server/                     # Server-side scripts (bash)
│   ├── scripts/                # VPS-hosted utilities
│   │   ├── install.sh          #   Server installer (curl | sudo bash)
│   │   ├── package.sh          #   Archive packer (sourced by export service)
│   │   ├── deploy_*.sh         #   Deploy archives into active directories
│   │   ├── import_*.sh         #   Import data into server directories
│   │   ├── export_*.sh         #   Export scripts for export service
│   │   └── list-backups.sh     #   List backup archives for nginx endpoint
│   ├── docker/                 # Docker Compose, Dockerfiles, nginx config
│   └── common                  # Server-side shared library
└── docs/
```

## Configuration System

Single JSON config file at `~/.config/tes3mp-easy/`:

| File | Purpose |
|------|---------|
| `tes3mp-easy.json` | All settings: `EDITOR`, `BACKUP_DIR`, `SSH_HOST`, `EXPORT_DIR`, `MORROWIND_PATH`, `TES3MP_DIR`, `PROTON_PATH` |

The parser `parse_json()` uses `jq`, not `source`, for safety.

## Admin Commands (Full Reference)

All accessible from the menu or directly.

### Layer 1 (Non-Interactive)

Call via: `bash ~/.local/share/tes3mp-easy/layer1/admin/<command> [args]`

| Command | Description |
|---------|-------------|
| `install-server` | Run server installer on VPS via SSH |
| `start-server` | Start Docker Compose stack |
| `stop-server` | Stop Docker Compose stack |
| `restart-server` | Restart all Docker services |
| `server-status` | Show running state |
| `server-logs` | Tail TES3MP logs |
| `export-mods` | Create `mods.tar.gz` from local `EXPORT_DIR/mods/` and upload via SSH |
| `export-players` | Create `players.tar.gz` from local `EXPORT_DIR/players/` and upload |
| `export-world` | Create `world.tar.gz` from local `EXPORT_DIR/world/` and upload |
| `generate-data` | Generate `requiredDataFiles.json` for mod verification |
| `deploy-mods <archive>` | Extract a specific archive into `mods/` |
| `deploy-players <archive>` | Extract a specific archive into `players/` |
| `deploy-world <archive>` | Extract a specific archive into `world/` |
| `show-backups-mods` | List mod backup archives (JSON) |
| `show-backups-players` | List player backup archives (JSON) |
| `show-backups-world` | List world backup archives (JSON) |
| `download-backup-mods <file>` | Download a specific mod backup |
| `download-backup-players <file>` | Download a specific player backup |
| `download-backup-world <file>` | Download a specific world backup |
| `edit-server-cfg` | Edit `tes3mp-server-default.cfg` on VPS |
| `edit-lua` | Edit `customScripts.lua` on VPS |
| `edit-banlist` | Edit `banlist.json` on VPS |
| `edit-config` | Edit local admin config in detected editor |
| `check-restart-flag` | Output "1" if restart needed |
| `check-server-status` | Output "Running" / "Stopped" |
| `check-server-installed` | Exit 0 if server is installed |
| `read-config-lua` | Output config.lua settings (key=value lines) |
| `write-config-lua <sed_script>` | Apply sed script to config.lua |

### Shared Layer 1 (Admin + Player)

Call via: `bash ~/.local/share/tes3mp-easy/layer1/shared/<command> [args]`

| Command | Description |
|---------|-------------|
| `run-openmw-cs` | Launch OpenMW Construction Set (available in both admin and player menus) |

### Layer 2 (Interactive)

Call via: `bash ~/.local/share/tes3mp-easy/layer2/admin/<command>`

| Command | Description |
|---------|-------------|
| `interactive-deploy-mods` | List archives via `show-backups`, prompt, deploy |
| `interactive-deploy-players` | List archives via `show-backups`, prompt, deploy |
| `interactive-deploy-world` | List archives via `show-backups`, prompt, deploy |
| `interactive-download-mods` | List backups via `show-backups`, prompt, download |
| `interactive-download-players` | List backups via `show-backups`, prompt, download |
| `interactive-download-world` | List backups via `show-backups`, prompt, download |
| `interactive-setup-wizard` | Guided setup (SSH, export dir, install, configure, start) |
| `interactive-configure-server` | Interactive config.lua editor (38 settings) |

## Player Commands (Full Reference)

All accessible from the menu or directly.

### Layer 1 (Non-Interactive)

Call via: `bash ~/.local/share/tes3mp-easy/layer1/player/<command> [args]`

| Command | Description |
|---------|-------------|
| `install-client` | Download TES3MP, set up Proton prefix, generate config |
| `install-mods-and-play` | Install mods, then launch TES3MP via Proton |
| `run-client` | Launch TES3MP via Proton |
| `edit-client-cfg` | Edit `tes3mp-client-default.cfg` |
| `install-mods` | Download and unpack latest mods archive |
| `install-localization <locale>` | Install a specific localization (non-interactive) |
| `install-fonts <option>` | Install a specific font set (1-12) |
| `configure-ui <ttf_res> <font_size> <scale>` | Set OpenMW UI settings |
| `download-backup-mods <file>` | Download a specific mod backup |
| `download-backup-players <file>` | Download a specific player backup |
| `download-backup-world <file>` | Download a specific world backup |
| `show-backups-mods` | List mod backups (JSON) |
| `show-backups-players` | List player backups (JSON) |
| `show-backups-world` | List world backups (JSON) |
| `edit-config` | Edit player config in detected editor |

### Shared Layer 1 (Admin + Player)

Call via: `bash ~/.local/share/tes3mp-easy/layer1/shared/<command> [args]`

| Command | Description |
|---------|-------------|
| `run-openmw-cs` | Launch OpenMW Construction Set |

> **Note:** `install-fonts`, `install-localization`, and `configure-ui` have corresponding Layer 1 scripts, but the Layer 3 dispatch routes them through Layer 2 (interactive) wrappers for convenience. To call them non-interactively, invoke the Layer 1 script directly.

### Layer 2 (Interactive)

Call via: `bash ~/.local/share/tes3mp-easy/layer2/player/<command>`

| Command | Description |
|---------|-------------|
| `interactive-install-fonts` | Show font selection menu, install chosen set |
| `interactive-install-localization` | List available localizations, prompt, install |
| `interactive-configure-ui` | Read current settings, prompt for new values, apply |
| `interactive-setup-wizard` | Guided setup (Morrowind path, TES3MP dir, Proton, install, fonts, UI, localization) |
| `interactive-download-mods` | List backups via `show-backups`, prompt, download |
| `interactive-download-players` | List backups via `show-backups`, prompt, download |
| `interactive-download-world` | List backups via `show-backups`, prompt, download |

## Library Modules

### `client/lib/common`

- **Logging wrappers** — `info()`, `ok()`, `warn()`, `err()` — delegate to `client/lib/log` for file logging. Colors are hardcoded ANSI escape codes.
- **Interactive input** — `confirm(prompt, default)` (yes/no prompt), `input(prompt, default, var_name)` (string input, sets `var_name`)
- **Deps** — `check_deps cmd1 cmd2 ...` (exits if any command is missing)
- **OS detection** — `is_os("linux")`, `is_os("windows")`, `is_os("macos")`
- **Server URL** — `_get_server_url()` builds `http://<server-addr>:8085` from TES3MP config
- **SSH resolution** — `_resolve_ssh_host_ip <host>` resolves SSH host alias to IP from `~/.ssh/config`

### `client/lib/log`

- **Automatic logging** — when sourced, creates `~/.config/tes3mp-easy/logs/YYYY-MM-DD/HH-MM-SS_<script>.log`
- **`_log_write level msg`** — internal: append a line to the log file (called by `err`/`ok`/`warn`/`info`)
- **`log_file`** — prints absolute path to current log file
- **`run_logged CMD`** — runs a command, captures stdout+stderr to console and log file simultaneously

### `client/lib/config`

- `parse_json <file>` — safe JSON parser (uses `jq`, not `source`)
- `load_config` — loads shared config from `tes3mp-easy.json`
- `write_config <key> <value>` — atomically set a key=value in JSON config using `jq`
- `find_editor` — detects available editor (checks `EDITOR` env var → `VISUAL` → `EDITOR` → nano → vim → vi)
- `edit_config` — opens config in detected editor

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

The `run_menu` calls `check_restart_flag()` and `check_server_status()` functions after each action to refresh the display. These functions must be defined in the calling Layer 3 script and delegate to `layer1/admin/check-restart-flag` and `layer1/admin/check-server-status`.

### `client/lib/menu-strings`

Contains all English menu string constants used in Layer 3:
- `MENU_TITLE_ADMIN`, `MENU_TITLE_PLAYER`
- `MENU_ADMIN_*`, `MENU_PLAYER_*` — per-item labels for menu entries
- Separator constants for menu section headers (`MENU_ADMIN_SEP_*`, `MENU_PLAYER_SEP_*`)

### `client/lib/localization/`

Contains locale-specific installer scripts:
- `russian/install.sh` — installs Russian game localization files

## How Installation Works

### `install.sh`

Downloads individual files from GitHub via `curl`, places them in `~/.local/share/tes3mp-easy/`, creates default JSON config. Always performs a clean install (removes previous scripts) but preserves existing configuration.

Each command script must be added to the download list in the installer.

### `server/scripts/install.sh`

Runs on VPS via `install-server` command. Installs Docker, downloads Docker files to `/tes3mp-easy/`, builds image, creates directory structure, extracts configs, creates init backups.

## Server-Side Scripts

All located at `/tes3mp-easy/scripts/` on the VPS (downloaded to this path by `server/scripts/install.sh`):

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
| `list-backups.sh` | Lists available backups for nginx endpoint |

## How to Add a New Command

### 1. Determine Which Layers Are Needed

```
Need an operation
    ↓
Is there user interaction? (selection, prompt, wizard)
    ├── NO → Layer 1 only
    └── YES → Layer 1 + Layer 2
```

### 2. Create Layer 1 Script

Create a file in `client/layer1/<player|admin|shared>/<command>`:

```bash
#!/bin/bash
# Description of what this script does.
# Usage: <command> [args]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/lib/common"
source "$SCRIPT_DIR/lib/config"

# Do the work
# - Accept arguments via $1, $2, ...
# - Print data to stdout (JSON, filenames, or nothing)
# - Exit 0 on success, non-zero on failure
```

**Rules:**
- No prompts, no menus, no `read` from user.
- No colors, no headers, no `[OK]`/`[WARN]` prefixes.
- All SSH/HTTP calls go here.

### 3. (Optional) Create Layer 2 Script

Only if user interaction is needed. Create a file in `client/layer2/<player|admin>/interactive-<command>`:

```bash
#!/bin/bash
# Description with interaction.

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$PROJECT_DIR/lib/common"
source "$PROJECT_DIR/lib/config"

# Interact with user (menu, prompts, confirmations)
# Delegate work to Layer 1:
#   bash "$PROJECT_DIR/layer1/player/<command>" "$selected_option"
```

### 4. Add Menu Entry in Layer 3

Edit `client/layer3/player.sh` or `client/layer3/admin.sh`:

- Add a **dispatch case** if it should be callable from CLI:
  ```bash
  # Layer 1 (no interaction):
  my-command) bash "$LAYER1_PATH/my-command" "$@" ;;
  # Layer 2 (interactive):
  my-command) bash "$LAYER2_PATH/interactive-my-command" ;;
  ```

- Add a **function wrapper** for `run_menu`:
  ```bash
  menu_my_command() { bash "$LAYER1_PLAYER/my-command"; }
  ```

- Add the item to the menu array:
  ```bash
  "${MENU_LABEL}|fn|menu_my_command"
  ```

### 5. Add Translations

Add labels in `client/lib/menu-strings` and/or locale installers in `client/lib/localization/`.

### 6. Add Download Line in Installer

Add a `download` line in `client/install.sh`:

```bash
download "client/layer1/player/my-command" "$UPDATE_DIR/layer1/player/my-command"
```

If Layer 2 was created, add it too:

```bash
download "client/layer2/player/interactive-my-command" "$UPDATE_DIR/layer2/player/interactive-my-command"
```

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
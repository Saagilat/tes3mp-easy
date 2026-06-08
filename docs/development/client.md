# Client Architecture

The CLI is divided into three strict layers. Each layer has a clear responsibility and calls the layer below it.

## Layer 1 — Non-Interactive (`client/layer1/`)

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

## Layer 2 — Interactive Wrappers (`client/layer2/`)

Scripts that add human-friendly interaction on top of Layer 1. They exist **only** when user input is needed: selecting from a list, answering prompts, running a multi-step wizard.

**Rules:**
- **No SSH/HTTP calls** — all network requests go through Layer 1.
- **No data fetching or parsing** — delegate to Layer 1, consume its output.
- **Adds UI** — headers, colors, numbering, error messages, confirmation prompts.
- **Each file is a standalone CLI utility** — callable directly: `bash layer2/player/interactive-download-mods`
- **If Layer 2 adds no interaction** — don't create it. Call Layer 1 directly from Layer 3.

**Examples:** `interactive-download-mods` (parses JSON from `show-backups-mods`, shows menu, calls `download-backup-mods`), `interactive-install-fonts` (shows font list, calls `install-fonts <option>`), `interactive-setup-wizard` (multi-step guided setup).

## Layer 3 — Menu / TUI (`client/layer3/`)

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

## Decision Flow

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

## Transport Roles

| Role | Transport | Notes |
|------|-----------|-------|
| Admin | SSH + SCP | Commands run on VPS; configs edited via SCP |
| Player | HTTP (nginx :8085) | No SSH keys needed |
| Shared (`run-openmw-cs`, `edit-config-record`) | N/A | Local operations only |

Layer 2 wrappers delegate to Layer 1 without knowing which transport is used. Admin commands happen to use SSH; player commands happen to use HTTP.

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
| `export-mods` | Create `mods.tar.gz` from local `EXPORT_DIR/<server_id>/mods/` and upload via SCP |
| `generate-data` | Generate `requiredDataFiles.json` for mod verification |
| `deploy-mods <archive>` | Extract a specific archive into `mods/` (SSH) |
| `deploy-state <archive>` | Extract a specific state archive into `players/` and `world/` (SSH) |
| `show-backups-mods` | List mod backup archives (JSON) |
| `show-backups-state` | List state backup archives (JSON) |
| `download-backup-mods <file>` | Download a specific mod backup via SCP |
| `download-backup-state` | Create fresh state backup on server and download via SCP |
| `download-backup-state <file>` | Download a specific state backup via SCP |
| `edit-server-cfg` | Edit `tes3mp-server-default.cfg` on VPS (SCP + local editor) |
| `edit-lua` | Edit `customScripts.lua` on VPS (SCP + local editor) |
| `edit-banlist` | Edit `banlist.json` on VPS (SCP + local editor) |
| `edit-config` | Edit local admin config in detected editor |
| `check-restart-flag` | Output "1" if restart needed |
| `check-server-status` | Output "Running" / "Stopped" |
| `check-server-installed` | Exit 0 if server is installed |
| `read-config-lua` | Output config.lua settings (key=value lines) |
| `write-config-lua <sed_script>` | Apply sed script to config.lua. **Important:** escape `/`, `\`, and `&` in values passed to sed. |

### Layer 2 (Interactive)

Call via: `bash ~/.local/share/tes3mp-easy/layer2/admin/<command>`

| Command | Description |
|---------|-------------|
| `interactive-deploy-mods` | List archives via `show-backups`, prompt, deploy |
| `interactive-deploy-state` | List archives via `show-backups`, prompt, deploy |
| `interactive-download-mods` | List backups via `show-backups`, prompt, download |
| `interactive-download-state` | List backups via `show-backups`, prompt, download. Option 0 creates a fresh backup. |
| `interactive-setup-wizard` | Guided setup (SSH, export dir, install, configure, start) |
| `interactive-configure-server` | Interactive config.lua editor (38 settings) |

## Player Commands (Full Reference)

All accessible from the menu or directly.

### Layer 1 (Non-Interactive)

Call via: `bash ~/.local/share/tes3mp-easy/layer1/player/<command> [args]`

| Command | Description |
|---------|-------------|
| `install-client` | Download TES3MP, set up Proton prefix, generate config |
| `run-client` | Launch TES3MP via Proton |
| `edit-client-cfg` | Edit `tes3mp-client-default.cfg` |
| `edit-client-cfg-record <key> <value>` | Set a key=value in `tes3mp-client-default.cfg` (non-interactive) |
| `install-mods` | Download mods archive, extract to `TES3MP_DIR/servers/<address>/data/Data Files/`, generate per-server `openmw.cfg` |
| `install-localization <locale>` | Install a specific localization (non-interactive) |
| `install-fonts <option>` | Install a specific font set (1-12) |
| `configure-ui <ttf_res> <font_size> <scale>` | Set OpenMW UI settings |
| `download-backup-mods <file>` | Download a specific mod backup via HTTP |
| `download-backup-state <file>` | Download a specific state backup via HTTP |
| `show-backups-mods` | List mod backups (JSON via HTTP) |
| `show-backups-state` | List state backups (JSON via HTTP) |
| `edit-config` | Edit player config in detected editor |

> **Note:** `install-fonts`, `install-localization`, and `configure-ui` have corresponding Layer 1 scripts, but the Layer 3 dispatch routes them through Layer 2 (interactive) wrappers for convenience. To call them non-interactively, invoke the Layer 1 script directly.

### Layer 2 (Interactive)

Call via: `bash ~/.local/share/tes3mp-easy/layer2/player/<command>`

| Command | Description |
|---------|-------------|
| `interactive-install-fonts` | Show font selection menu, install chosen set |
| `interactive-install-localization` | List available localizations, prompt, install |
| `interactive-configure-ui` | Read current settings, prompt for new values, apply |
| `interactive-install-mods-and-play` | Show server address, prompt to change, install mods, launch client |
| `interactive-setup-wizard` | Guided setup (Morrowind path, TES3MP dir, Proton, install, fonts, UI, localization) |
| `interactive-download-mods` | List backups via `show-backups`, prompt, download |
| `interactive-download-state` | List backups via `show-backups`, prompt, download |

## Shared Commands (Admin + Player)

Call via: `bash ~/.local/share/tes3mp-easy/layer1/shared/<command> [args]`

| Command | Description |
|---------|-------------|
| `run-openmw-cs` | Launch OpenMW Construction Set (available in both admin and player menus) |
| `edit-config-record <key> <value>` | Non-interactive config key=value setter |

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

### Client Installer (`client/install.sh`)

Downloads individual files from GitHub via `curl`, places them in `~/.local/share/tes3mp-easy/`, creates default JSON config. Always performs a clean install (removes previous scripts) but preserves existing configuration.

Each command script must be added to the download list in the installer.

## Logging

Client-side logs are written to `~/.config/tes3mp-easy/logs/YYYY-MM-DD/HH-MM-SS_<script>.log` automatically when any library that sources `client/lib/log` is used. Use `log_file` to get the current log file path.

For server-side logs, use `server-logs` (admin command) which runs `docker compose logs --tail=N` on the VPS via SSH.
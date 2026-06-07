# Server Architecture

Server-side scripts run on the VPS at `/tes3mp-easy/scripts/`. They are called from the client via SSH.

## VPS File Layout

```
/tes3mp-easy/
├── docker-compose.yml
├── configs/
│   ├── config.lua
│   ├── tes3mp-server-default.cfg
│   ├── customScripts.lua
│   └── banlist.json
├── scripts/                    # Server-side utilities
│   ├── install.sh
│   ├── package.sh
│   ├── deploy_mods.sh
│   ├── deploy_players.sh
│   ├── deploy_world.sh
│   ├── import_mods.sh
│   ├── import_players.sh
│   ├── import_world.sh
│   ├── export_players.sh
│   ├── export_world.sh
│   └── list-backups.sh
├── mods/
│   ├── plugins/
│   └── scripts/
├── players/
├── world/
│   ├── cell/
│   ├── world/
│   ├── map/
│   ├── recordstore/
│   └── custom/
├── backups/
│   ├── mods/
│   │   └── current.txt
│   ├── players/
│   └── world/
├── import-mods/
├── import-players/
├── import-world/
└── needs_restart.flag
```

## Principles

1. **One operation per script** — each script does exactly one thing.
2. **Machine-readable output (or none)** — no colors, no `[OK]`/`[WARN]`, no formatting. Use exit codes.
3. **Exit code** — 0 on success, non-zero on failure.
4. **Minimum logic** — don't do what the OS does for you (e.g. checking disk space — `tar` will fail on its own).
5. **Leave the system consistent** — use `tmp` folder + atomic move for destructive operations (extract → tmp → mv). Use `set -euo pipefail`.
6. **No automatic rollback** — if the operation fails, the admin recovers manually using the available commands. Auto-rollback introduces its own failure modes and complexity.
7. **Every deployed mod already has a backup** — `backups/mods/current.txt` + the archive itself.

## Scripts Reference

### Installation

| Script | Action |
|--------|--------|
| `install.sh` | Install Docker, download files, build image, extract configs, create init backups. Runs on VPS via the `install-server` admin command. |

### Deploy (extract archives into active directories)

| Script | Action |
|--------|--------|
| `deploy_mods.sh <archive>` | Backup world → backup players → extract mods → generate scripts → write current → touch restart flag |
| `deploy_players.sh <archive>` | Backup players → extract → write current → touch restart flag |
| `deploy_world.sh <archive>` | Backup world → extract → write current → touch restart flag |

### Import (move archives from staging into backups)

| Script | Action |
|--------|--------|
| `import_mods.sh` | Move archive from `import-mods/` → `backups/mods/import-<ts>-mods.tar.gz` |
| `import_players.sh` | Move archive from `import-players/` → `backups/players/import-<ts>-players.tar.gz` |
| `import_world.sh` | Move archive from `import-world/` → `backups/world/import-<ts>-world.tar.gz` |

### Export (for export Docker service)

| Script | Action |
|--------|--------|
| `export_players.sh` | Create backup archive of current player data |
| `export_world.sh` | Create backup archive of current world data |

### Library

| Script | Action |
|--------|--------|
| `package.sh` | Shared packaging library (sourced, not executed). Provides `package_world()` and `package_players()` functions. |

### List

| Script | Action |
|--------|--------|
| `list-backups.sh <type>` | Output JSON list of backups for nginx endpoint |

## Example: `deploy_mods` Sequence

```
deploy_mods.sh <archive>:
  1. Resolve archive path (current.txt, --latest, or explicit filename)
  2. Check free space for backup (world + players, 2x margin)
  3. Backup current world → backups/world/backup-<ts>-world.tar.gz
  4. Backup current players → backups/players/backup-<ts>-players.tar.gz
  5. Check free space for extraction
  6. Stop TES3MP
  7. Extract archive → tmp → mv to mods/plugins/ and mods/scripts/
  8. Generate customScripts.lua
  9. Write current.txt (sha256 filename)
  10. Start TES3MP
  11. Touch needs_restart.flag
```

If any step fails, `set -euo pipefail` stops the sequence. The admin recovers manually:

- Current mods are gone (step 7 ran before failure) — but old mods have a backup in `backups/mods/`
- Fresh world and player backups exist (steps 3-4 succeeded)
- Admin calls `deploy-mods <old-archive-from-current.txt>` and redeploys world/players from the fresh backups

## Logging

Server-side logs are accessed via the admin command `server-logs`, which runs `docker compose logs --tail=N`. Logs are not persisted to disk individually — they live in Docker's logging driver.
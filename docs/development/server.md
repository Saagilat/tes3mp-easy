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
│   ├── deploy_state.sh
│   ├── import_mods.sh
│   ├── list-backups.sh
│   └── set-staff-rank.sh
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
│   └── state/
├── import-mods/
└── needs_restart.flag
```

## Principles

1. **One operation per script** — each script does exactly one thing.
2. **Machine-readable output (or none)** — no colors, no `[OK]`/`[WARN]`, no formatting. Use exit codes.
3. **Exit code** — 0 on success, non-zero on failure.
4. **Minimum logic** — don't do what the OS does for you (e.g. checking disk space — `tar` will fail on its own).
5. **Leave the system consistent** — use `set -euo pipefail`. Clean directories before extraction. No fallback branches — fail fast on unexpected input.
6. **No automatic rollback** — if the operation fails, the admin recovers manually using the available commands. Auto-rollback introduces its own failure modes and complexity.
7. **Every deployed mod already has a backup** — `backups/mods/current.txt` + the archive itself.
8. **Archive format** — all archives are created by `package.sh` `_package_stage()` with `-- *` (no `./` prefix). Deploy scripts extract specific subdirectories directly (e.g. `plugins/ scripts/`), no `--wildcards`, no fallback.
9. **Fail fast** — no `||` fallback branches in deploy scripts. If extraction fails, `set -e` stops immediately with a clear error. The admin recovers manually from backups.

## Scripts Reference

### Installation

| Script | Action |
|--------|--------|
| `install.sh` | Install Docker, download files, build image, extract configs, create init backups. Runs on VPS via the `install-server` admin command. |

### Deploy (extract archives into active directories)

| Script | Action |
|--------|--------|
| `deploy_mods.sh <archive>` | Backup state → extract mods → generate scripts → write current → restart |
| `deploy_state.sh <archive>` | Stop TES3MP → extract players/ + world subdirs → start TES3MP |

### Import (move archives from staging into backups)

| Script | Action |
|--------|--------|
| `import_mods.sh` | Move archive from `import-mods/` → `backups/mods/import-<ts>-mods.tar.gz` |

### Export (for export Docker service)

| Script | Action |
|--------|--------|
| (handled by `export_server.sh` background loop) | Creates `backups/state/export-<ts>-state.tar.gz` every 5 minutes |

### Library

| Script | Action |
|--------|--------|
| `package.sh` | Shared packaging library (sourced, not executed). Provides `package_mods()`, `package_players()`, `package_world()`, `package_state()` functions. |

### List

| Script | Action |
|--------|--------|
| `list-backups.sh <type>` | Output JSON list of backups. Supported types: `mods`, `state` |

## Example: `deploy_mods` Sequence

```
deploy_mods.sh <archive>:
  1. Resolve archive path (current.txt, --latest, or explicit filename)
  2. Check free space for backup (state, 2x margin)
  3. Backup current state → backups/state/backup-<ts>-state.tar.gz
  4. Check free space for extraction
  5. Stop TES3MP
  6. Extract archive → plugins/ and scripts/ directly into mods/
  7. Generate customScripts.lua
  8. Write current.txt (sha256 filename)
  9. Start TES3MP
  10. Touch needs_restart.flag
```

If any step fails, `set -euo pipefail` stops the sequence. The admin recovers manually:

- Current mods are gone (step 6 ran before failure) — but old mods have a backup in `backups/mods/`
- Fresh state backup exists (step 3 succeeded)
- Admin calls `deploy-mods <old-archive-from-current.txt>` and redeploys mods; state can be restored from the backup

## Export Server

The `export` container runs `export_server.sh` — a lightweight HTTP server using `socat`. It:

- **Serves backup files** via HTTP on port 5000 (exposed via nginx on port 8085)
- **Creates state backups** every `BACKUP_INTERVAL` seconds in `backups/state/export-<ts>-state.tar.gz`
- **Only creates backups while TES3MP is running** — checks via Docker socket (`_tes3mp_running()`)
- **Cleans up backups older than 30 days**
- **Supports `?latest` query parameter** to force an immediate export
- **Uses Docker socket** (`/var/run/docker.sock`) to check TES3MP container status

### Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `BACKUP_INTERVAL` | 300 | Seconds between automatic backups |
| `PORT` | 5000 | Internal HTTP port |
| `BACKUPS_DIR` | `/mnt/backups` | Backup storage directory |
| `CACHE_DIR` | `/tmp/export_cache` | Temporary cache directory |

Set via `docker-compose.yml`:
```yaml
services:
  export:
    environment:
      - BACKUP_INTERVAL=300   # 5 minutes
```

### Health watch (entrypoint.sh)

Inside the `tes3mp` container, a background watcher monitors the export service:

1. On startup, waits up to 40 seconds for export to become reachable
2. Every 30 seconds, pings `http://export:5000/list-backups/state`
3. If export is unreachable, writes to stderr and kills TES3MP with SIGTERM

This prevents running the server without backup infrastructure.

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /list-backups/mods` | JSON list of mod backups |
| `GET /list-backups/state` | JSON list of state backups |
| `GET /download/mods` | Latest mod backup |
| `GET /download/state` | Latest state backup |
| `GET /download/state?latest` | Force new state backup and download it |
| `GET /download/<type>/<file>` | Specific backup file |

## Logging

Server-side logs are accessed via the admin command `server-logs`, which runs `docker compose logs --tail=N`. Logs are not persisted to disk individually — they live in Docker's logging driver.
# Server Architecture

Server-side scripts are organized into two folders: **public** and **private**.

## Public (`server/public/`)

Utilities called from the client via SSH. Each script does **one operation**.

```
Client ──SSH──→ server/public/<command> [args]
```

**Rules:**
1. **One operation per script** — deploy, backup, start, stop, check status, etc.
2. **Machine-readable output** (or none) — no colors, no `[OK]`/`[WARN]`, no formatting.
3. **Exit code** — 0 on success, 1+ on failure.
4. **May call multiple private scripts** — when the operation is compound (e.g. `deploy-mods` = backup + extract + generate).
5. **No internal complexity** — just sequences of private calls and `docker compose`.

## Private (`server/private/`)

Internal implementation. Each script does **exactly one thing**.

**Rules:**
1. **One action per script** — `backup-world.sh` does only tar, `extract-mods.sh` does only extract, etc.
2. **Typical size: 5-30 lines.** If longer, it probably does too much.
3. **Minimum logic.** Don't do what the OS does for you (e.g. checking disk space — `tar` will fail on its own).
4. **Leave the system consistent.** Use `tmp` folder + atomic move for destructive operations (extract → tmp → mv). Use `set -euo pipefail`.
5. **No colors ever.**
6. **No automatic rollback.** If the operation fails, the admin recovers manually using the available commands. Auto-rollback introduces its own failure modes and complexity.
7. **Every deployed mod already has a backup** — `backups/mods/current.txt` + the archive itself.

## Private Scripts Reference

### Backup

| Script | Action |
|--------|--------|
| `backup-world.sh` | Create `backups/world/backup-<ts>-world.tar.gz` |
| `backup-players.sh` | Create `backups/players/backup-<ts>-players.tar.gz` |

### Extract (destructive — use tmp + mv)

| Script | Action |
|--------|--------|
| `extract-mods.sh <archive>` | Extract archive into `mods/plugins/` and `mods/scripts/` |
| `extract-players.sh <archive>` | Extract archive into `players/` |
| `extract-world.sh <archive>` | Extract archive into `world/` |

### Generate / Write

| Script | Action |
|--------|--------|
| `generate-scripts.sh` | Generate `customScripts.lua` from `mods/scripts/` |
| `write-current.sh <archive>` | Write sha256 + filename to `backups/mods/current.txt` |

### Import

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

| File | Action |
|------|--------|
| `package.sh` | Shared packaging library (sourced, not executed) |

### List

| Script | Action |
|--------|--------|
| `list-backups.sh <type>` | Output JSON list of backups |

### Install

| Script | Action |
|--------|--------|
| `install.sh` | Install Docker, download files, build image, extract configs, create init backups |

## Public Utilities Reference

All called via `ssh "$SSH_HOST" "bash /tes3mp-easy/public/<command>" [args]`.

### Docker Management

| Utility | Action |
|---------|--------|
| `install` | Run `private/install.sh` (full server setup) |
| `start` | `docker compose up -d` + remove `needs_restart.flag` |
| `stop` | `docker compose down` |
| `restart` | `docker compose up -d --force-recreate` + remove `needs_restart.flag` |
| `status` | Output "Running" or "Stopped" |
| `logs [N]` | `docker compose logs --tail=N` |

### Checks

| Utility | Action |
|---------|--------|
| `check-installed` | Exit 0 if `/tes3mp-easy/docker-compose.yml` exists |
| `check-restart-flag` | Exit 0 if `/tes3mp-easy/needs_restart.flag` exists |

### Configuration

| Utility | Action |
|---------|--------|
| `read-config-lua` | Output `config.*` lines from `configs/config.lua` |
| `apply-config-lua` | Read sed script from stdin, apply to `configs/config.lua` |

### Deploy

| Utility | Action |
|---------|--------|
| `deploy-mods <archive>` | Backup world → backup players → extract mods → generate scripts → write current → touch restart flag |
| `deploy-players <archive>` | Backup players → extract players → write current → touch restart flag |
| `deploy-world <archive>` | Backup world → extract world → write current → touch restart flag |

### Import

| Utility | Action |
|---------|--------|
| `import-mods` | `private/import_mods.sh` |
| `import-players` | `private/import_players.sh` |
| `import-world` | `private/import_world.sh` |

### Backups

| Utility | Action |
|---------|--------|
| `list-backups <type>` | `private/list-backups.sh <type>` (JSON) |

### Data

| Utility | Action |
|---------|--------|
| `generate-data` | Generate `requiredDataFiles.json` |

## Example: `deploy-mods` Sequence

```
public/deploy-mods <archive>:
  1. bash private/backup-world.sh
  2. bash private/backup-players.sh
  3. bash private/extract-mods.sh <archive>
  4. bash private/generate-scripts.sh
  5. bash private/write-current.sh <archive>
  6. touch /tes3mp-easy/needs_restart.flag
```

If any step fails, `set -euo pipefail` stops the sequence. The admin recovers manually:

- Current mods are gone (step 3 ran before failure) — but old mods have a backup in `backups/mods/`
- Fresh world and player backups exist (steps 1-2 succeeded)
- Admin calls `deploy-mods <old-archive-from-current.txt>` and redeploys world/players from the fresh backups

## See Also

- [Client Architecture](client.md) — how client-side layers use these utilities
- [Communication](communication.md) — SSH/SCP/HTTP patterns
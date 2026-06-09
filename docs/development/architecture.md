# Architecture

## Overview

```
Local Machine                         VPS (Docker)
─────────────                        ────────────
Admin Menu (bash) ───[SSH]──► ┌─────────────────────┐
  ├─ Install Server           │  tes3mp (:25565/udp) │
  ├─ Start/Stop/Restart       │  nginx (:8085)        │
  ├─ Export Mods              │  export (auto state)  │
  ├─ Deploy mods/state        └─────────────────────┘
  └─ Edit configs

Player Menu (bash) ──[HTTP]─►
  ├─ Install Client (GitHub)
  ├─ Launch TES3MP
  ├─ Install Mods / Fonts
  ├─ Download mods/state backups
  └─ Configure UI / Localization
```

Three Docker services on the VPS:
- **tes3mp** — game server (UDP 25565)
- **nginx** — proxies backup requests to export container (port 8085), endpoints: `/list-backups/{type}`, `/download/{type}/{filename}`
- **export** — automatically creates combined state (players + world) backups every 5 minutes, cleans up backups older than 30 days

## Data Flow

```
User → Layer 3 (menu) ──→ Layer 2 (interactive) ──→ Layer 1 (non-int.) ──→ SSH / HTTP → Server
                            (if interaction needed)     (all network)              ↓
User ← Layer 3 (menu) ←── Layer 2 (interactive) ←── Layer 1 (non-int.) ←── JSON / stdout
```

### Admin → Server: SSH

Admin operations use SSH to call scripts on the VPS. Export + import is a two-step process: `scp` the archive, then call the script.

```bash
# Start the server
ssh "$SSH_HOST" "bash /tes3mp-easy/scripts/deploy_mods.sh archive.tar.gz"

# Export mods: pack locally + upload + import on server
cd "$EXPORT_DIR/mods" && tar czf /tmp/mods.tar.gz plugins/ scripts/
scp /tmp/mods.tar.gz "$SSH_HOST":/tes3mp-easy/import-mods/mods.tar.gz
ssh "$SSH_HOST" "bash /tes3mp-easy/scripts/import_mods.sh"
```

Config files are edited via SCP: download → edit locally → upload back. No remote editor execution.

```bash
scp "$SSH_HOST:$remote_path" "$tmpfile"
$EDITOR "$tmpfile"
scp "$tmpfile" "$SSH_HOST:$remote_path"
```

### Player → Server: HTTP

Player operations use HTTP to the nginx server (port 8085). No SSH required.
Access is deliberately unauthenticated — players can download mod and state
backups at any time to run their own server. This is by design: data portability is
a core principle of the project.

```bash
# List backups
curl -sf "$SERVER_URL/list-backups/mods"

# Download backup
curl -sfL "$SERVER_URL/download/mods/$filename" -o "$dest"
```

The server URL is built from `tes3mp-client-default.cfg`:
```bash
server_addr=$(grep -o '^destinationAddress *=.*' "$cfg" | cut -d= -f2 | tr -d ' ')
echo "http://${server_addr}:8085"
```

### Decision: SSH vs HTTP

| Operation | Transport | Reason |
|-----------|-----------|--------|
| Admin commands (start, stop, deploy, import, etc.) | SSH | Requires server-side execution |
| Admin config editing | SCP + local editor | Interactive, local editor UX |
| Admin download backups | SCP | Simple, secure |
| Player list backups | HTTP (nginx) | No SSH keys needed |
| Player download backups | HTTP (nginx) | Public access via URL |

## Example: Backup Workflow

```
User selects "Download state backup"
  → Layer 3: menu → menu_download_state()
    → Layer 2: interactive-download-state
      → Layer 1: show-backups-state (returns JSON via HTTP for player)
      → Layer 2: parses JSON, shows numbered menu
      → User picks a file
      → Layer 1: download-backup-state "file.tar.gz" (download via HTTP)
      → Layer 2: prints success message
    → Layer 3: returns to menu
```

Admins use SSH/SCP; players use HTTP. Layer 2 delegates without caring about the transport.

## Repository Structure

```
├── client/                     # Client-side scripts (bash)
│   ├── install.sh              # One-line installer (curl | bash)
│   ├── layer1/                 # Non-interactive commands
│   │   ├── admin/              #   Admin CLI
│   │   │   ├── start-server    #     SSH → docker compose up
│   │   │   ├── show-backups-*  #     JSON via SSH
│   │   │   ├── deploy-*        #     SSH → deploy script
│   │   │   ├── export-*        #     scp → import script (two-step)
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
│   │   ├── admin/              #   Admin
│   │   │   ├── interactive-deploy-*      # Archive selection → Layer 1
│   │   │   ├── interactive-download-*    # Backup selection → Layer 1
│   │   │   ├── interactive-setup-wizard  # Multi-step setup
│   │   │   └── interactive-configure-server  # Config.lua editor
│   │   └── player/             #   Player
│   │       ├── interactive-install-fonts # Font selection → Layer 1
│   │       ├── interactive-install-mods-and-play # Server prompt → Layer 1
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
│   │   ├── deploy_mods.sh      #   Deploy mods archive
│   │   ├── deploy_state.sh     #   Deploy state archive (players + world)
│   │   ├── import_mods.sh      #   Import mods archive
│   │   ├── list-backups.sh     #   List backup archives
│   │   └── set-staff-rank.sh   #   Set staff rank
│   ├── docker/                 # Docker Compose, Dockerfiles, nginx config
│   └── common                  # Server-side shared library
└── docs/
```

## Docker Infrastructure

- `docker-compose.yml` — defines `tes3mp`, `nginx`, `export` services
- `tes3mp.dockerfile` — builds the game server image
- `export.dockerfile` — builds the backup export service (includes `docker` CLI for status checks)
- `nginx.conf` — proxies `/list-backups/` and `/download/` to export container
- `entrypoint.sh` — container startup script, creates plugin symlinks and launches TES3MP
- `export_server.sh` — backup HTTP server with:
  - Background export loop (every 5 min, only when TES3MP runs)
  - Cleanup of backups older than 30 days
  - `?latest` query parameter for on-demand export
  - Docker socket (`/var/run/docker.sock`) mounted for container status checks

## Configuration System

Single JSON config file at `~/.config/tes3mp-easy/`:

| File | Purpose |
|------|---------|
| `tes3mp-easy.json` | All settings: `EDITOR`, `BACKUP_DIR`, `SSH_HOST`, `EXPORT_DIR`, `MORROWIND_PATH`, `TES3MP_DIR`, `PROTON_PATH` |

The parser uses `jq`, not `source`, for safety.
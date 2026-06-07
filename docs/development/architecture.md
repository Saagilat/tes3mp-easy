# Architecture

## Overview

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

## Repository Structure

```
├── client/                     # Client-side scripts (bash)
│   ├── install.sh              # One-line installer (curl | bash)
│   ├── layer1/                 # Non-interactive commands
│   │   ├── admin/              #   Admin CLI
│   │   ├── player/             #   Player CLI
│   │   └── shared/             #   Shared CLI (admin + player)
│   ├── layer2/                 # Interactive wrappers
│   │   ├── admin/              #   Admin interactive
│   │   └── player/             #   Player interactive
│   ├── layer3/                 # Interactive menu (TUI)
│   │   ├── admin.sh            #   Admin menu
│   │   └── player.sh           #   Player menu
│   └── lib/                    # Shared libraries (sourced, not executed)
│       ├── common              #   Colors, logging wrappers, utility functions
│       ├── log                 #   Logging subsystem (automatic log files)
│       ├── config              #   JSON config parser and editor
│       ├── menu-nav            #   Interactive TUI menu engine
│       ├── menu-strings        #   English menu string constants
│       └── localization/       #   Translation installers
├── server/                     # Server-side scripts (bash)
│   ├── public/                 # Public utilities (called via SSH from client)
│   ├── private/                # Private implementation (internal, 5-30 lines each)
│   ├── common                  # Server-side shared library
│   └── docker/                 # Docker Compose, Dockerfiles, nginx config
└── docs/
    ├── development/            # Development documentation
    ├── admin/                  # Admin-specific docs
    ├── admin-guide.md
    └── player-guide.md
```

## Data Flow

```
User → Layer 3 (menu) ──→ Layer 2 (interactive) ──→ Layer 1 (non-int.) ──→ SSH / HTTP → Server
                            (if interaction needed)     (all network)              ↓
User ← Layer 3 (menu) ←── Layer 2 (interactive) ←── Layer 1 (non-int.) ←── JSON / stdout
```

## Server Data Flow (Public/Private)

```
Client ──SSH──→ server/public/<command>
                ├── private/extract-mods.sh
                ├── private/generate-scripts.sh
                └── docker compose ...
```

## Example: Backup Workflow

```
User selects "Download player backup"
  → Layer 3: menu → menu_download_players()
    → Layer 2: interactive-download-players
      → Layer 1: show-backups-players (returns JSON via HTTP)
      → Layer 2: parses JSON, shows numbered menu
      → User picks a file
      → Layer 1: download-backup-players "file.tar.gz" (download via HTTP)
      → Layer 2: prints success message
    → Layer 3: returns to menu
```

## Docker Infrastructure

- `docker-compose.yml` — defines `tes3mp`, `nginx`, `export` services
- `tes3mp.dockerfile` — builds the game server image
- `export.dockerfile` — builds the backup export service
- `nginx.conf` — serves `/list-backups/` and `/download/` endpoints
- `entrypoint.sh` — container startup script
- `export_server.sh` — backup cron logic
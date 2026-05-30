# Server management reference

## Common commands

All commands are run on the server via SSH. Replace `my-server` with your SSH host.

| Action | Command |
|--------|---------|
| Start | `ssh my-server "cd /tes3mp-easy && docker compose up -d"` |
| Stop | `ssh my-server "cd /tes3mp-easy && docker compose down"` |
| Restart | `ssh my-server "cd /tes3mp-easy && docker compose restart"` |
| View logs | `ssh my-server "cd /tes3mp-easy && docker compose logs -f"` |
| Edit config | `ssh my-server "nano /tes3mp-easy/container-data/tes3mp-server-default.cfg"` |
| Edit Lua config | `ssh my-server "nano /tes3mp-easy/container-data/server/scripts/config.lua"` |
| Edit ban list | `ssh my-server "nano /tes3mp-easy/container-data/server/data/banlist.json"` |
| Export mods | `tes3mp-easy-export-mods` |
| Export players only | `tes3mp-easy-export-players` |
| Export cells only | `tes3mp-easy-export-cells` |
| Import mods (client) | `tes3mp-easy-import-mods` |
| Generate required data files | `tes3mp-easy-generate-required-data` |
| Import mods (server-side) | `ssh my-server "bash /tes3mp-easy/scripts/import_mods.sh"` |
| Import players only (hot-add, no restart) | `ssh my-server "bash /tes3mp-easy/scripts/import_players.sh"` |
| Import cells only (restarts TES3MP) | `ssh my-server "bash /tes3mp-easy/scripts/import_cells.sh"` |

## HTTP endpoints

The server can provide an optional HTTP endpoint on port **8085**.
It is disabled by default.

| Endpoint | Description | Backend |
|----------|-------------|---------|
| `/get-mods` | Download all server mods + scripts (`mods.tar.gz`) | nginx (static file) |

To enable:

1. **Uncomment the location block** in `/tes3mp-easy/nginx.conf`
2. **Uncomment the `nginx` service** in `/tes3mp-easy/docker-compose.yml`
3. Restart the container:

   ```bash
   ssh my-server "cd /tes3mp-easy && docker compose restart"
   ```

When enabled, the endpoint is available at:
- `http://<server-ip>:8085/get-mods`

## Player role management

The first account that registers on the server automatically receives the **ServerOwner** rank (`staffRank: 3`).

To change a player's role:

1. **Stop the server:**

   ```bash
   ssh my-server "cd /tes3mp-easy && docker compose down"
   ```

2. **Open the player file** and change `staffRank`:

   ```bash
   ssh my-server "nano /tes3mp-easy/container-data/server/data/player/<accountName>.json"
   ```

   Find the `settings` section and set the desired rank:

   ```json
   "settings": {
       "staffRank": 3,
       ...
   }
   ```

   | Value | Rank |
   |-------|------|
   | `0` | Regular player |
   | `1` | Moderator |
   | `2` | Admin |
   | `3` | Server owner |

3. **Start the server:**

   ```bash
   ssh my-server "cd /tes3mp-easy && docker compose up -d"
   ```

## Further reading

- [Modding — what works and what doesn't in TES3MP 0.8.1](modding.md)
- [config.lua reference — full settings documentation](tes3mp_settings.md)
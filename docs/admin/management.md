# Server management reference

## Admin menu

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/install-admin.sh | bash
```

Recommended alias:

```bash
alias tes3mp-easy-admin='bash ~/.local/share/tes3mp-easy/menu/admin.sh'
```

## Common commands (via alias)

| Action | Command |
|--------|---------|
| Start | `tes3mp-easy-admin start` |
| Stop | `tes3mp-easy-admin stop` |
| Restart | `tes3mp-easy-admin restart` |
| View logs | `tes3mp-easy-admin logs` |
| Edit config | `tes3mp-easy-admin config` |
| Reconfigure | `tes3mp-easy-admin configure-server` |
| Install server | `tes3mp-easy-admin install-server` |
| Export mods | `tes3mp-easy-admin export-mods` |
| Export players | `tes3mp-easy-admin export-players` |
| Export world | `tes3mp-easy-admin export-world` |
| Update scripts | `tes3mp-easy-admin self-update` |
| Player menu | `tes3mp-easy-admin player-menu` |

## HTTP endpoints

The server can provide an optional HTTP endpoint on port **8085**.
It is disabled by default.

| Endpoint | Description | Backend |
|----------|-------------|---------|
| `/get-mods` | Download all server mods + scripts (`mods.tar.gz`) | nginx (static file) |
| `/get-players` | Download current player data (cached 5 min) | export service |
| `/get-world` | Download current world data (cached 5 min) | export service |

To enable:

1. **Run configure-server** and answer "yes" to the endpoints question, or
2. **Edit the nginx config** directly on the server:
   ```bash
   ssh my-server "nano /tes3mp-easy/nginx.conf"
   ```

When enabled, endpoints are available at:
- `http://<server-ip>:8085/get-mods`
- `http://<server-ip>:8085/get-players`
- `http://<server-ip>:8085/get-world`

## Player role management

The first account that registers on the server automatically receives the **ServerOwner** rank (`staffRank: 3`).

To change a player's role via the admin menu — select "Player role management". Or manually via SSH:

1. **Stop the server:**
   ```bash
   ssh my-server "cd /tes3mp-easy && docker compose down"
   ```

2. **Edit the player file:**
   ```bash
   ssh my-server "nano /tes3mp-easy/players/<accountName>.json"
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

- [Admin install guide](install.md)
- [Modding — what works and what doesn't in TES3MP 0.8.1](modding.md)
- [config.lua reference — full settings documentation](tes3mp_settings.md)
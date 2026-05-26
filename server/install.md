# Installing TES3MP Server on Linux (via Docker)

## Quick install (recommended)

The script will install Docker, download the server, ask for configuration, and start the container.

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server/files/scripts/install.sh | bash
```

Or download and run:

```bash
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server/files/scripts/install.sh
sudo bash install.sh
```

The script will ask:

### Server settings
- **Server name** (default: `tes3mp`)
- **Server password** (can be left empty)
- **Max players** (default: `4`)
- **TES3MP port (UDP)** (default: `25565`)
### HTTP endpoints
HTTP port 8085 is only opened if at least one endpoint is enabled.
- **Enable `/get-mods`** — mod pack for players (default: no)
- **Enable `/get-world`** — world state (cells), suitable for co-op/RP (default: no)
- **Enable `/get-characters`** — player data (inventory, skills, spells, quests) — sensitive (default: no)

For each enabled endpoint you can set a **rate limit** in requests per minute (default: `5`, enter `0` to disable).

### Lua config (config.lua)
- **Game mode** (default: `Default`)
- **Difficulty** (`-100` to `100`, default: `0`)
- **Login time** in seconds (default: `60`)
- **Max clients per IP** (default: `3`)
- **Sharing:** journal, faction ranks, faction expulsion, faction reputation, dialogue topics, bounty, reputation, map exploration, videos
- **Permissions:** allow console (`~`), bed rest, wilderness rest, wait, `/suicide`, `/fixme`
- **Respawn & death:** players respawn on death, death time, jail days on death, reset bounty on death, bounty-based jail time, respawn at Imperial shrine, respawn at Tribunal temple
- **Collisions:** player-player, actor-actor, placed object
- **Time:** pass time when server is empty, night start/end hour
- **Stats limits:** max attribute, max speed, max skill, max acrobatics
- **Safety:** enforce same data files for all clients, ignore Lua script errors

### Firewall
If UFW or firewalld is active, the script will ask whether to open the required ports.

See [management.md](management.md) for server management instructions.

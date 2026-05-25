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
- **HTTP endpoint port (TCP)** (default: `8085`)

### HTTP endpoints
- **Enable `/get-mods`** — lets players download all server mods as a single archive (default: no)
- **Enable `/get-world`** — serves world state (all cells), useful for co-op/RP servers (default: no)
- **Enable `/get-characters`** — serves all character data (inventory, skills, spells, quests) (default: no)

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

Everything else is handled automatically.

---

<details>
<summary>Manual installation (in case the script doesn't fit your needs)</summary>

## 1. Install dependencies

TES3MP server requires: **Docker, Docker Compose, rsync, nano, python3, tar, zip**.

### Arch Linux

```bash
sudo pacman -Syu --noconfirm
```

```bash
sudo pacman -S docker docker-compose rsync nano python tar zip
```

```bash
sudo systemctl enable --now docker
```

### Debian / Ubuntu

```bash
sudo apt-get update
```

```bash
sudo apt-get install -y docker.io docker-compose rsync nano python3 tar zip
```

```bash
sudo systemctl enable --now docker
```

### Fedora

```bash
sudo dnf install -y docker docker-compose rsync nano python tar zip
```

```bash
sudo systemctl enable --now docker
```

To use docker without `sudo`, add your user to the `docker` group:

```bash
sudo usermod -aG docker $USER
```

Then log out and back in (or run `newgrp docker`).

---

## 2. Configure firewall (optional)

If you use UFW:

```bash
sudo ufw allow 25565/udp comment "TES3MP"
sudo ufw allow 8085/tcp comment "TES3MP HTTP endpoints"   # only if enabling endpoints
```

If you use firewalld:

```bash
sudo firewall-cmd --permanent --add-port=25565/udp
sudo firewall-cmd --permanent --add-port=8085/tcp            # only if enabling endpoints
sudo firewall-cmd --reload
```

> Adjust the port numbers if you plan to use non-default values.

---

## 3. Create the folder structure

```bash
sudo mkdir -p /opt/tes3mp/data /opt/tes3mp/mods
```

```bash
sudo chown -R root:root /opt/tes3mp
```

---

## 4. Download and extract the server

```bash
cd /opt/tes3mp/data
```

```bash
wget https://github.com/TES3MP/TES3MP/releases/download/tes3mp-0.8.1/tes3mp-server-GNU+Linux-x86_64-release-0.8.1-68954091c5-6da3fdea59.tar.gz
```

```bash
tar --strip-components=1 -xzf tes3mp-server-GNU+Linux-x86_64-release-0.8.1-68954091c5-6da3fdea59.tar.gz
```

```bash
rm tes3mp-server-GNU+Linux-x86_64-release-0.8.1-68954091c5-6da3fdea59.tar.gz
```

> `--strip-components=1` removes the root folder `TES3MP-server/` during extraction, so all files go directly into `/opt/tes3mp/data`.

---

## 5. Download Docker files and scripts

```bash
cd /opt/tes3mp
```

```bash
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server/files/docker/tes3mp.dockerfile
```

```bash
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server/files/docker/docker-compose.yml
```

```bash
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server/files/docker/nginx.conf
```

```bash
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server/files/docker/export.dockerfile
```

```bash
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server/files/docker/export_server.py
```

```bash
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server/files/scripts/update_mods.sh
```

```bash
chmod +x update_mods.sh
```

> Mod files, configs, and scripts are all copied into the image at build time. After changing any file in `/opt/tes3mp/data/`, you must **rebuild the image**. Management commands (logs, stop, rebuild) are in [management.md](management.md).

---

## 6. Configure tes3mp-server-default.cfg

Open the config file:

```bash
nano /opt/tes3mp/data/tes3mp-server-default.cfg
```

Find and replace the following lines:

```
hostname = YourServerName
password = YourPassword     # leave empty to disable
maximumPlayers = 10
```

Replace `YourServerName`, `YourPassword`, and `10` with your desired values.

---

## 7. Configure config.lua (optional but recommended)

Open the Lua config file:

```bash
nano /opt/tes3mp/data/server/scripts/config.lua
```

Below are all the settings the installer script configures. Find each line and change the value as desired.

### Game settings

```lua
config.gameMode = "Default"
config.difficulty = 0            -- -100 to 100
config.loginTime = 60            -- seconds
config.maxClientsPerIP = 3
```

### Sharing

```lua
config.shareJournal = true
config.shareFactionRanks = true
config.shareFactionExpulsion = false
config.shareFactionReputation = true
config.shareTopics = true
config.shareBounty = false
config.shareReputation = true
config.shareMapExploration = false
config.shareVideos = true
```

### Permissions

```lua
config.allowConsole = false                    -- allow ~ key
config.allowBedRest = true
config.allowWildernessRest = true
config.allowWait = true
config.allowSuicideCommand = true
config.allowFixmeCommand = true
```

### Respawn & Death

```lua
config.playersRespawn = true
config.deathTime = 5                            -- seconds
config.deathPenaltyJailDays = 5
config.bountyResetOnDeath = false
config.bountyDeathPenalty = false
config.respawnAtImperialShrine = true
config.respawnAtTribunalTemple = true
```

### Collisions

```lua
config.enablePlayerCollision = true
config.enableActorCollision = true
config.enablePlacedObjectCollision = false
```

### Time

```lua
config.passTimeWhenEmpty = false
config.nightStartHour = 20
config.nightEndHour = 6
```

### Stats Limits

```lua
config.maxAttributeValue = 200
config.maxSpeedValue = 365
config.maxSkillValue = 200
config.maxAcrobaticsValue = 1200
```

### Safety

```lua
config.enforceDataFiles = true
config.ignoreScriptErrors = false
```

Save the file (`Ctrl+O`, `Enter`) and exit (`Ctrl+X`).

---

## 8. Configure docker-compose.yml (ports and endpoints)

Open the compose file:

```bash
nano /opt/tes3mp/docker-compose.yml
```

### Change the TES3MP port (optional)

Replace `25565:25565/udp` with your chosen port:

```yaml
      - "25565:25565/udp"   # change the left number if you want a different host port
```

### Enable HTTP endpoints (optional)

If you want to enable `/get-mods`, `/get-world`, and/or `/get-characters`, uncomment the corresponding sections.

**nginx service** — required for any endpoint:

```yaml
  nginx:
    image: nginx:alpine
    ports:
      - "8085:80"
    volumes:
      - ./data:/usr/share/nginx/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    restart: unless-stopped
```

**export service** — required only for `/get-world` and `/get-characters`:

```yaml
  export:
    build:
      context: .
      dockerfile: export.dockerfile
    volumes:
      - tes3mp-characters:/mnt/characters:ro
      - tes3mp-cells:/mnt/cells:ro
    restart: unless-stopped
```

Change `"8085:80"` to your chosen HTTP port if different.

---

## 9. Configure nginx.conf (endpoint locations and rate limits)

Open the nginx config:

```bash
nano /opt/tes3mp/nginx.conf
```

### Adjust rate limits (optional)

The top lines define rate limits for each endpoint. The number before `r/m` is the limit in requests per minute:

```
limit_req_zone $binary_remote_addr zone=mods:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=world:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=characters:10m rate=5r/m;
```

Change `5r/m` to your desired rate. Use `0r/m` to disable rate limiting (not recommended).

### Enable location blocks

Uncomment the location blocks for the endpoints you want to enable:

**/get-mods** (serves a static file — only needs the nginx service):

```nginx
location /get-mods {
    limit_req zone=mods burst=1 nodelay;
    alias /usr/share/nginx/html/mods.zip;
    default_type application/zip;
}
```

**/get-world** (requires the export service):

```nginx
location /get-world {
    limit_req zone=world burst=1 nodelay;
    proxy_pass http://export:5000/get-world;
}
```

**/get-characters** (requires the export service):

```nginx
location /get-characters {
    limit_req zone=characters burst=1 nodelay;
    proxy_pass http://export:5000/get-characters;
}
```

---

## 10. HTTP endpoints reference

The server comes with optional HTTP endpoints that serve mods, world state, and character data over the HTTP port:

| Endpoint | What it serves | Requires |
|----------|---------------|----------|
| `/get-mods` | All server mods as `mods.zip` | nginx service |
| `/get-world` | World state (all cell JSON files) as `world_state.tar.gz` | nginx + export services |
| `/get-characters` | All character data as `characters.tar.gz` | nginx + export services |

**All three are disabled by default.** Enabling `/get-mods` is **recommended** — it lets players easily download the mod pack.

**Before enabling `/get-world` and `/get-characters`, consider:**
- Character data (inventories, skills, spells, quest progress) becomes publicly downloadable by anyone who knows the server IP.
- The entire world state becomes visible — all cells, placed items, modified objects.
- On a co-op or roleplay server this can be a **valuable feature** (backups, analytics, transparency). On a competitive server you may prefer to keep character data private.

**See [management.md](management.md) for managing endpoints after installation.**

---

## 11. Build the image and start the server

```bash
cd /opt/tes3mp
```

```bash
docker compose up -d --build
```

---

## 12. Managing the server

- **Logs:** `docker compose -f /opt/tes3mp/docker-compose.yml logs -f`
- **Stop:** `docker compose -f /opt/tes3mp/docker-compose.yml down`
- **Restart after config changes:** `docker compose -f /opt/tes3mp/docker-compose.yml up -d --build`
- **Install mods:** `bash /opt/tes3mp/update_mods.sh`

See [management.md](management.md) for detailed management instructions.

</details>
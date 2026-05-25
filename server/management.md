# Managing the TES3MP server (Docker)

All commands are run as root on the VPS from /opt/tes3mp.

| Action | Command | Details |
|--------|---------|---------|
| Start | `cd /opt/tes3mp && docker compose up -d` | Use `--build` only after changing mods or scripts |
| Restart | `cd /opt/tes3mp && docker compose restart` | Sends SIGTERM to TES3MP; with `stop_grace_period: 30s` the server saves before exit |
| Rebuild (mods, scripts) | `cd /opt/tes3mp && docker compose up -d --build` | Only when you need to pick up changes to mods or Docker image |
| View live logs | `cd /opt/tes3mp && docker compose logs -f` | |
| Stop | `cd /opt/tes3mp && docker compose down` | |
| Edit config | `nano /opt/tes3mp/config/tes3mp-server-default.cfg` | Afterwards, run **Restart** to apply changes |
| Edit Lua config | `nano /opt/tes3mp/config/server/scripts/config.lua` | Afterwards, run **Restart** to apply changes |
| Edit ban list | `nano /opt/tes3mp/config/server/data/banlist.json` | Afterwards, run **Restart** to apply changes |
| Edit required data files | `nano /opt/tes3mp/config/server/data/requiredDataFiles.json` | Afterwards, run **Restart** to apply changes |

---

## Start

```bash
cd /opt/tes3mp
docker compose up -d
```

What happens:
- Pulls the built image and starts the container in background
- Container `stop_grace_period` is set to **30 seconds** — enough for TES3MP to save player state before the container exits

> **Note:** the first time you run this (or after a reboot), TES3MP may re-seed the world with default NPCs and items. Player data (characters, inventory, cells) is **not** affected — it persists across restarts in bind mounts at `./data/players/` (→ `/tes3mp/server/data/player` inside the container) and `./data/cells/` (→ `/tes3mp/server/data/cell`).

## Rebuild (mods, scripts)

Only needed when you've modified mods, scripts, or the Docker image:

```bash
cd /opt/tes3mp
docker compose up -d --build
```

What happens:
- Stops the old container (with 30‑second grace period for saving)
- Rebuilds the Docker image (picks up changes in mods or scripts)
- Creates and starts a new container

## Restart

```bash
cd /opt/tes3mp
docker compose restart
```

Sends SIGTERM to TES3MP, which triggers a graceful save (player data, cells, records) before the container exits. The `stop_grace_period: 30s` setting ensures the server has enough time to finish saving before Docker forcefully kills the container.

If the server seems unresponsive during restart, increase `stop_grace_period` to `60s` in `docker-compose.yml`.

> **Fallback (hard restart, risk of data loss):** `docker compose restart --timeout 0`

## Configuration (bind mounts)

Config files are now stored on the host filesystem at `/opt/tes3mp/config/` and bind-mounted into the container. This means you can edit them with any text editor and changes take effect after a **Restart** (no rebuild needed).

| Host path | Container path |
|-----------|----------------|
| `/opt/tes3mp/config/tes3mp-server-default.cfg` | `/tes3mp/tes3mp-server-default.cfg` |
| `/opt/tes3mp/config/server/scripts/config.lua` | `/tes3mp/server/scripts/config.lua` |
| `/opt/tes3mp/config/server/data/banlist.json` | `/tes3mp/server/data/banlist.json` |
| `/opt/tes3mp/config/server/data/requiredDataFiles.json` | `/tes3mp/server/data/requiredDataFiles.json` |

Why `config/` and not `data/`? Because `data/` is reserved for TES3MP runtime data (players, cells). Putting config files there would cause them to be overwritten on server shutdown. The separate `config/` directory keeps configuration cleanly separated from runtime data.

After editing any config file, run:

```bash
cd /opt/tes3mp && docker compose restart
```

> **Note:** Config bind mounts are read-only inside the container. To make persistent changes, edit the host files. If you delete a config file from the host, the container will use the defaults bundled in the image.

## Data persistence

Player progress (characters, inventory, cells) is stored in bind mounts on the host filesystem:

| Inside container | On host |
|-----------------|---------|
| `/tes3mp/server/data/player/` | `/opt/tes3mp/data/players/` |
| `/tes3mp/server/data/cell/` | `/opt/tes3mp/data/cells/` |

Why `/tes3mp/server/data/player` and not `/tes3mp/players`? Because TES3MP's config sets `home = ./server`, and by default it writes player data to `./data/player` relative to that home directory. The bind mounts mirror exactly where TES3MP writes.

Unlike named volumes, bind mounts are never automatically removed by Docker — data survives rebuilds, container crashes, and even `docker compose down -v`.

### How saving works

TES3MP saves player data in three ways:

1. **On disconnect** — when a player leaves, `OnPlayerDisconnect` fires and calls `SaveToDrive()`
2. **Auto-save interval** — by default every **300 seconds (5 minutes)**, all players, world, and record stores are serialized to disk
3. **On server shutdown** — when the server receives SIGTERM (e.g. `docker compose restart` or `docker compose down`), it calls `OnServerExit` which triggers a final save

The auto-save interval (`config.autoSaveInterval` in `config.lua`) is your safety net — even if the server crashes, you lose at most 5 minutes of progress.

---

## Enabling endpoints: /get-mods, /get-world, /get-characters

All three endpoints are **disabled by default**. Enabling them is **recommended** — they allow players to easily download mods, and give access to world/character data for debugging, backups, or community tools.

### Available endpoints

| Endpoint | Description | Archive |
|----------|-------------|---------|
| `/get-mods` | Download all server mods (`.esp`/`.esm` files) | `mods.zip` |
| `/get-world` | Download world state (all cell JSON files) | `world_state.tar.gz` |
| `/get-characters` | Download all character data | `characters.tar.gz` |

### Before enabling — understand the implications

Enabling `/get-world` and `/get-characters` makes your server's data **publicly readable**:
- **Character data**: anyone with the server IP can download all characters — their inventories, skills, spells, quest progress, etc.
- **World state**: anyone can download every cell, every placed item, every modified object.
- **This can affect gameplay** — players could inspect each other's progress, bases, or hidden stashes.

Consider whether this fits your server's vision. For a co-op or roleplay server it can be a **valuable feature** (transparency, backups, community analytics). For a competitive server you may want to keep character data private.

### To enable

1. **Uncomment the desired location blocks** in `/opt/tes3mp/nginx.conf`.
2. For `/get-world` and `/get-characters` you also need to **uncomment the `export` service** in `/opt/tes3mp/docker-compose.yml`.
3. Uncomment the **`nginx` service** in docker-compose.yml (required for all endpoints).
4. Rebuild and restart:
   ```bash
   cd /opt/tes3mp && docker compose up -d --build
   ```

### To disable

Reverse the steps above and rebuild.

### Notes

- Rate limit: each endpoint has its own configurable limit (default: **5 requests per minute** per IP). Archive is cached for 10 minutes.
- When enabled, endpoints are available at:
  - `http://<server-IP>:8085/get-mods`
  - `http://<server-IP>:8085/get-world`
  - `http://<server-IP>:8085/get-characters`

---

## config.lua reference

Full documentation of all settings in `/opt/tes3mp/config/server/scripts/config.lua` (TES3MP 0.8.1).

The **Installer** column shows whether the setting is covered by the interactive install.sh questionnaire.

Legend: ✅ = asked during installation, ❌ = not asked (edit manually).

### Game settings

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.gameMode` | `"Default"` | ✅ | Game mode displayed in the server browser |
| `config.difficulty` | `0` | ✅ | Difficulty level (-100..100, any integer) |
| `config.loginTime` | `60` | ✅ | Time to login, in seconds |
| `config.maxClientsPerIP` | `3` | ✅ | Max clients allowed from the same IP |
| `config.dataPath` | auto | ❌ | Data folder path (auto-detected server-side) |
| `config.gameSettings` | *(table)* | ❌ | Enforced OpenMW game settings |
| `config.vrSettings` | *(table)* | ❌ | Enforced VR settings |
| `config.defaultTimeTable` | *(table)* | ❌ | World time for a newly created world |
| `config.chatWindowInstructions` | *(text)* | ❌ | Chat instructions shown to joining players |
| `config.startupScriptsInstructions` | *(text)* | ❌ | Warning shown before /runstartup |
| `config.worldStartupScripts` | *(list)* | ❌ | World startup scripts run via /runstartup |
| `config.playerStartupScripts` | *(list)* | ❌ | Player startup scripts run on join |
| `config.physicsFramerate` | `60` | ❌ | Physics framerate used by default |
| `config.enforcedLogLevel` | `-1` | ❌ | Enforced client log level (-1 = client choice) |

### Time

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.passTimeWhenEmpty` | `false` | ✅ | Pass world time when no players are online |
| `config.nightStartHour` | `20` | ✅ | Hour at which night starts |
| `config.nightEndHour` | `6` | ✅ | Hour at which night ends |

### Permissions

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.allowConsole` | `false` | ✅ | Allow players to use the ~ console |
| `config.allowBedRest` | `true` | ✅ | Allow players to rest in bed |
| `config.allowWildernessRest` | `true` | ✅ | Allow players to rest in the wilderness |
| `config.allowWait` | `true` | ✅ | Allow players to wait |
| `config.allowSuicideCommand` | `true` | ✅ | Allow /suicide command |
| `config.allowFixmeCommand` | `true` | ✅ | Allow /fixme command |
| `config.fixmeInterval` | `30` | ❌ | Seconds between /fixme uses |

### Sharing

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.shareJournal` | `true` | ✅ | Share journal entries across players |
| `config.shareFactionRanks` | `true` | ✅ | Share faction rank changes |
| `config.shareFactionExpulsion` | `false` | ✅ | Share faction expulsion |
| `config.shareFactionReputation` | `true` | ✅ | Share faction reputation |
| `config.shareTopics` | `true` | ✅ | Share dialogue topics |
| `config.shareBounty` | `false` | ✅ | Share crime bounties |
| `config.shareReputation` | `true` | ✅ | Share reputation |
| `config.shareMapExploration` | `false` | ✅ | Share map exploration |
| `config.shareVideos` | `true` | ✅ | Share ingame videos across players |
| `config.disabledClientScriptIds` | *(list)* | ❌ | Clientside scripts blanked out |
| `config.synchronizedClientScriptIds` | *(list)* | ❌ | Scripts with synced variables across players |

### Respawn & Death

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.playersRespawn` | `true` | ✅ | Players respawn when dying |
| `config.deathTime` | `5` | ✅ | Time dead before respawn, in seconds |
| `config.deathPenaltyJailDays` | `5` | ✅ | Jail days penalty on death |
| `config.bountyResetOnDeath` | `false` | ✅ | Reset bounty to 0 on death |
| `config.bountyDeathPenalty` | `false` | ✅ | Bounty-based jail time on death |
| `config.respawnAtImperialShrine` | `true` | ✅ | Respawn at nearest Imperial shrine |
| `config.respawnAtTribunalTemple` | `true` | ✅ | Respawn at nearest Tribunal temple |
| `config.defaultRespawn` | *(table)* | ❌ | Default respawn location (Balmora Temple) |

### Spawn

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.useInstancedSpawn` | `true` | ❌ | Use instanced spawn (separate cell per player) |
| `config.instancedSpawn` | *(table)* | ❌ | Instanced spawn location (Seyda Neen office) |
| `config.noninstancedSpawn` | *(table)* | ❌ | Non-instanced spawn location |
| `config.forbiddenCells` | `{"ToddTest"}` | ❌ | Cells players cannot enter |

### Collisions

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.enablePlayerCollision` | `true` | ✅ | Player-player collision |
| `config.enableActorCollision` | `true` | ✅ | Actor-actor collision |
| `config.enablePlacedObjectCollision` | `false` | ✅ | Placed objects collide with actors |
| `config.enforcedCollisionRefIds` | *(list)* | ❌ | RefIds with enforced collision |
| `config.useActorCollisionForPlacedObjects` | `false` | ❌ | Use actor-style collision for placed objects |

### Stats limits

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.maxAttributeValue` | `200` | ✅ | Max attribute value (except Speed) |
| `config.maxSpeedValue` | `365` | ✅ | Max Speed attribute |
| `config.maxSkillValue` | `200` | ✅ | Max skill value (except Acrobatics) |
| `config.maxAcrobaticsValue` | `1200` | ✅ | Max Acrobatics value |
| `config.ignoreModifierWithMaxSkill` | `false` | ❌ | Allow modifiers to bypass max skill values |
| `config.bannedEquipmentItems` | `{"helseth's ring"}` | ❌ | Items players cannot equip |

### Safety & enforcement

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.enforceDataFiles` | `true` | ✅ | Enforce same data files for all clients |
| `config.ignoreScriptErrors` | `false` | ✅ | Ignore Lua script errors (dangerous) |
| `config.databaseType` | `"json"` | ❌ | Database format: json or sqlite3 |
| `config.databasePath` | auto | ❌ | Database file path |
| `config.disallowedNameStrings` | *(list)* | ❌ | Substrings disallowed in player/item names |

### Object & record restrictions

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.maximumObjectScale` | `20` | ❌ | Max object scale |
| `config.generatedRecordIdPrefix` | `"$custom"` | ❌ | Prefix for auto-generated record IDs |
| `config.disallowedActivateRefIds` | `{}` | ❌ | RefIds players cannot activate |
| `config.disallowedDeleteRefIds` | `{"m'aiq"}` | ❌ | RefIds players cannot delete |
| `config.disallowedCreateRefIds` | `{}` | ❌ | RefIds players cannot place/spawn |
| `config.disallowedLockRefIds` | `{}` | ❌ | RefIds players cannot lock/unlock |
| `config.disallowedTrapRefIds` | `{}` | ❌ | RefIds players cannot trap/untrap |
| `config.disallowedStateRefIds` | `{}` | ❌ | RefIds players cannot enable/disable |
| `config.disallowedDoorStateRefIds` | `{}` | ❌ | Door refIds players cannot open/close |

### Networking & authority

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.pingDifferenceRequiredForAuthority` | `40` | ❌ | Ping diff needed for cell authority change |
| `config.allowOnContainerForUnloadedCells` | `false` | ❌ | Allow container access in unloaded cells |

### Record store internals

These are complex tables used by the `/storerecord` system. Refer to the stock config.lua for full details.

| Setting | Installer | Description |
|---------|-----------|-------------|
| `config.recordStoreLoadOrder` | ❌ | Order in which record stores are loaded |
| `config.enchantableRecordTypes` | ❌ | Record types that can carry enchantments |
| `config.carriableRecordTypes` | ❌ | Record types stored by players |
| `config.unplaceableRecordTypes` | ❌ | Record types that cannot be placed in world |
| `config.validRecordSettings` | ❌ | Accepted input fields per record type |
| `config.requiredRecordSettings` | ❌ | Required fields for records without baseId |
| `config.mutuallyExclusiveRecordSettings` | ❌ | Mutually exclusive field groups |
| `config.numericalRecordSettings` | ❌ | Fields converted to numbers |
| `config.booleanRecordSettings` | ❌ | Fields converted to booleans |
| `config.minMaxRecordSettings` | ❌ | Fields converted to min/max tables |
| `config.rgbRecordSettings` | ❌ | Fields converted to RGB color tables |
| `config.cellPacketTypes` | ❌ | Packet types stored in cell data |

### Key order (JSON save order)

These control the order of keys in saved JSON files. Rarely changed.

| Setting | Installer | Description |
|---------|-----------|-------------|
| `config.playerKeyOrder` | ❌ | Key order for player JSON files |
| `config.cellKeyOrder` | ❌ | Key order for cell JSON files |
| `config.recordstoreKeyOrder` | ❌ | Key order for record store JSON files |
| `config.worldKeyOrder` | ❌ | Key order for world state JSON files |

### Misc

| Setting | Default | Installer | Description |
|---------|---------|-----------|-------------|
| `config.fixmeInterval` | `30` | ❌ | Cooldown between /fixme uses |
| `config.rankColors` | *(table)* | ❌ | Colors for server ranks |
| `config.customMenuIds` | *(table)* | ❌ | Custom menu ID numbers |
| `config.menuHelperFiles` | *(list)* | ❌ | Menu files for menuHelper |
| `config.vrSettings` | *(table)* | ❌ | VR settings enforced on clients |
| `config.gameSettings` | *(13 items)* | ❌ | OpenMW game settings enforced on clients |


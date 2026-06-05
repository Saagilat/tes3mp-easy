# Backup Guide

The server stores backups of three data types: **mods**, **players**, and **world**. Each type has its own archive directory on the VPS.

## How Backups Work

```
Admin menu: Export Mods/Players/World
    ──► local data packaged into .tar.gz
    ──► uploaded to VPS via SSH
    ──► stored in /tes3mp-easy/backups/<type>/

nginx service on the VPS makes backups available via HTTP
    ──► players can download with Install Mods or Download Backup
    ──► admins can download backups from the admin menu via HTTP
```

## Admin Operations

### Exporting Data

1. Place your mods, players, or world data in `EXPORT_DIR`:
   ```
   $EXPORT_DIR/mods/plugins/       ← .esp/.esm/.omwaddon
   $EXPORT_DIR/mods/scripts/       ← Lua scripts
   $EXPORT_DIR/players/player/     ← player JSON files
   $EXPORT_DIR/world/{cell,world,map,recordstore,custom}/
   ```

2. From the admin menu, select **Export Mods**, **Export Players**, or **Export World**

### Deploying a Backup (Apply to Server)

1. From the admin menu, select **Deploy Mods / Players / World**
2. Choose an archive (or press Enter for the latest)
3. **Restart the server** for changes to take effect

### Viewing Backups

Select **Show Mod / Player / World Backups** to list archives on the VPS.

### Downloading a Backup (via HTTP)

Select **Download Mod / Player / World Backup** — lists archives via HTTP (port 8085) and saves the selected one to the current directory.

## Player Operations

- **Install Mods** — downloads and unpacks the latest mods archive automatically
- **Download Mod / Player / World Backup** — downloads a specific archive to `~/Downloads/`

## Restore Procedure

1. **Stop** the server from the admin menu
2. **Deploy** the desired backups (mods, players, world)
3. **Start** the server

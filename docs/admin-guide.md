# Admin Guide

## Prerequisites

- A VPS with **root/sudo access**
- **Port 25565/UDP** open for the game
- Your VPS added to `~/.ssh/config`:
  ```
  Host my-server
      HostName 203.0.113.10
      User root
  ```

---

## 1. Server Setup

**Step 1 — Install admin tools on your local machine:**
```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/client/install-admin.sh | bash
```

**Step 2 — Start the menu:**
```bash
bash ~/.local/share/tes3mp-easy/menu/admin.sh
```

**Step 3 — Configure settings:**
- From the menu, select **Common Settings** or **Admin Menu Settings**
- Set `SSH_HOST` (must match a host in `~/.ssh/config`) and `EXPORT_DIR`

**Step 4 — Install the server on VPS:**
- From the menu, select **Install Server**
- This runs the installer on your VPS via SSH automatically (Docker + TES3MP image)

**Step 5 — Start the server:**
- Select **Start Server** from the menu
- See [Player Guide](./player-guide.md) for connecting to the server

---

## 2. Installing Mods

1. Prepare your mods locally in `EXPORT_DIR`:
   ```
   $EXPORT_DIR/mods/plugins/    ← .esp/.esm/.omwaddon files
   $EXPORT_DIR/mods/scripts/    ← Lua scripts
   ```

2. From the admin menu, select **Export Mods** (creates archive and uploads to VPS)

3. From the admin menu, select **Deploy Mods** (picks an archive to apply)

4. **Restart the server** for changes to take effect

Players can then download the mods from the player menu with **Install Mods**.

---

## 3. Server Management

| Action | Menu Entry | Description |
|--------|-----------|-------------|
| Start | Start Server | Starts Docker services on VPS |
| Stop | Stop Server | Stops Docker services |
| Restart | Restart Server | Restarts all services |
| Status | Server Status | Shows if services are running |
| Logs | Server Logs | Tails the TES3MP log |

---

## 4. Backups

See [Backup Guide](./backup-guide.md) for details on creating, deploying, and downloading backups.

---

## Further Reading

- [Backup Guide](./backup-guide.md)
- [Modding Documentation](./admin/modding.md) — TES3MP modding capabilities
- [Server Settings Reference](./admin/tes3mp_settings.md) — all `config.lua` settings
- [Player Guide](./player-guide.md)

If you want to extend tes3mp-easy, see the [Development Guide](./development.md) for internals, full command reference, and how to add new features.

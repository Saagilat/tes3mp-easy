# Player Guide

## Prerequisites

- **Morrowind** installed (Steam, GOG, or any other version)
- **Proton** 9.0+ installed via Steam (for running the Windows client on Linux)

---

## 1. Client Setup

**Step 1 — Install player tools:**
```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/client/install-player.sh | bash
```

**Step 2 — Configure** `~/.tes3mp-easy-player.ini`:
```ini
DATA_FILES = /home/user/.steam/steam/steamapps/common/Morrowind/Data Files
TES3MP_DIR = games/tes3mp
```

| Setting | Description | Example |
|---------|-------------|---------|
| `DATA_FILES` | Path containing `Morrowind.esm` | `/home/user/.../Morrowind/Data Files` |
| `TES3MP_DIR` | TES3MP install path | `games/tes3mp` or absolute path |
| `PROTON_PATH` | Proton path (auto-detected if empty) | `/home/user/.../Proton 9.0` |

**Step 3 — Install the client:**
```bash
bash ~/.local/share/tes3mp-easy/bin/player/install-client
```
This downloads TES3MP (if needed), sets up the Proton prefix, and generates the client config.

**Step 4 — Install fonts and localization (optional):**
- From the player menu, select **Install Fonts** (for Cyrillic support)
- Select **Install Localization** (for translated UI)

**Step 5 — Start the player menu:**
```bash
bash ~/.local/share/tes3mp-easy/menu/player.sh
```

---

## 2. Run the Game with Mods

1. From the player menu, select **Install Mods** — downloads the latest server mods and unpacks them
2. Select **Run Client** — launches TES3MP and connects to the server configured in `tes3mp-client-default.cfg`

---

## 3. Backups

See [Backup Guide](./backup-guide.md) for downloading backups from the server.

---

## Further Reading

- [Backup Guide](./backup-guide.md)
- [Admin Guide](./admin-guide.md)

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Proton not found" | Install Proton 9.0+ via Steam, or set `PROTON_PATH` |
| "Morrowind.esm not found" | Check `DATA_FILES` path |
| Connection fails | Check server is running, correct IP/port, matching TES3MP versions |

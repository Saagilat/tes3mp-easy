# Player Guide

## Prerequisites

- **Morrowind** installed (Steam, GOG, or any other version)
- **Proton** 9.0+ installed via Steam

---

## 1. Client Setup

**Tip:** After installation, run **Quick Setup Wizard** from the player menu — it will guide you through the entire setup process step by step.

**Step 1** — Install player tools:

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/client/install-player.sh | bash
```

**Step 2** — Start the player menu:

```bash
bash ~/.local/share/tes3mp-easy/menu/player.sh
```

**Step 3** — Run Setup Wizard (recommended):
- From the menu, select **Quick Setup Wizard**
- Answer the prompts to configure paths, install client, fonts, and more
- Or follow the manual steps below

**Step 4** — Configure `~/.config/tes3mp-easy/tes3mp-easy-player.ini` (manual):

```ini
MORROWIND_PATH = /home/user/.steam/steam/steamapps/common/Morrowind
TES3MP_DIR = games/tes3mp
```

| Setting | Description | Example |
|---------|-------------|---------|
| `MORROWIND_PATH` | Path to Morrowind installation (parent of `Data Files`) | `/home/user/.../Morrowind` |
| `TES3MP_DIR` | TES3MP install path | `games/tes3mp` |
| `PROTON_PATH` | Proton path (auto-detected) | `/home/user/.../Proton 9.0` |

**Step 5** — Install the client:

```bash
bash ~/.local/share/tes3mp-easy/bin/player/install-client
```

**Step 6** — (Optional) fonts and localization:
- From the player menu, select **Install Fonts** — fixes font rendering issues
- Select **Install Localization** — for translated UI

---

## 2. Run the Game with Mods

1. From the player menu, select **Install Mods**
2. Select **Run Client**

---

<details>
<summary>Backups & further reading</summary>

- [Backup Guide](./backup-guide.md) — downloading backups from the server
- [Admin Guide](./admin-guide.md)

</details>

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Proton not found" | Install Proton 9.0+ via Steam, or set `PROTON_PATH` |
| "Morrowind.esm not found" | Check `MORROWIND_PATH` path |
| Connection fails | Check server is running, matching TES3MP versions |
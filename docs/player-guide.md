# Player Guide

## Prerequisites

- **Morrowind** installed (Steam, GOG, or any other version)
- **Proton** 9.0+

---

## 1. Client Setup


**Step 1** — Install scripts:

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/client/install.sh | bash
```

**Step 2** — Start the player menu:

```bash
bash ~/.local/share/tes3mp-easy/layer3/player.sh
```

**Step 3** — Run Setup Wizard (recommended):
- From the menu, select **Quick Setup Wizard**
- The wizard will configure Morrowind path, TES3MP directory, Proton path, install the client, fonts, localization, and set up the UI

That's it — the client is ready. See [Run the Game with Mods](#2-run-the-game-with-mods) to connect to a server.

---

## 2. Run the Game with Mods

1. From the player menu, select **Client config** — set server address and password in `tes3mp-client-default.cfg`
2. Select **Install Mods** — downloads and unpacks the latest mods archive
3. Select **Launch Client** — run the game via Proton

You can also launch **OpenMW-CS** (Construction Set) from the player menu for modding.

---

<details>
<summary>Further reading</summary>

- [Backup Guide](./backup-guide.md) — downloading backups from the server
- [Admin Guide](./admin-guide.md)

</details>

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Proton not found" | Install Proton 9.0+, or set `PROTON_PATH` in config |
| "Morrowind.esm not found" | Check `MORROWIND_PATH` path |
| Connection fails | Check server is running, matching TES3MP versions |
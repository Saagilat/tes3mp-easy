# TES3MP Easy

Guides and scripts for setting up and managing TES3MP servers and installing the TES3MP client.

## 🚀 Quick start (Linux / Git Bash)

```bash
# 1. Download the management script
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/tes3mp-easy
chmod +x tes3mp-easy

# 2. Run it
./tes3mp-easy
```

On first run the script will:
1. Download all module scripts to `~/.local/share/tes3mp-easy/`
2. Ask if you are an **admin** or a **player**
3. Guide you through initial setup (SSH host, paths, etc.)
4. Open the appropriate menu

### 👤 Player menu

```bash
./tes3mp-easy player-menu
```

- Install TES3MP client via Proton
- Configure fonts and server address
- Download mods, players, world data from server
- Install localization
- Generate `requiredDataFiles.json`

### 🖥️ Admin menu

```bash
./tes3mp-easy menu
```

- Install / reconfigure server on VPS
- Start, stop, restart, view logs
- Export mods, players, world to server
- Manage player roles
- Import backups
- Open player menu directly

### Commands without menu

```bash
./tes3mp-easy start              # docker compose up -d
./tes3mp-easy stop               # docker compose down
./tes3mp-easy restart            # docker compose restart
./tes3mp-easy logs               # follow logs
./tes3mp-easy export-mods        # package and upload mods
./tes3mp-easy export-players     # package and upload players
./tes3mp-easy export-world       # package and upload world
./tes3mp-easy install-server     # install server on VPS
./tes3mp-easy configure-server   # reconfigure server
./tes3mp-easy install-client     # install TES3MP client (Proton)
./tes3mp-easy download-mods      # download mods from server
./tes3mp-easy self-update        # update tes3mp-easy
./tes3mp-easy help               # show all commands
```

---

## 🎮 Player documentation

- [Step-by-step player guide](docs/player/install.md) — from client installation to joining the server.
- [Linux / Proton guide](docs/player/linux/proton/install.md) — detailed Proton setup.

## 🖥️ Server admin documentation

- [Admin guide](docs/admin/install.md) — from server setup to management.
- [Server management reference](docs/admin/management.md) — commands, endpoints, configs.
- [Modding](docs/admin/modding.md) — what works and what doesn't.
- [TES3MP settings reference](docs/admin/tes3mp_settings.md) — full config.lua docs.

---

## Requirements

- **bash** 4.0+
- **curl**, **wget**, **tar** — for downloading and packaging
- **rhash** — for CRC32 validation (required for mod export)
- **ssh**, **scp** — for server management (admin only)

On Windows, use **Git Bash** (comes with Git for Windows).

## Security

- All scripts are open-source on GitHub — inspect before running.
- The script **never touches** `~/.ssh/config` without explicit permission.
- Every SSH command is displayed before execution.
- Works from a regular user account, no root required.

## Resources

- [TES3MP on GitHub](https://github.com/TES3MP/TES3MP)
- [OpenMW on GitHub](https://github.com/OpenMW/openmw)

Thanks to David Cernat for TES3MP and the OpenMW team for making Morrowind open-source and cross-platform.
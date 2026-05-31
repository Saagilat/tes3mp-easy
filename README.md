# TES3MP Easy

Guides and scripts for setting up and managing TES3MP servers and installing the TES3MP client.

## 🚀 Quick start (Linux / Git Bash)

Choose your role:

### 🖥️ Admin — manage a server

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/install-admin.sh | bash
```

### 👤 Player — join a server

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/install-player.sh | bash
```

On first run the script will:
1. Download all necessary scripts to `~/.local/share/tes3mp-easy/`
2. Ask if you are an **admin** or a **player**
3. Guide you through initial setup (SSH host, paths, etc.)
4. Open the appropriate menu

### Subsequent runs

```bash
# Admin menu
bash ~/.local/share/tes3mp-easy/menu/admin.sh

# Player menu
bash ~/.local/share/tes3mp-easy/menu/player.sh
```

Or add an alias to `~/.bashrc`:
```bash
alias tes3mp='bash ~/.local/share/tes3mp-easy/menu/admin.sh'
```

### Direct commands (skip the menu)

```bash
# Admin
bash ~/.local/share/tes3mp-easy/menu/admin.sh start           # docker compose up -d
bash ~/.local/share/tes3mp-easy/menu/admin.sh stop            # docker compose down
bash ~/.local/share/tes3mp-easy/menu/admin.sh restart         # docker compose restart
bash ~/.local/share/tes3mp-easy/menu/admin.sh logs            # follow logs
bash ~/.local/share/tes3mp-easy/menu/admin.sh export-mods     # package and upload mods
bash ~/.local/share/tes3mp-easy/menu/admin.sh export-players  # package and upload players
bash ~/.local/share/tes3mp-easy/menu/admin.sh export-world    # package and upload world
bash ~/.local/share/tes3mp-easy/menu/admin.sh install-server  # install server on VPS
bash ~/.local/share/tes3mp-easy/menu/admin.sh self-update     # update scripts

# Player
bash ~/.local/share/tes3mp-easy/menu/player.sh download-mods  # download mods from server
bash ~/.local/share/tes3mp-easy/menu/player.sh install-client # install TES3MP client
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
- **curl** — for downloading scripts
- **rhash** — for CRC32 validation (required for admin mod export)
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
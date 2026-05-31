# TES3MP Easy

Guides and scripts for setting up and managing TES3MP servers and installing the TES3MP client.

## 🚀 Quick start

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
2. Guide you through initial setup (SSH host, paths, etc.)
3. Open the appropriate menu

### Recommended aliases

Add these to `~/.bashrc`:

```bash
alias tes3mp-easy-admin='bash ~/.local/share/tes3mp-easy/menu/admin.sh'
alias tes3mp-easy-player='bash ~/.local/share/tes3mp-easy/menu/player.sh'
```

### Direct commands (skip the menu)

```bash
# Admin
tes3mp-easy-admin install-server         # Install server on VPS
tes3mp-easy-admin start                  # docker compose up -d
tes3mp-easy-admin stop                   # docker compose down
tes3mp-easy-admin restart                # docker compose restart
tes3mp-easy-admin logs                   # follow logs
tes3mp-easy-admin export-mods            # push mods to server
tes3mp-easy-admin export-players         # push players to server
tes3mp-easy-admin export-world           # push world to server
tes3mp-easy-admin self-update            # update scripts

# Player
tes3mp-easy-player download-mods         # download mods from server
tes3mp-easy-player install-client        # install TES3MP client
tes3mp-easy-player install-localization  # install localization
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
# Admin Guide

## 1. Quick start — install the management tool

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/install-admin.sh | bash
```

This downloads all scripts to `~/.local/share/tes3mp-easy/` and opens the admin menu.

After the first run, use the menu or aliases:

```bash
alias tes3mp-easy-admin='bash ~/.local/share/tes3mp-easy/menu/admin.sh'
alias tes3mp-easy-player='bash ~/.local/share/tes3mp-easy/menu/player.sh'
```

Add these to `~/.bashrc` to make them permanent.

### Direct commands (skip the menu)

```bash
tes3mp-easy-admin install-server        # Install server on VPS
tes3mp-easy-admin configure-server      # Reconfigure server
tes3mp-easy-admin start                 # docker compose up -d
tes3mp-easy-admin stop                  # docker compose down
tes3mp-easy-admin restart               # docker compose restart
tes3mp-easy-admin logs                  # follow logs
tes3mp-easy-admin export-mods           # push mods to server
tes3mp-easy-admin export-players        # push players to server
tes3mp-easy-admin export-world          # push world to server
tes3mp-easy-admin self-update           # update scripts
```

---

## 2. Install the server on the VPS

The admin menu has an option "Install server on VPS" which runs the install script on your remote server. You can also do it manually:

### Interactive installation

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server/scripts/install.sh | bash
```

The script installs Docker and utilities, downloads server files,
builds the Docker image, then runs `configure.sh` interactively
to set up the server.

### Non-interactive (automatic) installation

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server/scripts/install.sh | bash -s -- --default
```

| Flag | Description |
|------|-------------|
| `--default` | Non-interactive mode with all default values (no password, endpoints disabled) |
| `--test` | Like `--default`, but sets password to `1234` and enables all HTTP endpoints (`/get-mods`, `/get-players`, `/get-world`) |

### What install.sh does

- Installs **Docker** and **docker compose plugin** (if missing)
- Installs system utilities (nano, rhash, tar, zip)
- Downloads Docker files, nginx config, helper scripts
- Downloads and builds the **TES3MP server Docker image**
- Runs `configure.sh` to finalize configuration

---

## 3. Reconfigure an existing server

After the initial installation, you can reconfigure the server
at any time **without losing player/world/mod data**.

Via admin menu:

```bash
tes3mp-easy-admin configure-server
```

Or manually via SSH:

```bash
# Interactive
ssh my-server "bash /tes3mp-easy/scripts/configure.sh"

# Non-interactive (test mode)
ssh my-server "bash /tes3mp-easy/scripts/configure.sh --test"
```

`configure.sh` accepts the same flags (`--default`, `--test`, `--help`).

What it does:
- Asks (or uses defaults for) server name, password, ports, endpoints
- Asks (or uses defaults for) Lua config settings
- Writes `tes3mp-server-default.cfg` and `config.lua`
- Configures nginx and docker-compose for selected endpoints
- Configures firewall (if active)
- Starts/restarts containers
- Creates initial archive backups

---

## 4. Set up SSH access

The admin menu requires SSH access to your VPS.

Add an SSH host entry to `~/.ssh/config`:

```
Host my-server
    HostName your-server-ip-or-host
    User root
```

Generate and copy the SSH key:

```bash
ssh-keygen -t ed25519
ssh-copy-id my-server
```

Now `ssh my-server` should connect without a password.

---

## 5. Push mods

Place your mod files (`.esp`/`.esm`/`.omwaddon`) in your plugins directory,
and Lua scripts in your server scripts directory.

Set the paths via the admin menu (Settings → SSH host, paths) or directly:

```bash
nano ~/.tes3mp-easy-admin.conf
```

Then run:

```bash
tes3mp-easy-admin export-mods
```

The script validates CRC32, packages mods+scripts, uploads them to the server,
and restarts the container.

---

## 6. Create an admin account and run the startup command

1. **Join the server** through the TES3MP client ([Player guide](../player/install.md))
2. **Register** — enter any username and password
3. **Exit the game**
4. **Set the admin role (if you are not the first player)** — see [Player role management](management.md#player-role-management) for instructions
5. **Log back into the server** as your admin character
6. **Run `/runstartup`** in the in-game chat (press **Y** to open the chat)
   > This command must be executed **on every newly created world** (after world creation or reset) for the server to function correctly.
7. **Restart the server:**
   ```bash
   tes3mp-easy-admin restart
   ```

Done — you are now a server administrator.

---

## Next steps

- [Server management reference](management.md) — commands, endpoints, configs
- [Player role management](management.md#player-role-management) — how to manage player roles
- [Modding — what works and what doesn't in TES3MP 0.8.1](modding.md)
- [config.lua reference — full settings documentation](tes3mp_settings.md)
- [Player guide](../player/install.md) — if you need to set up a client
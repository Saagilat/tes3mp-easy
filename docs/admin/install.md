# Admin Guide

## 1. Clone the repository

```bash
git clone git@github.com:Saagilat/tes3mp-easy.git
cd tes3mp-easy
```

---

## 2. Install the server

Run the install script on your server (VPS).

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

### Interactive reconfiguration

```bash
ssh my-server "bash /tes3mp-easy/scripts/configure.sh"
```

### Non-interactive reconfiguration

```bash
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

## 4. Set up SSH access and an alias

To push mods to the server with a single command, configure SSH access and create an alias.

First, add an SSH host entry to `~/.ssh/config`:

```
Host my-server
    HostName your-server-ip-or-host
    User root
```

Then generate and copy the SSH key:

```bash
ssh-keygen -t ed25519
ssh-copy-id my-server
```

Now `ssh my-server` should connect without a password.

Add a bash alias to `~/.bashrc` or `~/.bash_aliases`:

```bash
alias tes3mp-easy-server-update-mods='bash ~/tes3mp-easy/tools/linux/tes3mp-easy-export-mods'
```

Apply the changes:

```bash
source ~/.bashrc
```

---

## 5. Push mods

Edit the sync config:

```bash
nano tools/linux/tes3mp-easy-export.conf.example
```

Set the SSH host (the one from `~/.ssh/config`) and your local mod directories:

```
SSH_HOST=my-server
PLUGINS_DIR=/path/to/your/plugins
SERVER_SCRIPTS_DIR=/path/to/your/server-scripts
```

Place your mod files (`.esp`/`.esm`/`.omwaddon`) in `PLUGINS_DIR`,
and Lua scripts in `SERVER_SCRIPTS_DIR`.

Run the sync:

```bash
tes3mp-easy-server-update-mods
```

The script copies all files to the server and restarts the container.

---

## 6. Create an admin account and run the startup command

1. **Join the server** through the TES3MP client ([Player guide](../player/install.md) — if you need to set up a client)
2. **Register** — enter any username and password
3. **Exit the game**
4. **Set the admin role (if you are not the first player)** — see [Player role management](management.md#player-role-management) for instructions
5. **Log back into the server** as your admin character
6. **Run `/runstartup`** in the in-game chat (press **Y** to open the chat)
   > This command must be executed **on every newly created world** (after world creation or reset) for the server to function correctly.
7. **Restart the server:**

   ```bash
   ssh my-server "cd /tes3mp-easy && docker compose restart"
   ```

Done — you are now a server administrator.

---

## Next steps

- [Server management reference](management.md) — commands, endpoints, configs
- [Player role management](management.md#player-role-management) — how to manage player roles
- [Modding — what works and what doesn't in TES3MP 0.8.1](modding.md)
- [config.lua reference — full settings documentation](tes3mp_settings.md)
- [Player guide](../player/install.md) — if you need to set up a client
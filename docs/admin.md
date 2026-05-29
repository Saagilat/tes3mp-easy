# Admin Guide

## 1. Clone the repository

```bash
git clone git@github.com:Saagilat/tes3mp-easy-setup.git
cd tes3mp-easy-setup
```

---

## 2. Install the server

Run the install script on your server (VPS):

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server_setup/scripts/install.sh | bash
```

Or download and run it manually:

```bash
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server_setup/scripts/install.sh
sudo bash install.sh
```

The script installs Docker, downloads the TES3MP server, configures settings, and starts the container.

---

## 3. Set up SSH access and an alias

To push mods to the server with a single command, set up an SSH key:

```bash
ssh-keygen -t ed25519
ssh-copy-id root@your-server-ip-or-host
```

Verify the connection:

```bash
ssh root@your-server-ip-or-host
```

Add an alias to `~/.bashrc` or `~/.bash_aliases`:

```bash
alias tes3mp-easy-server-name='bash ~/tes3mp-easy-setup/tools/linux/tes3mp-server-update-mods'
```

Apply the changes:

```bash
source ~/.bashrc
```

---

## 4. Push mods

Edit the sync config:

```bash
nano tools/linux/tes3mp-server-update-mods.conf
```

Set the server and your local mod directories:

```
SSH_HOST=root@your-server-ip-or-host
PLUGINS_DIR=/path/to/your/plugins
SERVER_SCRIPTS_DIR=/path/to/your/server-scripts
```

Place your mod files (`.esp`/`.esm`/`.omwaddon`) in `PLUGINS_DIR`,
and Lua scripts in `SERVER_SCRIPTS_DIR`.

Run the sync:

```bash
tes3mp-easy-server-name
```

The script copies all files to the server and restarts the container.

---

## 5. Create an admin account

1. **Join the server** through the TES3MP client
2. **Register** — enter any username and password (the first registered account gets ServerOwner rank by default)
3. **Exit the game**
4. **Stop the server:**

   ```bash
   ssh root@your-server-ip-or-host "cd /tes3mp-easy && docker compose down"
   ```

5. **Open the player file** and change `staffRank`:

   ```bash
   ssh root@your-server-ip-or-host "nano /tes3mp-easy/container-data/server/data/player/<accountName>.json"
   ```

   Find the `settings` section and set the desired rank:

   ```json
   "settings": {
       "staffRank": 3,
       ...
   }
   ```

   | Value | Rank |
   |-------|------|
   | `0` | Regular player |
   | `1` | Moderator |
   | `2` | Admin |
   | `3` | Server owner |

6. **Start the server:**

   ```bash
   ssh root@your-server-ip-or-host "cd /tes3mp-easy && docker compose up -d"
   ```

Done — you are now a server administrator.
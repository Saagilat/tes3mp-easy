# Adding mods to a TES3MP server

## Quick setup (recommended)

The `tes3mp-upload-mods` script automates syncing your local mods folder to a remote server and running `update_mods.sh` — all with a single command.

### 1. Install the script (one time)

```bash
# Download
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/tools/linux/admin/tes3mp-upload-mods

# Make executable and install
chmod +x tes3mp-upload-mods
sudo mv tes3mp-upload-mods /usr/local/bin/
```

Or copy from the repository directly.

### 2. Set up SSH access (one time)

Add an alias for your server in `~/.ssh/config`:

```
Host tes3mp-server
    HostName 1.2.3.4
    Port 22
    User root
    IdentityFile ~/.ssh/tes3mp_key
```

### 3. Create the admin config (one time)

Create `~/.config/tes3mp/admin.conf`:

```bash
mkdir -p ~/.config/tes3mp
wget -O ~/.config/tes3mp/admin.conf \
  https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/tools/linux/admin/admin.conf
```

Then edit it with your values:

```ini
SSH_HOST=tes3mp-server
MODS_DIR=/home/user/tes3mp-mods
```

- `SSH_HOST` — the alias from `~/.ssh/config` (or `user@host` if you prefer)
- `MODS_DIR` — absolute path to the folder where you keep your mod files

### 4. Upload mods

Put your `.esp`/`.esm`/`.omwaddon`/`.omwscripts`/`.omwgame` files in the `MODS_DIR` folder, then run:

```bash
tes3mp-upload-mods
```

The script will:
1. Sync your mods to `/opt/tes3mp/mods/` on the server (removing files that no longer exist locally)
2. Run `update_mods.sh` on the server, which copies them to `data/`, generates `requiredDataFiles.json`, packs `mods.zip`, and rebuilds the Docker container

---

## Alternative: Manual upload

If you prefer not to set up the script, or need to manage mods on a local server:

### Remote server (via VPS)

> ⚠️ If other people also manage the server mods, always **pull first** to avoid overwriting their work.

1. Pull existing mods from the server:
   ```bash
   cd /path/to/mods/folder
   rsync -avz user@server:/opt/tes3mp/mods/ ./
   ```

2. Push your mods and update the server:
   ```bash
   rsync -avz ./ user@server:/opt/tes3mp/mods/ && \
     ssh user@server "cd /opt/tes3mp && bash update_mods.sh"
   ```

If you are the only person managing mods and don't need existing files — skip step 1.

### Local server (same machine)

```bash
sudo cp -r . /opt/tes3mp/mods/
cd /opt/tes3mp && sudo bash update_mods.sh
```

---

## Distributing mods to players

After the script runs, mods are packaged into `mods.zip` in the `data/` folder. A separate `mods-server` container (nginx) is running on the server, serving this archive at a single endpoint.

Players can download the archive via:
```
http://<server-IP>:8085/get-mods
```

There is a rate limit: **no more than 10 downloads per 2 minutes** from a single IP.

### Player quick setup

Players can use the `tes3mp-download-mods` script to automate installation — see [client/installing-mods.md](../client/installing-mods.md).
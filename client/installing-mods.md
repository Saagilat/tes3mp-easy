# Installing Mods from the Server

If the server provides a ready-made mod pack (as described in the [server admin guide](../server/modding.md)), this guide explains how to download and install it.

> **Prerequisites**: You must have TES3MP installed and configured.

## Quick setup (recommended)

The `tes3mp-download-mods` script automates everything: it downloads the latest mods, replaces old ones, and configures `openmw.cfg`.

### 1. Install the script (one time)

```bash
# Download
wget https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/tools/linux/player/tes3mp-download-mods

# Make executable and install
chmod +x tes3mp-download-mods
sudo mv tes3mp-download-mods /usr/local/bin/
```

Or copy from the repository directly.

### 2. Create the client config (one time)

```bash
mkdir -p ~/.config/tes3mp
wget -O ~/.config/tes3mp/client.conf \
  https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/tools/linux/player/client.conf
```

Edit the config with your actual paths:

```ini
CLIENT_DEFAULT=/path/to/tes3mp-client-default.cfg
DATA_FILES=/path/to/OpenMW/Data Files
OPENMW_CFG=/home/user/.config/openmw/openmw.cfg
```

- `CLIENT_DEFAULT` — path to your `tes3mp-client-default.cfg` (the script reads the server address from it)
- `DATA_FILES` — path to the game's `Data Files` folder (where `.esp`/`.esm`/`.omwaddon` files go)
- `OPENMW_CFG` — path to `openmw.cfg` (typically `~/.config/openmw/openmw.cfg` on Linux)

The mod archive is always downloaded from port `8085` — this is the default HTTP port used by the server's nginx container.

> **Note**: The `DATA_FILES` path may contain spaces. Write the path as-is (do **not** use quotes or backslashes).

### 3. Install mods

```bash
tes3mp-download-mods
```

The script will:
1. Read the server address from `tes3mp-client-default.cfg`
2. Download the mod pack from `http://<server>:8085/get-mods`
3. Remove old mod files from `Data Files` (preserving `Morrowind.esm`, `Tribunal.esm`, `Bloodmoon.esm`)
4. Extract the new mods into `Data Files`
5. Add `include = mods.cfg` to `openmw.cfg` if not already present

To update mods later, just run `tes3mp-download-mods` again.

> **Pro tip**: You can add `tes3mp-download-mods` as a **pre-launch command** in Steam (TES3MP) so mods update automatically every time you launch the game.

---

## Manual installation

If you prefer to do it manually:

### 1. Download and extract mods

The server may expose a download endpoint (typically `http://{SERVER_ADDRESS}:8085/get-mods`) that serves a mod archive.  
**Note:** The server administrator may disable this endpoint — if it doesn't work, ask the admin to enable it.

Download the archive using your browser or any download tool, then extract its contents into the game's `Data Files` folder.

### 2. Enable mods in OpenMW config

Locate your `openmw.cfg` file — it is **not** in the game folder, but in your user profile:

| Platform | Typical path |
|----------|-------------|
| Linux    | `~/.config/openmw/openmw.cfg` or `~/openmw-profile/openmw.cfg` |
| Windows  | `%USERPROFILE%\Documents\My Games\OpenMW\openmw.cfg` |

Open this file and add the following line at the end:

```
include = mods.cfg
```

> **Important**: Do **not** wrap filenames in quotes, even if they contain spaces. For example, `content=Dark Brotherhood Attacks Once - Delayed Attacks.ESP` is correct — **no** quotes around the path.

### 3. How to update mods

Download and extract the archive again — the new files will overwrite the old ones. No changes to `openmw.cfg` are needed.

### 4. How to remove the mod pack

Delete the extracted mod files, then open `openmw.cfg` and remove the `include = mods.cfg` line you added earlier.
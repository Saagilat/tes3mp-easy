# Player Guide

## 1. Clone the repository

```bash
git clone git@github.com:Saagilat/tes3mp-easy.git
cd tes3mp-easy
```

---

## 2. Install the client

| OS | Guide |
|----|-------|
| Linux (Proton) | [Installation guide](linux/proton/install.md) |

---

## 3. Configure fonts

OpenMW uses bitmap fonts by default, which look blurry on modern screens. For better readability, install TrueType fonts:

1. Download **TrueType fonts for OpenMW** from Nexus Mods:  
   https://www.nexusmods.com/morrowind/mods/46854  
2. Extract the archive contents into your `openmw-profile` folder

Copy the example file from the repository:

```bash
cp tools/example-settings.cfg /path/to/openmw-profile/settings.cfg
```

<details>
<summary>Parameter explanations</summary>

- `ttf resolution` — font resolution (higher = sharper)
- `font size` — range is limited to 12–20  
- `scaling factor` — determines the overall UI size
</details>

For more font options see the [OpenMW font documentation](https://openmw.readthedocs.io/en/openmw-0.47.0_a/reference/modding/font.html).

---

## 4. (optional) Install localization

| Language | Instructions |
|----------|-------------|
| Russian | [Setup guide](../../tools/localization/russian/README.md) |

---

## 5. Set the server address

Open `tes3mp-client-default.cfg` (next to your TES3MP client executable) and set the server address:

```
destinationAddress = your-server-ip-or-host
```

Default port is `25565`. For a non-standard port, set it explicitly:

```
destinationPort = 25565
```

---

## 6. Install the mod update tool

Edit the config:

```bash
nano tools/linux/tes3mp-easy-client-update-mods.conf
```

Set the paths to your files:

```
CLIENT_DEFAULT=/path/to/tes3mp-client-default.cfg
DATA_FILES=/path/to/Data Files/
OPENMW_CFG=/path/to/openmw.cfg
```

Run the sync:

```bash
bash tools/linux/tes3mp-easy-client-update-mods
```

The script downloads mods from the server, installs them into `Data Files/`, and updates `openmw.cfg`.

---

## 7. Join the server

1. Launch your TES3MP client and connect to the server
2. Enter a username and password to register
3. Done — you are on the server!
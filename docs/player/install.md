# Player Guide

## 1. Install the TES3MP management tool

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/install-player.sh | bash
```

This downloads all scripts to `~/.local/share/tes3mp-easy/` and opens the player menu.

After the first run, use the menu or aliases:

```bash
alias tes3mp-easy-player='bash ~/.local/share/tes3mp-easy/menu/player.sh'
```

Add to `~/.bashrc` to make it permanent.

### Direct commands (skip the menu)

```bash
tes3mp-easy-player download-mods              # Download and install mods
tes3mp-easy-player install-client             # Install TES3MP client (Proton)
tes3mp-easy-player install-localization       # Install localization
tes3mp-easy-player generate-required-data     # Generate requiredDataFiles.json
tes3mp-easy-player self-update                # Update scripts
```

---

## 2. Install the client

| OS | Guide |
|----|-------|
| Linux (Proton) | [Installation guide](linux/proton/install.md) |

Or run in the player menu: `1. Install TES3MP client (Proton)`

---

## 3. Configure fonts

OpenMW uses bitmap fonts by default, which look blurry on modern screens. For better readability, install TrueType fonts:

1. Download **TrueType fonts for OpenMW** from Nexus Mods:  
   https://www.nexusmods.com/morrowind/mods/46854
2. Extract the archive contents into your `openmw-profile` folder

Then in the player menu select: `2. Configure fonts (TrueType)`

<details>
<summary>Parameter explanations</summary>

- `ttf resolution` — font resolution (higher = sharper)
- `font size` — range is limited to 12–20  
- `scaling factor` — determines the overall UI size
</details>

For more font options see the [OpenMW font documentation](https://openmw.readthedocs.io/en/openmw-0.47.0_a/reference/modding/font.html).

---

## 4. Set the server address

In the player menu select: `3. Configure server address`

Or directly via alias:

```bash
tes3mp-easy-player config
# → edit CLIENT_DEFAULT path
```

The script updates `destinationAddress` and `destinationPort` in your `tes3mp-client-default.cfg`.

---

## 5. Download and install mods

In the player menu select: `4. Download and install mods`

Or directly:

```bash
tes3mp-easy-player download-mods
```

The script downloads mods from the server, installs them into `Data Files/`, and updates `openmw.cfg`.

---

## 6. (optional) Install localization

| Language | Action |
|----------|--------|
| Russian | `tes3mp-easy-player install-localization` |

---

## 7. Join the server

1. Launch your TES3MP client and connect to the server
2. Enter a username and password to register
3. Done — you are on the server!
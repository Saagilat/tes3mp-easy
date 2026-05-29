# Player Guide

## 1. Clone the repository

```bash
git clone git@github.com:Saagilat/tes3mp-easy-setup.git
cd tes3mp-easy-setup
```

---

## 2. Install the client

| OS | Guide |
|----|-------|
| Linux (Proton) | [Installation guide](linux/proton/install.md) |

---

## 3. Configure fonts

Create `settings.cfg` inside your `openmw-profile` folder.
Copy the example file from the repository:

```bash
mkdir -p ~/openmw-profile
cp tools/linux/example-settings.cfg ~/openmw-profile/settings.cfg
```

> **Note:** Replace `~/openmw-profile` with the actual path to your OpenMW profile.
> Linux (Proton): the file is located next to `openmw.cfg` (see step 2).

---

## 4. (optional) Install localization

| Language | Command |
|----------|---------|
| Russian | [Setup guide](localization/russian/) |

---

## 5. Edit tes3mp-client-default.cfg

Open `tes3mp-client-default.cfg` (next to `tes3mp.exe`) and set the server address:

```
destinationAddress = your-server-ip-or-host
```

Default port is `25565`. For a non-standard port, set it explicitly:

```
destinationPort = 25565
```

---

## 6. Install the mod update tool

Copy and edit the config:

```bash
cp tools/linux/tes3mp-easy-client-update-mods.conf tools/linux/tes3mp-easy-client-update-mods.conf.local
nano tools/linux/tes3mp-easy-client-update-mods.conf.local
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

1. Launch `tes3mp.exe` through Steam
2. Enter a username and password to register
3. Done — you are on the server!
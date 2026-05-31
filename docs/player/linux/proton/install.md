# Installing TES3MP Client via Proton

## 1. Download and extract the Windows version of TES3MP

- Download `tes3mp.Win64.release.0.8.1.zip` from the [releases page](https://github.com/TES3MP/TES3MP/releases/download/tes3mp-0.8.1/tes3mp.Win64.release.0.8.1.zip)
- Extract it to any convenient folder, e.g. `~/morrowind/tes3mp`

## 2. Add `openmw-wizard.exe` to Steam as a non-Steam game

- Add `openmw-wizard.exe` as a non-Steam game
- Assign it Proton (e.g., 11.0 or Experimental)
- Create a symlink to the Morrowind folder

```bash
ln -s ~/.steam/steam/steamapps/common/Morrowind ~/morrowind
```

<details>
<summary>Why is the symlink needed?</summary>
The file browser inside Wine/Proton cannot see hidden folders (those starting with a dot). The Steam folder is hidden (`~/.steam`). Therefore you create a symlink to Morrowind in your home directory.
</details>

- Run `openmw-wizard.exe` through Steam. When the wizard asks for the path to Morrowind files, select `~/morrowind/Data Files/Morrowind.esm`
- Immediately create a symlink to the config folder so you don't have to navigate into compatdata every time:

```bash
ln -s "$HOME/.steam/steam/steamapps/compatdata/{WIZARD_ID}/pfx/drive_c/users/steamuser/Documents/My Games/OpenMW" ~/openmw-profile
```

## 3. Add `tes3mp.exe` to Steam and replace its prefix

- Add `tes3mp.exe` as a non-Steam game
- Assign the same Proton version (11.0 or Experimental)
- Run it once — Steam will create its own compatdata
- Close the game

This compatdata ID is referred to as `{TES3MP_ID}`.

- Delete the `pfx` that Steam created for `tes3mp.exe`:

```bash
rm -rf ~/.steam/steam/steamapps/compatdata/{TES3MP_ID}/pfx
```

- Create a symlink from tes3mp `pfx` to the wizard's `pfx`:

```bash
ln -s ~/.steam/steam/steamapps/compatdata/{WIZARD_ID}/pfx ~/.steam/steam/steamapps/compatdata/{TES3MP_ID}/pfx
```

> **Note about the `data/` folder:** OpenMW also looks for plugins in a `data/`
> folder next to `openmw.cfg`, and gives it **higher priority** than `data=`
> paths. If `openmw-cs` creates this folder, plugin versions there may differ
> from the server and cause CRC mismatch. `tes3mp-easy-client-update-mods` automatically
> detects this folder and offers to remove it.
>
> Symlinks from the prefix to external directories do **not** work in
> Wine/Proton. Always let `tes3mp-easy-client-update-mods` remove the `data/` folder.

<details>
<summary>If you add other OpenMW utilities</summary>
For `openmw-cs.exe` and other OpenMW utilities repeat step 3:

- Run once, find its compatdata ID
- Delete `pfx`
- Symlink to the wizard's `pfx`
</details>

## 4. Limit FPS

<details>
<summary>Why is this needed?</summary>
OpenMW does not limit FPS by default, which can cause the GPU to overheat. Use **MangoHud** — a utility that can limit FPS and works with Proton.
</details>

- Install MangoHud:

```
paru -S mangohud
```

- In the Steam properties of the non-Steam game `tes3mp.exe`, set the launch options:

```
MANGOHUD_CONFIG=fps_limit=120,no_display mangohud %command%
```

---

After Proton setup is complete, continue with the [general player guide](../../install.md) for font configuration, server address setup, mods, and joining the server.

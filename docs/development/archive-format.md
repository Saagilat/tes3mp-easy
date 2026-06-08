# Archive Format

All three archive types use a consistent format:
- Paths are **relative** (no `./` prefix)
- Archives are created with `(cd "$dir" && tar czf "$output" -- * )`
- Deploy scripts extract only the subdirectories they need; extra files are ignored

## Mods Archive

```text
plugins/
  AllBuildings.esp
  BeautifulMorrowind.esm
  requiredDataFiles.json
scripts/
  custom.lua
```

**Created by:** `package_mods()`, `package_init_mods()`, `export-mods`  
**Deployed by:** `deploy_mods.sh` — extracts `plugins/ scripts/`

## Players Archive

```text
players/
  Saagilat.json
  SomeGuy.json
requiredDataFiles.json
current.txt
```

**Created by:** `package_players()`, `package_init_players()`, `export-players`  
**Deployed by:** `deploy_players.sh` — extracts `players/`

## World Archive

```text
cell/
world/
map/
recordstore/
custom/
requiredDataFiles.json
current.txt
```

**Created by:** `package_world()`, `package_init_world()`, `export-world`  
**Deployed by:** `deploy_world.sh` — extracts `cell/ world/ map/ recordstore/ custom/`

## Metadata Files

- `requiredDataFiles.json` — lists all plugins with CRC32 hashes
  - In **mods** archive: inside `plugins/` (TES3MP entrypoint expects it there)
  - In **players** and **world** archives: at root (copied from mods archive for reference)
- `current.txt` — contains `<sha256> <filename>` of the corresponding mods archive

Both files are for reference/validation only. Deploy scripts ignore them.
# Modding TES3MP 0.8.1 — Limitations and Capabilities

This document describes what is supported and **not** supported in TES3MP 0.8.1 (based on OpenMW 0.47).

## Supported

### Plugins (`.esp`/`.esm`/`.omwaddon`/`.omwscripts`/`.omwgame`)

Plugins are the only way to modify the game on the client side.
The server checks their presence and CRC when a player connects via `requiredDataFiles.json`.

- All clients must have the same plugins
- `test_plugin.omwaddon` is an example working plugin
- Plugins are distributed via `/get-mods` inside `mods.zip`

### Server-side Lua scripts

Server scripts (`.lua` in `server-scripts/`) execute **on the server**.
They use the `customEventHooks` and `customCommandHooks` API.

- `test_server.lua` is an example working server script
- Documentation: `Tutorial.md` shipped with TES3MP

## NOT supported

### Client-side Lua scripts

**No client Lua API exists.** OpenMW 0.47 does not have a built-in Lua engine on the client — support appeared only in OpenMW 0.48+.

- `tes3mp.MessageBox()`, `tes3mp.LoadClientScript()` and similar client functions **do not exist**
- `.lua` files placed in `Data Files/` are ignored and never executed
- There is no need to download client scripts from the server — they are useless for this version

### The `.omwscripts` format

The `.omwscripts` extension was included in `update_mods.sh` for forward compatibility, but its support depends on the OpenMW version. In TES3MP 0.8.1 / OpenMW 0.47:

- `.omwscripts` may be ignored or cause an error on the client
- Only `.esp`/`.esm`/`.omwaddon` are recommended

## Summary

| What can be modded | How |
|-------------------|-----|
| Game data (items, spells, worlds) | Plugins `.esp`/`.esm`/`.omwaddon` |
| Server logic (commands, events) | Lua scripts in `server-scripts/` |
| Client scripts (GUI, custom features) | **NOT SUPPORTED** in TES3MP 0.8.1 |

Client-side Lua scripting requires TES3MP based on OpenMW 0.48+.
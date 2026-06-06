# TES3MP Easy

A set of tools to set up a **TES3MP** multiplayer server and connect to it as a player.

## Installation

Install the scripts on your local machine:

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/client/install.sh | bash
```

This installs both admin and player tools. Existing configuration is preserved.

### Administrator

```bash
bash ~/.local/share/tes3mp-easy/layer3/admin.sh
```

From the menu you can: run the setup wizard → install the server → configure settings (38 options from `config.lua`) → create and export mods → deploy backups → start/stop/restart the server.

See the [Admin Guide](./docs/admin-guide.md) for detailed instructions.

### Player (Linux)

```bash
bash ~/.local/share/tes3mp-easy/layer3/player.sh
```

From the menu you can: run the setup wizard → install the client → configure server connection → install mods → run the game.

See the [Player Guide](./docs/player-guide.md) for detailed instructions.

## Developer

Interested in the internals? See the [Development Guide](./docs/development.md) for architecture, layer design, how to add new commands, and full command references.

## Acknowledgements

Thanks to the [TES3MP](https://github.com/TES3MP) and [OpenMW](https://github.com/OpenMW) teams for their work on making Morrowind multiplayer possible.
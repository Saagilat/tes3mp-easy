# TES3MP Easy

A set of tools to set up a **TES3MP** multiplayer server and connect to it as a player.

## Administrator

Install the admin tools on your local machine:

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/client/install-admin.sh | bash
```

```bash
bash ~/.local/share/tes3mp-easy/menu/admin.sh
```

From the menu: configure settings → install server → install mods → start server.

See the [Admin Guide](./docs/admin-guide.md) for detailed instructions.

## Player (Linux)

Install the player tools:

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/client/install-player.sh | bash
```

```bash
bash ~/.local/share/tes3mp-easy/menu/player.sh
```

From the menu: install client → configure server connection → install mods → run the game.

See the [Player Guide](./docs/player-guide.md) for detailed instructions.

## Acknowledgements

Thanks to the [TES3MP](https://github.com/TES3MP) and [OpenMW](https://github.com/OpenMW) teams for their work on making Morrowind multiplayer possible.

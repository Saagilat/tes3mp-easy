# TES3MP Easy Setup

Guides and scripts for setting up and managing TES3MP servers and installing the TES3MP client.

## Quickstart

### 🎮 Player
Follow the [player guide](docs/player/README.md) for your OS.

### 🖥️ Server admin

```bash
curl -fsSL https://raw.githubusercontent.com/Saagilat/tes3mp-easy-setup/master/server_setup/scripts/install.sh | bash
```

For detailed setup instructions see [setup guide](docs/admin/install.md).  
For server management see [management guide](docs/admin/management.md).

## Tools

- **`tools/linux/tes3mp-server-update`** — sync plugins and server scripts from your local machine to the server
- **`tools/linux/tes3mp-client-update`** — download and install the latest plugins from the server

## Repository layout

```
server_setup/ — server setup (Docker, install/update scripts)
tools/        — synchronisation utilities
docs/         — admin and player documentation
example/      — example Lua scripts (for testing)
```

---

- [TES3MP on GitHub](https://github.com/TES3MP/TES3MP)
- [OpenMW on GitHub](https://github.com/OpenMW/openmw)

Thanks to David Cernat for TES3MP and the OpenMW team for making Morrowind open-source and cross-platform.

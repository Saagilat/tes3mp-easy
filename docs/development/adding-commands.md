# Adding Commands

Step-by-step guide for adding a new command.

## 1. Determine Which Layers Are Needed

```
Need an operation
    ↓
Is there user interaction? (selection, prompt, wizard)
    ├── NO → Layer 1 only (client) + possibly public (server)
    └── YES → Layer 1 + Layer 2 (client) + possibly public (server)
```

## 2. Server Side: Public/Private

If the operation runs on the server, determine where the logic goes:

### Private

Create a script in `server/private/` if it's a new server action:

```bash
#!/bin/bash
# private/my-new-action.sh — description
set -euo pipefail

# Do one thing
tar czf "/tes3mp-easy/backups/example/backup-$(date +%F_%H-%M-%S).tar.gz" \
  -C /tes3mp-easy/input data
```

**Size target: 5-30 lines.**

### Public

If the private action is called directly from the client (or composed with others), create a public utility in `server/public/`:

```bash
#!/bin/bash
# public/my-operation — compose a safe operation
set -euo pipefail

bash /tes3mp-easy/private/backup-world.sh
bash /tes3mp-easy/private/my-new-action.sh
```

## 3. Create Layer 1 Script

Create a file in `client/layer1/<player|admin|shared>/<command>`:

```bash
#!/bin/bash
# Description of what this script does.
# Usage: <command> [args]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/lib/common"
source "$SCRIPT_DIR/lib/config"

# Do the work
# - Accept arguments via $1, $2, ...
# - Print data to stdout (JSON, filenames, or nothing)
# - Exit 0 on success, non-zero on failure
```

**Rules:**
- No prompts, no menus, no `read` from user.
- No colors, no headers, no `[OK]`/`[WARN]` prefixes.
- All SSH/HTTP calls go here.
- For admin SSH calls: `ssh "$SSH_HOST" "bash /tes3mp-easy/public/<command>" [args]`
- For player HTTP calls: `curl -sf "$SERVER_URL/..."`

## 4. (Optional) Create Layer 2 Script

Only if user interaction is needed. Create a file in `client/layer2/<player|admin>/interactive-<command>`:

```bash
#!/bin/bash
# Description with interaction.

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
source "$PROJECT_DIR/lib/common"
source "$PROJECT_DIR/lib/config"

# Interact with user (menu, prompts, confirmations)
# Delegate work to Layer 1:
#   bash "$PROJECT_DIR/layer1/player/<command>" "$selected_option"
```

**Rules:**
- No SSH/HTTP calls.
- No data fetching or parsing — delegate to Layer 1.
- Adds UI: headers, colors, numbering, error messages, confirmation prompts.

## 5. Add Menu Entry in Layer 3

Edit `client/layer3/player.sh` or `client/layer3/admin.sh`:

### Add a dispatch case

```bash
# Layer 1 (no interaction):
my-command) bash "$LAYER1_PATH/my-command" "$@" ;;

# Layer 2 (interactive):
my-command) bash "$LAYER2_PATH/interactive-my-command" ;;
```

### Add a function wrapper for `run_menu`

```bash
menu_my_command() { bash "$LAYER1_PLAYER/my-command"; }
```

### Add the item to the menu array

```bash
"${MENU_LABEL}|fn|menu_my_command"
```

## 6. Add Translations

Add labels in `client/lib/menu-strings` and/or locale installers in `client/lib/localization/`.

## 7. Add Download Lines in Installer

Add `download` lines in `client/install.sh`:

```bash
download "client/layer1/player/my-command" "$UPDATE_DIR/layer1/player/my-command"
```

If Layer 2 was created, add it too:

```bash
download "client/layer2/player/interactive-my-command" "$UPDATE_DIR/layer2/player/interactive-my-command"
```

Also add new server-side files to `server/scripts/install.sh` download list:

```bash
for f in my-new-action.sh; do
    wget "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server/private/$f" \
      -O "$dest/private/$f"
done

for f in my-operation; do
    wget "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server/public/$f" \
      -O "$dest/public/$f"
done
chmod +x "$dest/public/"*
```

## Checklist

- [ ] Private script created in `server/private/` (if server action)
- [ ] Public utility created in `server/public/` (if called from client)
- [ ] Layer 1 script in `client/layer1/<role>/<command>`
- [ ] Layer 2 script in `client/layer2/<role>/interactive-<command>` (if interactive)
- [ ] Menu entry in Layer 3 (`dispatch()`, wrapper func, menu array item)
- [ ] Translations in `client/lib/menu-strings`
- [ ] Download line in `client/install.sh`
- [ ] Download lines in `server/scripts/install.sh` (for new server files)
# Adding Commands

Step-by-step guide for adding a new command to the project.

## 1. Determine Which Layers Are Needed

```
Need an operation
    ↓
Is there user interaction? (selection, prompt, wizard)
    ├── NO → Layer 1 only
    └── YES → Layer 1 + Layer 2
```

If the operation runs on the VPS, you also need a server-side script in `server/scripts/`.

## 2. Create Server-Side Script (if needed)

Create a script in `server/scripts/` if the operation runs on the VPS:

```bash
#!/bin/bash
# scripts/my-new-action.sh — description
set -euo pipefail

# Do one thing
tar czf "/tes3mp-easy/backups/example/backup-$(date +%F_%H-%M-%S).tar.gz" \
  -C /tes3mp-easy/input data
```

**Size target: 5-30 lines.** If longer, it probably does too much.

Rules:
- One operation per script.
- Machine-readable output (or none) — no colors, no `[OK]`/`[WARN]`.
- Exit 0 on success, 1 on failure.
- Use `tmp` folder + atomic move for destructive operations.

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
- For admin SSH calls: `ssh "$SSH_HOST" "bash /tes3mp-easy/scripts/<command>" [args]`
- For player HTTP calls: `curl -sf "$SERVER_URL/..."`
- For SCP operations: download → edit locally → upload

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

## 7. Add Download Lines in Installers

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
    wget "https://raw.githubusercontent.com/Saagilat/tes3mp-easy/master/server/scripts/$f" \
      -O "$dest/$f"
done
```

## Checklist

- [ ] Server-side script created in `server/scripts/` (if VPS action)
- [ ] Layer 1 script in `client/layer1/<role>/<command>`
- [ ] Layer 2 script in `client/layer2/<role>/interactive-<command>` (if interactive)
- [ ] Menu entry in Layer 3 (`dispatch()`, wrapper func, menu array item)
- [ ] Translations in `client/lib/menu-strings`
- [ ] Download line in `client/install.sh`
- [ ] Download lines in `server/scripts/install.sh` (for new server files)
- [ ] Tested: ran the command manually and verified the result
- [ ] Logging: errors are written to the log file (via `err()` wrapper)
- [ ] Safety: no raw user input passed to `sed`, `eval`, or unquoted shell expansions
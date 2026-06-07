# Communication

How the client talks to the server.

## Admin → Server: SSH + Public Utilities

All admin operations use SSH to call utilities in `server/public/`. The client **never** issues manual commands (no `docker compose`, `grep`, `sed`, `rm`, etc. in SSH strings).

### Operation calls

```bash
ssh "$SSH_HOST" "bash /tes3mp-easy/public/<command>" [args]
```

Examples:

```bash
# Start the server
ssh "$SSH_HOST" "bash /tes3mp-easy/public/start"

# Deploy a mod archive
ssh "$SSH_HOST" "bash /tes3mp-easy/public/deploy-mods archive.tar.gz"

# Check server status
ssh "$SSH_HOST" "bash /tes3mp-easy/public/status"

# List mod backups (JSON)
ssh "$SSH_HOST" "bash /tes3mp-easy/public/list-backups mods"

# Read config.lua settings
ssh "$SSH_HOST" "bash /tes3mp-easy/public/read-config-lua"

# Install/update server
ssh "$SSH_HOST" "bash /tes3mp-easy/public/install"
```

### Export + Import (two-step: scp archive then call utility)

```bash
# Export mods: create archive locally + upload + import on server
cd "$EXPORT_DIR/mods" && tar czf /tmp/mods.tar.gz plugins/ scripts/
scp /tmp/mods.tar.gz "$SSH_HOST":/tes3mp-easy/import-mods/mods.tar.gz
ssh "$SSH_HOST" "bash /tes3mp-easy/public/import-mods"
```

## Admin → Server: SCP for File Editing

Config files are edited by downloading, editing locally, then uploading back. No remote editor execution.

### Pattern

```bash
remote_path="/tes3mp-easy/configs/tes3mp-server-default.cfg"
tmpfile=$(mktemp)

# Download
scp "$SSH_HOST:$remote_path" "$tmpfile"

# Edit locally
$EDITOR "$tmpfile"

# Upload back
scp "$tmpfile" "$SSH_HOST:$remote_path"
rm -f "$tmpfile"
```

### Files edited this way

| Local script | Remote file |
|--------------|-------------|
| `edit-server-cfg` | `/tes3mp-easy/configs/tes3mp-server-default.cfg` |
| `edit-lua` | `/tes3mp-easy/configs/customScripts.lua` |
| `edit-banlist` | `/tes3mp-easy/configs/banlist.json` |

### Non-interactive config editing

For programmatic config changes (e.g., `interactive-configure-server`), use `read-config-lua` and `apply-config-lua`:

```bash
# Read current settings
ssh "$SSH_HOST" "bash /tes3mp-easy/public/read-config-lua"

# Apply changes (sed script via stdin)
echo "s/config.port = 25565/config.port = 25566/" | \
  ssh "$SSH_HOST" "bash /tes3mp-easy/public/apply-config-lua"
```

## Player → Server: HTTP

Player operations use HTTP to the nginx server (port 8085). No SSH required.

### List backups

```bash
curl -sf "$SERVER_URL/list-backups/mods"
```

### Download backup

```bash
curl -sfL "$SERVER_URL/download/mods/$filename" -o "$dest"
```

### Server URL resolution

The server URL is built from `tes3mp-client-default.cfg` configuration:

```bash
server_addr=$(grep -o '^destinationAddress *=.*' "$cfg" | cut -d= -f2 | tr -d ' ')
echo "http://${server_addr}:8085"
```

## Decision: SSH vs HTTP

| Operation | Transport | Reason |
|-----------|-----------|--------|
| Admin commands (start, stop, deploy, import, etc.) | SSH | Requires server-side execution |
| Admin config editing | SCP + local editor | Interactive, local editor UX |
| Admin download backups | SCP | Simple, secure |
| Player list backups | HTTP (nginx) | No SSH keys needed |
| Player download backups | HTTP (nginx) | Public access via URL |
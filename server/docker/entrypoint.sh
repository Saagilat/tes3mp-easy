#!/bin/bash
#
# entrypoint.sh — TES3MP container entrypoint
#
# Creates symlinks for plugins from the mods mount into server/data/,
# then launches TES3MP.
#
# Runs a background watcher that monitors the export container via HTTP.
# If export becomes unreachable, TES3MP shuts down to prevent data loss
# without backups.
#

shopt -s nullglob nocaseglob

# Create symlinks for plugins from /tes3mp/data-plugins/ to /tes3mp/server/data/
if [ -d /tes3mp/data-plugins ]; then
  for ext in esp esm omwaddon omwscripts omwgame; do
    for f in /tes3mp/data-plugins/*."$ext"; do
      ln -sf "$f" /tes3mp/server/data/
    done
  done
  # requiredDataFiles.json is not a plugin — link it separately
  if [ -f /tes3mp/data-plugins/requiredDataFiles.json ]; then
    ln -sf /tes3mp/data-plugins/requiredDataFiles.json /tes3mp/server/data/requiredDataFiles.json
  fi
fi

# ─────────────────────────────────────────────
# Export health watcher (background)
# Checks export container every 30 seconds via HTTP.
# If unreachable, kills the main process.
# ─────────────────────────────────────────────
(
  # Wait for export to become available at startup
  for i in $(seq 1 20); do
    if curl -sf http://export:5000/list-backups/state >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  # Monitor loop
  while true; do
    sleep 30
    if ! curl -sf http://export:5000/list-backups/state >/dev/null 2>&1; then
      echo "[watcher] Export container unreachable — shutting down TES3MP" >&2
      kill -TERM 1 2>/dev/null || exit 1
    fi
  done
) &

# Launch TES3MP
exec /tes3mp/tes3mp-server
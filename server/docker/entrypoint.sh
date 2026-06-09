#!/bin/bash
#
# entrypoint.sh — TES3MP container entrypoint
#
# Creates symlinks for plugins from the mods mount into server/data/,
# then launches TES3MP.
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

# Launch TES3MP
exec /tes3mp/tes3mp-server
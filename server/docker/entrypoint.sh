#!/bin/bash
#
# entrypoint.sh — TES3MP container entrypoint
#
# Creates symlinks for plugins from the mods mount into server/data/,
# then launches TES3MP.
#

shopt -s nullglob

# Create symlinks for plugins from /tes3mp/data-plugins/ to /tes3mp/server/data/
if [ -d /tes3mp/data-plugins ]; then
  ln -sf /tes3mp/data-plugins/*.esp /tes3mp/server/data/ 2>/dev/null
  ln -sf /tes3mp/data-plugins/*.omwaddon /tes3mp/server/data/ 2>/dev/null
  if [ -f /tes3mp/data-plugins/requiredDataFiles.json ]; then
    ln -sf /tes3mp/data-plugins/requiredDataFiles.json /tes3mp/server/data/requiredDataFiles.json
  fi
fi

# Launch TES3MP
exec /tes3mp/tes3mp-server
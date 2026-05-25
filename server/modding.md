# Adding mods to a TES3MP server

Use the `update_mods.sh` script, which automates removing old mods, copying new ones, computing CRC32, generating `requiredDataFiles.json`, and rebuilding the Docker container.

## Option A: Remote server (via VPS)

> ⚠️ If other people also manage the server mods, always **pull first** to avoid overwriting their work.

1. Pull existing mods from the server:
   ```bash
   cd /path/to/mods/folder
   rsync -avz user@server:/opt/tes3mp/mods/ ./
   ```

2. Push your mods and update the server:
   ```bash
   rsync -avz ./ user@server:/opt/tes3mp/mods/ && \
     ssh user@server "cd /opt/tes3mp && bash update_mods.sh"
   ```

If you are the only person managing mods and don't need existing files — skip step 1.

## Option B: Local server (same machine)

```bash
sudo cp -r . /opt/tes3mp/mods/
cd /opt/tes3mp && sudo bash update_mods.sh
```

---

## Distributing mods to players

After the script runs, mods are packaged into `mods.zip` in the `data/` folder. A separate `mods-server` container (nginx) is running on the server, serving this archive at a single endpoint.

Players can download the archive via:
```
http://<server-IP>:8085/get-mods
```

There is a rate limit: **no more than 10 downloads per 2 minutes** from a single IP.


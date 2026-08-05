#!/usr/bin/env bash
# save-hook.sh - laeuft beim Pod-Stop (SIGTERM) ueber den Trap im gepatchten
# /start.sh. Auto-Save des HF-Repos, mit Timeout (große Uploads koennen beim
# Pod-Grace abbrechen - dann vorher manuell save.sh pasten).
set -o pipefail

REPO="${HF_REPO:-meierme/comfyui-sync}"
SYNC_DIR="/workspace/comfyui-sync"

if [ -z "${HF_TOKEN:-}" ]; then
  echo "[save] Kein HF_TOKEN - Auto-Save uebersprungen (manuell save.sh aufrufen)"
  exit 0
fi

if [ ! -d "$SYNC_DIR" ]; then
  echo "[save] Sync-Ordner fehlt - nichts zu speichern"
  exit 0
fi

echo "[save] Auto-Save -> $REPO (Timeout 10 Min)"
timeout 600 bash "$SYNC_DIR/scripts/save.sh" || echo "[save] save.sh fehlgeschlagen (Timeout oder Fehler) - ggf. manuell nachholen"
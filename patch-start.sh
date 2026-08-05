#!/usr/bin/env bash
# patch-start.sh (laeuft beim Docker-BUILD, GNU sed)
# Patcht den offiziellen /start.sh des Base-Images:
#   1) Inject "bash /sync.sh" VOR "# Start ComfyUI" -> Modelle/Nodes/Workflows
#      sind beim ersten ComfyUI-Ordner-Scan bereits da (kein Restart noetig).
#   2) SIGTERM/SIGINT-Trap ruft ZUSAETZLICH /save-hook.sh auf -> Auto-Save
#      beim Pod-Stop.
set -euo pipefail

if ! grep -q '/sync.sh' /start.sh; then
  sed -i '/^# Start ComfyUI/i\
bash /sync.sh || echo "[sync] fehlgeschlagen, ComfyUI startet trotzdem"' /start.sh
fi

if ! grep -q '/save-hook.sh' /start.sh; then
  sed -i 's~^trap .* SIGTERM SIGINT$~trap '"'"'bash /save-hook.sh || true; kill $COMFY_PID 2>/dev/null'"'"' SIGTERM SIGINT~' /start.sh
fi
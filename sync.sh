#!/usr/bin/env bash
# sync.sh - laeuft vom gepatchten /start.sh VOR dem ComfyUI-Start.
# Laedt das private HF-Repo, verlinkt Models/Workflows und zieht alles aus
# models.txt (HF-Modelle + GitHub-Custom-Nodes). Schlägt fehl -> ComfyUI
# startet trotzdem (Meldung im Log).
set -o pipefail

REPO="${HF_REPO:-meierme/comfyui-sync}"
SYNC_DIR="/workspace/comfyui-sync"
EXTRAS_DIR="/workspace/comfyui-extras"
MODELS_TXT="$SYNC_DIR/models.txt"
COMFY_DIR="${COMFY_DIR:-/workspace/runpod-slim/ComfyUI}"

if [ ! -f "$COMFY_DIR/main.py" ]; then
  for d in /workspace/runpod-slim/ComfyUI /workspace/comfyui /workspace/madapps/ComfyUI; do
    if [ -f "$d/main.py" ]; then COMFY_DIR="$d"; break; fi
  done
fi
export COMFY_DIR

echo "[sync] Lade Repo $REPO -> $SYNC_DIR"
hf download "$REPO" --repo-type dataset --local-dir "$SYNC_DIR" || echo "[sync] hf download fehlgeschlagen"

echo "[sync] Verlinke Models/Workflows"
bash "$SYNC_DIR/scripts/load.sh" || echo "[sync] load.sh fehlgeschlagen"

if [ ! -f "$MODELS_TXT" ]; then
  echo "[sync] Keine models.txt - fertig"
  exit 0
fi

echo "[sync] Verarbeite models.txt"
mkdir -p "$EXTRAS_DIR"

while IFS= read -r line || [ -n "$line" ]; do
  line="$(echo "$line" | xargs)"
  case "$line" in
    ""|"#"*) continue ;;
  esac

  if [[ "$line" == *"github.com"* ]]; then
    url="$line"
    [[ "$url" != http* ]] && url="https://$url"
    name=$(basename "$url" .git)
    if [ -d "$COMFY_DIR/custom_nodes/$name" ]; then
      echo "[sync] Node existiert: $name"
    else
      echo "[sync] Klone Node: $name"
      git clone --depth 1 "$url" "$COMFY_DIR/custom_nodes/$name" || echo "[sync] clone fehlgeschlagen: $name"
      if [ -f "$COMFY_DIR/custom_nodes/$name/requirements.txt" ]; then
        echo "[sync] Installiere Node-Abhaengigkeiten: $name"
        pip install -q -r "$COMFY_DIR/custom_nodes/$name/requirements.txt" || echo "[sync] pip fehlgeschlagen: $name"
      fi
    fi

  elif [[ "$line" == *"huggingface.co"* ]] || [[ "$line" == *"hf.co"* ]]; then
    url="${line%|*}"
    target="${line#*|}"
    url="$(echo "$url" | xargs)"
    target="$(echo "$target" | xargs)"
    if [ -z "$target" ]; then
      echo "[sync] kein Zielordner (Format: URL | ordner): $url"
      continue
    fi
    repo_type="model"
    [[ "$url" == *"/datasets/"* ]] && repo_type="dataset"
    rest="${url#*//}"
    rest="${rest#huggingface.co/}"
    rest="${rest#hf.co/}"
    rest="${rest#datasets/}"
    repo="${rest%%/*}"
    rest2="${rest#*/}"
    repo="$repo/${rest2%%/*}"
    path="${rest2#*blob/}"
    [ "$path" = "$rest2" ] && path="${rest2#*resolve/}"
    path="${path#*/}"
    echo "[sync] Lade $repo/$path -> $EXTRAS_DIR/$target/"
    rm -rf /tmp/hfmodels
    mkdir -p /tmp/hfmodels "$EXTRAS_DIR/$target"
    hf download "$repo" "$path" --repo-type "$repo_type" --local-dir /tmp/hfmodels || { echo "[sync] hf fehlgeschlagen: $path"; continue; }
    cp -f "/tmp/hfmodels/$path" "$EXTRAS_DIR/$target/$(basename "$path")"

  else
    echo "[sync] uebersprungen (keine HF/GitHub-URL): $line"
  fi
done < "$MODELS_TXT"

YAML="$COMFY_DIR/extra_model_paths.yaml"
if ! grep -q "comfyui_extras" "$YAML" 2>/dev/null; then
  echo "[sync] Lege extra_model_paths.yaml an"
  cat >> "$YAML" <<'YAMLEOF'
comfyui_extras:
  base_path: /workspace/comfyui-extras
  checkpoints: checkpoints
  unet: unet
  diffusion_models: diffusion_models
  text_encoders: text_encoders
  clip: text_encoders
  vae: vae
  loras: loras
  embeddings: embeddings
  upscale_models: upscale_models
  clip_vision: clip_vision
  controlnet: controlnet
YAMLEOF
fi

echo "[sync] fertig"
# comfyui-image

Custom RunPod-Image für ComfyUI auf Basis von `runpod/comfyui:1.4.5-cuda13.0`.
Es patcht den offiziellen `/start.sh` so, dass pro Pod automatisch:

1. das private HF-Repo (`meierme/comfyui-sync`) nach `/workspace/comfyui-sync` geladen wird,
2. Models/Workflows per Symlink in die ComfyUI-Installation verlinkt werden,
3. alle Einträge aus `models.txt` (HF-Modelle + GitHub-Custom-Nodes) gezogen werden,
4. ComfyUI **danach** startet — alle Ordner sind beim ersten Scan gefüllt → kein Restart nötig,
5. beim Pod-Stop (SIGTERM) automatisch `save.sh` läuft → Auto-Save.

Im Alltag: Pod deployen → ComfyUI-Tab öffnen → fertig. Stoppen → wird gespeichert.
Kein Paste, kein manuelles `save.sh`, kein Restart.

## Image bauen (automatisch via GitHub Actions)

1. Diesen Ordner in ein GitHub-Repo pushen (z.B. `comfyui-image`).
2. Bei jedem Push auf `main` baut die Action (`.github/workflows/docker.yml`)
   das Image für `linux/amd64` und pusht es nach GHCR:
   `ghcr.io/<dein-github-user-lowercase>/comfyui-image:v1`
3. Im GitHub-Package (`https://github.com/users/<user>/packages/container/comfyui-image`)
   unten *Package settings* → *Danger Zone* → **Change visibility → Public**
   (sonst kann RunPod es nicht anonym pullen; für Private ein RunPod-Registry-Secret anlegen).

## RunPod-Template anpassen

- **Container image:** `ghcr.io/<dein-github-user-lowercase>/comfyui-image:v1`
- **Container Start Command:** *leer lassen* (das Image übernimmt alles)
- **Environment variables:**
  - `HF_TOKEN` = dein HF-Token mit **Write**-Rechten (als Secret anlegen → verschlüsselt)
  - `HF_REPO` = `meierme/comfyui-sync`
- **Container disk:** 50 GB
- **Persistent storage:** 0 GB
- **HTTP Ports:** 8188 (ComfyUI), 8080 (FileBrowser), 8888 (Jupyter)
- **TCP Port:** 22 (SSH)

## Workflow im Alltag

| Aktion | Was passiert |
|---|---|
| Pod deployen | ComfyUI startet mit allen Workflows + Modellen + Nodes fertig |
| Workflow in ComfyUI ändern + Ctrl+S | landet via Symlink im Sync-Ordner |
| Neues Model/Node | Eintrag in `models.txt` (im HF-Repo) → ab nächstem Pod automatisch geladen |
| Pod **Stop** | Auto-Save läuft (SIGTERM-Trap) → Änderungen auf HF |
| Pod **Restart** | `/workspace` bleibt → kein Re-Sync nötig; Stop würde es löschen |
| Großer manueller Upload (neuer Lora) | trotz Auto-Save einmal manuell `save.sh` pasten, um Pod-Grace nicht zu riskieren |

## Hinweise

- `models.txt` liegt im privaten HF-Repo (nicht in diesem Image-Repo). Änderungen there → `save.sh` → nächster Pod zieht sie. Kein Rebuild nötig.
- Base image getagt mit `:v1` (RunPod empfiehlt versionierte Tags statt `:latest`).
- Falls der GitHub-Username Großbuchstaben enthält: der Workflow lowercased `repository_owner` automatisch für den GHCR-Pfad.
- Auto-Save hat 10 Min Timeout; bei sehr großen neuen Dateien im Sync-Ordner kann der Pod-Grace knapp werden → dann einmal manuell speichern.
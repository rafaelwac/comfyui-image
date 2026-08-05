FROM runpod/comfyui:1.4.5-cuda13.0

# git wird zum Klonen von Custom Nodes (models.txt) gebraucht
RUN apt-get update --yes \
 && DEBIAN_FRONTEND=noninteractive apt-get install --yes --no-install-recommends git \
 && rm -rf /var/lib/apt/lists/*

# huggingface_hub inkl. hf_xet (schneller Xet/CDN-Transfer)
RUN pip install --no-cache-dir -U "huggingface_hub[hf_xet]"

# Eigene Scripts ins Image
COPY sync.sh /sync.sh
COPY save-hook.sh /save-hook.sh
COPY patch-start.sh /patch-start.sh
RUN chmod +x /sync.sh /save-hook.sh /patch-start.sh && /patch-start.sh

# Sanity-Check: die gepatchten Anker im Build-Log sichtbar
RUN grep -n '/sync.sh\|/save-hook.sh' /start.sh
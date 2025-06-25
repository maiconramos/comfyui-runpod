#!/usr/bin/env bash
set -e

echo "--- INICIANDO SCRIPT DE INICIALIZAÇÃO ---"

export COMFYUI_DIR="/ComfyUI"
export WORKFLOW_DIR="$COMFYUI_DIR/user/default/workflows"
export CUSTOM_NODES_DIR="$COMFYUI_DIR/custom_nodes"

# Ativa libtcmalloc se disponível
TCMALLOC="$(ldconfig -p | grep -Po "libtcmalloc.so.\d" | head -n 1 || true)"
export LD_PRELOAD="${TCMALLOC}"

# Garante pastas essenciais
mkdir -p "$WORKFLOW_DIR" "$CUSTOM_NODES_DIR"

# Clona script CivitAI
git clone "https://github.com/Hearmeman24/CivitAI_Downloader.git" || true
mv CivitAI_Downloader/download.py /usr/local/bin/ || true
chmod +x /usr/local/bin/download.py
rm -rf CivitAI_Downloader

# Instala custom nodes
declare -a CUSTOM_NODES_REPOS=(
  "https://github.com/Burgstall-labs/ComfyUI-BETA-Helpernodes.git"
  "https://github.com/pythongosssss/ComfyUI-Custom-Scripts.git"
  "https://github.com/lldacing/ComfyUI_PuLID_Flux_ll.git"
  "https://github.com/Kijai/ComfyUI-KJNodes.git"
  "https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git"
  "https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git"
  "https://github.com/Comfy-Org/ComfyUI-Manager.git"
  "https://github.com/tsogzark/ComfyUI-load-image-from-url.git"
  "https://github.com/giriss/comfy-image-saver.git"
  "https://github.com/WASasquatch/was-node-suite-comfyui.git"
  "https://github.com/stavsap/comfyui-kokoro.git"
  "https://github.com/yuvraj108c/ComfyUI-Whisper.git"
  "https://github.com/MixLabPro/comfyui-mixlab-nodes.git"
  "https://github.com/welltop-cn/ComfyUI-TeaCache.git" # Hunyuan
)

cd "$CUSTOM_NODES_DIR"

for repo in "${CUSTOM_NODES_REPOS[@]}"; do
  NAME=$(basename "$repo" .git)
  if [ ! -d "$NAME" ]; then
    git clone "$repo"
    if [ -f "$NAME/requirements.txt" ]; then
      pip install -r "$NAME/requirements.txt" || echo "Erro nos requirements de $NAME"
    fi
    if [ -f "$NAME/install.py" ]; then
      python3 "$NAME/install.py"
    fi
  else
    echo "$NAME já instalado."
  fi
done

# Função para download de modelos
download_model() {
  URL=$1
  DEST=$2
  HEADER=$3
  if [ ! -f "$DEST" ]; then
    echo "Baixando modelo para $DEST"
    wget -c -O "$DEST" --header="$HEADER" "$URL"
  else
    echo "Modelo já existe em $DEST"
  fi
}

# FLUX
if [ "$download_flux" == "true" ]; then
  mkdir -p "$COMFYUI_DIR/models/diffusion_models" "$COMFYUI_DIR/models/vae" "$COMFYUI_DIR/models/text_encoders"
  download_model "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/flux1-dev.safetensors" \
    "$COMFYUI_DIR/models/diffusion_models/flux1-dev.safetensors" \
    "Authorization: Bearer ${hugging_face_token}"
  download_model "https://huggingface.co/black-forest-labs/FLUX.1-schnell/resolve/main/ae.safetensors" \
    "$COMFYUI_DIR/models/vae/ae.safetensors" \
    "Authorization: Bearer ${hugging_face_token}"
  download_model "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors" \
    "$COMFYUI_DIR/models/text_encoders/clip_l.safetensors"
  download_model "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp8_e4m3fn.safetensors" \
    "$COMFYUI_DIR/models/text_encoders/t5xxl_fp8_e4m3fn.safetensors"
fi

# PULID
if [ "$install_pulid" == "true" ]; then
  mkdir -p "$COMFYUI_DIR/models/pulid"
  download_model "https://huggingface.co/guozinan/PuLID/resolve/main/pulid_flux_v0.9.0.safetensors?download=true" \
    "$COMFYUI_DIR/models/pulid/pulid_flux_v0.9.0.safetensors"
  pip install numpy insightface==0.7.3 facexlib onnxruntime-gpu timm onnxruntime
fi

# HUNYUAN
if [ "$download_hunyuan" == "true" ]; then
  mkdir -p "$COMFYUI_DIR/models/diffusion_models" "$COMFYUI_DIR/models/vae" "$COMFYUI_DIR/models/text_encoders"
  download_model "https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_720_cfgdistill_bf16.safetensors" \
    "$COMFYUI_DIR/models/diffusion_models/hunyuan_video_720_cfgdistill_bf16.safetensors"
  download_model "https://huggingface.co/Kijai/HunyuanVideo_comfy/resolve/main/hunyuan_video_vae_fp32.safetensors" \
    "$COMFYUI_DIR/models/vae/hunyuan_video_vae_fp32.safetensors"
  download_model "https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/text_encoders/clip_l.safetensors" \
    "$COMFYUI_DIR/models/text_encoders/clip_l.safetensors"
  download_model "https://huggingface.co/Comfy-Org/HunyuanVideo_repackaged/resolve/main/split_files/text_encoders/llava_llama3_fp8_scaled.safetensors" \
    "$COMFYUI_DIR/models/text_encoders/llava_llama3_fp8_scaled.safetensors"
fi

# Inicia JupyterLab
echo "Iniciando JupyterLab..."
jupyter-lab --ip=0.0.0.0 --port=8888 --allow-root --no-browser \
  --NotebookApp.token='' --NotebookApp.password='' \
  --ServerApp.terminado_settings='{"shell_command":["/bin/bash"]}' \
  --ServerApp.allow_origin='*' \
  --notebook-dir="/ComfyUI" &

# Copia workflows da pasta /workflows para o diretório do ComfyUI
if [ -d "/workflows" ]; then
  echo "Copiando workflows personalizados para $WORKFLOW_DIR..."
  cp -u /workflows/*.json "$WORKFLOW_DIR/" || true
fi

# Inicia ComfyUI
echo "Iniciando ComfyUI..."
cd "$COMFYUI_DIR"
python3 main.py --listen
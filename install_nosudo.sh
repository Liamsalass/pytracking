#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: bash $(basename "$0") <conda_install_path> <environment_name>"
  exit 1
fi

conda_install_path=$1
conda_env_name=$2

# --- conda activation ---
source "$conda_install_path/etc/profile.d/conda.sh"

echo "****************** Creating conda environment ${conda_env_name} (Python 3.10) ******************"
# Create if missing; otherwise just proceed
if ! conda env list | grep -qE "^[^#]*\b${conda_env_name}\b"; then
  conda create -y -n "$conda_env_name" python=3.10 -c conda-forge
fi

echo ""
echo "****************** Activating conda environment ${conda_env_name} ******************"
conda activate "$conda_env_name"

# --- core build/runtime deps (no sudo) ---
# ninja & libjpeg-turbo via conda-forge; jpeg4py can then install cleanly
echo ""
echo "****************** Installing base packages (conda-forge) ******************"
conda install -y -c conda-forge ninja libjpeg-turbo pkg-config cython

# --- PyTorch: choose GPU (CUDA 11.8) if available; else CPU-only ---
echo ""
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "****************** Installing PyTorch (GPU, CUDA 11.8) ******************"
  conda install -y -c pytorch -c nvidia pytorch torchvision pytorch-cuda=11.8
else
  echo "****************** Installing PyTorch (CPU-only) ******************"
  conda install -y -c pytorch pytorch torchvision cpuonly
fi

# --- Python deps ---
echo ""
echo "****************** Installing Python packages (pip/conda) ******************"
conda install -y -c conda-forge matplotlib pandas tqdm scikit-image
pip install visdom tb-nightly tikzplotlib gdown lvis pycocotools

# Prefer jpeg4py via conda-forge (binds to libjpeg-turbo we installed)
conda install -y -c conda-forge jpeg4py || pip install jpeg4py || true

# OpenCV: use pip wheel (no sudo). If you prefer conda, you can: conda install -c conda-forge opencv
pip install opencv-python

# Optional for some trackers:
pip install spatial-correlation-sampler || true

# --- model weights ---
echo ""
echo "****************** Downloading networks ******************"
mkdir -p pytracking/networks
# DiMP50 (official link from their script)
gdown "https://drive.google.com/uc?id=1qgachgqks2UGjKx-GdO1qylBDdB1f9KN" -O pytracking/networks/dimp50.pth

# --- environment files ---
echo ""
echo "****************** Setting up local environment files ******************"
python - <<'PY'
from pytracking.evaluation.environment import create_default_local_file
from ltr.admin.environment import create_default_local_file as create_ltr
create_default_local_file()
create_ltr()
print("Created pytracking & LTR local.py files.")
PY

echo ""
echo "****************** Installation complete (no sudo used)! ******************"
echo "Activate with: conda activate ${conda_env_name}"
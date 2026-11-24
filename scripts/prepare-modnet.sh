#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
# Reuse the Python project's known-working Python 3.11 installation, but install
# conversion dependencies into an isolated environment in this repository.
task_python="${MODNET_PYTHON:-/Users/jialishen/Coding/Python/AutoIDPhotos/.venv/bin/python}"
if [ ! -x .model-tools/bin/python ]; then
    "$task_python" -m venv .model-tools
fi
.model-tools/bin/python -m pip install -r scripts/model-requirements.txt
.model-tools/bin/python scripts/convert_modnet.py "$@"

#!/usr/bin/env bash
set -e

export DOTNET_ROOT="${DOTNET_ROOT:-/home/gigi/.dotnet}"
export PATH="/home/gigi/miniconda3/envs/myenv/bin:/home/gigi/.local/bin:$DOTNET_ROOT:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Avvio Training Headless (Python + Godot) ==="
python main.py &
PYTHON_PID=$!

cleanup() {
    echo "Terminazione processi..."
    kill $PYTHON_PID 2>/dev/null || true
}
trap cleanup EXIT INT TERM

sleep 2

echo "Avvio Godot headless..."
godot --headless --path "$SCRIPT_DIR/godot"

wait $PYTHON_PID

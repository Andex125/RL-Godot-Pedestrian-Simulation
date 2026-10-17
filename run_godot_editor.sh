#!/usr/bin/env bash
set -e

export DOTNET_ROOT="${DOTNET_ROOT:-/home/gigi/.dotnet}"
export PATH="/home/gigi/miniconda3/envs/myenv/bin:/home/gigi/.local/bin:$DOTNET_ROOT:$PATH"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec godot --editor --path "$SCRIPT_DIR/godot"

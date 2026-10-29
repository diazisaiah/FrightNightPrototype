#!/usr/bin/env bash
# Syncs the game into the Playground project and runs it.
#   bash playground/run_playground.sh       play it
#   bash playground/run_playground.sh -e    open it in the Godot editor
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
godot="${GODOT:-/c/Users/IsaiahandLaura/Desktop/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe}"
playground_python="${PLAYGROUND_PYTHON:-python}"
"$playground_python" "$here/sync.py"
"$godot" --headless --path "$here/project" --import > /dev/null 2>&1 || true
"$godot" --path "$here/project" "$@"

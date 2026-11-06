#!/usr/bin/env bash
# Exports the Lab (the phone playground: playground/src/lab) and pushes it to
# the restricted itch page isaiahd0221/fn-mobile-playground.
#   bash release_lab.sh 0.10.1      # sync + export + push to itch
#   bash release_lab.sh --export    # export only (builds/lab)
# release_mobile.sh calls this after a mobile push, so the Lab always matches
# the mobile game. It never touches the game's version or git.
set -euo pipefail
cd "$(dirname "$0")"
godot="${GODOT:-/c/Users/IsaiahandLaura/Desktop/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe}"
arg="${1:?usage: bash release_lab.sh <version, e.g. 0.10.1> | --export}"

python playground/sync.py
# Rebuilds the project's class list (new game scripts) before exporting.
"$godot" --headless --path playground/project --import >/dev/null 2>&1 || true
mkdir -p builds/lab
"$godot" --headless --path playground/project --export-release "Web Lab" ../../builds/lab/index.html
[ -f builds/lab/index.pck ] || { echo "Lab export failed." >&2; exit 1; }
[ "$arg" = "--export" ] && { echo "Exported the Lab to builds/lab."; exit 0; }

butler push builds/lab isaiahd0221/fn-mobile-playground:html5 --userversion "$arg"
echo "Pushed the Lab $arg to itch (fn-mobile-playground)."

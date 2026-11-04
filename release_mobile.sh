#!/usr/bin/env bash
# Exports the "Web Mobile" preset to builds/mobile and pushes it to the
# separate itch page isaiahd0221/fright-night-mobile (create that project on
# itch first: Kind of project = HTML, then upload once via butler).
#   bash release_mobile.sh 0.1.0      # export + push to itch
#   bash release_mobile.sh --export   # export only (test locally / on a phone)
# Unlike release.sh this doesn't touch the project version or tag anything.
set -euo pipefail
cd "$(dirname "$0")"
godot="${GODOT:-/c/Users/IsaiahandLaura/Desktop/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe}"
arg="${1:?usage: bash release_mobile.sh <mobile version, e.g. 0.1.0> | --export}"

mkdir -p builds/mobile
"$godot" --headless --path punch-craft --export-release "Web Mobile" ../builds/mobile/index.html
[ -f builds/mobile/index.pck ] || { echo "Export failed." >&2; exit 1; }
[ "$arg" = "--export" ] && { echo "Exported to builds/mobile."; exit 0; }

butler push builds/mobile isaiahd0221/fright-night-mobile:html5 --userversion "$arg"
echo "Pushed mobile $arg to itch (fright-night-mobile)."

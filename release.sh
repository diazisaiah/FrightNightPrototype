#!/usr/bin/env bash
# Ships a release to itch: sets the version, exports the "Web Release" preset
# (no DEV tag on the title screen) to builds/release, pushes it to itch with
# that version, then commits and tags it on GitHub so it can be rolled back.
#   bash release.sh 0.9.1
# Day-to-day changes don't go to itch: they go to GitHub Pages (deploy_pages.sh).
set -euo pipefail
cd "$(dirname "$0")"
version="${1:?usage: bash release.sh <version, e.g. 0.9.1>}"
godot="${GODOT:-/c/Users/IsaiahandLaura/Desktop/Godot_v4.5.1-stable_win64.exe/Godot_v4.5.1-stable_win64_console.exe}"

if git rev-parse -q --verify "refs/tags/v$version" >/dev/null; then
	echo "v$version is already released - pick a new version." >&2
	exit 1
fi
sed -i "s/^config\/version=.*/config\/version=\"$version\"/" punch-craft/project.godot

mkdir -p builds/release
"$godot" --headless --path punch-craft --export-release "Web Release" ../builds/release/index.html
[ -f builds/release/index.pck ] || { echo "Export failed." >&2; exit 1; }

butler push builds/release isaiahd0221/fright-night:html5 --userversion "$version"

git add -A
git commit -q -m "Release v$version" || true
git tag -a "v$version" -m "Fright Night v$version"
git push -q
git push -q origin "v$version"
echo "Released v$version to itch and tagged it on GitHub."

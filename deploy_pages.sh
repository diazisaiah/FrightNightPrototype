#!/usr/bin/env bash
# Publishes the current web build (builds/web) to the gh-pages branch, which
# GitHub Pages serves at https://diazisaiah.github.io/FrightNightPrototype/.
# Run from the repo root after exporting the Web preset:
#   bash deploy_pages.sh
# Each deploy replaces the branch with a single fresh commit, so the 50 MB
# build doesn't pile up in the repo's history.
set -euo pipefail
cd "$(dirname "$0")"
[ -f builds/web/index.html ] || { echo "No web build in builds/web - export the Web preset first." >&2; exit 1; }

site="$(mktemp -d)"
trap 'rm -rf "$site"' EXIT
cp -r builds/web/. "$site/"
touch "$site/.nojekyll"   # serve files as-is (no Jekyll processing)

source_commit="$(git rev-parse --short HEAD)"
git -C "$site" init -q -b gh-pages
git -C "$site" add -A
git -C "$site" -c user.name="$(git config user.name)" -c user.email="$(git config user.email)" \
	commit -q -m "Web build from $source_commit"
git -C "$site" push -q -f "$(git remote get-url origin)" gh-pages
echo "Deployed builds/web ($source_commit) to gh-pages."

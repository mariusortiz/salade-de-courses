#!/bin/sh
# Exporte le jeu pour le navigateur et le publie sur GitHub Pages (branche gh-pages).
set -e
cd "$(dirname "$0")"

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
DEPOT="$(git remote get-url origin)"

rm -rf export
mkdir export
touch export/.gdignore export/.nojekyll
"$GODOT" --headless --path . --export-release "Web" export/index.html

# La branche gh-pages ne garde qu'un seul commit : la dernière version en ligne.
cd export
git init -q -b gh-pages
git config user.name "$(git -C .. config user.name)"
git config user.email "$(git -C .. config user.email)"
git add -A
git commit -q -m "Mise en ligne"
git push -q -f "$DEPOT" gh-pages
rm -rf .git
echo "En ligne dans une minute ou deux."

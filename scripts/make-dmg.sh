#!/usr/bin/env bash
# Packs an already-built Possum.app into a compressed DMG with the
# drag-to-Applications installer window (background, arrow, icon layout).
# Uses dmgbuild, which writes the Finder layout directly — no Finder scripting,
# so it works headless on CI runners.
#
# Usage: scripts/make-dmg.sh <path/to/Possum.app> <output.dmg>
set -euo pipefail

APP="$1"
DMG="$2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DMGBUILD_VERSION="1.6.5"

venv="$(mktemp -d)/venv"
trap 'rm -rf "$(dirname "$venv")"' EXIT
python3 -m venv "$venv"
"$venv/bin/python" -m pip install --quiet --disable-pip-version-check "dmgbuild==$DMGBUILD_VERSION"

rm -f "$DMG"
"$venv/bin/dmgbuild" -s "$ROOT/Support/dmg-settings.py" -D app="$APP" -D resources="$ROOT/Resources" Possum "$DMG"

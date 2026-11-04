#!/usr/bin/env bash
# Packs an already-built Possum.app into a compressed DMG with an /Applications link.
# Usage: scripts/make-dmg.sh <path/to/Possum.app> <output.dmg>
set -euo pipefail

APP="$1"
DMG="$2"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

ditto "$APP" "$staging/Possum.app"
ln -s /Applications "$staging/Applications"
rm -f "$DMG"
hdiutil create -volname Possum -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$DMG"

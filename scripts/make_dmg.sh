#!/bin/bash
# Packages ProjectorHold.app into dist/ProjectorHold.dmg with a drag-to-Applications link.
# Run build_app.sh (or release.sh) first.
set -euo pipefail

cd "$(dirname "$0")/.."

APP="ProjectorHold.app"
DIST="dist"
DMG="$DIST/ProjectorHold.dmg"

[ -d "$APP" ] || { echo "Missing $APP. Run ./build_app.sh first." >&2; exit 1; }

rm -rf "$DIST"
mkdir -p "$DIST/staging"
cp -R "$APP" "$DIST/staging/"
ln -s /Applications "$DIST/staging/Applications"
hdiutil create -volname "Projector Hold" -srcfolder "$DIST/staging" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$DIST/staging"

echo "$(pwd)/$DMG"

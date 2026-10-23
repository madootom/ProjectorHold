#!/bin/bash
# Builds a Developer ID-signed, notarized ProjectorHold.dmg in dist/, ready to
# attach to a GitHub Release.
#
# One-time setup (needs a paid Apple Developer Program membership):
#   1. In Xcode > Settings > Accounts, or at developer.apple.com, create a
#      "Developer ID Application" certificate and install it in your keychain.
#      Check its name with:  security find-identity -v -p codesigning
#   2. Create an app-specific password at account.apple.com, then store
#      notarization credentials in the keychain:
#        xcrun notarytool store-credentials projectorhold-notary \
#          --apple-id you@example.com --team-id TEAMID
#
# Usage:
#   DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)" VERSION=1.0.0 ./release.sh
set -euo pipefail

cd "$(dirname "$0")"

: "${DEVELOPER_ID:?Set DEVELOPER_ID to your Developer ID Application certificate name}"
NOTARY_PROFILE="${NOTARY_PROFILE:-projectorhold-notary}"
export VERSION="${VERSION:-1.0.0}"

APP="ProjectorHold.app"
DIST="dist"
DMG="$DIST/ProjectorHold-$VERSION.dmg"

./build_app.sh

echo "Signing with $DEVELOPER_ID"
codesign --force --timestamp --options runtime --sign "$DEVELOPER_ID" "$APP"
codesign --verify --strict --verbose=2 "$APP"

echo "Creating $DMG"
rm -rf "$DIST"
mkdir -p "$DIST/staging"
cp -R "$APP" "$DIST/staging/"
ln -s /Applications "$DIST/staging/Applications"
hdiutil create -volname "Projector Hold" -srcfolder "$DIST/staging" -ov -format UDZO "$DMG"
rm -rf "$DIST/staging"
codesign --force --timestamp --sign "$DEVELOPER_ID" "$DMG"

echo "Submitting for notarization (this usually takes a few minutes)"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose "$DMG"

echo "Release ready: $(pwd)/$DMG"

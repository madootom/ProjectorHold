#!/bin/bash
# Builds ProjectorHold and packages it as ProjectorHold.app next to this script.
# Set VERSION to stamp a release version, e.g. VERSION=1.2.0 ./build_app.sh
set -euo pipefail

cd "$(dirname "$0")"

VERSION="${VERSION:-1.0.0}"
BUNDLE_ID="com.melvinardra.ProjectorHold"

swift build -c release
BIN_PATH="$(swift build -c release --show-bin-path)/ProjectorHold"

APP="ProjectorHold.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/ProjectorHold"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>ProjectorHold</string>
    <key>CFBundleDisplayName</key>
    <string>Projector Hold</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key>
    <string>ProjectorHold</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>MIT License</string>
</dict>
</plist>
PLIST

# Ad-hoc signature for local use, with a requirement based on the bundle ID
# rather than the binary's hash, so the Screen Recording permission survives
# rebuilds. release.sh replaces this with a Developer ID signature.
codesign --force --sign - \
    --requirements "=designated => identifier \"${BUNDLE_ID}\"" \
    "$APP"

echo "Built $(pwd)/$APP"

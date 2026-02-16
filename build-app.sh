#!/bin/bash
# Build Peek.app bundle and package as DMG
set -e

APP_NAME="Peek"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
DMG_NAME="$APP_NAME.dmg"
DMG_STAGING="dmg-staging"

# --- Build release binary ---
echo "Building release binary..."
swift build -c release

# --- Create .app bundle ---
echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

cp "$BUILD_DIR/$APP_NAME" "$MACOS/$APP_NAME"
cp "Sources/Peek/Info.plist" "$CONTENTS/Info.plist"
cp "AppIcon.icns" "$RESOURCES/AppIcon.icns"

# --- Code sign ---
echo "Signing app..."
codesign --force --deep --sign "Developer ID Application" "$APP_BUNDLE"

# --- Create DMG ---
echo "Packaging DMG..."
rm -rf "$DMG_STAGING" "$DMG_NAME"
mkdir -p "$DMG_STAGING"

# Copy the app into staging
cp -R "$APP_BUNDLE" "$DMG_STAGING/"

# Add Applications symlink for drag-to-install
ln -s /Applications "$DMG_STAGING/Applications"

# Create the DMG
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

# Clean up staging
rm -rf "$DMG_STAGING"

echo ""
echo "Done! Created $DMG_NAME"
echo "To install: open the DMG and drag Peek to Applications"

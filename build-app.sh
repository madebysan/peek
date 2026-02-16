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
codesign --force --deep --options runtime --sign "Developer ID Application" "$APP_BUNDLE"

# --- Notarize ---
echo "Submitting for notarization..."
ditto -c -k --keepParent "$APP_BUNDLE" "$APP_NAME.zip"
xcrun notarytool submit "$APP_NAME.zip" --keychain-profile "notarytool-profile" --wait
rm "$APP_NAME.zip"

echo "Stapling notarization ticket..."
xcrun stapler staple "$APP_BUNDLE"

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

# Sign and notarize the DMG too
codesign --force --sign "Developer ID Application" "$DMG_NAME"
xcrun notarytool submit "$DMG_NAME" --keychain-profile "notarytool-profile" --wait
xcrun stapler staple "$DMG_NAME"

# Clean up staging
rm -rf "$DMG_STAGING"

echo ""
echo "Done! Created $DMG_NAME (signed + notarized)"

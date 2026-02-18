#!/bin/bash
# Build SSHMan.app — a proper macOS .app bundle
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_DIR="$PROJECT_DIR/build/SSHMan.app"

echo "==> Building SSHMan release binary..."
cd "$PROJECT_DIR"
swift build -c release

echo "==> Assembling SSHMan.app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Copy binary
cp "$PROJECT_DIR/.build/release/SSHMan" "$APP_DIR/Contents/MacOS/SSHMan"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

echo "==> Generating app icon..."
bash "$SCRIPT_DIR/gen-icon.sh"
cp "$PROJECT_DIR/build/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"

echo "==> Code signing (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR"

# Extract version from Info.plist for DMG filename
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_DIR/Contents/Info.plist")
DMG_PATH="$PROJECT_DIR/build/SSHMan-v${VERSION}.dmg"
DMG_RW="$PROJECT_DIR/build/SSHMan-rw.dmg"
DMG_MOUNT="/tmp/sshman-dmg-$$"
echo "==> Creating DMG..."
rm -f "$DMG_PATH" "$DMG_RW"

# Create a writable DMG with unique mount point to avoid collisions
hdiutil create -size 50m -fs HFS+ -volname "SSHMan" "$DMG_RW"
mkdir -p "$DMG_MOUNT"
DEVICE=$(hdiutil attach "$DMG_RW" -mountpoint "$DMG_MOUNT" -nobrowse | head -1 | awk '{print $1}')
cp -R "$APP_DIR" "$DMG_MOUNT/"
ln -s /Applications "$DMG_MOUNT/Applications"

# Style the DMG Finder window with large icons and drag-to-install layout
echo "==> Styling DMG window..."
osascript - "$DMG_MOUNT" <<'APPLESCRIPT' || echo "  (Finder styling skipped — AppleEvent timeout)"
on run argv
    set mountPath to POSIX file (item 1 of argv) as alias
    tell application "Finder"
        tell folder mountPath
            open
            delay 1
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {200, 200, 720, 500}
            set theViewOptions to icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 128
            set position of item "SSHMan.app" of container window to {130, 140}
            set position of item "Applications" of container window to {390, 140}
            delay 1
            close
        end tell
    end tell
end run
APPLESCRIPT

# Detach using device path (reliable, avoids name collisions)
sleep 1
sync
hdiutil detach "$DEVICE" -force
rmdir "$DMG_MOUNT" 2>/dev/null || true

# Wait until fully released
for i in $(seq 1 10); do
    hdiutil info 2>/dev/null | grep -q "$DMG_RW" || break
    sleep 1
done

hdiutil convert "$DMG_RW" -format UDZO -o "$DMG_PATH"
rm -f "$DMG_RW"

echo ""
echo "================================================"
echo "  SSHMan.app built successfully!"
echo ""
echo "  App:  $APP_DIR"
echo "  DMG:  $DMG_PATH"
echo ""
echo "  To install, open the DMG and drag to Applications."
echo "  To launch now:  open $APP_DIR"
echo "================================================"

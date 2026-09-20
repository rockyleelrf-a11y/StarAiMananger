#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

APP_NAME="AI智能体管家"
BUNDLE_DIR="$DIR/build/${APP_NAME}.app"
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Contents/Resources"
CACHE_DIR="$DIR/.swift-cache"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$CACHE_DIR"

# 1. Automated Test Check
if [ "$1" == "check" ]; then
    echo "==> Running automated test check..."
    swiftc -module-cache-path "$CACHE_DIR" \
        Sources/Models/AIAgentApp.swift \
        Sources/Services/AIAgentProber.swift \
        Sources/Services/AIAgentManager.swift \
        run_check.swift \
        -o /tmp/aiagent_check
    /tmp/aiagent_check
    rm -f /tmp/aiagent_check
    echo "==> Test check passed!"
    exit 0
fi

# 2. Generate AppIcon.icns from logo.png if needed
if [ -f "$DIR/logo.png" ]; then
    if [ ! -f "$DIR/Resources/AppIcon.icns" ] || [ "$DIR/logo.png" -nt "$DIR/Resources/AppIcon.icns" ]; then
        echo "==> Generating AppIcon.icns from logo.png..."
        ICONSET="/tmp/AppIcon.iconset"
        rm -rf "$ICONSET"
        mkdir -p "$ICONSET"
        sips -z 16 16     "$DIR/logo.png" --out "$ICONSET/icon_16x16.png" >/dev/null
        sips -z 32 32     "$DIR/logo.png" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
        sips -z 32 32     "$DIR/logo.png" --out "$ICONSET/icon_32x32.png" >/dev/null
        sips -z 64 64     "$DIR/logo.png" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
        sips -z 128 128   "$DIR/logo.png" --out "$ICONSET/icon_128x128.png" >/dev/null
        sips -z 256 256   "$DIR/logo.png" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
        sips -z 256 256   "$DIR/logo.png" --out "$ICONSET/icon_256x256.png" >/dev/null
        sips -z 512 512   "$DIR/logo.png" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
        sips -z 512 512   "$DIR/logo.png" --out "$ICONSET/icon_512x512.png" >/dev/null
        sips -z 1024 1024 "$DIR/logo.png" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
        iconutil -c icns "$ICONSET" -o "$DIR/Resources/AppIcon.icns"
        rm -rf "$ICONSET"
        echo "==> AppIcon.icns created successfully."
    fi
fi

# 3. Compile App
echo "==> Compiling ${APP_NAME}..."
swiftc -O -module-cache-path "$CACHE_DIR" \
    Sources/Models/AIAgentApp.swift \
    Sources/Services/AIAgentProber.swift \
    Sources/Services/AIAgentManager.swift \
    Sources/Views/AIAgentViews.swift \
    Sources/AppDelegate.swift \
    Sources/main.swift \
    -o "$MACOS_DIR/AIAgentManager"

# 4. Copy Bundle Resources
echo "==> Copying Info.plist & AppIcon..."
cp "$DIR/Resources/Info.plist" "$BUNDLE_DIR/Contents/Info.plist"
if [ -f "$DIR/Resources/AppIcon.icns" ]; then
    cp "$DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
if [ -f "$DIR/logo.png" ]; then
    cp "$DIR/logo.png" "$RESOURCES_DIR/logo.png"
fi
chmod +x "$MACOS_DIR/AIAgentManager"
touch "$BUNDLE_DIR"

echo "==> Build finished successfully: $BUNDLE_DIR"

# 5. Handle DMG Packaging
if [ "$1" == "dmg" ]; then
    echo "==> Packaging installable DMG with drag-to-Applications shortcut..."
    DMG_DIR="$DIR/build"
    DMG_NAME="${APP_NAME}.dmg"
    FINAL_DMG="$DMG_DIR/$DMG_NAME"
    STAGING="/tmp/${APP_NAME}_dmg_staging"
    RW_DMG="/tmp/${APP_NAME}_rw.dmg"

    rm -rf "$STAGING" "$RW_DMG" "$FINAL_DMG"
    mkdir -p "$STAGING/.background"

    # Copy App and create Applications symlink
    cp -R "$BUNDLE_DIR" "$STAGING/"
    ln -s /Applications "$STAGING/Applications"

    # Copy background
    if [ -f "$DIR/Resources/dmg_background.tiff" ]; then
        cp "$DIR/Resources/dmg_background.tiff" "$STAGING/.background/dmg_background.tiff"
    fi
    if [ -f "$DIR/Resources/dmg_background.png" ]; then
        cp "$DIR/Resources/dmg_background.png" "$STAGING/.background/dmg_background.png"
    fi

    # Create temporary read-write DMG
    hdiutil create -srcfolder "$STAGING" -volname "${APP_NAME}" -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -size 300m "$RW_DMG" >/dev/null

    # Mount temporary DMG
    MOUNT_POINT=$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | grep "/Volumes/${APP_NAME}" | awk -F '\t' '{print $NF}')
    if [ -z "$MOUNT_POINT" ]; then
        MOUNT_POINT="/Volumes/${APP_NAME}"
    fi

    # Set Volume Icon
    if [ -f "$DIR/Resources/AppIcon.icns" ]; then
        cp "$DIR/Resources/AppIcon.icns" "$MOUNT_POINT/.VolumeIcon.icns"
        SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns" 2>/dev/null || true
        SetFile -a C "$MOUNT_POINT" 2>/dev/null || true
    fi

    # Configure Finder window layout
    osascript << APPLESCRIPT
tell application "Finder"
    tell disk "${APP_NAME}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {300, 150, 940, 550}
        set viewOptions to the icon view options of container window
        set icon size of viewOptions to 96
        set arrangement of viewOptions to not arranged
        if exists file ".background:dmg_background.png" then
            set background picture of viewOptions to file ".background:dmg_background.png"
        else if exists file ".background:dmg_background.tiff" then
            set background picture of viewOptions to file ".background:dmg_background.tiff"
        end if
        set position of item "${APP_NAME}.app" of container window to {160, 175}
        set position of item "Applications" of container window to {480, 175}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT

    # Sync and detach
    sync
    hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1 || (sleep 2 && hdiutil detach "$MOUNT_POINT" -force >/dev/null 2>&1)

    # Convert to compressed read-only DMG
    echo "==> Compressing final DMG..."
    hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null

    rm -rf "$STAGING" "$RW_DMG"
    echo "==> DMG successfully created: $FINAL_DMG ($(du -h "$FINAL_DMG" | cut -f1))"
    exit 0
fi

# 6. Launch App if requested
if [ "$1" == "run" ]; then
    echo "==> Launching ${APP_NAME} in menu bar..."
    open "$BUNDLE_DIR"
fi

#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

ACTION="${1:-sim}"
BUILD_DIR="$DIR/build"
APP_NAME="StarButlerCompanion"
BUNDLE_IDENTIFIER="com.rockylee.StarButlerCompanion"
VERSION="1.0.0"

SOURCES=(
    "StarButlerCompanion/Sources/Models/CompanionAgent.swift"
    "StarButlerCompanion/Sources/Services/CompanionClient.swift"
    "StarButlerCompanion/Sources/Views/CompanionAgentCard.swift"
    "StarButlerCompanion/Sources/Views/CompanionConnectionSheet.swift"
    "StarButlerCompanion/Sources/Views/CompanionDashboardView.swift"
    "StarButlerCompanion/Sources/StarButlerCompanionApp.swift"
)

mkdir -p "$BUILD_DIR"

generate_app_bundle() {
    local DEST_SDK="$1"      # iphonesimulator or iphoneos
    local TARGET_TRIPLE="$2" # arm64-apple-ios16.0-simulator or arm64-apple-ios16.0
    local OUT_DIR="$BUILD_DIR/${APP_NAME}_${DEST_SDK}.app"
    
    echo "==> Building ${APP_NAME} for ${DEST_SDK} (${TARGET_TRIPLE})..."
    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"
    
    local SDK_PATH
    SDK_PATH=$(xcrun --sdk "$DEST_SDK" --show-sdk-path)
    
    # 1. Compile Swift sources
    swiftc -O \
        -target "$TARGET_TRIPLE" \
        -sdk "$SDK_PATH" \
        -module-cache-path "$DIR/.swift-cache" \
        -emit-executable \
        "${SOURCES[@]}" \
        -o "$OUT_DIR/${APP_NAME}"
        
    # 2. Generate Info.plist
    cat <<EOF > "$OUT_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>StarButler</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_IDENTIFIER}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>StarButler</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSRequiresIPhoneOS</key>
    <true/>
    <key>UIDeviceFamily</key>
    <array>
        <integer>1</integer>
        <integer>2</integer>
    </array>
    <key>UILaunchScreen</key>
    <dict/>
    <key>UIRequiredDeviceCapabilities</key>
    <array>
        <string>arm64</string>
    </array>
    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>UISupportedInterfaceOrientations~ipad</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationPortraitUpsideDown</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>
    <key>NSLocalNetworkUsageDescription</key>
    <string>StarButler 需要访问本地局域网，以自动发现并实时同步监控 Mac 主机上的 AI 智能体状态与 Token 消耗。</string>
    <key>NSBonjourServices</key>
    <array>
        <string>_starbutler._tcp</string>
    </array>
</dict>
</plist>
EOF

    # 3. Generate App Icons from logo.png
    if [ -f "$DIR/logo.png" ]; then
        sips -z 120 120   "$DIR/logo.png" --out "$OUT_DIR/AppIcon60x60@2x.png" >/dev/null 2>&1 || true
        sips -z 180 180   "$DIR/logo.png" --out "$OUT_DIR/AppIcon60x60@3x.png" >/dev/null 2>&1 || true
        sips -z 152 152   "$DIR/logo.png" --out "$OUT_DIR/AppIcon76x76@2x~ipad.png" >/dev/null 2>&1 || true
        sips -z 167 167   "$DIR/logo.png" --out "$OUT_DIR/AppIcon83.5x83.5@2x~ipad.png" >/dev/null 2>&1 || true
        sips -z 1024 1024 "$DIR/logo.png" --out "$OUT_DIR/AppIcon512@2x.png" >/dev/null 2>&1 || true
    fi

    # 4. Ad-hoc sign for simulator or developer sign for device
    if [ "$DEST_SDK" == "iphonesimulator" ]; then
        codesign --force --sign - --timestamp=none "$OUT_DIR"
    else
        # Find developer signing identity
        local SIGN_ID
        SIGN_ID=$(security find-identity -p codesigning -v | grep -o 'Apple Development: [^"]*' | head -n 1 || true)
        if [ -n "$SIGN_ID" ]; then
            echo "==> Signing with $SIGN_ID..."
            codesign --force --sign "$SIGN_ID" --timestamp=none "$OUT_DIR"
        else
            echo "==> Performing ad-hoc codesign..."
            codesign --force --sign - --timestamp=none "$OUT_DIR"
        fi
    fi
    
    echo "==> Successfully created: $OUT_DIR"
}

if [ "$ACTION" == "sim" ] || [ "$ACTION" == "run-sim" ]; then
    generate_app_bundle "iphonesimulator" "arm64-apple-ios16.0-simulator"
    
    if [ "$ACTION" == "run-sim" ]; then
        echo "==> Booting iOS Simulator and launching StarButler..."
        SIM_ID=$(xcrun simctl list devices | grep -E "iPhone 15 \(" | grep -o '[A-F0-9-]\{36\}' | head -n 1)
        if [ -z "$SIM_ID" ]; then
            SIM_ID="booted"
        fi
        
        xcrun simctl boot "$SIM_ID" 2>/dev/null || true
        open -a Simulator
        echo "==> Installing to Simulator ($SIM_ID)..."
        xcrun simctl install "$SIM_ID" "$BUILD_DIR/${APP_NAME}_iphonesimulator.app"
        echo "==> Launching StarButler Companion on Simulator..."
        xcrun simctl launch "$SIM_ID" "$BUNDLE_IDENTIFIER"
        echo "==> Done! StarButler Companion is now running in the iOS Simulator."
    fi
elif [ "$ACTION" == "device" ]; then
    generate_app_bundle "iphoneos" "arm64-apple-ios16.0"
    
    # Check if a physical device is connected
    echo "==> Checking for connected iOS devices..."
    DEVICES=$(xcrun devicectl list devices 2>&1 || true)
    echo "$DEVICES"
fi

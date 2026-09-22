#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "=================================================="
echo "    StarButler Companion - iOS 真机一键安装部署"
echo "=================================================="

# 1. 检查物理设备是否连接
echo "==> 正在检测已连接的 iOS 设备..."
DEVICE_INFO=$(ios-deploy -c 2>&1 || true)

if ! echo "$DEVICE_INFO" | grep -q "Found"; then
    echo "⚠️  未检测到已连接的 iPhone / iPad 设备！"
    echo "请用数据线连接 iPhone 至这台 Mac，并在手机弹窗中点击【信任此电脑】。"
    exit 0
fi

echo "$DEVICE_INFO"

# 2. 编译真机版
echo "==> 正在编译真机版应用..."
./build_companion.sh device

# 3. 注入最新的 Xcode 描述文件与证书签名
LATEST_PROVISION=$(ls -t ~/Library/MobileDevice/Provisioning\ Profiles/*.mobileprovision 2>/dev/null | head -n 1 || true)
if [ -n "$LATEST_PROVISION" ]; then
    echo "==> 注入开发者描述文件: $LATEST_PROVISION"
    cp "$LATEST_PROVISION" "build/StarButlerCompanion_iphoneos.app/embedded.mobileprovision"
    
    python3 -c '
import plistlib, subprocess, sys
prof_path = sys.argv[1]
raw = subprocess.check_output(["security", "cms", "-D", "-i", prof_path])
data = plistlib.loads(raw)
with open("/tmp/entitlements.plist", "wb") as f:
    plistlib.dump(data["Entitlements"], f)
' "$LATEST_PROVISION"

    codesign --force --sign "Apple Development: dongls3000@qq.com (27U66JUTXQ)" \
        --entitlements /tmp/entitlements.plist \
        --timestamp=none \
        "build/StarButlerCompanion_iphoneos.app"
fi

# 4. 使用 ios-deploy 推送安装（绕过 Xcode DDI 限制）
echo "==> 正在通过 USB 向手机安装 StarButler Companion..."
ios-deploy -b "build/StarButlerCompanion_iphoneos.app" -W -n

echo ""
echo "🎉 安装完成！StarButler Companion 已经出现在你的 iPhone 桌面上！"

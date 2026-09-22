#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

echo "=================================================="
echo "    StarButler Companion - iOS 真机一键安装部署"
echo "=================================================="

# 1. 检查物理设备是否连接
echo "==> 正在检测已连接的 iOS 设备..."
DEVICE_INFO=$(xcrun devicectl list devices 2>&1 || true)

if echo "$DEVICE_INFO" | grep -q "No devices found"; then
    echo "⚠️  未检测到已连接的 iPhone / iPad 设备！"
    echo ""
    echo "请按以下 2 步准备你的 iPhone："
    echo "  1. 【开启开发者模式】（iOS 16+ 必选）："
    echo "     在 iPhone 上进入【设置】->【隐私与安全性】-> 滑到最底部【开发者模式】-> 开启并按提示重启手机。"
    echo "  2. 【连线并信任电脑】："
    echo "     用数据线将 iPhone 连接至这台 Mac，在手机弹窗中点击【信任此电脑】并输入锁屏密码。"
    echo ""
    echo "连接完成后，再次运行本脚本即可自动推送到手机："
    echo "  $ ./deploy_to_iphone.sh"
    echo ""
    echo "💡 提示：你也可以使用以下方式安装："
    echo "  - 方式 A：打开 Xcode 直接运行：open StarButlerCompanion/Package.swift"
    echo "  - 方式 B：用 爱思助手 / Apple Configurator 拖入现成安装包: build/StarButlerCompanion.ipa"
    exit 0
fi

echo "$DEVICE_INFO"

# 2. 如果存在已连接设备，提取设备 ID 并推送安装
DEVICE_ID=$(echo "$DEVICE_INFO" | grep -E "iPhone|iPad" | awk '{print $1}' | head -n 1)

if [ -z "$DEVICE_ID" ]; then
    DEVICE_ID=$(xcrun xctrace list devices 2>&1 | grep -A 10 "== Devices ==" | grep -E "iPhone|iPad" | grep -o '([A-F0-9-]\{36\})' | tr -d '()' | head -n 1)
fi

echo "==> 检测到目标设备: $DEVICE_ID"
echo "==> 正在编译并打包真机版应用..."
./build_companion.sh device

echo "==> 正在向手机推送安装 StarButler Companion..."
xcrun devicectl device install app --device "$DEVICE_ID" "$DIR/build/StarButlerCompanion_iphoneos.app"

echo ""
echo "🎉 成功推送到手机！"
echo "初次打开时提示："
echo "  1. 若提示“不受信任的开发者”：在 iPhone 进入【设置】->【通用】->【VPN与设备管理】点击开发者信任。"
echo "  2. 打开 App 后提示“本地网络权限”请点击【允许】，即可自动秒连 Mac 主机！"

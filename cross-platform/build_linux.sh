#!/bin/bash
# Build script for Linux AppImage
# Run on a Linux machine or in a Linux Docker container
# Deps: pip install pyinstaller pystray pillow psutil

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Installing Python deps..."
pip install --quiet pyinstaller pystray pillow psutil

echo "==> Building Linux binary with PyInstaller..."
pyinstaller \
  --onefile \
  --noconsole \
  --name "StarAiManager" \
  --add-data "../logo.png:." \
  main_linux.py

echo "==> Binary at: dist/StarAiManager"

# Optional: wrap into AppImage if appimagetool is available
if command -v appimagetool &>/dev/null; then
  mkdir -p AppDir/usr/bin
  cp dist/StarAiManager AppDir/usr/bin/

  cat > AppDir/StarAiManager.desktop <<EOF
[Desktop Entry]
Name=StarAI Manager
Exec=StarAiManager
Icon=StarAiManager
Type=Application
Categories=Utility;
EOF

  cp ../logo.png AppDir/StarAiManager.png

  ARCH=x86_64 appimagetool AppDir StarAiManager-linux-x86_64.AppImage
  echo "==> AppImage: StarAiManager-linux-x86_64.AppImage"
else
  echo "[INFO] appimagetool not found — distributing the binary in dist/StarAiManager directly"
fi

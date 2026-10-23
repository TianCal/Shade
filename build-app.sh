#!/bin/zsh
# 编译 release 版本并打包成 Shade.app（菜单栏应用，没有 Dock 图标）
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=build/Shade.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Shade "$APP/Contents/MacOS/Shade"
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Shade</string>
    <key>CFBundleIdentifier</key><string>com.github.tiancal.shade</string>
    <key>CFBundleExecutable</key><string>Shade</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
</dict>
</plist>
PLIST
codesign --force --sign - "$APP" >/dev/null
echo "已生成 $APP"

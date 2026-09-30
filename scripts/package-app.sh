#!/bin/bash
#
# package-app.sh — 构建并打包 Peggy Tools 的 macOS 发布产物
#
# 用法: ./scripts/package-app.sh <version>   例: ./scripts/package-app.sh 1.0.0
#
# 产物（输出到 dist/）:
#   PeggyTools-<version>-macOS-universal.zip  — 通用二进制 .app 的 zip
#   PeggyTools-<version>.dmg                  — DMG 安装镜像
#
set -euo pipefail

VERSION="${1:?用法: package-app.sh <version，如 1.0.0>}"
cd "$(dirname "$0")/.."

echo "==> 注入版本号 ${VERSION}"
cat > PeggyTools/App/AppVersion.swift <<EOF
//
//  AppVersion.swift
//  PeggyTools
//
//  Created by Peggy Tools
//

/// 应用版本号的唯一来源。
/// 本地开发时为手写值；正式发版时由 scripts/package-app.sh 按 git tag（vX.Y.Z）重新生成。
enum AppVersion {
    static let current = "${VERSION}"
}
EOF

echo "==> 运行测试"
swift test

echo "==> 构建 universal 二进制 (arm64 + x86_64)"
swift build -c release --arch arm64 --arch x86_64

BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"
BIN="${BIN_DIR}/PeggyTools"
if [ ! -f "$BIN" ]; then
  echo "错误: 未找到构建产物 $BIN" >&2
  exit 1
fi
echo "==> 二进制: $BIN"
lipo -info "$BIN"

echo "==> 组装 PeggyTools.app"
APP="dist/PeggyTools.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/PeggyTools"
chmod +x "$APP/Contents/MacOS/PeggyTools"
sed -e "s/@VERSION@/${VERSION}/g" PeggyTools/Info.plist > "$APP/Contents/Info.plist"

echo "==> Ad-hoc 签名（未使用 Apple Developer 证书）"
codesign --force --sign - "$APP"
codesign --verify "$APP"

echo "==> 生成 zip"
ditto -c -k --keepParent "$APP" "dist/PeggyTools-${VERSION}-macOS-universal.zip"

echo "==> 生成 dmg（应用 + /Applications 快捷方式，拖拽安装）"
STAGING="dist/dmg-staging"
DMG="dist/PeggyTools-${VERSION}.dmg"
TMP_DMG="dist/.PeggyTools-tmp.dmg"
rm -rf "$STAGING" "$DMG" "$TMP_DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

# 先做可写镜像，挂载到 /Volumes 后用 Finder 排好双图标窗口，再压缩为 UDZO；
# 排版属于体验优化，任何失败都回退为普通压缩（不影响出包）
VOL_PATH="/Volumes/Peggy Tools"
if hdiutil create -volname "Peggy Tools" -srcfolder "$STAGING" -fs HFS+ -format UDRW -ov "$TMP_DMG" -quiet \
   && hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen -quiet; then
  sleep 2
  osascript <<'APPLESCRIPT' || true
tell application "Finder"
    tell disk "Peggy Tools"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {200, 120, 760, 440}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set position of item "PeggyTools.app" of container window to {160, 150}
        set position of item "Applications" of container window to {400, 150}
        update without registering applications
        delay 1
        close
    end tell
end tell
APPLESCRIPT
  sleep 1
  rm -rf "$VOL_PATH/.fseventsd"       # 挂载会话产生的系统目录，不打进发行镜像
  hdiutil detach "$VOL_PATH" -quiet -force
  hdiutil convert "$TMP_DMG" -format UDZO -o "$DMG" -quiet
else
  hdiutil detach "$VOL_PATH" -quiet -force 2>/dev/null || true
  hdiutil create -volname "Peggy Tools" -srcfolder "$STAGING" -ov -format UDZO "$DMG" -quiet
fi
rm -rf "$STAGING" "$TMP_DMG"

echo "==> 完成"
ls -lh dist/

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

echo "==> 生成 dmg"
hdiutil create -volname "Peggy Tools ${VERSION}" -srcfolder "$APP" -ov -format UDZO "dist/PeggyTools-${VERSION}.dmg" -quiet

echo "==> 完成"
ls -lh dist/

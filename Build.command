#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
trap 'echo "生成未完成。请保留上方错误信息，回到聊天中反馈。"; read -r -p "按回车关闭…"' ERR
if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "此脚本需要在苹果电脑上运行。"; exit 1
fi
if ! /usr/bin/xcrun --find swiftc >/dev/null 2>&1; then
  echo "首次生成需要 Apple Command Line Tools（免费）。"
  echo "接下来会打开苹果安装窗口。完成安装后，再运行一次本脚本。"
  /usr/bin/xcode-select --install || true
  read -r -p "按回车关闭…"
  exit 0
fi
BUILD_DIR="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/workcheer.XXXXXX")"
APP="$BUILD_DIR/上班鼓励器.app"
mkdir -p "$APP/Contents/MacOS"
echo "正在生成原生 macOS 悬浮工具…"
/usr/bin/xcrun swiftc -swift-version 5 -O -target "$(uname -m)-apple-macosx12.0" -framework AppKit -framework SwiftUI -framework Combine Pay.swift App.swift -o "$APP/Contents/MacOS/WorkCheer"
cp Info.plist "$APP/Contents/Info.plist"
/usr/bin/codesign --force --sign - "$APP"
"$APP/Contents/MacOS/WorkCheer" --self-test
DEST="$PWD/上班鼓励器.app"
if [[ -e "$DEST" ]]; then
  DEST="$PWD/上班鼓励器-$(date +%Y%m%d-%H%M%S).app"
fi
/bin/mv "$APP" "$DEST"
/bin/rmdir "$BUILD_DIR"
echo "已生成：$DEST"
echo "可将它拖入‘应用程序’文件夹。点击菜单栏‘薪’可恢复窗口或退出。"
/usr/bin/open -R "$DEST"
/usr/bin/open "$DEST"

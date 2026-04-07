#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="TutorTable"
LAUNCHER_NAME="TutorTableLauncher"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LAUNCHER_APP_DIR="$RESOURCES_DIR/$LAUNCHER_NAME.app"
LAUNCHER_CONTENTS_DIR="$LAUNCHER_APP_DIR/Contents"
LAUNCHER_MACOS_DIR="$LAUNCHER_CONTENTS_DIR/MacOS"
LAUNCHER_RESOURCES_DIR="$LAUNCHER_CONTENTS_DIR/Resources"
MODULE_CACHE_DIR="$BUILD_DIR/module-cache"
TOOLCHAIN_SHADOW_DIR="$BUILD_DIR/toolchain"
TOOLCHAIN_INCLUDE_DIR="$TOOLCHAIN_SHADOW_DIR/usr/include/swift"
TOOLCHAIN_LIB_DIR="$TOOLCHAIN_SHADOW_DIR/usr/lib"
SWIFT_RESOURCE_DIR="$TOOLCHAIN_LIB_DIR/swift"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$LAUNCHER_MACOS_DIR" "$LAUNCHER_RESOURCES_DIR" "$MODULE_CACHE_DIR" "$TOOLCHAIN_INCLUDE_DIR" "$TOOLCHAIN_LIB_DIR"

export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE_DIR"
export SWIFT_MODULECACHE_PATH="$MODULE_CACHE_DIR"

ln -sfn /Library/Developer/CommandLineTools/usr/lib/swift "$SWIFT_RESOURCE_DIR"
cp /Library/Developer/CommandLineTools/usr/include/swift/bridging "$TOOLCHAIN_INCLUDE_DIR/bridging"
cp /Library/Developer/CommandLineTools/usr/include/swift/module.modulemap "$TOOLCHAIN_INCLUDE_DIR/module.modulemap"

/usr/bin/swiftc \
  -O \
  -emit-executable \
  -target arm64-apple-macosx13.0 \
  -resource-dir "$SWIFT_RESOURCE_DIR" \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -module-name "$APP_NAME" \
  -o "$MACOS_DIR/$APP_NAME" \
  "$ROOT_DIR"/Sources/TutorTable/*.swift \
  -framework AppKit \
  -framework SwiftUI \
  -framework Combine \
  -framework Carbon \
  -framework AVFoundation \
  -framework AudioToolbox \
  -framework UserNotifications

/usr/bin/swiftc \
  -O \
  -emit-executable \
  -target arm64-apple-macosx13.0 \
  -resource-dir "$SWIFT_RESOURCE_DIR" \
  -module-cache-path "$MODULE_CACHE_DIR" \
  -module-name "$LAUNCHER_NAME" \
  -o "$LAUNCHER_MACOS_DIR/$LAUNCHER_NAME" \
  "$ROOT_DIR"/Sources/TutorTableLauncher/*.swift \
  -framework AppKit \
  -framework Carbon

cp "$ROOT_DIR/App/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/App/LauncherInfo.plist" "$LAUNCHER_CONTENTS_DIR/Info.plist"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

echo "Built $APP_DIR"
echo "Open it with:"
echo "open \"$APP_DIR\""

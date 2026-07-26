#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="${USAGE_TOPBAR_APP_OUTPUT:-${TMPDIR:-/private/tmp}/usage-topbar-dev/UsageTopbar.app}"
MACOS="$APP/Contents/MacOS"

mkdir -p "$MACOS" "$APP/Contents/Resources" "$ROOT/assets"
MODULE_CACHE="${TMPDIR:-/private/tmp}/usage-topbar-module-cache"
mkdir -p "$MODULE_CACHE"
CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun swiftc \
  "$ROOT/src/UsageTopbar.swift" \
  -o "$MACOS/UsageTopbar" \
  -target arm64-apple-macos13.0 \
  -module-cache-path "$MODULE_CACHE" \
  -framework AppKit \
  -framework CoreGraphics \
  -framework IOKit \
  -framework Network \
  -framework ScreenCaptureKit \
  -O
cp "$ROOT/app/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/app/PkgInfo" "$APP/Contents/PkgInfo"
cp "$ROOT/assets/UsageTopbar.icns" "$APP/Contents/Resources/UsageTopbar.icns"
if [ -d "$ROOT/assets/liquid-icon/UsageTopbar.icon" ]; then
  ditto "$ROOT/assets/liquid-icon/UsageTopbar.icon" \
    "$APP/Contents/Resources/UsageTopbar.icon"
fi
codesign --force --deep --sign - \
  --identifier "local.alex.usage-topbar" \
  --requirements '=designated => identifier "local.alex.usage-topbar"' \
  "$APP" >/dev/null
[ -f "$ROOT/assets/usage-topbar-preview.png" ]
echo "$APP"

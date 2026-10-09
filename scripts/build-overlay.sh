#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="${USAGE_TOPBAR_APP_OUTPUT:-${TMPDIR:-/private/tmp}/usage-topbar-dev/UsageTopbar.app}"
ARCHS="${USAGE_TOPBAR_ARCHS:-arm64 x86_64}"
MACOS="$APP/Contents/MacOS"
MODULE_CACHE="${TMPDIR:-/private/tmp}/usage-topbar-module-cache"
WORK=$(mktemp -d "${TMPDIR:-/private/tmp}/usage-topbar-build.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir -p "$MACOS" "$APP/Contents/Resources" "$MODULE_CACHE"
set --
for ARCH in $ARCHS; do
  case "$ARCH" in arm64|x86_64) ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 2 ;; esac
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun swiftc \
    "$ROOT/src/UsageTopbar.swift" -o "$WORK/UsageTopbar-$ARCH" \
    -target "$ARCH-apple-macos13.0" -module-cache-path "$MODULE_CACHE" \
    -framework AppKit -framework CoreGraphics -framework IOKit \
    -framework Network -framework ScreenCaptureKit -O
  set -- "$@" "$WORK/UsageTopbar-$ARCH"
done
[ "$#" -gt 0 ] || { echo "No architectures selected" >&2; exit 2; }
xcrun lipo -create "$@" -output "$MACOS/UsageTopbar"
cp "$ROOT/app/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/app/PkgInfo" "$APP/Contents/PkgInfo"
cp "$ROOT/assets/UsageTopbar.icns" "$APP/Contents/Resources/UsageTopbar.icns"
if [ -d "$ROOT/assets/liquid-icon/UsageTopbar.icon" ]; then
  ditto "$ROOT/assets/liquid-icon/UsageTopbar.icon" "$APP/Contents/Resources/UsageTopbar.icon"
fi
codesign --force --deep --sign - --identifier "local.alex.usage-topbar" \
  --requirements '=designated => identifier "local.alex.usage-topbar"' "$APP" >/dev/null
codesign --verify --deep --strict "$APP"
echo "$APP"

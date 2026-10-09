#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="${USAGE_TOPBAR_APP_OUTPUT:-${TMPDIR:-/private/tmp}/usage-topbar-dev/UsageTopbar.app}"
ARCHS="${USAGE_TOPBAR_ARCHS:-arm64}"
MACOS="$APP/Contents/MacOS"
MODULE_CACHE="${TMPDIR:-/private/tmp}/usage-topbar-module-cache"
WORK=$(mktemp -d "${TMPDIR:-/private/tmp}/usage-topbar-build.XXXXXX")
trap 'rm -rf "$WORK"' EXIT HUP INT TERM
mkdir -p "$MACOS" "$APP/Contents/Resources" "$MODULE_CACHE"
SPARKLE=$("$ROOT/scripts/fetch-sparkle.sh")
cp "$ROOT/src/UsageTopbar.swift" "$WORK/main.swift"
set --
for ARCH in $ARCHS; do
  case "$ARCH" in arm64) ;; *) echo "Unsupported architecture: $ARCH" >&2; exit 2 ;; esac
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun swiftc \
    "$WORK/main.swift" "$ROOT/src/AppUpdater.swift" "$ROOT/src/OverlayPreferences.swift" -F "$SPARKLE" -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks -o "$WORK/UsageTopbar-$ARCH" \
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
# Only public verification material may enter this bundle. Missing key leaves the
# menu fail-closed; release builds must opt into the strict configuration gate.
python3 "$ROOT/scripts/configure-updater.py" "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$SPARKLE/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
# Sign inside out. These are ad-hoc development signatures, NOT Developer ID.
for CHILD in "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc" "$FRAMEWORK/Versions/B/Autoupdate" "$FRAMEWORK/Versions/B/Updater.app"; do
  codesign --force --sign - "$CHILD"
done
codesign --force --sign - "$FRAMEWORK"
codesign --force --sign - --identifier "local.alex.usage-topbar" \
  --requirements '=designated => identifier "local.alex.usage-topbar"' "$APP" >/dev/null
codesign --verify --deep --strict "$APP"
echo "$APP"

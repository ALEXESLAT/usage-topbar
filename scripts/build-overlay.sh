#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHANNEL="${USAGE_TOPBAR_CHANNEL:-testing}"
case "$CHANNEL" in
  testing) APP_NAME="UsageTopbar Testing.app"; EXEC_NAME="UsageTopbarTest"; BUNDLE_ID="local.alex.usage-topbar.testing"; SWIFT_VARIANT="-DUSAGE_TOPBAR_TESTING" ;;
  release) APP_NAME="UsageTopbar.app"; EXEC_NAME="UsageTopbar"; BUNDLE_ID="local.alex.usage-topbar"; SWIFT_VARIANT="" ;;
  *) echo "Unknown build channel: $CHANNEL" >&2; exit 2 ;;
esac
APP="${USAGE_TOPBAR_APP_OUTPUT:-${TMPDIR:-/private/tmp}/usage-topbar-$CHANNEL/$APP_NAME}"
[ "$(basename "$APP")" = "$APP_NAME" ] || { echo "Channel requires app name: $APP_NAME" >&2; exit 2; }
case "$APP" in /Applications/*|"$HOME"/Applications/*) echo "Build into a staging folder, never an installed application." >&2; exit 2 ;; esac
[ ! -e "$APP" ] || { echo "Output already exists; choose a fresh staging directory." >&2; exit 2; }
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
  CLANG_MODULE_CACHE_PATH="$MODULE_CACHE" xcrun swiftc $SWIFT_VARIANT \
    "$WORK/main.swift" "$ROOT/src/AppUpdater.swift" "$ROOT/src/OverlayPreferences.swift" "$ROOT/src/ProgressGradient.swift" "$ROOT/src/GradientEditor.swift" "$ROOT/src/QuotaHistory.swift" "$ROOT/src/HistoryChart.swift" -F "$SPARKLE" -framework Sparkle \
    -Xlinker -rpath -Xlinker @executable_path/../Frameworks -o "$WORK/UsageTopbar-$ARCH" \
    -target "$ARCH-apple-macos13.0" -module-cache-path "$MODULE_CACHE" \
    -framework AppKit -framework CoreGraphics -framework IOKit \
    -framework Network -framework ScreenCaptureKit -O
  set -- "$@" "$WORK/UsageTopbar-$ARCH"
done
[ "$#" -gt 0 ] || { echo "No architectures selected" >&2; exit 2; }
xcrun lipo -create "$@" -output "$MACOS/$EXEC_NAME"
cp "$ROOT/app/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/app/PkgInfo" "$APP/Contents/PkgInfo"
cp "$ROOT/assets/UsageTopbar.icns" "$APP/Contents/Resources/UsageTopbar.icns"
if [ -d "$ROOT/assets/liquid-icon/UsageTopbar.icon" ]; then
  ditto "$ROOT/assets/liquid-icon/UsageTopbar.icon" "$APP/Contents/Resources/UsageTopbar.icon"
fi
# Only public verification material may enter this bundle. Missing key leaves the
# menu fail-closed; release builds must opt into the strict configuration gate.
if [ "$CHANNEL" = release ]; then
  /usr/libexec/PlistBuddy -c 'Set :UsageTopbarHistorySource real' "$APP/Contents/Info.plist"
  python3 "$ROOT/scripts/configure-updater.py" "$APP/Contents/Info.plist"
else
  python3 - "$APP/Contents/Info.plist" <<'PLIST'
import plistlib, sys
from pathlib import Path
p=Path(sys.argv[1]); info=plistlib.loads(p.read_bytes())
for key in list(info):
    if key.startswith('SU'): del info[key]
info.update(CFBundleName='UsageTopbar Testing', CFBundleDisplayName='Usage Topbar 测试版',
            CFBundleExecutable='UsageTopbarTest', CFBundleIdentifier='local.alex.usage-topbar.testing',
            UsageTopbarChannel='testing', UsageTopbarHistorySource='simulation-switchable')
p.write_bytes(plistlib.dumps(info, sort_keys=False))
PLIST
fi
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp "$SPARKLE/LICENSE" "$APP/Contents/Resources/Sparkle-LICENSE.txt"
FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework"
# Sign inside out. These are ad-hoc development signatures, NOT Developer ID.
for CHILD in "$FRAMEWORK/Versions/B/XPCServices/Downloader.xpc" "$FRAMEWORK/Versions/B/XPCServices/Installer.xpc" "$FRAMEWORK/Versions/B/Autoupdate" "$FRAMEWORK/Versions/B/Updater.app"; do
  codesign --force --sign - "$CHILD"
done
codesign --force --sign - "$FRAMEWORK"
codesign --force --sign - --identifier "$BUNDLE_ID" \
  --requirements "=designated => identifier \"$BUNDLE_ID\"" "$APP" >/dev/null
codesign --verify --deep --strict "$APP"
echo "$APP"

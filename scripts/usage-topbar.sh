#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
APP="/Applications/UsageTopbar.app"
EXEC="$APP/Contents/MacOS/UsageTopbar"
BUILD_APP="${TMPDIR:-/private/tmp}/usage-topbar-dev/UsageTopbar.app"

case "${1:-status}" in
  start)
    [ -x "$EXEC" ] || {
      echo "UsageTopbar is not installed at $APP" >&2
      exit 1
    }
    open "$APP"
    ;;
  demo)
    [ -x "$EXEC" ] || {
      echo "UsageTopbar is not installed at $APP" >&2
      exit 1
    }
    open -n "$APP" --args --mock
    ;;
  stop)
    pkill -x UsageTopbar 2>/dev/null || true
    ;;
  status)
    if pgrep -x UsageTopbar >/dev/null 2>&1; then
      echo "running"
    else
      echo "stopped"
    fi
    ;;
  build)
    mkdir -p "$(dirname "$BUILD_APP")"
    USAGE_TOPBAR_APP_OUTPUT="$BUILD_APP" "$ROOT/scripts/build-overlay.sh"
    ;;
  preview)
    echo "$ROOT/assets/usage-topbar-preview.png"
    ;;
  *)
    echo "usage: $0 {start|demo|stop|status|build|preview}" >&2
    exit 2
    ;;
esac

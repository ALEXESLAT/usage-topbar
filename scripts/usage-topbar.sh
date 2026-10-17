#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CHANNEL="${USAGE_TOPBAR_CHANNEL:-testing}"
case "$CHANNEL" in
  testing) APP_NAME="UsageTopbar Testing.app"; EXEC_NAME="UsageTopbarTest" ;;
  release) APP_NAME="UsageTopbar.app"; EXEC_NAME="UsageTopbar" ;;
  *) echo "Unknown build channel: $CHANNEL" >&2; exit 2 ;;
esac
APP="/Applications/$APP_NAME"
EXEC="$APP/Contents/MacOS/$EXEC_NAME"

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
    pkill -x "$EXEC_NAME" 2>/dev/null || true
    ;;
  status)
    if STATUS_OUTPUT=$(pgrep -x "$EXEC_NAME" 2>&1); then
      echo "running"
    else
      STATUS_CODE=$?
      if [ "$STATUS_CODE" -eq 1 ]; then
        echo "stopped"
      else
        echo "unknown: $STATUS_OUTPUT" >&2
        exit "$STATUS_CODE"
      fi
    fi
    ;;
  build)
    BUILD_ROOT=$(mktemp -d "${TMPDIR:-/private/tmp}/usage-topbar-$CHANNEL.XXXXXX")
    USAGE_TOPBAR_CHANNEL="$CHANNEL" USAGE_TOPBAR_APP_OUTPUT="$BUILD_ROOT/$APP_NAME" "$ROOT/scripts/build-overlay.sh"
    ;;
  preview)
    echo "$ROOT/assets/usage-topbar-preview.png"
    ;;
  *)
    echo "usage: $0 {start|demo|stop|status|build|preview}" >&2
    exit 2
    ;;
esac

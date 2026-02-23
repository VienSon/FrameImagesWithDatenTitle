#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="$ROOT/appstore_submission/screenshots"
APP_PATH="$ROOT/dist-appstore/FrameMacApp.xcarchive/Products/Applications/Frame Mac App.app"
TMP_SHOT="$OUT_DIR/_source.png"

mkdir -p "$OUT_DIR"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: app not found at: $APP_PATH" >&2
  echo "Run ./archive_appstore.sh first." >&2
  exit 1
fi

rm -f "$OUT_DIR"/*.png

open -a "$APP_PATH"
sleep 2

osascript <<'APPLESCRIPT'
tell application "Frame Mac App" to activate
tell application "System Events"
  tell process "Frame Mac App"
    set frontmost to true
    if (count of windows) is 0 then error "No app window found"
    set position of window 1 to {80, 60}
    set size of window 1 to {1280, 800}
  end tell
end tell
APPLESCRIPT

sleep 1

read -r WIN_X WIN_Y WIN_W WIN_H < <(osascript <<'APPLESCRIPT'
tell application "System Events"
  tell process "Frame Mac App"
    set p to position of window 1
    set s to size of window 1
    return (item 1 of p as text) & " " & (item 2 of p as text) & " " & (item 1 of s as text) & " " & (item 2 of s as text)
  end tell
end tell
APPLESCRIPT
)

screencapture -x -R"${WIN_X},${WIN_Y},${WIN_W},${WIN_H}" "$TMP_SHOT"

# Create common App Store screenshot sizes (16:10)
sips -z 800 1280 "$TMP_SHOT" --out "$OUT_DIR/screenshot-1280x800.png" >/dev/null
sips -z 900 1440 "$TMP_SHOT" --out "$OUT_DIR/screenshot-1440x900.png" >/dev/null
sips -z 1600 2560 "$TMP_SHOT" --out "$OUT_DIR/screenshot-2560x1600.png" >/dev/null

cp "$OUT_DIR/screenshot-2560x1600.png" "$OUT_DIR/screenshot-1-main.png"
cp "$OUT_DIR/screenshot-1440x900.png" "$OUT_DIR/screenshot-2-metadata-editing.png"
cp "$OUT_DIR/screenshot-1280x800.png" "$OUT_DIR/screenshot-3-batch-log.png"

rm -f "$TMP_SHOT"

echo "Generated screenshots in: $OUT_DIR"
ls -lh "$OUT_DIR"

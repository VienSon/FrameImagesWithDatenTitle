#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_NAME="Frame Mac App"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/Frame-Mac-App.dmg"
VOL_NAME="Frame Mac App Installer"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: app bundle not found. Build first: $APP_PATH" >&2
  exit 1
fi

rm -f "$DMG_PATH"

TMP_DMG="$DIST_DIR/Frame-Mac-App-tmp.dmg"
rm -f "$TMP_DMG"

echo "Creating DMG..."
hdiutil create \
  -srcfolder "$APP_PATH" \
  -volname "$VOL_NAME" \
  -fs HFS+ \
  -format UDZO \
  "$TMP_DMG" >/dev/null

mv "$TMP_DMG" "$DMG_PATH"
echo "Done: $DMG_PATH"

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/Frame Mac App.app"
DMG_PATH="$DIST_DIR/Frame-Mac-App.dmg"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: app bundle not found: $APP_PATH" >&2
  exit 1
fi

echo "Codesign verify..."
codesign --verify --deep --strict "$APP_PATH"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed -n '1,40p'

echo "Gatekeeper assessment..."
spctl -a -vv "$APP_PATH"

if [[ -f "$DMG_PATH" ]]; then
  echo "DMG Gatekeeper assessment..."
  spctl -a -vv "$DMG_PATH"
fi

echo "Verification complete."

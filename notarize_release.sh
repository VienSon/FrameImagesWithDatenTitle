#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_PATH="$DIST_DIR/Frame Mac App.app"
DMG_PATH="$DIST_DIR/Frame-Mac-App.dmg"

PROFILE_NAME="${NOTARY_PROFILE:-}"

if [[ -z "$PROFILE_NAME" ]]; then
  echo "Error: set NOTARY_PROFILE to a notarytool keychain profile name." >&2
  echo "Example: export NOTARY_PROFILE=AC_NOTARY" >&2
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "Error: app bundle not found: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Error: DMG not found: $DMG_PATH" >&2
  exit 1
fi

echo "Submitting app for notarization..."
xcrun notarytool submit "$APP_PATH" \
  --keychain-profile "$PROFILE_NAME" \
  --wait

echo "Stapling app..."
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "Submitting DMG for notarization..."
xcrun notarytool submit "$DMG_PATH" \
  --keychain-profile "$PROFILE_NAME" \
  --wait

echo "Stapling DMG..."
xcrun stapler staple "$DMG_PATH"
xcrun stapler validate "$DMG_PATH"

echo "Notarization complete."

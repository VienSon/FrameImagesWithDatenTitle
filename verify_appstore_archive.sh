#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./verify_appstore_archive.sh
#   ./verify_appstore_archive.sh "/path/to/MyApp.xcarchive"

ARCHIVE_PATH="${1:-}"
if [[ -z "${ARCHIVE_PATH}" ]]; then
  ARCHIVE_PATH="$(find "$HOME/Library/Developer/Xcode/Archives" -name "*.xcarchive" -type d -print0 \
    | xargs -0 ls -td 2>/dev/null | head -n 1)"
fi

if [[ -z "${ARCHIVE_PATH}" || ! -d "${ARCHIVE_PATH}" ]]; then
  echo "ERROR: No .xcarchive found."
  exit 1
fi

APP_PATH="$(find "${ARCHIVE_PATH}/Products/Applications" -maxdepth 1 -name "*.app" -type d | head -n 1)"
if [[ -z "${APP_PATH}" || ! -d "${APP_PATH}" ]]; then
  echo "ERROR: No .app found inside archive: ${ARCHIVE_PATH}"
  exit 1
fi

ICON_PATH="${APP_PATH}/Contents/Resources/AppIcon.icns"
if [[ ! -f "${ICON_PATH}" ]]; then
  echo "ERROR: Missing AppIcon.icns at: ${ICON_PATH}"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "${TMP_DIR}"; }
trap cleanup EXIT

iconutil -c iconset "${ICON_PATH}" -o "${TMP_DIR}/iconset.iconset"
ICON_1024="${TMP_DIR}/iconset.iconset/icon_512x512@2x.png"
if [[ ! -f "${ICON_1024}" ]]; then
  echo "ERROR: .icns does not contain icon_512x512@2x.png (1024x1024)."
  exit 1
fi

SIZE="$(sips -g pixelWidth -g pixelHeight "${ICON_1024}" 2>/dev/null \
  | awk '/pixelWidth:/{w=$2} /pixelHeight:/{h=$2} END{print w "x" h}')"
if [[ "${SIZE}" != "1024x1024" ]]; then
  echo "ERROR: icon_512x512@2x.png is ${SIZE}, expected 1024x1024."
  exit 1
fi

ENT_XML="$(codesign -d --entitlements :- "${APP_PATH}" 2>/dev/null || true)"
if ! grep -q "<key>com.apple.security.app-sandbox</key>" <<<"${ENT_XML}"; then
  echo "ERROR: Missing com.apple.security.app-sandbox entitlement."
  exit 1
fi
if ! grep -q "<true/>" <<<"${ENT_XML}"; then
  echo "ERROR: com.apple.security.app-sandbox is not set to true."
  exit 1
fi

echo "PASS"
echo "Archive: ${ARCHIVE_PATH}"
echo "App: ${APP_PATH}"
echo "Icon 512@2x: ${SIZE}"
echo "Sandbox entitlement: enabled"

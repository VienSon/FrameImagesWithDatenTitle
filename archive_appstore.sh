#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPSTORE_DIR="$ROOT_DIR/AppStoreProject"
PROJECT_PATH="$APPSTORE_DIR/FrameMacApp.xcodeproj"
SCHEME="FrameMacApp"
ARCHIVE_PATH="$ROOT_DIR/dist-appstore/FrameMacApp.xcarchive"
EXPORT_PATH="$ROOT_DIR/dist-appstore/export"
EXPORT_OPTIONS="$APPSTORE_DIR/ExportOptions-AppStore.plist"

if [[ -f "$ROOT_DIR/.appstore.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.appstore.env"
fi

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Error: Xcode project not found at $PROJECT_PATH" >&2
  echo "Run: ./generate_xcode_project.sh" >&2
  exit 1
fi

"$ROOT_DIR/preflight_appstore.sh"

BUILD_OVERRIDES=()
[[ -n "${APPLE_TEAM_ID:-}" ]] && BUILD_OVERRIDES+=("DEVELOPMENT_TEAM=$APPLE_TEAM_ID")
[[ -n "${APP_BUNDLE_ID:-}" ]] && BUILD_OVERRIDES+=("PRODUCT_BUNDLE_IDENTIFIER=$APP_BUNDLE_ID")
[[ -n "${APP_VERSION:-}" ]] && BUILD_OVERRIDES+=("MARKETING_VERSION=$APP_VERSION")
[[ -n "${APP_BUILD:-}" ]] && BUILD_OVERRIDES+=("CURRENT_PROJECT_VERSION=$APP_BUILD")

mkdir -p "$ROOT_DIR/dist-appstore"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

TMP_EXPORT_OPTIONS="$EXPORT_OPTIONS"
if [[ -n "${APPLE_TEAM_ID:-}" ]]; then
  TMP_EXPORT_OPTIONS="$ROOT_DIR/dist-appstore/ExportOptions-AppStore.effective.plist"
  cp "$EXPORT_OPTIONS" "$TMP_EXPORT_OPTIONS"
  /usr/libexec/PlistBuddy -c "Delete :teamID" "$TMP_EXPORT_OPTIONS" >/dev/null 2>&1 || true
  /usr/libexec/PlistBuddy -c "Add :teamID string $APPLE_TEAM_ID" "$TMP_EXPORT_OPTIONS"
fi

echo "Archiving for App Store..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  "${BUILD_OVERRIDES[@]}" \
  -allowProvisioningUpdates

echo "Exporting upload package..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$TMP_EXPORT_OPTIONS" \
  -allowProvisioningUpdates

echo "Done."
echo "Archive: $ARCHIVE_PATH"
echo "Export: $EXPORT_PATH"

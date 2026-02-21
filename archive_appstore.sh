#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPSTORE_DIR="$ROOT_DIR/AppStoreProject"
PROJECT_PATH="$APPSTORE_DIR/FrameMacApp.xcodeproj"
SCHEME="FrameMacApp"
ARCHIVE_PATH="$ROOT_DIR/dist-appstore/FrameMacApp.xcarchive"
EXPORT_PATH="$ROOT_DIR/dist-appstore/export"
EXPORT_OPTIONS="$APPSTORE_DIR/ExportOptions-AppStore.plist"

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Error: Xcode project not found at $PROJECT_PATH" >&2
  echo "Run: ./generate_xcode_project.sh" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/dist-appstore"
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "Archiving for App Store..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  -allowProvisioningUpdates

echo "Exporting upload package..."
xcodebuild \
  -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS" \
  -allowProvisioningUpdates

echo "Done."
echo "Archive: $ARCHIVE_PATH"
echo "Export: $EXPORT_PATH"

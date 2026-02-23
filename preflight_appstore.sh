#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APPSTORE_DIR="$ROOT_DIR/AppStoreProject"
PROJECT_PATH="$APPSTORE_DIR/FrameMacApp.xcodeproj"
SCHEME="FrameMacApp"
ICONSET_DIR="$APPSTORE_DIR/FrameMacApp.xcassets/AppIcon.appiconset"

if [[ -f "$ROOT_DIR/.appstore.env" ]]; then
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.appstore.env"
fi

must_have_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: missing required command: $1" >&2
    exit 1
  fi
}

must_have_cmd xcodebuild
must_have_cmd plutil

if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "Error: missing Xcode project at $PROJECT_PATH" >&2
  echo "Run: ./generate_xcode_project.sh" >&2
  exit 1
fi

for file in "$APPSTORE_DIR/Info.plist" "$APPSTORE_DIR/ExportOptions-AppStore.plist" "$APPSTORE_DIR/FrameMacApp.entitlements"; do
  plutil -lint "$file" >/dev/null
  echo "OK plist: $file"
done

get_project_yml_value() {
  local key="$1"
  awk -v k="$key" '
    $1 == k ":" {
      val = $2
      sub(/^"/, "", val)
      sub(/"$/, "", val)
      print val
      exit
    }
  ' "$APPSTORE_DIR/project.yml"
}

PROJECT_BUNDLE_ID="$(get_project_yml_value PRODUCT_BUNDLE_IDENTIFIER)"
PROJECT_TEAM_ID="$(get_project_yml_value DEVELOPMENT_TEAM)"
PROJECT_VERSION="$(get_project_yml_value MARKETING_VERSION)"
PROJECT_BUILD="$(get_project_yml_value CURRENT_PROJECT_VERSION)"

EFFECTIVE_BUNDLE_ID="${APP_BUNDLE_ID:-$PROJECT_BUNDLE_ID}"
EFFECTIVE_TEAM_ID="${APPLE_TEAM_ID:-$PROJECT_TEAM_ID}"
EFFECTIVE_VERSION="${APP_VERSION:-$PROJECT_VERSION}"
EFFECTIVE_BUILD="${APP_BUILD:-$PROJECT_BUILD}"

if [[ -z "$EFFECTIVE_BUNDLE_ID" || "$EFFECTIVE_BUNDLE_ID" == local.* ]]; then
  echo "Error: set a real bundle identifier (current: '$EFFECTIVE_BUNDLE_ID')." >&2
  echo "Set APP_BUNDLE_ID in .appstore.env or update AppStoreProject/project.yml." >&2
  exit 1
fi

if [[ -z "$EFFECTIVE_TEAM_ID" ]]; then
  echo "Error: missing Apple Team ID." >&2
  echo "Set APPLE_TEAM_ID in .appstore.env or update AppStoreProject/project.yml." >&2
  exit 1
fi

if [[ ! "$EFFECTIVE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]]; then
  echo "Error: APPLE_TEAM_ID must be a 10-character Team ID (got '$EFFECTIVE_TEAM_ID')." >&2
  exit 1
fi

if [[ ! "$EFFECTIVE_VERSION" =~ ^[0-9]+(\.[0-9]+){1,2}$ ]]; then
  echo "Error: APP_VERSION/MARKETING_VERSION must look like 1.0 or 1.0.0 (got '$EFFECTIVE_VERSION')." >&2
  exit 1
fi

if [[ ! "$EFFECTIVE_BUILD" =~ ^[0-9]+$ ]]; then
  echo "Error: APP_BUILD/CURRENT_PROJECT_VERSION must be an integer (got '$EFFECTIVE_BUILD')." >&2
  exit 1
fi

required_icons=(
  icon_16x16.png
  icon_16x16@2x.png
  icon_32x32.png
  icon_32x32@2x.png
  icon_128x128.png
  icon_128x128@2x.png
  icon_256x256.png
  icon_256x256@2x.png
  icon_512x512.png
  icon_512x512@2x.png
)

for icon in "${required_icons[@]}"; do
  if [[ ! -f "$ICONSET_DIR/$icon" ]]; then
    echo "Error: missing app icon file: $ICONSET_DIR/$icon" >&2
    exit 1
  fi
done

echo "OK icons: $ICONSET_DIR"

if ! xcodebuild -project "$PROJECT_PATH" -list | rg -q "^\s+$SCHEME$"; then
  echo "Error: scheme '$SCHEME' not found in $PROJECT_PATH" >&2
  exit 1
fi

echo ""
echo "Preflight summary"
echo "- Team ID: $EFFECTIVE_TEAM_ID"
echo "- Bundle ID: $EFFECTIVE_BUNDLE_ID"
echo "- Version: $EFFECTIVE_VERSION"
echo "- Build: $EFFECTIVE_BUILD"
echo ""
echo "Preflight checks passed."

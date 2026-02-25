#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Frame Mac App"
APP_BIN_NAME="FrameMacApp"
APP_VERSION="1.0.0"
APP_BUILD="1"
BUNDLE_ID="local.vienson.frame-mac-app"
APP_CATEGORY="public.app-category.photography"
SPM_DIR="$ROOT_DIR/FrameMacApp"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
PKG_PATH="$DIST_DIR/Frame-Mac-App-AppStore.pkg"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS_FILE="$DIST_DIR/appstore-entitlements.plist"
ICON_ICNS="$ROOT_DIR/assets/AppIcon.icns"

APP_SIGN_IDENTITY=""
INSTALLER_SIGN_IDENTITY=""
PROVISIONING_PROFILE=""

usage() {
  cat <<'USAGE'
Usage:
  ./build_app_store_pkg.sh \
    --app-sign-identity "Apple Distribution: YOUR NAME (TEAMID)" \
    --installer-sign-identity "3rd Party Mac Developer Installer: YOUR NAME (TEAMID)" \
    --provisioning-profile "/abs/path/Your_Profile.provisionprofile" \
    --bundle-id "com.yourcompany.frame-mac-app" \
    --version "1.1.0" \
    --build "2"

Notes:
  - This script is for Mac App Store submission package (.pkg), not notarized DMG.
  - The provisioning profile must match bundle id + signing identity.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-sign-identity)
      APP_SIGN_IDENTITY="${2:-}"
      shift 2
      ;;
    --installer-sign-identity)
      INSTALLER_SIGN_IDENTITY="${2:-}"
      shift 2
      ;;
    --provisioning-profile)
      PROVISIONING_PROFILE="${2:-}"
      shift 2
      ;;
    --version)
      APP_VERSION="${2:-}"
      shift 2
      ;;
    --build)
      APP_BUILD="${2:-}"
      shift 2
      ;;
    --bundle-id)
      BUNDLE_ID="${2:-}"
      shift 2
      ;;
    --app-category)
      APP_CATEGORY="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$APP_SIGN_IDENTITY" || -z "$INSTALLER_SIGN_IDENTITY" || -z "$PROVISIONING_PROFILE" ]]; then
  echo "Error: missing required signing inputs." >&2
  usage
  exit 1
fi

if [[ ! -f "$PROVISIONING_PROFILE" ]]; then
  echo "Error: provisioning profile not found: $PROVISIONING_PROFILE" >&2
  exit 1
fi

if [[ ! -d "$SPM_DIR" ]]; then
  echo "Error: Swift package not found at $SPM_DIR" >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR/fonts" ]]; then
  echo "Error: fonts folder not found at $ROOT_DIR/fonts" >&2
  exit 1
fi

if [[ ! -f "$ICON_ICNS" ]]; then
  if [[ -x "$ROOT_DIR/generate_icon_icns.sh" ]]; then
    "$ROOT_DIR/generate_icon_icns.sh"
  else
    echo "Error: app icon not found at $ICON_ICNS" >&2
    exit 1
  fi
fi

mkdir -p "$DIST_DIR"

echo "Building SwiftUI app (release)..."
cd "$SPM_DIR"
swift build -c release

BIN_PATH="$SPM_DIR/.build/release/$APP_BIN_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "Error: built binary not found at $BIN_PATH" >&2
  exit 1
fi

echo "Assembling .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_BIN_NAME"
cp -R "$ROOT_DIR/fonts" "$RES_DIR/fonts"
cp "$ICON_ICNS" "$RES_DIR/AppIcon.icns"
cp "$PROVISIONING_PROFILE" "$CONTENTS_DIR/embedded.provisionprofile"
chmod +x "$MACOS_DIR/$APP_BIN_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>__APP_BIN_NAME__</string>
  <key>CFBundleIdentifier</key>
  <string>__BUNDLE_ID__</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>__APP_NAME__</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>__APP_VERSION__</string>
  <key>CFBundleVersion</key>
  <string>__APP_BUILD__</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSApplicationCategoryType</key>
  <string>__APP_CATEGORY__</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

sed -i '' \
  -e "s|__APP_BIN_NAME__|$APP_BIN_NAME|g" \
  -e "s|__BUNDLE_ID__|$BUNDLE_ID|g" \
  -e "s|__APP_NAME__|$APP_NAME|g" \
  -e "s|__APP_VERSION__|$APP_VERSION|g" \
  -e "s|__APP_BUILD__|$APP_BUILD|g" \
  -e "s|__APP_CATEGORY__|$APP_CATEGORY|g" \
  "$CONTENTS_DIR/Info.plist"

cat > "$ENTITLEMENTS_FILE" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <true/>
  <key>com.apple.security.files.user-selected.read-write</key>
  <true/>
  <key>com.apple.security.get-task-allow</key>
  <false/>
</dict>
</plist>
ENT

echo "Signing app binary..."
codesign \
  --force \
  --timestamp \
  --sign "$APP_SIGN_IDENTITY" \
  "$MACOS_DIR/$APP_BIN_NAME"

echo "Signing app bundle (App Store sandbox entitlements)..."
codesign \
  --force \
  --timestamp \
  --options runtime \
  --entitlements "$ENTITLEMENTS_FILE" \
  --sign "$APP_SIGN_IDENTITY" \
  "$APP_DIR"

echo "Verifying app signature..."
codesign --verify --deep --strict "$APP_DIR"
codesign -dv --verbose=4 "$APP_DIR" 2>&1 | sed -n '1,60p'

echo "Building signed App Store package..."
rm -f "$PKG_PATH"
productbuild \
  --component "$APP_DIR" /Applications \
  --sign "$INSTALLER_SIGN_IDENTITY" \
  "$PKG_PATH"

echo "Verifying package signature..."
pkgutil --check-signature "$PKG_PATH"

echo "Done: $PKG_PATH"
echo "Next: upload pkg in Transporter or Xcode Organizer."

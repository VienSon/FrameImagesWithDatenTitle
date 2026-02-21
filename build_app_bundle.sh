#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Frame Mac App"
APP_BIN_NAME="FrameMacApp"
APP_VERSION="1.0.0"
APP_BUILD="1"
BUNDLE_ID="local.vienson.frame-mac-app"
SPM_DIR="$ROOT_DIR/FrameMacApp"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"
ENTITLEMENTS_FILE="$DIST_DIR/entitlements.plist"
ICON_ICNS="$ROOT_DIR/assets/AppIcon.icns"

SIGN_IDENTITY="-"
RELEASE_SIGNING=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sign-identity)
      SIGN_IDENTITY="${2:-}"
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
    --release-signing)
      RELEASE_SIGNING=1
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

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
  "$CONTENTS_DIR/Info.plist"

if [[ $RELEASE_SIGNING -eq 1 ]]; then
  cat > "$ENTITLEMENTS_FILE" <<'ENT'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.allow-jit</key>
  <false/>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
  <false/>
  <key>com.apple.security.cs.disable-library-validation</key>
  <false/>
  <key>com.apple.security.cs.disable-executable-page-protection</key>
  <false/>
  <key>com.apple.security.get-task-allow</key>
  <false/>
</dict>
</plist>
ENT

  echo "Signing app bundle (Developer ID, hardened runtime)..."
  codesign \
    --force \
    --deep \
    --options runtime \
    --entitlements "$ENTITLEMENTS_FILE" \
    --timestamp \
    --sign "$SIGN_IDENTITY" \
    "$APP_DIR"
else
  echo "Signing app bundle (ad-hoc)..."
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
fi

echo "Done: $APP_DIR"
echo "Open with: open \"$APP_DIR\""

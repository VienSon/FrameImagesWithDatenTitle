#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Frame Mac App"
SPM_DIR="$ROOT_DIR/FrameMacApp"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"

if [[ ! -d "$SPM_DIR" ]]; then
  echo "Error: Swift package not found at $SPM_DIR" >&2
  exit 1
fi

if [[ ! -d "$ROOT_DIR/venv-gui" ]]; then
  echo "Error: required venv not found at $ROOT_DIR/venv-gui" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"

echo "Building SwiftUI app (release)..."
cd "$SPM_DIR"
swift build -c release

BIN_PATH="$SPM_DIR/.build/release/FrameMacApp"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "Error: built binary not found at $BIN_PATH" >&2
  exit 1
fi

echo "Assembling .app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/FrameMacApp"
cp "$ROOT_DIR/frame-backend-bundled" "$RES_DIR/frame-backend"
cp "$ROOT_DIR/frame_backend_api.py" "$RES_DIR/frame_backend_api.py"
cp "$ROOT_DIR/frame_auto_date_title.py" "$RES_DIR/frame_auto_date_title.py"
cp -R "$ROOT_DIR/fonts" "$RES_DIR/fonts"
# Resolve symlinks inside venv so the app bundle is self-contained.
cp -R -L "$ROOT_DIR/venv-gui" "$RES_DIR/venv-gui"
chmod +x "$RES_DIR/frame-backend" "$MACOS_DIR/FrameMacApp"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>FrameMacApp</string>
  <key>CFBundleIdentifier</key>
  <string>local.vienson.frame-mac-app</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Frame Mac App</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "Signing app bundle (ad-hoc)..."
codesign --force --deep --sign - "$APP_DIR"

echo "Done: $APP_DIR"
echo "Open with: open \"$APP_DIR\""
